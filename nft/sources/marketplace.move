// SPDX-License-Identifier: MIT

module nft::marketplace {
    use nft::collectible::{Self, Collection, Collectible};
    use nft::errors;
    use std::string::String;
    use sui::{
        coin::{Self, Coin},
        dynamic_object_field as dof,
        event::emit,
        sui::SUI,
        transfer_policy::{Self as policy, TransferPolicy, TransferRequest},
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
    public struct Listing<phantom T> has key, store {
        id: UID,
        /// The NFT being listed
        nft: Collectible<T>,
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

        let listing = Listing<T> {
            id: object::new(ctx),
            nft,
            price,
            seller,
            collection_id,
            created_at,
        };

        let listing_id = object::id(&listing);

        // Update marketplace stats
        marketplace.total_listings = marketplace.total_listings + 1;
        marketplace.active_listings = marketplace.active_listings + 1;

        emit(NFTListed {
            listing_id,
            nft_id,
            collection_id,
            seller,
            price,
            created_at,
        });

        // Add listing to marketplace using dynamic object field
        dof::add(&mut marketplace.id, listing_id, listing);
    }

    /// Buy an NFT from a listing
    public fun buy_nft<T: store>(
        marketplace: &mut Marketplace,
        listing_id: ID,
        payment: Coin<SUI>,
        ctx: &mut TxContext,
    ): Collectible<T> {
        assert!(dof::exists_(&marketplace.id, listing_id), ERR_LISTING_NOT_FOUND);

        let listing: Listing<T> = dof::remove(&mut marketplace.id, listing_id);
        let Listing {
            id,
            nft,
            price,
            seller,
            collection_id,
            created_at: _,
        } = listing;

        object::delete(id);

        // Verify payment
        assert!(coin::value(&payment) >= price, ERR_INSUFFICIENT_PAYMENT);

        let buyer = ctx.sender();
        let nft_id = object::id(&nft);
        let sold_at = ctx.epoch_timestamp_ms();

        // Update marketplace stats
        marketplace.active_listings = marketplace.active_listings - 1;
        marketplace.total_volume = marketplace.total_volume + price;

        // Transfer payment to seller
        transfer::public_transfer(payment, seller);

        emit(NFTSold {
            listing_id,
            nft_id,
            collection_id,
            seller,
            buyer,
            price,
            sold_at,
        });

        nft
    }

    /// Delist an NFT (remove from marketplace)
    public fun delist_nft<T: store>(
        marketplace: &mut Marketplace,
        listing_id: ID,
        ctx: &mut TxContext,
    ): Collectible<T> {
        assert!(dof::exists_(&marketplace.id, listing_id), ERR_LISTING_NOT_FOUND);

        let listing: Listing<T> = dof::remove(&mut marketplace.id, listing_id);
        let Listing {
            id,
            nft,
            price: _,
            seller,
            collection_id,
            created_at: _,
        } = listing;

        object::delete(id);

        // Verify caller is the seller
        assert!(ctx.sender() == seller, ERR_NOT_OWNER);

        let nft_id = object::id(&nft);
        let delisted_at = ctx.epoch_timestamp_ms();

        // Update marketplace stats
        marketplace.active_listings = marketplace.active_listings - 1;

        emit(NFTDelisted {
            listing_id,
            nft_id,
            collection_id,
            seller,
            delisted_at,
        });

        nft
    }

    /// Update the price of a listing
    public fun update_price<T: store>(
        marketplace: &mut Marketplace,
        listing_id: ID,
        new_price: u64,
        ctx: &mut TxContext,
    ) {
        assert!(dof::exists_(&marketplace.id, listing_id), ERR_LISTING_NOT_FOUND);
        assert!(new_price > 0, ERR_INVALID_PRICE);

        let listing: &mut Listing<T> = dof::borrow_mut(&mut marketplace.id, listing_id);
        
        // Verify caller is the seller
        assert!(ctx.sender() == listing.seller, ERR_NOT_OWNER);

        let old_price = listing.price;
        listing.price = new_price;

        let updated_at = ctx.epoch_timestamp_ms();

        emit(PriceUpdated {
            listing_id,
            nft_id: object::id(&listing.nft),
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
        dof::exists_(&marketplace.id, listing_id)
    }

    /// Get listing details
    public fun get_listing_details<T: store>(
        marketplace: &Marketplace,
        listing_id: ID,
    ): (u64, address, ID, u64) {
        assert!(dof::exists_(&marketplace.id, listing_id), ERR_LISTING_NOT_FOUND);
        let listing: &Listing<T> = dof::borrow(&marketplace.id, listing_id);
        (listing.price, listing.seller, listing.collection_id, listing.created_at)
    }

    /// Get NFT reference from listing
    public fun get_nft_from_listing<T: store>(
        marketplace: &Marketplace,
        listing_id: ID,
    ): &Collectible<T> {
        assert!(dof::exists_(&marketplace.id, listing_id), ERR_LISTING_NOT_FOUND);
        let listing: &Listing<T> = dof::borrow(&marketplace.id, listing_id);
        &listing.nft
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }
}