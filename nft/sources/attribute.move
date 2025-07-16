// SPDX-License-Identifier: MIT

module nft::attributes {
    use std::string::String;
    use sui::event::emit;

    public struct Attribute<T> has key, store {
        id: UID,
        image_url: Option<String>,
        key: String, // Background, Cloth, etc.
        value: String, // red-sky, jacket, etc.
        // NOTE: This is for the unique attributes like one of one NFTS
        override_score: Option<u8>,
        meta: Option<T>,
        meta_borrowable: bool,
    }

    public struct Meta_borrow {
        attribute_id: ID,
    }

    // ============== Events ==============
    public struct AttributeMinted has copy, drop {
        collection_id: ID,
        attribute_id: ID,
        image_url: Option<String>,
        override_score: Option<u8>,
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

    public fun borrow_meta<T: store>(self: &mut Attribute<T>): (T, Meta_borrow) {
        (self.meta.extract(), Meta_borrow { attribute_id: self.id.to_inner() })
    }

    public fun return_meta<T: store>(self: &mut Attribute<T>, meta: T, _meta_borrow: Meta_borrow) {
        let Meta_borrow { attribute_id } = _meta_borrow;
        assert!(self.id.to_inner() == attribute_id, 0);
        self.meta.fill(meta);
    }

    // NOTE: Added the override_score
    public(package) fun new<T: store>(
        image_url: Option<String>,
        key: String,
        value: String,
        collection: ID,
        meta: Option<T>,
        meta_borrowable: bool,
        override_score: Option<u8>,
        ctx: &mut TxContext,
    ): Attribute<T> {
        let attribute = Attribute<T> {
            id: object::new(ctx),
            image_url,
            key,
            value,
            meta,
            override_score,
            meta_borrowable,
        };
        emit(AttributeMinted {
            collection_id: collection,
            attribute_id: object::id(&attribute),
            image_url,
            override_score,
            key,
            value,
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
}
