// SPDX-License-Identifier: MIT

module nft::collectible {
    use nft::{attributes::{Self, Attribute}, errors, registry::Registry};
    use std::{hash::sha2_256, string::{Self, String}};
    use sui::{
        borrow::{Self, Referent, Borrow},
        display::{Self, Display},
        dynamic_object_field as dyn_field,
        event::emit,
        package::{Self, Publisher},
        transfer_policy::{Self as policy, TransferPolicyCap},
        vec_map::{Self as map, VecMap}
    };

    public struct Meta_borrow {
        collectible_id: ID,
    }

    public struct Config has copy, store {
        // Max mintable collectibles
        max_supply: Option<u32>,
        // How many collectibles have been minted
        minted: u32,
        // How many collectibles have been burned
        burned: u32,
        // If the collection is owned by the creator
        owned: bool,
        // If the collection is burnable
        burnable: bool,
        // If the collection is dynamic and attributes can be equipped or unequipped
        dynamic: bool,
        // If the meta is borrowable, if true consider the risks of it and its usecase
        meta_borrowable: bool,
    }

    public struct Collection<T: store> has key, store {
        id: UID,
        // Stored objects
        publisher: Referent<Publisher>,
        display_collectible: Referent<Display<Collectible<T>>>,
        display_attribute: Referent<Display<Attribute<T>>>,
        policy_cap_collectible: Referent<TransferPolicyCap<Collectible<T>>>,
        policy_cap_attribute: Referent<TransferPolicyCap<Attribute<T>>>,
        // Data fields
        attribute_fields: vector<String>,
        banner_url: String,
        creator: Option<String>,
        config: Config,
    }

    public struct CollectionCap<phantom T: store> has key, store {
        id: UID,
        collection: ID,
    }

    public struct CollectionTicket<phantom T: store> has key, store {
        id: UID,
        publisher: Publisher,
        max_supply: Option<u32>,
    }

    public struct Collectible<T: store> has key, store {
        id: UID,
        image_url: String,
        name: String,
        description: String,
        equipped: VecMap<String, ID>,
        attributes: VecMap<String, String>,
        meta: Option<T>,
    }

    // ===================== Events =====================

    public struct TicketClaimed has copy, drop {
        ticket_id: ID,
        creator: address,
    }

    public struct CollectionCreated has copy, drop {
        collection_id: ID,
        collection_cap_id: ID,
        max_supply: Option<u32>,
        creator: address,
        attributes_fields: vector<String>,
        banner_url: String,
        dynamic: bool,
        burnable: bool,
    }

    public struct CollectibleMinted has copy, drop {
        collection_id: ID,
        collectible_id: ID,
        image_url: String,
        name: Option<String>,
        description: Option<String>,
        attributes: VecMap<String, String>,
        equipped: VecMap<String, ID>,
    }

    public struct RevokeOwnership has copy, drop {
        collection_id: ID,
        collection_cap_id: ID,
    }

    public struct DestroyCollectible has copy, drop {
        collection_id: ID,
        collectible_id: ID,
    }

    public struct EditMade has copy, drop {
        item_id: ID,
        edit_name: String,
        edit_value: String,
    }

    /// Called in the external module initializer. Sends a `CollectionTicket`
    /// to the transaction sender which then enables them to initialize the
    /// Collection.
    ///
    /// - The OTW parameter is a One-Time-Witness;
    /// - The T parameter is the expected Metadata / custom type to use for
    /// the Collection;
    #[allow(lint(self_transfer))]
    public fun claim_ticket<OTW: drop, T: store>(
        otw: OTW,
        max_supply: Option<u32>,
        ctx: &mut TxContext,
    ) {
        assert!(sui::types::is_one_time_witness(&otw), errors::notOneTimeWitness!());
        let sender = ctx.sender();

        let publisher = package::claim(otw, ctx);

        assert!(package::from_module<T>(&publisher), errors::typeNotFromModule!());
        let ticket = CollectionTicket<T> {
            id: object::new(ctx),
            publisher,
            max_supply,
        };

        emit(TicketClaimed {
            ticket_id: object::id(&ticket),
            creator: sender,
        });

        transfer::transfer(ticket, sender);
    }

    #[allow(lint(share_owned))]
    public fun create_collection<T: store>(
        ticket: CollectionTicket<T>,
        registry: &Registry,
        banner_url: String,
        fields: vector<String>,
        creator: Option<String>,
        dynamic: bool,
        burnable: bool,
        meta_borrowable: bool,
        ctx: &mut TxContext,
    ): (Collection<T>, CollectionCap<T>) {
        let CollectionTicket { id, publisher, max_supply } = ticket;
        object::delete(id);

        let mut display_collectible = display::new<Collectible<T>>(
            registry.borrow_publisher(),
            ctx,
        );
        let display_attribute = display::new<Attribute<T>>(registry.borrow_publisher(), ctx);
        let (policy_collectible, policy_cap_collectible) = policy::new<Collectible<T>>(
            registry.borrow_publisher(),
            ctx,
        );
        let (policy_attribute, policy_cap_attribute) = policy::new<Attribute<T>>(
            registry.borrow_publisher(),
            ctx,
        );

        display_collectible.add(b"name".to_string(), b"{name}".to_string());
        display_collectible.add(b"image_url".to_string(), b"image_url".to_string());
        display_collectible.add(b"description".to_string(), b"{description}".to_string());
        display_collectible.add(b"attributes".to_string(), b"{attributes}".to_string());
        display_collectible.add(b"equipped".to_string(), b"{equipped}".to_string());
        display_collectible.update_version();

        transfer::public_share_object(policy_collectible);
        transfer::public_share_object(policy_attribute);

        let config = Config {
            max_supply,
            minted: 0,
            burned: 0,
            owned: true,
            burnable,
            dynamic,
            meta_borrowable,
        };

        let collection = Collection<T> {
            id: object::new(ctx),
            display_collectible: borrow::new(display_collectible, ctx),
            display_attribute: borrow::new(display_attribute, ctx),
            policy_cap_collectible: borrow::new(policy_cap_collectible, ctx),
            policy_cap_attribute: borrow::new(policy_cap_attribute, ctx),
            publisher: borrow::new(publisher, ctx),
            banner_url,
            attribute_fields: fields,
            creator,
            config,
        };

        let cap = CollectionCap<T> {
            id: object::new(ctx),
            collection: object::id(&collection),
        };

        emit(CollectionCreated {
            collection_id: object::id(&collection),
            collection_cap_id: object::id(&cap),
            max_supply,
            creator: ctx.sender(),
            attributes_fields: fields,
            banner_url,
            dynamic,
            burnable,
        });
        (collection, cap)
    }

    // === Minting ===

    /// Mint a single Collectible specifying the fields.
    /// Can only be performed by the owner of the `CollectionCap`.
    public fun mint<T: store>(
        collection: &mut Collection<T>,
        cap: &CollectionCap<T>,
        name: Option<String>,
        image_url: String,
        description: Option<String>,
        attribute_items: Option<vector<Attribute<T>>>,
        meta: Option<T>,
        ctx: &mut TxContext,
    ): Collectible<T> {
        cap.assert_correct_collection(collection.id.to_inner());
        assert!(
            option::is_none(&collection.config.max_supply) || *option::borrow(&collection.config.max_supply) > collection.config.minted,
            errors::capReached!(),
        );
        collection.config.minted = collection.config.minted + 1;
        let empty_string = string::utf8(b"");

        let mut item = Collectible {
            id: object::new(ctx),
            image_url,
            name: name.destroy_with_default<String>(empty_string),
            description: description.destroy_with_default<String>(empty_string),
            attributes: map::empty<String, String>(),
            equipped: map::empty<String, ID>(),
            meta,
        };

        if (attribute_items.is_some()) {
            let att_items: vector<Attribute<T>> = attribute_items.destroy_some();
            att_items.do!(|att_item| { item.internal_join_attribute<T>(collection, att_item); });
        } else {
            option::destroy_none(attribute_items);
        };

        emit(CollectibleMinted {
            collection_id: object::id(collection),
            collectible_id: object::id(&item),
            image_url,
            name,
            description,
            attributes: item.attributes,
            equipped: item.equipped,
        });

        item
    }

    public fun mint_attribute<T: store>(
        collection: &mut Collection<T>,
        cap: &CollectionCap<T>,
        image_url: Option<String>,
        key: String,
        value: String,
        meta: Option<T>,
        ctx: &mut TxContext,
    ): Attribute<T> {
        cap.assert_correct_collection(collection.id.to_inner());
        collection.assert_attribute_check(&key);

        attributes::new(
            image_url,
            key,
            value,
            collection.id.to_inner(),
            meta,
            collection.config.meta_borrowable,
            ctx,
        )
    }

    // =============== Attribute Functions ============
    // === Validations ===

    public fun join_attribute<T: store>(
        collectible: &mut Collectible<T>,
        collection: &mut Collection<T>,
        attribute: Attribute<T>,
        _: &mut TxContext,
    ) {
        collection.assert_dynamic();
        collectible.internal_join_attribute<T>(collection, attribute);
    }

    public fun split_attribute<T: store>(
        collectible: &mut Collectible<T>,
        collection: &mut Collection<T>,
        key: String,
        _: &mut TxContext,
    ): Attribute<T> {
        collection.assert_dynamic();
        collectible.internal_split_attribute<T>(collection, key)
    }

    public fun create_attribute_hash<T: store>(
        collection: &Collection<T>,
        keys: vector<String>,
        values: vector<String>,
    ): vector<u8> {
        assert!(&keys.length() == &values.length(), errors::notSameLength!());
        assert!(collection.attribute_fields.length() != 0, errors::doesNotHaveAttributes!());
        let types = collection.attribute_fields;
        let mut attribute_hash = vector<u8>[];

        keys.zip_do!(values, |key, value| {
            assert!(types.contains(&key), errors::attributeNotAllowed!());
            attribute_hash.append(string::into_bytes(value));
        });

        sha2_256(attribute_hash)
    }

    public fun validate_attribute<T: key + store>(
        collectible: &Collectible<T>,
        hashed_attribute: vector<u8>,
        keys: vector<String>,
    ): bool {
        let mut attribute_hash = vector<u8>[];

        keys.do!(|key| {
            let attribute: &Attribute<T> = dyn_field::borrow(&collectible.id, key);
            attribute_hash.append(string::into_bytes(attribute.into_value()));
        });

        sha2_256(attribute_hash) == hashed_attribute
    }

    // ================ Edit methods ==================
    public fun edit_banner<T: store>(
        collection: &mut Collection<T>,
        cap: &CollectionCap<T>,
        banner_url: String,
    ) {
        cap.assert_correct_collection(collection.id.to_inner());

        collection.banner_url = banner_url;
        emit(EditMade {
            item_id: object::id(collection),
            edit_name: string::utf8(b"banner_url"),
            edit_value: banner_url,
        });
    }

    // ================ Borrowing methods ==================

    public fun borrow_mut_policy_cap_collectible<T: store>(
        self: &mut Collection<T>,
        _: &CollectionCap<T>,
    ): (TransferPolicyCap<Collectible<T>>, Borrow) {
        borrow::borrow(&mut self.policy_cap_collectible)
    }

    public fun return_policy_cap_collectible<T: store>(
        self: &mut Collection<T>,
        cap: TransferPolicyCap<Collectible<T>>,
        borrow: Borrow,
    ) {
        borrow::put_back(&mut self.policy_cap_collectible, cap, borrow)
    }

    public fun borrow_mut_policy_cap_attribute<T: store>(
        self: &mut Collection<T>,
        _: &CollectionCap<T>,
    ): (TransferPolicyCap<Attribute<T>>, Borrow) {
        borrow::borrow(&mut self.policy_cap_attribute)
    }

    public fun return_policy_cap_attribute<T: store>(
        self: &mut Collection<T>,
        cap: TransferPolicyCap<Attribute<T>>,
        borrow: Borrow,
    ) {
        borrow::put_back(&mut self.policy_cap_attribute, cap, borrow)
    }

    public fun borrow_mut_display_collectible<T: store>(
        self: &mut Collection<T>,
        _: &CollectionCap<T>,
    ): (Display<Collectible<T>>, Borrow) {
        borrow::borrow(&mut self.display_collectible)
    }

    /// Return the `Display` to the `CollectionCap`. Must be called if
    /// the capability was borrowed, or a transaction would fail.
    public fun return_display_collectible<T: store>(
        self: &mut Collection<T>,
        display: Display<Collectible<T>>,
        borrow: Borrow,
    ) {
        borrow::put_back(&mut self.display_collectible, display, borrow)
    }

    public fun borrow_mut_display_attribute<T: store>(
        self: &mut Collection<T>,
        _: &CollectionCap<T>,
    ): (Display<Attribute<T>>, Borrow) {
        borrow::borrow(&mut self.display_attribute)
    }

    /// Return the `Display` to the `CollectionCap`. Must be called if
    /// the capability was borrowed, or a transaction would fail.
    public fun return_display_attribute<T: store>(
        self: &mut Collection<T>,
        display: Display<Attribute<T>>,
        borrow: Borrow,
    ) {
        borrow::put_back(&mut self.display_attribute, display, borrow)
    }

    /// Take the `Publisher` from the `CollectionCap`.
    public fun borrow_mut_publisher<T: store>(
        self: &mut Collection<T>,
        _: &CollectionCap<T>,
    ): (Publisher, Borrow) {
        borrow::borrow(&mut self.publisher)
    }

    /// Return the `Publisher` to the `CollectionCap`. Must be called if
    /// the capability was borrowed, or a transaction would fail.
    public fun return_publisher<T: store>(
        self: &mut Collection<T>,
        publisher: Publisher,
        borrow: Borrow,
    ) {
        borrow::put_back(&mut self.publisher, publisher, borrow)
    }

    public fun borrow_meta<T: store>(collectible: &Collectible<T>): &Option<T> {
        &collectible.meta
    }

    public fun borrow_mut_meta<T: store>(
        collectible: &mut Collectible<T>,
        collection: &Collection<T>,
    ): (T, Meta_borrow) {
        assert!(collection.is_meta_borrowable(), errors::notMetaBorrowable!());
        let meta: T = collectible.meta.extract();
        (meta, Meta_borrow { collectible_id: object::id(collectible) })
    }

    public fun return_meta<T: store>(
        collectible: &mut Collectible<T>,
        meta: T,
        borrow: Meta_borrow,
    ) {
        let Meta_borrow { collectible_id } = borrow;
        assert!(collectible_id == object::id(collectible), errors::wrongCollectible!());
        collectible.meta.fill(meta);
    }

    // === Burn ===
    public fun destroy_collectible<T: store>(
        self: &mut Collection<T>,
        _: &CollectionCap<T>,
        collectible: Collectible<T>,
    ): Option<T> {
        let Collectible<T> { id, meta, .. } = collectible;
        emit(DestroyCollectible {
            collection_id: object::id(self),
            collectible_id: id.to_inner(),
        });
        id.delete();
        self.config.burned = self.config.burned + 1;
        meta
    }

    public fun revoke_ownership<T: store>(cap: CollectionCap<T>, collection: &mut Collection<T>) {
        let collection_id = object::id(collection);
        cap.assert_correct_collection(collection_id);

        collection.config.owned = false;
        let CollectionCap<T> { id, .. } = cap;
        emit(RevokeOwnership {
            collection_id: collection_id,
            collection_cap_id: id.to_inner(),
        });
        id.delete();
    }

    // ================= View functions ========================
    // === Collection ===
    public fun get_max_supply<T: store>(collection: &Collection<T>): Option<u32> {
        collection.config.max_supply
    }

    public fun get_minted<T: store>(collection: &Collection<T>): u32 {
        collection.config.minted
    }

    public fun get_banner_url<T: store>(collection: &Collection<T>): String {
        collection.banner_url
    }

    public fun get_attribute_fields<T: store>(collection: &Collection<T>): vector<String> {
        collection.attribute_fields
    }

    public fun get_collection_id_by_cap<T: store>(cap: &CollectionCap<T>): ID {
        cap.collection
    }

    public fun get_burned<T: store>(collection: &Collection<T>): (bool, u32) {
        (collection.config.burnable, collection.config.burned)
    }

    public fun is_dynamic<T: store>(collection: &Collection<T>): bool {
        collection.config.dynamic
    }

    public fun is_meta_borrowable<T: store>(collection: &Collection<T>): bool {
        collection.config.meta_borrowable
    }

    public fun get_creator<T: store>(collection: &Collection<T>): String {
        if (collection.creator.is_some()) {
            *option::borrow(&collection.creator)
        } else {
            string::utf8(b"")
        }
    }

    // === Collectible ===
    public fun get_image_url<T: store>(collectible: &Collectible<T>): String {
        collectible.image_url
    }

    public fun get_name<T: store>(collectible: &Collectible<T>): String {
        collectible.name
    }

    public fun get_description<T: store>(collectible: &Collectible<T>): String {
        collectible.description
    }

    public fun get_attribute_map<T: store>(collectible: &Collectible<T>): VecMap<String, String> {
        collectible.attributes
    }

    public fun get_equipped_map<T: store>(collectible: &Collectible<T>): VecMap<String, ID> {
        collectible.equipped
    }

    // ================= Internal =======================
    fun internal_join_attribute<T: store>(
        collectible: &mut Collectible<T>,
        collection: &Collection<T>,
        attribute: Attribute<T>,
    ) {
        assert!(
            collection.attribute_fields.contains(&attribute.into_key()),
            errors::attributeNotAllowed!(),
        );
        assert!(
            !dyn_field::exists_(&collectible.id, attribute.into_key()),
            errors::attributeTypeAlreadyExists!(),
        );

        attribute.emit_joined(object::id(collectible));

        collectible.equipped.insert(attribute.into_key(), object::id(&attribute));
        collectible.attributes.insert(attribute.into_key(), attribute.into_value());

        dyn_field::add(&mut collectible.id, attribute.into_key(), attribute);
    }

    fun internal_split_attribute<T: store>(
        collectible: &mut Collectible<T>,
        collection: &Collection<T>,
        key: String,
    ): Attribute<T> {
        assert!(collection.attribute_fields.contains(&key), errors::attributeNotAllowed!());
        assert!(dyn_field::exists_(&collectible.id, key), errors::attributeTypeAlreadyExists!());

        collectible.attributes.remove(&key);
        collectible.equipped.remove(&key);

        let attribute: Attribute<T> = dyn_field::remove(&mut collectible.id, key);
        attribute.emit_split(object::id(collectible));

        attribute
    }

    fun assert_correct_collection<T: store>(self: &CollectionCap<T>, id: ID) {
        assert!(self.collection == id, errors::wrongCollection!());
    }

    fun assert_attribute_check<T: store>(self: &Collection<T>, key: &String) {
        assert!(self.attribute_fields.contains(key), errors::attributeNotAllowed!());
    }

    fun assert_dynamic<T: store>(self: &Collection<T>) {
        assert!(self.config.dynamic, errors::notDynamic!());
    }
}
