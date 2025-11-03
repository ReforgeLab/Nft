module nft::nft;

use nft::{
    attributes::{Self, Attribute},
    collectible::{Self, Collectible},
    collection::{Collection, CollectionCap},
    errors,
    render::{Self, RenderNode},
    render_fee_rule
};
use std::string::String;
use sui::{coin::Coin, sui::SUI, transfer_policy::{TransferPolicy, TransferRequest}};

public struct Meta_borrow {
    collectible_id: ID,
}

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
    collection.mint_check(cap);
    collectible::mint(collection.id(), name, image_url, description, attribute_items, meta, ctx)
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
    cap.assert_correct_collection(collection.id());
    collection.assert_attribute_check(&key);

    if (!collection.is_strict()) {
        collection.add_attribute_field(key, value);
    };

    attributes::new(
        image_url,
        key,
        value,
        collection.id(),
        meta,
        collection.is_meta_borrowable(),
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
    collection.assert_attribute_check(&attribute.into_key());
    let attribute_id = object::id(&attribute);
    collectible.internal_join_attribute<T>(attribute);

    render::new(
        attribute_id,
        object::id(collectible),
        collectible.get_image_url(),
    )
}

public fun split_attribute<T: store>(
    collectible: &mut Collectible<T>,
    collection: &mut Collection<T>,
    key: String,
    _: &mut TxContext,
): (RenderNode, Attribute<T>) {
    collection.assert_dynamic();
    collection.assert_attribute_check(&key);
    let attribute = collectible.internal_split_attribute<T>(key);
    (
        render::new(
            object::id(&attribute),
            object::id(collectible),
            collectible.get_image_url(),
        ),
        attribute,
    )
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

    render_node.assert_image_url_change(
        new_image_url,
        object::id(collectible),
        collectible.get_image_url(),
        attribute_id,
    );

    render_fee_rule::pay(policy, request, payment);
    collectible.update_image_url(new_image_url);
}

public fun borrow_meta<T: store>(collectible: &Collectible<T>): &Option<T> {
    collectible.borrow_meta()
}

public fun borrow_mut_meta<T: store>(
    collectible: &mut Collectible<T>,
    collection: &Collection<T>,
): (T, Meta_borrow) {
    collection.assert_meta_borrowable();
    (collectible.borrow_mut_meta(), Meta_borrow { collectible_id: object::id(collectible) })
}

public fun return_meta<T: store>(collectible: &mut Collectible<T>, meta: T, borrow: Meta_borrow) {
    let Meta_borrow { collectible_id } = borrow;
    assert!(collectible_id == object::id(collectible), errors::wrongCollectible!());
    collectible.return_meta(meta);
}

// === Burn ===
public fun destroy_collectible<T: store>(
    collection: &mut Collection<T>,
    _: &CollectionCap<T>,
    collectible: Collectible<T>,
): Option<T> {
    let meta = collectible.destroy_collectible(collection.id());
    collection.increment_burn_count();
    // let Collectible { id, meta, .. } = collectible;
    // emit(DestroyCollectible {
    //     collection_id: object::id(self),
    //     collectible_id: id.to_inner(),
    // });
    // id.delete();
    meta
}
