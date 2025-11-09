// SPDX-License-Identifier: MIT

module nft::attributes;

use nft::errors;
use std::string::String;
use sui::{dynamic_object_field as dof, event::emit};

public struct Attribute<phantom T> has key, store {
    id: UID,
    image_url: Option<String>,
    key: String, // Background, Cloth, etc.
    value: String, // red-sky, jacket, etc.
    meta_borrowable: bool,
}

public struct MetaBorrow {
    attribute_id: ID,
    meta_id: ID,
}

// ============== Events ==============
public struct AttributeMinted has copy, drop {
    collection_id: ID,
    attribute_id: ID,
    image_url: Option<String>,
    key: String,
    value: String,
}

public struct AttributeJoined has copy, drop {
    collectible_id: ID,
    attribute_id: ID,
}

public struct AttributeSplit has copy, drop {
    collectible_id: ID,
    attribute_id: ID,
}

public fun borrow_mut_meta<T: store, Target: key + store>(
    self: &mut Attribute<T>,
    target: ID,
): (Target, MetaBorrow) {
    assert!(self.meta_borrowable, errors::notMetaBorrowable!());
    (
        dof::remove<ID, Target>(&mut self.id, target),
        MetaBorrow { attribute_id: self.id.to_inner(), meta_id: target },
    )
}

public fun return_meta<T: store, AttributeMeta: key + store>(
    self: &mut Attribute<T>,
    meta: AttributeMeta,
    borrow: MetaBorrow,
) {
    let MetaBorrow { attribute_id, meta_id } = borrow;
    assert!(self.id.to_inner() == attribute_id, errors::wrongId!());
    assert!(meta_id == object::id(&meta), errors::wrongMetaId!());
    dof::add(&mut self.id, meta_id, meta);
}

public(package) fun new<T: store, AttributeMeta: key + store>(
    image_url: Option<String>,
    key: String,
    value: String,
    collection: ID,
    meta: Option<AttributeMeta>,
    meta_borrowable: bool,
    ctx: &mut TxContext,
): Attribute<T> {
    let mut attribute = Attribute<T> {
        id: object::new(ctx),
        image_url,
        key,
        value,
        // meta,
        meta_borrowable,
    };
    emit(AttributeMinted {
        collection_id: collection,
        attribute_id: object::id(&attribute),
        image_url,
        key,
        value,
    });
    meta.do!(|meta| {
        dof::add(&mut attribute.id, object::id(&meta), meta);
    });
    attribute
}

public fun into_value<T: store>(self: &Attribute<T>): String {
    self.value
}

public fun into_key<T: store>(self: &Attribute<T>): String {
    self.key
}

public fun get_attribute_data<T: store>(attribute: &Attribute<T>): (String, String) {
    (attribute.key, attribute.value)
}

public fun get_attribute_image_url<T: store>(attribute: &Attribute<T>): Option<String> {
    attribute.image_url
}

public(package) fun emit_joined<T: store>(self: &Attribute<T>, collectible_id: ID) {
    emit(AttributeJoined {
        collectible_id,
        attribute_id: self.id.to_inner(),
    });
}

public(package) fun emit_split<T: store>(self: &Attribute<T>, collectible_id: ID) {
    emit(AttributeSplit {
        collectible_id,
        attribute_id: self.id.to_inner(),
    });
}

public(package) fun add_meta<T: store, AttributeMeta: key + store>(
    self: &mut Attribute<T>,
    meta: AttributeMeta,
) {
    dof::add(&mut self.id, object::id(&meta), meta);
}
