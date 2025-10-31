// SPDX-License-Identifier: MIT

module nft::collectible;

use nft::{attributes::{Self, Attribute}, errors, registry::Registry, render_fee_rule};
use std::{hash::sha2_256, string::{Self, String}};
use sui::{
    borrow::{Self, Referent, Borrow},
    coin::{Self, Coin},
    display::{Self, Display},
    dynamic_object_field as dyn_field,
    event::emit,
    package::{Self, Publisher},
    sui::SUI,
    transfer_policy::{Self as policy, TransferPolicyCap, TransferPolicy, TransferRequest},
    vec_map::{Self as map, VecMap}
};

public struct Meta_borrow {
    collectible_id: ID,
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

public struct CollectibleMinted has copy, drop {
    collection_id: ID,
    collectible_id: ID,
    image_url: String,
    name: Option<String>,
    description: Option<String>,
    attributes: VecMap<String, String>,
    equipped: VecMap<String, ID>,
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

// === Minting ===

// / Mint a single Collectible specifying the fields.
// / Can only be performed by the owner of the `CollectionCap`.
public(package) fun mint<T: store>(
    // collection: &mut Collection<T>,
    // cap: &CollectionCap<T>,
    name: Option<String>,
    image_url: String,
    description: Option<String>,
    attribute_items: Option<vector<Attribute<T>>>,
    meta: Option<T>,
    ctx: &mut TxContext,
): Collectible<T> {
    // cap.assert_correct_collection(collection.id.to_inner());
    // assert!(
    //     option::is_none(&collection.config.max_supply) || *option::borrow(&collection.config.max_supply) > collection.config.minted,
    //     errors::capReached!(),
    // );
    // collection.config.minted = collection.config.minted + 1;
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
    let meta: T = collectible.meta.extract();
    (meta, Meta_borrow { collectible_id: object::id(collectible) })
}

public fun return_meta<T: store>(collectible: &mut Collectible<T>, meta: T, borrow: Meta_borrow) {
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
    let Collectible { id, meta, .. } = collectible;
    emit(DestroyCollectible {
        collection_id: object::id(self),
        collectible_id: id.to_inner(),
    });
    id.delete();
    self.config.burned = self.config.burned + 1;
    meta
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

public fun get_attribute_fields<T: store>(
    collection: &Collection<T>,
): VecMap<String, vector<String>> {
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
        !dyn_field::exists_(&collectible.id, attribute.into_key()),
        errors::attributeTypeAlreadyExists!(),
    );

    collection.assert_attribute_check(&attribute.into_key());

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
    assert!(dyn_field::exists_(&collectible.id, key), errors::attributeTypeAlreadyExists!());

    collection.assert_attribute_check(&key);

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
