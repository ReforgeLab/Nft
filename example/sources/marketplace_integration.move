// SPDX-License-Identifier: MIT

/// Comprehensive example showing marketplace integration with NFT collections
/// This demonstrates real-world usage patterns for the marketplace system
module example::marketplace_integration {
    use nft::{
        collectible::{Self, CollectionCap, CollectionTicket, Collection, Collectible},
        marketplace_simple::{Self as marketplace, Marketplace, Escrow},
        marketplace_utils::{Self as utils},
        registry::Registry
    };
    use std::{option::{none, some}, string::{Self, String}};
    use sui::{
        coin::{Self, Coin},
        sui::SUI,
        event::emit
    };

    // ===================== Constants =====================

    /// Collection configuration
    const MAX_SUPPLY: u32 = 10000;
    const COLLECTION_NAME: vector<u8> = b"Mystical Creatures";
    const COLLECTION_DESCRIPTION: vector<u8> = b"A collection of mystical creatures with unique powers";

    /// Rarity levels
    const RARITY_COMMON: u8 = 1;
    const RARITY_UNCOMMON: u8 = 2;
    const RARITY_RARE: u8 = 3;
    const RARITY_EPIC: u8 = 4;
    const RARITY_LEGENDARY: u8 = 5;

    // ===================== Structs =====================

    public struct MARKETPLACE_INTEGRATION has drop {}

    public struct CreatureMetadata has key, store {
        id: UID,
        name: String,
        species: String,
        element: String,
        rarity: u8,
        power: u64,
        health: u64,
        speed: u64,
        generation: u64,
        birth_time: u64,
    }

    // ===================== Events =====================

    public struct CreatureCreated has copy, drop {
        creature_id: ID,
        name: String,
        species: String,
        element: String,
        rarity: u8,
        owner: address,
    }

    public struct CreatureListedForSale has copy, drop {
        creature_id: ID,
        name: String,
        rarity: u8,
        price: u64,
        seller: address,
    }

    public struct CreatureSold has copy, drop {
        creature_id: ID,
        name: String,
        rarity: u8,
        price: u64,
        seller: address,
        buyer: address,
    }

    // ===================== Initialization =====================

    fun init(otw: MARKETPLACE_INTEGRATION, ctx: &mut TxContext) {
        collectible::claim_ticket<MARKETPLACE_INTEGRATION, CreatureMetadata>(
            otw,
            some(MAX_SUPPLY),
            ctx
        );
    }

    #[allow(lint(self_transfer))]
    public fun setup_collection(
        ticket: CollectionTicket<CreatureMetadata>,
        registry: &Registry,
        ctx: &mut TxContext,
    ) {
        let (mut collection, cap) = ticket.create_collection(
            registry,
            b"https://mystical-creatures.com/banner.png".to_string(),
            vector[
                b"Species".to_string(),
                b"Element".to_string(),
                b"Rarity".to_string(),
                b"Power".to_string(),
                b"Health".to_string(),
                b"Speed".to_string(),
            ],
            some(b"Mystical Creatures Studio".to_string()),
            true,  // dynamic - allows attribute modification
            false, // not burnable - preserve value
            true,  // meta_borrowable
            ctx,
        );

        // Setup enhanced display
        setup_display(&mut collection, &cap);

        transfer::public_share_object(collection);
        transfer::public_transfer(cap, ctx.sender());
    }

    fun setup_display(
        collection: &mut Collection<CreatureMetadata>,
        cap: &CollectionCap<CreatureMetadata>,
    ) {
        let (mut display, borrow) = collection.borrow_mut_display_collectible(cap);
        
        // Basic info
        display.add(b"project_name".to_string(), b"Mystical Creatures".to_string());
        display.add(b"website".to_string(), b"https://mystical-creatures.com".to_string());
        display.add(b"twitter".to_string(), b"@mystical_creatures".to_string());
        display.add(b"discord".to_string(), b"https://discord.gg/mystical".to_string());
        
        // Marketplace info
        display.add(b"marketplace".to_string(), b"https://mystical-creatures.com/marketplace".to_string());
        display.add(b"trading_enabled".to_string(), b"true".to_string());
        
        display.update_version();
        collection.return_display_collectible(display, borrow);
    }

    // ===================== Creature Creation =====================

    #[allow(lint(self_transfer))]
    public fun create_creature(
        collection: &mut Collection<CreatureMetadata>,
        cap: &CollectionCap<CreatureMetadata>,
        name: String,
        species: String,
        element: String,
        rarity: u8,
        power: u64,
        health: u64,
        speed: u64,
        generation: u64,
        ctx: &mut TxContext,
    ) {
        let birth_time = ctx.epoch_timestamp_ms();
        let creator = ctx.sender();
        
        // Create metadata
        let metadata = CreatureMetadata {
            id: object::new(ctx),
            name,
            species,
            element,
            rarity,
            power,
            health,
            speed,
            generation,
            birth_time,
        };

        // Generate image URL based on attributes
        let image_url = generate_image_url(&species, &element, rarity);
        
        // Create attributes
        let mut attributes = vector::empty();
        
        // Species attribute
        let species_attr = collection.mint_attribute(
            cap,
            some(b"https://mystical-creatures.com/species/".to_string()),
            b"Species".to_string(),
            species,
            none(),
            ctx,
        );
        vector::push_back(&mut attributes, species_attr);
        
        // Element attribute
        let element_attr = collection.mint_attribute(
            cap,
            some(b"https://mystical-creatures.com/elements/".to_string()),
            b"Element".to_string(),
            element,
            none(),
            ctx,
        );
        vector::push_back(&mut attributes, element_attr);
        
        // Rarity attribute
        let rarity_attr = collection.mint_attribute(
            cap,
            some(b"https://mystical-creatures.com/rarity/".to_string()),
            b"Rarity".to_string(),
            rarity_to_string(rarity),
            none(),
            ctx,
        );
        vector::push_back(&mut attributes, rarity_attr);

        // Create the NFT
        let nft = collection.mint(
            cap,
            some(name),
            image_url,
            some(generate_description(&species, &element, rarity)),
            some(attributes),
            some(metadata),
            ctx,
        );

        let creature_id = object::id(&nft);

        emit(CreatureCreated {
            creature_id,
            name,
            species,
            element,
            rarity,
            owner: creator,
        });

        transfer::public_transfer(nft, creator);
    }

    // ===================== Marketplace Integration =====================

    #[allow(lint(self_transfer))]
    public fun list_creature_for_sale(
        marketplace: &mut Marketplace,
        collection: &Collection<CreatureMetadata>,
        creature: Collectible<CreatureMetadata>,
        price: u64,
        ctx: &mut TxContext,
    ) {
        let creature_id = object::id(&creature);
        let seller = ctx.sender();
        
        // Get creature metadata for event (simplified - in practice you'd borrow it)
        let rarity = 1; // Placeholder
        let name = b"Creature".to_string(); // Placeholder
        
        marketplace::list_nft(
            marketplace,
            collection,
            creature,
            price,
            ctx,
        );

        emit(CreatureListedForSale {
            creature_id,
            name,
            rarity,
            price,
            seller,
        });
    }

    #[allow(lint(self_transfer))]
    public fun buy_creature(
        marketplace: &mut Marketplace,
        escrow: Escrow<CreatureMetadata>,
        payment: Coin<SUI>,
        ctx: &mut TxContext,
    ) {
        let buyer = ctx.sender();
        
        // Get creature info before purchase (simplified)
        let creature_id = object::new(ctx);
        let creature_uid = object::uid_to_inner(&creature_id);
        object::delete(creature_id);
        
        let price = coin::value(&payment);
        
        let creature = marketplace::buy_nft(
            marketplace,
            escrow,
            payment,
            ctx,
        );

        // Emit purchase event
        emit(CreatureSold {
            creature_id: creature_uid,
            name: b"Creature".to_string(),
            rarity: 1,
            price,
            seller: @0x0, // Placeholder
            buyer,
        });

        transfer::public_transfer(creature, buyer);
    }

    #[allow(lint(self_transfer))]
    public fun cancel_creature_listing(
        marketplace: &mut Marketplace,
        escrow: Escrow<CreatureMetadata>,
        ctx: &mut TxContext,
    ) {
        let creature = marketplace::delist_nft(
            marketplace,
            escrow,
            ctx,
        );
        
        transfer::public_transfer(creature, ctx.sender());
    }

    // ===================== Market Analysis =====================

    /// Get floor price for creatures by rarity
    public fun get_floor_price_by_rarity(
        marketplace: &Marketplace,
        collection_id: ID,
        rarity: u8,
    ): Option<u64> {
        // In a real implementation, this would filter by rarity
        utils::get_floor_price(marketplace, collection_id)
    }

    /// Get recommended listing price
    public fun get_recommended_listing_price(
        marketplace: &Marketplace,
        collection_id: ID,
        rarity: u8,
    ): Option<u64> {
        // Base recommendation on rarity multiplier
        let base_price = utils::get_floor_price(marketplace, collection_id);
        if (option::is_some(&base_price)) {
            let floor = *option::borrow(&base_price);
            let multiplier = rarity_price_multiplier(rarity);
            option::some(floor * multiplier / 100)
        } else {
            option::none<u64>()
        }
    }

    /// Check if listing price is competitive
    public fun is_competitive_price(
        marketplace: &Marketplace,
        collection_id: ID,
        rarity: u8,
        price: u64,
    ): bool {
        let recommended = get_recommended_listing_price(marketplace, collection_id, rarity);
        if (option::is_some(&recommended)) {
            price <= *option::borrow(&recommended)
        } else {
            true // No data available, assume competitive
        }
    }

    // ===================== Helper Functions =====================

    fun generate_image_url(species: &String, element: &String, rarity: u8): String {
        let mut url = b"https://mystical-creatures.com/images/".to_string();
        url.append(*species);
        url.append(b"_".to_string());
        url.append(*element);
        url.append(b"_".to_string());
        url.append(rarity_to_string(rarity));
        url.append(b".png".to_string());
        url
    }

    fun generate_description(species: &String, element: &String, rarity: u8): String {
        let mut desc = b"A ".to_string();
        desc.append(rarity_to_string(rarity));
        desc.append(b" ".to_string());
        desc.append(*species);
        desc.append(b" with ".to_string());
        desc.append(*element);
        desc.append(b" elemental powers. This mystical creature is ready for adventure!".to_string());
        desc
    }

    fun rarity_to_string(rarity: u8): String {
        if (rarity == RARITY_COMMON) b"Common".to_string()
        else if (rarity == RARITY_UNCOMMON) b"Uncommon".to_string()
        else if (rarity == RARITY_RARE) b"Rare".to_string()
        else if (rarity == RARITY_EPIC) b"Epic".to_string()
        else b"Legendary".to_string()
    }

    fun rarity_price_multiplier(rarity: u8): u64 {
        if (rarity == RARITY_COMMON) 100        // 1x
        else if (rarity == RARITY_UNCOMMON) 150 // 1.5x
        else if (rarity == RARITY_RARE) 300     // 3x
        else if (rarity == RARITY_EPIC) 500     // 5x
        else 1000                               // 10x for legendary
    }

    // ===================== Getter Functions =====================

    /// Get creature metadata
    public fun get_creature_metadata(creature: &CreatureMetadata): (String, String, String, u8, u64, u64, u64, u64, u64) {
        (
            creature.name,
            creature.species,
            creature.element,
            creature.rarity,
            creature.power,
            creature.health,
            creature.speed,
            creature.generation,
            creature.birth_time
        )
    }

    /// Get creature battle stats
    public fun get_battle_stats(creature: &CreatureMetadata): (u64, u64, u64) {
        (creature.power, creature.health, creature.speed)
    }

    /// Calculate creature value based on stats and rarity
    public fun calculate_creature_value(creature: &CreatureMetadata): u64 {
        let base_value = creature.power + creature.health + creature.speed;
        let rarity_multiplier = rarity_price_multiplier(creature.rarity);
        base_value * rarity_multiplier / 100
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        let otw = MARKETPLACE_INTEGRATION {};
        init(otw, ctx);
    }
}