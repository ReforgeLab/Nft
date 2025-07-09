module example::marketplace_example {
    use nft::{
        collectible::{Self, CollectionCap, CollectionTicket, Collection, Collectible},
        marketplace_simple::{Self as marketplace, Marketplace, Escrow},
        registry::Registry
    };
    use std::{option::{none, some}, string::String};
    use sui::{
        coin::{Self, Coin},
        sui::SUI
    };

    public struct MARKETPLACE_EXAMPLE has drop {}

    public struct GameItem has key, store {
        id: UID,
        name: String,
        rarity: u8,
        attack: u64,
        defense: u64,
        magic: u64,
    }

    fun init(otw: MARKETPLACE_EXAMPLE, ctx: &mut TxContext) {
        collectible::claim_ticket<MARKETPLACE_EXAMPLE, GameItem>(otw, some(10000), ctx);
    }

    #[allow(lint(self_transfer))]
    public fun collection_init(
        ticket: CollectionTicket<GameItem>,
        registry: &Registry,
        ctx: &mut TxContext,
    ) {
        let (mut collection, cap): (
            Collection<GameItem>,
            CollectionCap<GameItem>,
        ) = ticket.create_collection(
            registry,
            b"https://gameworld.com/banner".to_string(),
            vector[
                b"Weapon".to_string(),
                b"Armor".to_string(),
                b"Accessory".to_string(),
                b"Rarity".to_string(),
            ],
            some(b"GameWorld Studios".to_string()),
            true,  // dynamic - allows attribute modification
            true,  // burnable
            true,  // meta_borrowable
            ctx,
        );

        // Setup display for the collection
        let (mut display, borrow) = collection.borrow_mut_display_collectible(&cap);
        display.add(b"project_url".to_string(), b"https://gameworld.com".to_string());
        display.add(b"website".to_string(), b"https://gameworld.com".to_string());
        display.add(b"twitter".to_string(), b"https://twitter.com/gameworld".to_string());
        display.update_version();
        collection.return_display_collectible(display, borrow);

        transfer::public_share_object(collection);
        transfer::public_transfer(cap, ctx.sender());
    }

    #[allow(lint(self_transfer))]
    public fun mint_game_item(
        collection: &mut Collection<GameItem>,
        cap: &CollectionCap<GameItem>,
        name: String,
        rarity: u8,
        attack: u64,
        defense: u64,
        magic: u64,
        ctx: &mut TxContext,
    ) {
        let image_url = b"https://gameworld.com/items/".to_string();
        image_url.append(name);
        image_url.append(b".png".to_string());

        let meta = GameItem {
            id: object::new(ctx),
            name,
            rarity,
            attack,
            defense,
            magic,
        };

        // Create rarity attribute
        let rarity_attr = collection.mint_attribute(
            cap,
            some(b"https://gameworld.com/rarity.png".to_string()),
            b"Rarity".to_string(),
            if (rarity == 1) { b"Common".to_string() }
            else if (rarity == 2) { b"Uncommon".to_string() }
            else if (rarity == 3) { b"Rare".to_string() }
            else if (rarity == 4) { b"Epic".to_string() }
            else { b"Legendary".to_string() },
            some(meta),
            ctx,
        );

        let nft = collection.mint(
            cap,
            some(name),
            image_url,
            some(b"A powerful game item ready for adventure".to_string()),
            some(vector[rarity_attr]),
            none(),
            ctx,
        );

        transfer::public_transfer(nft, ctx.sender());
    }

    #[allow(lint(self_transfer))]
    public fun list_item_for_sale(
        marketplace: &mut Marketplace,
        collection: &Collection<GameItem>,
        nft: Collectible<GameItem>,
        price: u64,
        ctx: &mut TxContext,
    ) {
        marketplace::list_nft(
            marketplace,
            collection,
            nft,
            price,
            ctx,
        );
    }

    #[allow(lint(self_transfer))]
    public fun buy_item(
        marketplace: &mut Marketplace,
        escrow: Escrow<GameItem>,
        payment: Coin<SUI>,
        ctx: &mut TxContext,
    ) {
        let nft = marketplace::buy_nft(
            marketplace,
            escrow,
            payment,
            ctx,
        );
        
        transfer::public_transfer(nft, ctx.sender());
    }

    #[allow(lint(self_transfer))]
    public fun cancel_listing(
        marketplace: &mut Marketplace,
        escrow: Escrow<GameItem>,
        ctx: &mut TxContext,
    ) {
        let nft = marketplace::delist_nft(
            marketplace,
            escrow,
            ctx,
        );
        
        transfer::public_transfer(nft, ctx.sender());
    }

    public fun update_listing_price(
        marketplace: &mut Marketplace,
        listing_id: ID,
        new_price: u64,
        ctx: &mut TxContext,
    ) {
        marketplace::update_price(
            marketplace,
            listing_id,
            new_price,
            ctx,
        );
    }

    // Getter functions for game item metadata
    public fun get_game_item_stats(item: &GameItem): (String, u8, u64, u64, u64) {
        (item.name, item.rarity, item.attack, item.defense, item.magic)
    }

    public fun get_marketplace_stats(marketplace: &Marketplace): (u64, u64, u64) {
        marketplace::get_marketplace_stats(marketplace)
    }

    public fun is_item_listed(marketplace: &Marketplace, nft_id: ID): bool {
        marketplace::is_nft_listed(marketplace, nft_id)
    }

    public fun get_listing_details(marketplace: &Marketplace, listing_id: ID): (ID, u64, address, ID, u64) {
        marketplace::get_listing_details(marketplace, listing_id)
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        let otw = MARKETPLACE_EXAMPLE {};
        init(otw, ctx);
    }
}