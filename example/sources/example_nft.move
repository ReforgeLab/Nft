module example::nft_example {
    use nft::{collectible::{Self, CollectionCap, CollectionTicket, Collection}, registry::Registry};
    use std::{option::{none, some}, string::String};
    use sui::object::UID;
    use sui::test_utils::destroy;

    public struct NFT_EXAMPLE has drop {}

    public struct Nft<phantom T> has key, store {
        id: UID,
        name: String,
        cool: bool,
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

        // The collection is automatically shared by create_collection
        // We only need to transfer the cap to the sender
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

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        let otw = NFT_EXAMPLE {};
        init(otw, ctx);
    }
}
