module example::nft_example {
    use nft::{collectible::{Self, CollectionCap, CollectionTicket, Collection}, registry::Registry};
    use std::{option::{none, some}, string::{Self, String}};
    use sui::test_utils::destroy;

    public struct NFT_EXAMPLE has drop {}

    public struct Nft<phantom T> has key, store {
        id: UID,
        name: String,
        cool: bool,
    }

    public struct PixelArtMeta has store, drop {
        attribute_names: vector<String>,   // ["Hat", "Eyes", "Background"]
        attribute_values: vector<String>,  // ["Cowboy Hat", "Blue Eyes", "Space"]
        creator: address,
        creation_time: u64,
        editing_tool: String,
        layer_count: u64,
    }

    public struct CollectionMeta has store, drop {
        rarity_tier: String,
        rarity_score: u64,
        generation_batch: u64,
        trait_rules_applied: vector<String>,
        total_traits: u64,
    }

    fun init(otw: NFT_EXAMPLE, ctx: &mut TxContext) {
        collectible::claim_ticket<NFT_EXAMPLE, Nft<NFT_EXAMPLE>>(otw, option::some(100), ctx);
    }

    #[allow(lint(self_transfer))]
    public fun collection_init(
        ticket: CollectionTicket<Nft<NFT_EXAMPLE>>,
        registry: &Registry,
        ctx: &mut TxContext,
    ) {
        let (cap, render_cap_opt) = ticket.create_collection(
            registry,
            b"https://www.banner.com".to_string(),
            vector[b"Background".to_string(), b"Clothing".to_string()],
            some(b"Reblixt is the Creator".to_string()),
            false,
            true,
            true,
            ctx,
        );

        // Destroy the render cap option if it exists
        if (render_cap_opt.is_some()) {
            let render_cap = render_cap_opt.destroy_some();
            destroy(render_cap);
        } else {
            option::destroy_none(render_cap_opt);
        };

        transfer::public_transfer(cap, ctx.sender());
    }

    #[allow(lint(self_transfer))]
    public fun create_flexible_collection(
        ticket: CollectionTicket<PixelArtMeta>,
        registry: &Registry,
        ctx: &mut TxContext,
    ) {
        let (cap, render_cap_opt) = ticket.create_collection(
            registry,
            b"https://banner.com/example".to_string(),
            vector[],
            some(b"Example Community".to_string()),
            false,
            true,
            false,
            ctx,
        );

        if (render_cap_opt.is_some()) {
            let render_cap = render_cap_opt.destroy_some();
            destroy(render_cap);
        } else {
            option::destroy_none(render_cap_opt);
        };

        transfer::public_transfer(cap, ctx.sender());
    }

    #[allow(lint(self_transfer))]
    public fun mint(
        collection: &mut Collection<Nft<NFT_EXAMPLE>>,
        cap: &CollectionCap<Nft<NFT_EXAMPLE>>,
        ctx: &mut TxContext,
    ) {
        // The image_url is optional use `some` to pass it or `none to skip it
        let image_url = b"www.image.com".to_string();
        let key = b"Background".to_string();
        let value = b"Red".to_string();
        // Meta is optional use `some` to pass it or `none` to skip it
        let meta = Nft<NFT_EXAMPLE> {
            id: object::new(ctx),
            name: b"NFT".to_string(),
            cool: true,
        };

        // Here you can create a loop to create multiple attributes
        let attribute = collection.mint_attribute(
            cap,
            some(image_url),
            key,
            value,
            some(meta),
            ctx,
        );

        let nft = collection.mint(
            cap,
            some(b"Test_name".to_string()),
            b"https://www.image.com".to_string(),
            some(b"Test_description".to_string()),
            some(vector[attribute]),
            none(),
            ctx,
        );
        transfer::public_transfer(nft, ctx.sender())
    }

    #[allow(lint(self_transfer))]
    public fun mint_with_pixel_art_meta(
        collection: &mut Collection<PixelArtMeta>,
        cap: &CollectionCap<PixelArtMeta>,
        name: String,
        description: String,
        image_url: String,
        attribute_names: vector<String>,
        attribute_values: vector<String>,
        editing_tool: String,
        ctx: &mut TxContext,
    ) {
        let pixel_meta = PixelArtMeta {
            attribute_names,
            attribute_values,
            creator: ctx.sender(),
            creation_time: ctx.epoch(),
            editing_tool,
            layer_count: 3,
        };

        let nft = collection.mint(
            cap,
            some(name),
            image_url,
            some(description),
            none(),
            some(pixel_meta),
            ctx,
        );
        transfer::public_transfer(nft, ctx.sender())
    }

    #[allow(lint(self_transfer))]
    public fun mint_with_collection_meta(
        collection: &mut Collection<CollectionMeta>,
        cap: &CollectionCap<CollectionMeta>,
        name: String,
        image_url: String,
        rarity_tier: String,
        rarity_score: u64,
        generation_batch: u64,
        ctx: &mut TxContext,
    ) {
        let collection_meta = CollectionMeta {
            rarity_tier,
            rarity_score,
            generation_batch,
            trait_rules_applied: vector[string::utf8(b"no_conflicting_hats"), string::utf8(b"rare_combinations")],
            total_traits: 5,
        };

        let nft = collection.mint(
            cap,
            some(name),
            image_url,
            some(string::utf8(b"Part of a generated collection with rarity mechanics")),
            none(),
            some(collection_meta),
            ctx,
        );
        transfer::public_transfer(nft, ctx.sender())
    }

    #[allow(lint(self_transfer))]
    public fun mint_simple(
        collection: &mut Collection<PixelArtMeta>,
        cap: &CollectionCap<PixelArtMeta>,
        name: String,
        image_url: String,
        ctx: &mut TxContext,
    ) {
        let nft = collection.mint(
            cap,
            some(name),
            image_url,
            some(string::utf8(b"Simple NFT without complex metadata")),
            none(),
            none(),
            ctx,
        );
        transfer::public_transfer(nft, ctx.sender())
    }

    #[test_only]
    public fun test_init_pixel_art_collection(ctx: &mut TxContext) {
        let otw = NFT_EXAMPLE {};
        collectible::claim_ticket<NFT_EXAMPLE, PixelArtMeta>(otw, none(), ctx);
    }

    #[test_only]
    public fun test_init_collection_meta_collection(ctx: &mut TxContext) {
        let otw = NFT_EXAMPLE {};
        collectible::claim_ticket<NFT_EXAMPLE, CollectionMeta>(otw, some(10000), ctx);
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        let otw = NFT_EXAMPLE {};
        init(otw, ctx);
    }
}
