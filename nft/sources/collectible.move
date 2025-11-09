// SPDX-License-Identifier: MIT

module nft::collectible;

use nft::{attributes::{Self, Attribute}, errors, registry::Registry, render_fee_rule};
use std::{hash::sha2_256, option::some, string::{Self, String}};
use sui::{
    coin::Coin,
    display::{Self, Display},
    dynamic_object_field as dof,
    event::emit,
    package::{Self, Publisher},
    sui::SUI,
    transfer_policy::{Self as policy, TransferPolicy, TransferRequest},
    vec_map::{Self as map, VecMap}
};

public struct MetaBorrow {
    collectible_id: ID,
    meta_id: ID,
}

public struct RenderNode {
    attribute_id: ID,
    nft_id: ID,
    old_nft_image_url: String,
}

public struct CollectionBorrow {
    collection_id: ID,
    meta_id: ID,
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
    // If true, only predefined attributes from the schema are allowed
    strict_schema: bool,
    // If the meta is borrowable, if true consider the risks of it and its usecase
    meta_borrowable: bool,
}

public struct Collection<phantom T: store> has key, store {
    id: UID,
    // Data fields
    dof_list: vector<ID>,
    attribute_fields: VecMap<String, vector<String>>,
    banner_url: Option<String>,
    cover_url: Option<String>,
    creator: Option<String>,
    config: Config,
}

public struct CollectionCap<phantom T: store> has key, store {
    id: UID,
    collection: ID,
}

public struct RenderCap<phantom T: store> has key, store {
    id: UID,
    collection: ID,
}

public struct CollectionTicket<phantom T: store> has key, store {
    id: UID,
    publisher: Publisher,
    max_supply: Option<u32>,
}

public struct Collectible<phantom T: store> has key, store {
    id: UID,
    image_url: String,
    name: String,
    description: String,
    equipped: VecMap<String, ID>,
    attributes: VecMap<String, String>,
    dof_list: vector<ID>,
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
    banner_url: Option<String>,
    cover_url: Option<String>,
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
    banner_url: Option<String>,
    cover_url: Option<String>,
    fields: VecMap<String, vector<String>>,
    creator: Option<String>,
    dynamic: bool,
    burnable: bool,
    strict_schema: bool,
    meta_borrowable: bool,
    ctx: &mut TxContext,
): (CollectionCap<T>, Option<RenderCap<T>>) {
    let CollectionTicket { id, publisher, max_supply } = ticket;
    object::delete(id);

    let mut display_collectible = display::new<Collectible<T>>(
        registry.borrow_publisher(),
        ctx,
    );
    let display_attribute = display::new<Attribute<T>>(
        registry.borrow_publisher(),
        ctx,
    );
    let (policy_collectible, policy_cap_collectible) = policy::new<Collectible<T>>(
        registry.borrow_publisher(),
        ctx,
    );
    let (policy_attribute, policy_cap_attribute) = policy::new<Attribute<T>>(
        registry.borrow_publisher(),
        ctx,
    );

    let collection_uid = object::new(ctx);
    let collection_id = collection_uid.to_inner();
    setup_collectible_display<T>(&mut display_collectible, collection_id);

    transfer::public_share_object(policy_collectible);
    transfer::public_share_object(policy_attribute);

    let config = Config {
        max_supply,
        minted: 0,
        burned: 0,
        owned: true,
        burnable,
        dynamic,
        strict_schema,
        meta_borrowable,
    };

    let mut collection = Collection<T> {
        id: collection_uid,
        dof_list: vector[
            object::id(&display_collectible),
            object::id(&display_attribute),
            object::id(&policy_cap_collectible),
            object::id(&policy_cap_attribute),
            object::id(&publisher),
        ],
        cover_url,
        banner_url,
        attribute_fields: fields,
        creator,
        config,
    };
    dof::add(
        &mut collection.id,
        object::id(&display_collectible),
        display_collectible,
    );
    dof::add(
        &mut collection.id,
        object::id(&display_attribute),
        display_attribute,
    );
    dof::add(
        &mut collection.id,
        object::id(&policy_cap_collectible),
        policy_cap_collectible,
    );
    dof::add(
        &mut collection.id,
        object::id(&policy_cap_attribute),
        policy_cap_attribute,
    );
    dof::add(
        &mut collection.id,
        object::id(&publisher),
        publisher,
    );

    let cap = CollectionCap<T> {
        id: object::new(ctx),
        collection: collection_id,
    };

    emit(CollectionCreated {
        collection_id,
        collection_cap_id: object::id(&cap),
        max_supply,
        creator: ctx.sender(),
        attributes_fields: vector[],
        banner_url,
        cover_url,
        dynamic,
        burnable,
    });
    transfer::share_object(collection);
    if (dynamic) {
        (
            cap,
            option::some(RenderCap<T> {
                id: object::new(ctx),
                collection: collection_id,
            }),
        )
    } else {
        (cap, option::none())
    }
}

// === Minting ===

/// Mint a single Collectible specifying the fields.
/// Can only be performed by the owner of the `CollectionCap`.
public fun mint<T: store, Meta: key + store>(
    collection: &mut Collection<T>,
    cap: &CollectionCap<T>,
    name: Option<String>,
    image_url: String,
    description: Option<String>,
    attribute_items: Option<vector<Attribute<T>>>,
    meta: Option<Meta>,
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
        dof_list: vector<ID>[],
    };

    meta.do!(|meta| {
        item.dof_list.push_back(object::id(&meta));
        dof::add(
            &mut item.id,
            object::id(&meta),
            meta,
        );
    });

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

public fun mint_attribute<T: store, AttributeMeta: key + store>(
    collection: &mut Collection<T>,
    cap: &CollectionCap<T>,
    image_url: Option<String>,
    key: String,
    value: String,
    meta: Option<AttributeMeta>,
    ctx: &mut TxContext,
): Attribute<T> {
    cap.assert_correct_collection(collection.id.to_inner());
    collection.assert_attribute_check(&key);

    if (!collection.config.strict_schema) {
        if (!collection.attribute_fields.contains(&key)) {
            collection.attribute_fields.insert(key, vector[value]);
        } else {
            // Get the current values for this key and add the new value if it doesn't exist
            let current_values = collection.attribute_fields.get(&key);
            if (!current_values.contains(&value)) {
                // Create a new vector with the existing values plus the new value
                let mut new_values = vector[];
                let mut i = 0;
                while (i < current_values.length()) {
                    new_values.push_back(current_values[i]);
                    i = i + 1;
                };
                new_values.push_back(value);
                // Remove the old entry and insert the updated one
                collection.attribute_fields.remove(&key);
                collection.attribute_fields.insert(key, new_values);
            };
        };
    };

    attributes::new<T, AttributeMeta>(
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
): RenderNode {
    collection.assert_dynamic();
    let node = RenderNode {
        attribute_id: object::id(&attribute),
        nft_id: collectible.id.to_inner(),
        old_nft_image_url: collectible.image_url,
    };
    collectible.internal_join_attribute<T>(collection, attribute);
    node
}

public fun split_attribute<T: store>(
    collectible: &mut Collectible<T>,
    collection: &mut Collection<T>,
    key: String,
    _: &mut TxContext,
): (RenderNode, Attribute<T>) {
    collection.assert_dynamic();
    let attribute = collectible.internal_split_attribute<T>(collection, key);
    let node = RenderNode {
        attribute_id: object::id(&attribute),
        nft_id: collectible.id.to_inner(),
        old_nft_image_url: collectible.image_url,
    };
    (node, attribute)
}

public fun update_image<T: store>(
    collectible: &mut Collectible<T>,
    collection: &mut Collection<T>,
    policy: &mut TransferPolicy<Collectible<T>>,
    request: &mut TransferRequest<Collectible<T>>,
    payment: Coin<SUI>,
    attribute_id: ID,
    new_image_url: String,
    render_node: RenderNode,
    _: &mut TxContext,
) {
    collection.assert_dynamic();

    let RenderNode { attribute_id: attr_id, nft_id, old_nft_image_url } = render_node;
    assert!(attribute_id == attr_id);
    assert!(nft_id == collectible.id.to_inner());
    assert!(old_nft_image_url == collectible.image_url && new_image_url != old_nft_image_url);
    render_fee_rule::pay(policy, request, payment);
    collectible.image_url = new_image_url;
}

public fun create_attribute_hash<T: store>(
    collection: &Collection<T>,
    keys: vector<String>,
    values: vector<String>,
): vector<u8> {
    assert!(&keys.length() == &values.length(), errors::notSameLength!());
    assert!(!map::is_empty(&collection.attribute_fields), errors::doesNotHaveAttributes!());
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
        let attribute: &Attribute<T> = dof::borrow(&collectible.id, key);
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

    collection.banner_url = some(banner_url);
    emit(EditMade {
        item_id: object::id(collection),
        edit_name: string::utf8(b"banner_url"),
        edit_value: banner_url,
    });
}

// ================ Borrowing methods ==================

public fun add_collection_meta<T: store, meta: key + store>(
    self: &mut Collection<T>,
    _cap: &CollectionCap<T>,
    meta: meta,
) {
    self.dof_list.push_back(object::id(&meta));
    dof::add(&mut self.id, object::id(&meta), meta);
}

public fun borrow_mut_collection_meta<T: store, meta: key + store>(
    self: &mut Collection<T>,
    meta_id: ID,
    _: &CollectionCap<T>,
): (meta, CollectionBorrow) {
    (
        dof::remove(&mut self.id, meta_id),
        CollectionBorrow {
            collection_id: object::id(self),
            meta_id,
        },
    )
}

public fun return_collection_meta<T: store, meta: key + store>(
    self: &mut Collection<T>,
    meta: meta,
    borrow: CollectionBorrow,
) {
    let CollectionBorrow { collection_id, meta_id } = borrow;
    assert!(collection_id == object::id(self), errors::wrongCollection!());
    assert!(object::id(&meta) == meta_id, errors::wrongId!());
    dof::add(&mut self.id, meta_id, meta);
}

public fun remove_collection_meta<T: store, meta: key + store>(
    self: &mut Collection<T>,
    meta_id: ID,
): meta {
    let (found, index) = self.dof_list.index_of(&meta_id);
    assert!(found, errors::wrongId!());
    self.dof_list.remove(index);
    dof::remove(&mut self.id, meta_id)
}

// === Collectible Meta ===

public fun add_collectible_meta<T: store, meta: key + store>(
    collectible: &mut Collectible<T>,
    _cap: &CollectionCap<T>,
    meta: meta,
) {
    collectible.dof_list.push_back(object::id(&meta));
    dof::add(&mut collectible.id, object::id(&meta), meta);
}

public fun borrow_collectible_meta<T: store, meta: key + store>(
    collectible: &Collectible<T>,
    _cap: &CollectionCap<T>,
    meta_id: ID,
): &meta {
    dof::borrow(&collectible.id, meta_id)
}

public fun borrow_mut_collectible_meta<T: store, meta: key + store>(
    collectible: &mut Collectible<T>,
    meta_id: ID,
): (meta, MetaBorrow) {
    (
        dof::remove(&mut collectible.id, meta_id),
        MetaBorrow {
            collectible_id: object::id(collectible),
            meta_id,
        },
    )
}

public fun return_collectible_meta<T: store, meta: key + store>(
    collectible: &mut Collectible<T>,
    meta: meta,
    borrow: MetaBorrow,
) {
    let MetaBorrow { collectible_id, meta_id } = borrow;
    assert!(collectible_id == object::id(collectible), errors::wrongCollectible!());
    assert!(object::id(&meta) == meta_id, errors::wrongId!());
    dof::add(&mut collectible.id, object::id(&meta), meta);
}

public fun remove_collectible_meta<T: store, meta: key + store>(
    collectible: &mut Collectible<T>,
    meta_id: ID,
): meta {
    let (found, index) = collectible.dof_list.index_of(&meta_id);
    assert!(found, errors::wrongId!());
    collectible.dof_list.remove(index);
    dof::remove(&mut collectible.id, meta_id)
}

// === Burn ===
public fun destroy_collectible<T: store>(
    self: &mut Collection<T>,
    _: &CollectionCap<T>,
    collectible: Collectible<T>,
) {
    let Collectible { id, dof_list, .. } = collectible;
    assert!(self.config.burnable, errors::notBurnable!());
    assert!(dof_list.is_empty(), errors::listNotEmpty!());

    emit(DestroyCollectible {
        collection_id: object::id(self),
        collectible_id: id.to_inner(),
    });
    id.delete();
    self.config.burned = self.config.burned + 1;
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
public fun get_max_supply<T: store>(self: &Collection<T>): Option<u32> {
    self.config.max_supply
}

public fun get_minted<T: store>(self: &Collection<T>): u32 {
    self.config.minted
}

public fun get_banner_url<T: store>(self: &Collection<T>): Option<String> {
    self.banner_url
}

public fun get_attribute_fields<T: store>(self: &Collection<T>): VecMap<String, vector<String>> {
    self.attribute_fields
}

public fun get_collection_id_by_cap<T: store>(self: &CollectionCap<T>): ID {
    self.collection
}

public fun get_burned<T: store>(self: &Collection<T>): (bool, u32) {
    (self.config.burnable, self.config.burned)
}

public fun is_dynamic<T: store>(self: &Collection<T>): bool {
    self.config.dynamic
}

public fun get_creator<T: store>(self: &Collection<T>): String {
    if (self.creator.is_some()) {
        *option::borrow(&self.creator)
    } else {
        string::utf8(b"")
    }
}

public fun get_collection_dof_list<T: store>(self: &Collection<T>): vector<ID> {
    self.dof_list
}

// === Collectible ===
public fun get_image_url<T: store>(self: &Collectible<T>): String {
    self.image_url
}

public fun get_name<T: store>(self: &Collectible<T>): String {
    self.name
}

public fun get_description<T: store>(self: &Collectible<T>): String {
    self.description
}

public fun get_attribute_map<T: store>(self: &Collectible<T>): VecMap<String, String> {
    self.attributes
}

public fun get_equipped_map<T: store>(self: &Collectible<T>): VecMap<String, ID> {
    self.equipped
}

public fun get_collectible_dof_list<T: store>(self: &Collectible<T>): vector<ID> {
    self.dof_list
}

// ================= Internal =======================
fun internal_join_attribute<T: store>(
    self: &mut Collectible<T>,
    collection: &Collection<T>,
    attribute: Attribute<T>,
) {
    assert!(!dof::exists_(&self.id, attribute.into_key()), errors::attributeTypeAlreadyExists!());

    collection.assert_attribute_check(&attribute.into_key());

    attribute.emit_joined(object::id(self));

    self.equipped.insert(attribute.into_key(), object::id(&attribute));
    self.attributes.insert(attribute.into_key(), attribute.into_value());

    dof::add(&mut self.id, attribute.into_key(), attribute);
}

fun internal_split_attribute<T: store>(
    self: &mut Collectible<T>,
    collection: &Collection<T>,
    key: String,
): Attribute<T> {
    assert!(dof::exists_(&self.id, key), errors::attributeTypeAlreadyExists!());

    collection.assert_attribute_check(&key);

    self.attributes.remove(&key);
    self.equipped.remove(&key);

    let attribute: Attribute<T> = dof::remove(&mut self.id, key);
    attribute.emit_split(object::id(self));

    attribute
}

fun setup_collectible_display<T: store>(display: &mut Display<Collectible<T>>, collection_id: ID) {
    display.add(b"collection_id".to_string(), collection_id.to_address().to_string());
    display.add(b"name".to_string(), b"{name}".to_string());
    display.add(b"image_url".to_string(), b"{image_url}".to_string());
    display.add(b"description".to_string(), b"{description}".to_string());
    display.add(b"attributes".to_string(), b"{attributes}".to_string());
    display.add(b"equipped".to_string(), b"{equipped}".to_string());
    display.update_version();
}

fun assert_correct_collection<T: store>(self: &CollectionCap<T>, id: ID) {
    assert!(self.collection == id, errors::wrongCollection!());
}

fun assert_attribute_check<T: store>(self: &Collection<T>, key: &String) {
    if (self.config.strict_schema) {
        // Validate against predefined schema
        assert!(self.attribute_fields.contains(key), errors::attributeNotAllowed!());
        return
    };
    // If not strict schema, allow any attributes (no validation needed)
}

fun assert_dynamic<T: store>(self: &Collection<T>) {
    assert!(self.config.dynamic, errors::notDynamic!());
}
