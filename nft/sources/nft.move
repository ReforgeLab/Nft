module nft::nft;

use nft::{
    attributes::Attribute,
    collectible::{Self, Collectible},
    collection::{Collection, CollectionCap}
};
use std::string::String;

public(package) fun mint<T: store>(
    collection: &mut Collection<T>,
    cap: &CollectionCap<T>,
    name: Option<String>,
    image_url: String,
    description: Option<String>,
    attribute_items: Option<vector<Attribute<T>>>,
    meta: Option<T>,
    ctx: &mut TxContext,
): Collectible<T> {
    collection.mint_check();
    collectible::mint(name, image_url, description, attribute_items, meta, ctx)
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
