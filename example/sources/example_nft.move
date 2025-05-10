module example::nft_example {
    use nft::{collectible::{Self, CollectionCap, CollectionTicket, Collection}, registry::Registry};
    use std::{option::{none, some}, string::String};

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
        let (mut collection, cap): (
            Collection<Nft<NFT_EXAMPLE>>,
            CollectionCap<Nft<NFT_EXAMPLE>>,
        ) = ticket.create_collection(
            registry,
            b"https://www.banner.com".to_string(),
            vector[b"Background".to_string(), b"Clothing".to_string()],
            some(b"Reblixt is the Creator".to_string()),
            false,
            true,
            true,
            ctx,
        );

        let (mut display, borrow) = collection.borrow_mut_display_collectible(&cap);

        display.add(b"project_url".to_string(), b"www.project.com".to_string());
        display.update_version();

        collection.return_display_collectible(display, borrow);

        transfer::public_transfer(collection, ctx.sender());
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
