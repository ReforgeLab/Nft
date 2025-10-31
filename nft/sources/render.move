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

public(package) fun new<T: store>(collection_id: ID, id: UID): RenderCap<T> {
    RenderCap<T> {
        id,
        collection: collection_id,
    }
}
