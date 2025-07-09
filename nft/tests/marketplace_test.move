#[test_only]
module nft::marketplace_test {
    use nft::{
        collectible::{Self as collectible, Collection, CollectionCap, CollectionTicket, Collectible},
        marketplace::{Self, Marketplace, MarketplaceCap},
        registry::{Self, Registry}
    };
    use std::{option::{some, none}, string::String};
    use sui::{
        coin::{Self, Coin},
        sui::SUI,
        test_scenario::{Self as scenario, Scenario},
        test_utils::{destroy, assert_eq}
    };

    // Test addresses
    const ALICE: address = @0x1abc;
    const BOB: address = @0x2def;
    const CHARLIE: address = @0x3456;

    // Test structs
    public struct MARKETPLACE_TEST has drop {}

    public struct TestMeta has key, store {
        id: UID,
        name: String,
        rarity: u8,
    }

    // Setup functions
    fun setup_test_environment(): (Scenario, Registry, Collection<TestMeta>, CollectionCap<TestMeta>, Marketplace) {
        let mut scenario = scenario::begin(ALICE);
        
        // Initialize registry
        registry::test_init(scenario.ctx());
        scenario.next_tx(ALICE);
        let registry = scenario.take_shared<Registry>();
        
        // Initialize marketplace
        marketplace::test_init(scenario.ctx());
        scenario.next_tx(ALICE);
        let marketplace = scenario.take_shared<Marketplace>();
        
        // Create collection
        let otw = MARKETPLACE_TEST {};
        collectible::claim_ticket<MARKETPLACE_TEST, TestMeta>(otw, some(1000), scenario.ctx());
        scenario.next_tx(ALICE);
        
        let ticket = scenario.take_from_sender<CollectionTicket<TestMeta>>();
        let (collection, cap) = ticket.create_collection(
            &registry,
            b"https://example.com/banner".to_string(),
            vector[b"Background".to_string(), b"Clothing".to_string()],
            some(b"Test Creator".to_string()),
            false, // not dynamic
            true,  // burnable
            true,  // meta_borrowable
            scenario.ctx(),
        );
        
        transfer::public_share_object(collection);
        scenario.next_tx(ALICE);
        
        let collection = scenario.take_shared<Collection<TestMeta>>();
        
        (scenario, registry, collection, cap, marketplace)
    }

    fun mint_test_nft(
        scenario: &mut Scenario,
        collection: &mut Collection<TestMeta>,
        cap: &CollectionCap<TestMeta>,
        recipient: address,
    ): Collectible<TestMeta> {
        scenario.next_tx(recipient);
        
        let meta = TestMeta {
            id: object::new(scenario.ctx()),
            name: b"Test NFT".to_string(),
            rarity: 5,
        };
        
        collection.mint(
            cap,
            some(b"Test NFT Name".to_string()),
            b"https://example.com/image.png".to_string(),
            some(b"Test NFT Description".to_string()),
            none(), // no attributes
            some(meta),
            scenario.ctx(),
        )
    }

    fun create_test_coin(amount: u64, ctx: &mut TxContext): Coin<SUI> {
        coin::mint_for_testing<SUI>(amount, ctx)
    }

    // Test cases
    #[test]
    fun test_marketplace_initialization() {
        let mut scenario = scenario::begin(ALICE);
        
        marketplace::test_init(scenario.ctx());
        scenario.next_tx(ALICE);
        
        let marketplace = scenario.take_shared<Marketplace>();
        let (total_listings, active_listings, total_volume) = marketplace::get_marketplace_stats(&marketplace);
        
        assert_eq(total_listings, 0);
        assert_eq(active_listings, 0);
        assert_eq(total_volume, 0);
        
        destroy(marketplace);
        scenario.end();
    }

    #[test]
    fun test_list_nft() {
        let (mut scenario, registry, mut collection, cap, mut marketplace) = setup_test_environment();
        
        // Mint an NFT
        let nft = mint_test_nft(&mut scenario, &mut collection, &cap, ALICE);
        let nft_id = object::id(&nft);
        
        // List the NFT
        marketplace::list_nft(
            &mut marketplace,
            &collection,
            nft,
            1000, // price in SUI
            scenario.ctx(),
        );
        
        // Check marketplace stats
        let (total_listings, active_listings, total_volume) = marketplace::get_marketplace_stats(&marketplace);
        assert_eq(total_listings, 1);
        assert_eq(active_listings, 1);
        assert_eq(total_volume, 0);
        
        destroy(marketplace);
        destroy(collection);
        destroy(cap);
        destroy(registry);
        scenario.end();
    }

    #[test]
    fun test_buy_nft() {
        let (mut scenario, registry, mut collection, cap, mut marketplace) = setup_test_environment();
        
        // Mint an NFT for Alice
        let nft = mint_test_nft(&mut scenario, &mut collection, &cap, ALICE);
        let nft_id = object::id(&nft);
        
        // Alice lists the NFT
        marketplace::list_nft(
            &mut marketplace,
            &collection,
            nft,
            1000, // price in SUI
            scenario.ctx(),
        );
        
        // Get the listing ID (in practice, this would be obtained from events)
        let listing_id = nft_id; // Using nft_id as placeholder for listing_id
        
        // Bob buys the NFT
        scenario.next_tx(BOB);
        let payment = create_test_coin(1000, scenario.ctx());
        
        let purchased_nft = marketplace::buy_nft<TestMeta>(
            &mut marketplace,
            listing_id,
            payment,
            scenario.ctx(),
        );
        
        // Verify NFT ownership changed
        assert_eq(object::id(&purchased_nft), nft_id);
        
        // Check marketplace stats
        let (total_listings, active_listings, total_volume) = marketplace::get_marketplace_stats(&marketplace);
        assert_eq(total_listings, 1);
        assert_eq(active_listings, 0);
        assert_eq(total_volume, 1000);
        
        destroy(purchased_nft);
        destroy(marketplace);
        destroy(collection);
        destroy(cap);
        destroy(registry);
        scenario.end();
    }

    #[test]
    fun test_delist_nft() {
        let (mut scenario, registry, mut collection, cap, mut marketplace) = setup_test_environment();
        
        // Mint an NFT
        let nft = mint_test_nft(&mut scenario, &mut collection, &cap, ALICE);
        let nft_id = object::id(&nft);
        
        // List the NFT
        marketplace::list_nft(
            &mut marketplace,
            &collection,
            nft,
            1000, // price in SUI
            scenario.ctx(),
        );
        
        // Get the listing ID
        let listing_id = nft_id; // Using nft_id as placeholder
        
        // Delist the NFT
        let delisted_nft = marketplace::delist_nft<TestMeta>(
            &mut marketplace,
            listing_id,
            scenario.ctx(),
        );
        
        // Verify NFT is returned
        assert_eq(object::id(&delisted_nft), nft_id);
        
        // Check marketplace stats
        let (total_listings, active_listings, total_volume) = marketplace::get_marketplace_stats(&marketplace);
        assert_eq(total_listings, 1);
        assert_eq(active_listings, 0);
        assert_eq(total_volume, 0);
        
        destroy(delisted_nft);
        destroy(marketplace);
        destroy(collection);
        destroy(cap);
        destroy(registry);
        scenario.end();
    }

    #[test]
    fun test_update_price() {
        let (mut scenario, registry, mut collection, cap, mut marketplace) = setup_test_environment();
        
        // Mint an NFT
        let nft = mint_test_nft(&mut scenario, &mut collection, &cap, ALICE);
        let nft_id = object::id(&nft);
        
        // List the NFT
        marketplace::list_nft(
            &mut marketplace,
            &collection,
            nft,
            1000, // initial price
            scenario.ctx(),
        );
        
        // Get the listing ID
        let listing_id = nft_id; // Using nft_id as placeholder
        
        // Update the price
        marketplace::update_price<TestMeta>(
            &mut marketplace,
            listing_id,
            1500, // new price
            scenario.ctx(),
        );
        
        // Verify price was updated
        let (price, seller, collection_id, created_at) = marketplace::get_listing_details<TestMeta>(
            &marketplace,
            listing_id,
        );
        assert_eq(price, 1500);
        assert_eq(seller, ALICE);
        
        destroy(marketplace);
        destroy(collection);
        destroy(cap);
        destroy(registry);
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 103)] // ERR_INVALID_PRICE
    fun test_list_nft_with_zero_price() {
        let (mut scenario, registry, mut collection, cap, mut marketplace) = setup_test_environment();
        
        // Mint an NFT
        let nft = mint_test_nft(&mut scenario, &mut collection, &cap, ALICE);
        
        // Try to list NFT with zero price - should fail
        marketplace::list_nft(
            &mut marketplace,
            &collection,
            nft,
            0, // invalid price
            scenario.ctx(),
        );
        
        destroy(marketplace);
        destroy(collection);
        destroy(cap);
        destroy(registry);
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 100)] // ERR_INSUFFICIENT_PAYMENT
    fun test_buy_nft_insufficient_payment() {
        let (mut scenario, registry, mut collection, cap, mut marketplace) = setup_test_environment();
        
        // Mint an NFT
        let nft = mint_test_nft(&mut scenario, &mut collection, &cap, ALICE);
        let nft_id = object::id(&nft);
        
        // List the NFT
        marketplace::list_nft(
            &mut marketplace,
            &collection,
            nft,
            1000, // price
            scenario.ctx(),
        );
        
        // Try to buy with insufficient payment - should fail
        scenario.next_tx(BOB);
        let insufficient_payment = create_test_coin(500, scenario.ctx()); // less than price
        
        let listing_id = nft_id; // Using nft_id as placeholder
        let purchased_nft = marketplace::buy_nft<TestMeta>(
            &mut marketplace,
            listing_id,
            insufficient_payment,
            scenario.ctx(),
        );
        
        destroy(purchased_nft);
        destroy(marketplace);
        destroy(collection);
        destroy(cap);
        destroy(registry);
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 102)] // ERR_NOT_OWNER
    fun test_delist_nft_not_owner() {
        let (mut scenario, registry, mut collection, cap, mut marketplace) = setup_test_environment();
        
        // Mint an NFT for Alice
        let nft = mint_test_nft(&mut scenario, &mut collection, &cap, ALICE);
        let nft_id = object::id(&nft);
        
        // Alice lists the NFT
        marketplace::list_nft(
            &mut marketplace,
            &collection,
            nft,
            1000,
            scenario.ctx(),
        );
        
        // Bob tries to delist Alice's NFT - should fail
        scenario.next_tx(BOB);
        let listing_id = nft_id; // Using nft_id as placeholder
        let delisted_nft = marketplace::delist_nft<TestMeta>(
            &mut marketplace,
            listing_id,
            scenario.ctx(),
        );
        
        destroy(delisted_nft);
        destroy(marketplace);
        destroy(collection);
        destroy(cap);
        destroy(registry);
        scenario.end();
    }
}