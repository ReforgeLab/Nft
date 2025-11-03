module nft::render;

use std::string::String;

public struct RenderNode {
    attribute_id: ID,
    nft_id: ID,
    old_nft_image_url: String,
}

public struct RenderCap<phantom T: store> has key, store {
    id: UID,
    collection: ID,
}

public(package) fun new(attribute_id: ID, nft_id: ID, old_nft_image_url: String): RenderNode {
    RenderNode {
        attribute_id,
        nft_id,
        old_nft_image_url,
    }
}

public(package) fun create_cap<T: store>(collection_id: ID, ctx: &mut TxContext): RenderCap<T> {
    RenderCap<T> {
        id: object::new(ctx),
        collection: collection_id,
    }
}

public(package) fun assert_image_url_change(
    self: RenderNode,
    new_image_url: String,
    collectible_id: ID,
    collectible_image: String,
    attribute_id: ID,
) {
    let RenderNode { attribute_id: attr_id, nft_id, old_nft_image_url } = self;
    assert!(attribute_id == attr_id);
    assert!(nft_id == collectible_id);
    assert!(old_nft_image_url == collectible_image && new_image_url != old_nft_image_url);
}
