// SPDX-License-Identifier: MIT

module nft::collectible;

use nft::{attributes::Attribute, errors};
use std::{hash::sha2_256, string::{Self, String}};
use sui::{dynamic_object_field as dyn_field, event::emit, vec_map::{Self as map, VecMap}};

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

// =============== Attribute Functions ============

public fun validate_attribute<T: key + store>(
    collectible: &Collectible<T>,
    hashed_attribute: vector<u8>,
    keys: vector<String>,
): bool {
    let mut attribute_hash: vector<u8> = vector[];

    keys.do!(|key| {
        let attribute: &Attribute<T> = dyn_field::borrow(&collectible.id, key);
        attribute_hash.append(string::into_bytes(attribute.into_value()));
    });

    sha2_256(attribute_hash) == hashed_attribute
}

// ================ Borrowing methods ==================

// public fun borrow_mut_policy_cap_collectible<T: store>(
//     self: &mut Collection<T>,
//     _: &CollectionCap<T>,
// ): (TransferPolicyCap<Collectible<T>>, Borrow) {
//     borrow::borrow(&mut self.policy_cap_collectible)
// }
//
// public fun return_policy_cap_collectible<T: store>(
//     self: &mut Collection<T>,
//     cap: TransferPolicyCap<Collectible<T>>,
//     borrow: Borrow,
// ) {
//     borrow::put_back(&mut self.policy_cap_collectible, cap, borrow)
// }
//
// public fun borrow_mut_policy_cap_attribute<T: store>(
//     self: &mut Collection<T>,
//     _: &CollectionCap<T>,
// ): (TransferPolicyCap<Attribute<T>>, Borrow) {
//     borrow::borrow(&mut self.policy_cap_attribute)
// }
//
// public fun return_policy_cap_attribute<T: store>(
//     self: &mut Collection<T>,
//     cap: TransferPolicyCap<Attribute<T>>,
//     borrow: Borrow,
// ) {
//     borrow::put_back(&mut self.policy_cap_attribute, cap, borrow)
// }
//
// public fun borrow_mut_display_collectible<T: store>(
//     self: &mut Collection<T>,
//     _: &CollectionCap<T>,
// ): (Display<Collectible<T>>, Borrow) {
//     borrow::borrow(&mut self.display_collectible)
// }
//
// /// Return the `Display` to the `CollectionCap`. Must be called if
// /// the capability was borrowed, or a transaction would fail.
// public fun return_display_collectible<T: store>(
//     self: &mut Collection<T>,
//     display: Display<Collectible<T>>,
//     borrow: Borrow,
// ) {
//     borrow::put_back(&mut self.display_collectible, display, borrow)
// }
//
// public fun borrow_meta<T: store>(collectible: &Collectible<T>): &Option<T> {
//     &collectible.meta
// }
//
// public fun borrow_mut_meta<T: store>(
//     collectible: &mut Collectible<T>,
//     collection: &Collection<T>,
// ): (T, Meta_borrow) {
//     let meta: T = collectible.meta.extract();
//     (meta, Meta_borrow { collectible_id: object::id(collectible) })
// }
//
// public fun return_meta<T: store>(collectible: &mut Collectible<T>, meta: T, borrow: Meta_borrow) {
//     let Meta_borrow { collectible_id } = borrow;
//     assert!(collectible_id == object::id(collectible), errors::wrongCollectible!());
//     collectible.meta.fill(meta);
// }

// ================= View functions ========================
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

// ================= Package =======================

// === Minting ===

// / Mint a single Collectible specifying the fields.
// / Can only be performed by the owner of the `CollectionCap`.
public(package) fun mint<T: store>(
    collection_id: ID,
    name: Option<String>,
    image_url: String,
    description: Option<String>,
    attribute_items: Option<vector<Attribute<T>>>,
    meta: Option<T>,
    ctx: &mut TxContext,
): Collectible<T> {
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
        att_items.do!(|att_item| { item.internal_join_attribute<T>(att_item); });
    } else {
        option::destroy_none(attribute_items);
    };

    emit(CollectibleMinted {
        collection_id,
        collectible_id: object::id(&item),
        image_url,
        name,
        description,
        attributes: item.attributes,
        equipped: item.equipped,
    });

    item
}

public(package) fun internal_join_attribute<T: store>(
    collectible: &mut Collectible<T>,
    attribute: Attribute<T>,
) {
    assert!(
        !dyn_field::exists_(&collectible.id, attribute.into_key()),
        errors::attributeTypeAlreadyExists!(),
    );

    attribute.emit_joined(object::id(collectible));

    collectible.equipped.insert(attribute.into_key(), object::id(&attribute));
    collectible.attributes.insert(attribute.into_key(), attribute.into_value());

    dyn_field::add(&mut collectible.id, attribute.into_key(), attribute);
}

public(package) fun internal_split_attribute<T: store>(
    collectible: &mut Collectible<T>,
    // collection: &Collection<T>,
    key: String,
): Attribute<T> {
    assert!(dyn_field::exists_(&collectible.id, key), errors::attributeTypeAlreadyExists!());

    // collection.assert_attribute_check(&key);

    collectible.attributes.remove(&key);
    collectible.equipped.remove(&key);

    let attribute: Attribute<T> = dyn_field::remove(&mut collectible.id, key);
    attribute.emit_split(object::id(collectible));

    attribute
}

public(package) fun update_image_url<T: store>(self: &mut Collectible<T>, new_image_url: String) {
    self.image_url = new_image_url;
}

public(package) fun borrow_meta<T: store>(collectible: &Collectible<T>): &Option<T> {
    &collectible.meta
}

public(package) fun borrow_mut_meta<T: store>(collectible: &mut Collectible<T>): (T) {
    collectible.meta.extract()
}

public(package) fun return_meta<T: store>(collectible: &mut Collectible<T>, meta: T) {
    collectible.meta.fill(meta);
}

public(package) fun destroy_collectible<T: store>(
    collectible: Collectible<T>,
    collection_id: ID,
): Option<T> {
    let Collectible { id, meta, .. } = collectible;
    emit(DestroyCollectible {
        collection_id,
        collectible_id: id.to_inner(),
    });
    id.delete();
    meta
}
