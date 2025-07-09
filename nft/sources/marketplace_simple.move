// SPDX-License-Identifier: MIT

module nft::marketplace_simple {
    use nft::collectible::{Self, Collection, Collectible};
    use nft::errors;
    use std::string::String;
    use sui::{
        coin::{Self, Coin},
        event::emit,
        sui::SUI,
        table::{Self, Table},
        vec_map::{Self, VecMap}
    };

    // ===================== Constants =====================

    const ERR_INSUFFICIENT_PAYMENT: u64 = 100;
    const ERR_LISTING_NOT_FOUND: u64 = 101;
    const ERR_NOT_OWNER: u64 = 102;
    const ERR_INVALID_PRICE: u64 = 103;
    const ERR_LISTING_ALREADY_EXISTS: u64 = 104;

    // ===================== Structs =====================

    /// Represents a marketplace listing for an NFT
    public struct Listing has store {
        /// The NFT being listed
        nft_id: ID,
        /// Price in SUI
        price: u64,
        /// Seller's address
        seller: address,
        /// Collection ID for filtering
        collection_id: ID,
        /// Timestamp when listed
        created_at: u64,
    }

    /// Marketplace object that holds all listings
    public struct Marketplace has key {
        id: UID,
        /// Table of listings by listing ID
        listings: Table<ID, Listing>,
        /// Map of NFT ID to listing ID
        nft_to_listing: Table<ID, ID>,
        /// Total number of listings
        total_listings: u64,
        /// Active listings count
        active_listings: u64,
        /// Total volume traded
        total_volume: u64,
    }

    /// Marketplace capability for administrative functions
    public struct MarketplaceCap has key, store {
        id: UID,
        marketplace_id: ID,
    }

    /// Escrow object that holds NFT until sale is complete
    public struct Escrow<T: store> has key {
        id: UID,
        /// The escrowed NFT
        nft: Collectible<T>,
        /// Associated listing ID
        listing_id: ID,
        /// Seller address
        seller: address,
    }

    // ===================== Events =====================

    public struct MarketplaceCreated has copy, drop {
        marketplace_id: ID,
        creator: address,
    }

    public struct NFTListed has copy, drop {
        listing_id: ID,
        nft_id: ID,
        collection_id: ID,
        seller: address,
        price: u64,
        created_at: u64,
    }

    public struct NFTSold has copy, drop {
        listing_id: ID,
        nft_id: ID,
        collection_id: ID,
        seller: address,
        buyer: address,
        price: u64,
        sold_at: u64,
    }

    public struct NFTDelisted has copy, drop {
        listing_id: ID,
        nft_id: ID,
        collection_id: ID,
        seller: address,
        delisted_at: u64,
    }

    public struct PriceUpdated has copy, drop {
        listing_id: ID,
        nft_id: ID,
        old_price: u64,
        new_price: u64,
        updated_at: u64,
    }

    // ===================== Functions =====================

    /// Initialize the marketplace
    fun init(ctx: &mut TxContext) {
        let marketplace = Marketplace {
            id: object::new(ctx),
            listings: table::new(ctx),
            nft_to_listing: table::new(ctx),
            total_listings: 0,
            active_listings: 0,
            total_volume: 0,
        };

        let marketplace_id = object::id(&marketplace);
        let cap = MarketplaceCap {
            id: object::new(ctx),
            marketplace_id,
        };

        emit(MarketplaceCreated {
            marketplace_id,
            creator: ctx.sender(),
        });

        transfer::share_object(marketplace);
        transfer::transfer(cap, ctx.sender());
    }

    /// List an NFT for sale
    public fun list_nft<T: store>(
        marketplace: &mut Marketplace,
        collection: &Collection<T>,
        nft: Collectible<T>,
        price: u64,
        ctx: &mut TxContext,
    ) {
        assert!(price > 0, ERR_INVALID_PRICE);

        let seller = ctx.sender();
        let nft_id = object::id(&nft);
        let collection_id = object::id(collection);
        let created_at = ctx.epoch_timestamp_ms();

        // Check if NFT is already listed
        assert!(!table::contains(&marketplace.nft_to_listing, nft_id), ERR_LISTING_ALREADY_EXISTS);

        // Create listing
        let listing_id = object::new(ctx);
        let listing_uid = object::uid_to_inner(&listing_id);
        object::delete(listing_id);

        let listing = Listing {
            nft_id,
            price,
            seller,
            collection_id,
            created_at,
        };

        // Create escrow for the NFT
        let escrow = Escrow<T> {
            id: object::new(ctx),
            nft,
            listing_id: listing_uid,
            seller,
        };

        // Add to marketplace
        table::add(&mut marketplace.listings, listing_uid, listing);
        table::add(&mut marketplace.nft_to_listing, nft_id, listing_uid);

        // Update marketplace stats
        marketplace.total_listings = marketplace.total_listings + 1;
        marketplace.active_listings = marketplace.active_listings + 1;

        emit(NFTListed {
            listing_id: listing_uid,
            nft_id,
            collection_id,
            seller,
            price,
            created_at,
        });

        // Transfer escrow to marketplace
        transfer::share_object(escrow);
    }

    /// Buy an NFT from a listing
    public fun buy_nft<T: store>(
        marketplace: &mut Marketplace,
        escrow: Escrow<T>,
        payment: Coin<SUI>,
        ctx: &mut TxContext,
    ): Collectible<T> {
        let Escrow {
            id,
            nft,
            listing_id,
            seller,
        } = escrow;

        object::delete(id);

        assert!(table::contains(&marketplace.listings, listing_id), ERR_LISTING_NOT_FOUND);

        let listing = table::remove(&mut marketplace.listings, listing_id);
        let nft_id = object::id(&nft);

        // Remove from nft_to_listing mapping
        table::remove(&mut marketplace.nft_to_listing, nft_id);

        // Verify payment
        assert!(coin::value(&payment) >= listing.price, ERR_INSUFFICIENT_PAYMENT);

        let buyer = ctx.sender();
        let sold_at = ctx.epoch_timestamp_ms();

        // Update marketplace stats
        marketplace.active_listings = marketplace.active_listings - 1;
        marketplace.total_volume = marketplace.total_volume + listing.price;

        // Transfer payment to seller
        transfer::public_transfer(payment, seller);

        emit(NFTSold {
            listing_id,
            nft_id,
            collection_id: listing.collection_id,
            seller,
            buyer,
            price: listing.price,
            sold_at,
        });

        nft
    }

    /// Delist an NFT (remove from marketplace)
    public fun delist_nft<T: store>(
        marketplace: &mut Marketplace,
        escrow: Escrow<T>,
        ctx: &mut TxContext,
    ): Collectible<T> {
        let Escrow {
            id,
            nft,
            listing_id,
            seller,
        } = escrow;

        object::delete(id);

        // Verify caller is the seller
        assert!(ctx.sender() == seller, ERR_NOT_OWNER);

        assert!(table::contains(&marketplace.listings, listing_id), ERR_LISTING_NOT_FOUND);

        let listing = table::remove(&mut marketplace.listings, listing_id);
        let nft_id = object::id(&nft);

        // Remove from nft_to_listing mapping
        table::remove(&mut marketplace.nft_to_listing, nft_id);

        let delisted_at = ctx.epoch_timestamp_ms();

        // Update marketplace stats
        marketplace.active_listings = marketplace.active_listings - 1;

        emit(NFTDelisted {
            listing_id,
            nft_id,
            collection_id: listing.collection_id,
            seller,
            delisted_at,
        });

        nft
    }

    /// Update the price of a listing
    public fun update_price(
        marketplace: &mut Marketplace,
        listing_id: ID,
        new_price: u64,
        ctx: &mut TxContext,
    ) {
        assert!(table::contains(&marketplace.listings, listing_id), ERR_LISTING_NOT_FOUND);
        assert!(new_price > 0, ERR_INVALID_PRICE);

        let listing = table::borrow_mut(&mut marketplace.listings, listing_id);
        
        // Verify caller is the seller
        assert!(ctx.sender() == listing.seller, ERR_NOT_OWNER);

        let old_price = listing.price;
        listing.price = new_price;

        let updated_at = ctx.epoch_timestamp_ms();

        emit(PriceUpdated {
            listing_id,
            nft_id: listing.nft_id,
            old_price,
            new_price,
            updated_at,
        });
    }

    // ===================== Getter Functions =====================

    /// Get marketplace statistics
    public fun get_marketplace_stats(marketplace: &Marketplace): (u64, u64, u64) {
        (marketplace.total_listings, marketplace.active_listings, marketplace.total_volume)
    }

    /// Check if a listing exists
    public fun listing_exists(marketplace: &Marketplace, listing_id: ID): bool {
        table::contains(&marketplace.listings, listing_id)
    }

    /// Get listing details
    public fun get_listing_details(
        marketplace: &Marketplace,
        listing_id: ID,
    ): (ID, u64, address, ID, u64) {
        assert!(table::contains(&marketplace.listings, listing_id), ERR_LISTING_NOT_FOUND);
        let listing = table::borrow(&marketplace.listings, listing_id);
        (listing.nft_id, listing.price, listing.seller, listing.collection_id, listing.created_at)
    }

    /// Get listing ID for an NFT
    public fun get_listing_id_for_nft(marketplace: &Marketplace, nft_id: ID): ID {
        assert!(table::contains(&marketplace.nft_to_listing, nft_id), ERR_LISTING_NOT_FOUND);
        *table::borrow(&marketplace.nft_to_listing, nft_id)
    }

    /// Check if NFT is listed
    public fun is_nft_listed(marketplace: &Marketplace, nft_id: ID): bool {
        table::contains(&marketplace.nft_to_listing, nft_id)
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }
}