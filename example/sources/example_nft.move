module example::nft_example {
    use nft::{collectible::{Self, CollectionCap, CollectionTicket, Collection}, registry::Registry};
    use std::{option::{none, some}, string::{Self, String}};
    use sui::vec_map::{Self as map};

    public struct NFT_EXAMPLE has drop {}

    public struct Nft<phantom T> has key, store {
        id: UID,
        name: String,
        cool: bool,
        // Flexible metadata fields - can be used for any type of NFT
        creator: address,
        created_at: u64,
        rarity_score: u64,
        rarity_tier: String,
        custom_attributes: vector<String>,
        editing_tool: Option<String>,
        generation_batch: Option<u64>,
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
        let mut fields = map::empty<String, vector<String>>();
        fields.insert(b"Background".to_string(), vector[b"red".to_string(), b"blue".to_string()]);
        fields.insert(b"Clothing".to_string(), vector[b"jacket".to_string(), b"shirt".to_string()]);

        let (cap, render_cap_opt) = ticket.create_collection<Nft<NFT_EXAMPLE>>(
            registry,
            b"https://www.banner.com".to_string(),
            fields,
            some(b"Reblixt is the Creator".to_string()),
            false,
            true,
            true,
            true,
            ctx,
        );

        // Destroy the render cap option if it exists
        if (render_cap_opt.is_some()) {
            let render_cap = render_cap_opt.destroy_some();
            transfer::public_transfer(render_cap, ctx.sender());
        } else {
            option::destroy_none(render_cap_opt);
        };

        transfer::public_transfer(cap, ctx.sender());
    }

    #[allow(lint(self_transfer))]
    public fun create_flexible_collection(
        ticket: CollectionTicket<Nft<NFT_EXAMPLE>>,
        registry: &Registry,
        ctx: &mut TxContext,
    ) {
        let fields = map::empty<String, vector<String>>();

        let (cap, render_cap_opt) = ticket.create_collection<Nft<NFT_EXAMPLE>>(
            registry,
            b"https://banner.com/example".to_string(),
            fields,
            some(b"Example Community".to_string()),
            false,
            true,
            false,
            false,
            ctx,
        );

        if (render_cap_opt.is_some()) {
            let render_cap = render_cap_opt.destroy_some();
            transfer::public_transfer(render_cap, ctx.sender());
        } else {
            option::destroy_none(render_cap_opt);
        };

        transfer::public_transfer(cap, ctx.sender());
    }

    #[allow(lint(self_transfer))]
    public fun create_collection_meta_collection(
        ticket: CollectionTicket<Nft<NFT_EXAMPLE>>,
        registry: &Registry,
        ctx: &mut TxContext,
    ) {
        let mut fields = map::empty<String, vector<String>>();
        fields.insert(b"Rarity".to_string(), vector[b"common".to_string(), b"rare".to_string(), b"epic".to_string()]);
        fields.insert(b"Tier".to_string(), vector[b"bronze".to_string(), b"silver".to_string(), b"gold".to_string()]);

        let (cap, render_cap_opt) = ticket.create_collection<Nft<NFT_EXAMPLE>>(
            registry,
            b"https://banner.com/collection".to_string(),
            fields,
            some(b"Collection Generator".to_string()),
            false,
            true,
            true,
            true,
            ctx,
        );

        if (render_cap_opt.is_some()) {
            let render_cap = render_cap_opt.destroy_some();
            transfer::public_transfer(render_cap, ctx.sender());
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
        // Attribute meta is optional use `some` to pass it or `none` to skip it
        let attribute_meta = Nft<NFT_EXAMPLE> {
            id: object::new(ctx),
            name: b"NFT".to_string(),
            cool: true,
            creator: ctx.sender(),
            created_at: ctx.epoch(),
            rarity_score: 100,
            rarity_tier: b"common".to_string(),
            custom_attributes: vector[b"Hat:Cowboy Hat".to_string(), b"Eyes:Blue Eyes".to_string()],
            editing_tool: some(b"Paint".to_string()),
            generation_batch: some(1),
        };

        // Here you can create a loop to create multiple attributes
        let attribute = collection.mint_attribute(
            cap,
            some(image_url),
            key,
            value,
            some(attribute_meta),
            ctx,
        );

        // NFT metadata is separate from attribute metadata
        let nft_meta = Nft<NFT_EXAMPLE> {
            id: object::new(ctx),
            name: b"NFT_Meta".to_string(),
            cool: false,
            creator: ctx.sender(),
            created_at: ctx.epoch(),
            rarity_score: 100,
            rarity_tier: b"common".to_string(),
            custom_attributes: vector[],
            editing_tool: none(),
            generation_batch: none(),
        };

        let nft = collection.mint(
            cap,
            some(b"Test_name".to_string()),
            b"https://www.image.com".to_string(),
            some(b"Test_description".to_string()),
            some(vector[attribute]),
            some(nft_meta),
            ctx,
        );
        transfer::public_transfer(nft, ctx.sender())
    }

    #[allow(lint(self_transfer))]
    public fun mint_with_pixel_art_meta(
        collection: &mut Collection<Nft<NFT_EXAMPLE>>,
        cap: &CollectionCap<Nft<NFT_EXAMPLE>>,
        name: String,
        description: String,
        image_url: String,
        attribute_names: vector<String>,
        attribute_values: vector<String>,
        editing_tool: String,
        ctx: &mut TxContext,
    ) {
        let mut custom_attributes = vector[];
        let mut i = 0;
        while (i < attribute_names.length()) {
            let mut attr_string = string::utf8(b"");
            attr_string.append_utf8(attribute_names[i].into_bytes());
            attr_string.append_utf8(b":");
            attr_string.append_utf8(attribute_values[i].into_bytes());
            custom_attributes.push_back(attr_string);
            i = i + 1;
        };

        let nft_meta = Nft<NFT_EXAMPLE> {
            id: object::new(ctx),
            name: name,
            cool: false,
            creator: ctx.sender(),
            created_at: ctx.epoch(),
            rarity_score: 100,
            rarity_tier: b"common".to_string(),
            custom_attributes,
            editing_tool: some(editing_tool),
            generation_batch: none(),
        };

        let nft = collection.mint(
            cap,
            some(name),
            image_url,
            some(description),
            none(),
            some(nft_meta),
            ctx,
        );
        transfer::public_transfer(nft, ctx.sender())
    }

    #[allow(lint(self_transfer))]
    public fun mint_with_collection_meta(
        collection: &mut Collection<Nft<NFT_EXAMPLE>>,
        cap: &CollectionCap<Nft<NFT_EXAMPLE>>,
        name: String,
        image_url: String,
        rarity_tier: String,
        rarity_score: u64,
        generation_batch: u64,
        ctx: &mut TxContext,
    ) {
        let nft_meta = Nft<NFT_EXAMPLE> {
            id: object::new(ctx),
            name: name,
            cool: false,
            creator: ctx.sender(),
            created_at: ctx.epoch(),
            rarity_score: rarity_score,
            rarity_tier: rarity_tier,
            custom_attributes: vector[],
            editing_tool: none(),
            generation_batch: some(generation_batch),
        };

        let nft = collection.mint(
            cap,
            some(name),
            image_url,
            some(string::utf8(b"Part of a generated collection with rarity mechanics")),
            none(),
            some(nft_meta),
            ctx,
        );
        transfer::public_transfer(nft, ctx.sender())
    }

    #[allow(lint(self_transfer))]
    public fun mint_simple(
        collection: &mut Collection<Nft<NFT_EXAMPLE>>,
        cap: &CollectionCap<Nft<NFT_EXAMPLE>>,
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
    public fun test_init(ctx: &mut TxContext) {
        let otw = NFT_EXAMPLE {};
        init(otw, ctx);
    }
}
