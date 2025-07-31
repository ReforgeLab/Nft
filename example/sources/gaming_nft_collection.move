module example::gaming_nft {
    use nft::{collectible::{Self, CollectionCap, CollectionTicket, Collection}, registry::Registry};
    use std::{option::{none, some}, string::String};
    use sui::vec_map::{Self as map};

    // One-Time Witness for the gaming collection
    public struct GAMING_NFT has drop{}

    //Comprehensive gaming NFT metadata structure
    public struct GameItem<phantom T> has key, store {
        id: UID,
        // Basic item information 
        item_name: String,
        item_type: String, // "weapon", "armor", "consumable", "artifact"
        description: String,

        // Game mechanics
        level: u64,
        rarity: String, // "common", "uncommon", "rare", "epic", "legendary", "mythic"
        power_level: u64,
        durability: u64,
        max_durability: u64,

        //Stats for RPG mechanics
        attack_power: u64,
        defense_power: u64,
        magic_power: u64,
        speed_bonus: u64,
        critical_chance: u64, // percentage (0-100)

        // Crafting and enhancement
        enhancement_level: u64,
        max_enhancement: u64,
        crafting_materials: vector<String>,
        enchantments: vector<String>,

        // Ownership and history
        original_owner: address,
        current_owner: address,
        creation_timestamp: u64,
        last_used_timestamp: u64,
        total_battles: u64,
        victories: u64,

        // Special properties
        is_tradeable: bool,
        is_upgradeable: bool,
        is_consumable: bool,
        uses_remaining: Option<u64>,

        // Lore and flavor
        lore_text: String,
        origin_story: String,
        legendary_deeds: vector<String>
    }

    // Initialize the gaming NFT collection
    fun init(otw: GAMING_NFT, ctx: &mut TxContext) {
        // Create ticket with max supply of 10,000 items
        collectible::claim_ticket<GAMING_NFT, GameItem<GAMING_NFT>>(otw, option::some(10000), ctx);
    }

    // Create a comprehensive gaming collection with dertailed attribute schema
    #[allow(lint(self_transfer))]
    public fun create_gaming_collection(
        ticket: CollectionTicket<GameItem<GAMING_NFT>>,
        registry: &Registry,
        ctx: &mut TxContext
    ) {
        let mut fields = map::empty<String, vector<String>>();

         // Item types
        fields.insert(
            b"ItemType".to_string(), 
            vector[
                b"Sword".to_string(), b"Axe".to_string(), b"Bow".to_string(), b"Staff".to_string(),
                b"Shield".to_string(), b"Helmet".to_string(), b"Armor".to_string(), b"Boots".to_string(),
                b"Ring".to_string(), b"Amulet".to_string(), b"Potion".to_string(), b"Scroll".to_string()
            ]
        );

        // Rarity tiers
        fields.insert(
            b"Rarity".to_string(),
            vector[
                b"Common".to_string(), b"Uncommon".to_string(), b"Rare".to_string(),
                b"Epic".to_string(), b"Legendary".to_string(), b"Mythic".to_string()
            ]
        );
        
        // Enchantments
        fields.insert(
            b"Enchantment".to_string(),
            vector[
                b"Fire".to_string(), b"Ice".to_string(), b"Lightning".to_string(), b"Poison".to_string(),
                b"Holy".to_string(), b"Shadow".to_string(), b"Arcane".to_string(), b"Nature".to_string()
            ]
        );
        
        // Materials
        fields.insert(
            b"Material".to_string(),
            vector[
                b"Iron".to_string(), b"Steel".to_string(), b"Mithril".to_string(), b"Adamantine".to_string(),
                b"Dragonscale".to_string(), b"Ethereal".to_string(), b"Void".to_string()
            ]
        );

        let (cap, render_cap_opt) = ticket.create_collection<GameItem<GAMING_NFT>>(
            registry,
            b"https://gaming-nft-banner.com/epic-items".to_string(),
            fields,
            some(b"Epic Games Studio - Master Craftsmen".to_string()),
            true,  // dynamic - items can be enhanced and modified
            false, // not burnable - preserve game history
            true,  // strict schema - maintain game balance
            true,  // meta borrowable - allow temporary lending for battles
            ctx,
        );

        if (render_cap_opt.is_some()) {
            let render_cap = render_cap_opt.destroy_some();
            transfer::public_transfer(render_cap, ctx.sender());
        } else {
            option::destroy_none(render_cap_opt)
        };

        transfer::public_transfer(cap, ctx.sender())
    }

    // Mint a legendary weapon with full stats and lore
    #[allow(lint(self_transfer))]
    public fun mint_legendary_weapon(
        collection: &mut Collection<GameItem<GAMING_NFT>>,
        cap: &CollectionCap<GameItem<GAMING_NFT>>,
        weapon_name: String,
        weapon_type: String,
        lore: String,
        ctx: &mut TxContext,
    ) {
        // Create enchantment attributes
        let fire_enchant = collection.mint_attribute(
            cap,
            some(b"https://images.game.com/enchants/fire.png".to_string()),
            b"Enchantment".to_string(),
            b"Fire".to_string(),
            none(),
            ctx,
        );

        let material_attr = collection.mint_attribute(
            cap,
            some(b"https://images.game.com/materials/mithril.png".to_string()),
            b"Material".to_string(),
            b"Mithril".to_string(),
            none(),
            ctx,
        );

        // Create comprehensive game item metadata
        let game_meta = GameItem<GAMING_NFT> {
            id: object::new(ctx),
            item_name: weapon_name,
            item_type: weapon_type,
            description: b"A legendary weapon forged in the fires of Mount Doom".to_string(),
            
            level: 50,
            rarity: b"Legendary".to_string(),
            power_level: 850,
            durability: 1000,
            max_durability: 1000,
            
            attack_power: 120,
            defense_power: 30,
            magic_power: 80,
            speed_bonus: 15,
            critical_chance: 25,
            
            enhancement_level: 0,
            max_enhancement: 10,
            crafting_materials: vector[
                b"Mithril Ore".to_string(), 
                b"Dragon Heart".to_string(), 
                b"Phoenix Feather".to_string()
            ],
            enchantments: vector[b"Fire Damage +50".to_string()],
            
            original_owner: ctx.sender(),
            current_owner: ctx.sender(),
            creation_timestamp: ctx.epoch(),
            last_used_timestamp: 0,
            total_battles: 0,
            victories: 0,
            
            is_tradeable: true,
            is_upgradeable: true,
            is_consumable: false,
            uses_remaining: none(),
            
            lore_text: lore,
            origin_story: b"Forged by the legendary blacksmith Thorin in the age of heroes".to_string(),
            legendary_deeds: vector[],
        
        };

        let nft = collection.mint(
            cap,
            some(weapon_name),
            b"https://images.game.com/weapons/legendary-sword.png".to_string(),
            some(b"A weapon of immense power, capable of cleaving through the strongest armor".to_string()),
            some(vector[fire_enchant, material_attr]),
            some(game_meta),
            ctx,
        );

        transfer::public_transfer(nft, ctx.sender());
    }

    // Mint consumable items with limited uses
    #[allow(lint(self_transfer))]
    public fun mint_consumable_potion(
        collection: &mut Collection<GameItem<GAMING_NFT>>,
        cap: &CollectionCap<GameItem<GAMING_NFT>>,
        potion_name: String,
        uses: u64,
        ctx: &mut TxContext,
    ) {
        let consumable_meta = GameItem<GAMING_NFT> {
            id: object::new(ctx),
            item_name: potion_name,
            item_type: b"Consumable".to_string(),
            description: b"A powerful healing potion brewed by master alchemists".to_string(),
            
            level: 1,
            rarity: b"Common".to_string(),
            power_level: 50,
            durability: uses,
            max_durability: uses,
            
            attack_power: 0,
            defense_power: 0,
            magic_power: 0,
            speed_bonus: 0,
            critical_chance: 0,
            
            enhancement_level: 0,
            max_enhancement: 0,
            crafting_materials: vector[
                b"Healing Herbs".to_string(), 
                b"Pure Water".to_string(), 
                b"Magic Crystal".to_string()
            ],
            enchantments: vector[],
            
            original_owner: ctx.sender(),
            current_owner: ctx.sender(),
            creation_timestamp: ctx.epoch(),
            last_used_timestamp: 0,
            total_battles: 0,
            victories: 0,
            
            is_tradeable: true,
            is_upgradeable: false,
            is_consumable: true,
            uses_remaining: some(uses),
            
            lore_text: b"Restores health and vitality to the weary adventurer".to_string(),
            origin_story: b"Crafted in the ancient alchemical laboratories".to_string(),
            legendary_deeds: vector[],
        };

        let nft = collection.mint(
            cap,
            some(potion_name),
            b"https://images.game.com/potions/healing-potion.png".to_string(),
            some(b"Restores 100 HP when consumed".to_string()),
            none(),
            some(consumable_meta),
            ctx,
        );

        transfer::public_transfer(nft, ctx.sender());
    }
    
    // Batch mint starter equipment for new players
    #[allow(lint(self_transfer))]
    public fun mint_starter_set(
        collection: &mut Collection<GameItem<GAMING_NFT>>,
        cap: &CollectionCap<GameItem<GAMING_NFT>>,
        player: address,
        ctx: &mut TxContext,
    ) {
        // Mint basic sword
        let sword_meta = GameItem<GAMING_NFT> {
            id: object::new(ctx),
            item_name: b"Iron Sword".to_string(),
            item_type: b"Sword".to_string(),
            description: b"A basic iron sword for beginning adventurers".to_string(),
            level: 1, rarity: b"Common".to_string(), power_level: 25,
            durability: 100, max_durability: 100,
            attack_power: 15, defense_power: 0, magic_power: 0, speed_bonus: 0, critical_chance: 5,
            enhancement_level: 0, max_enhancement: 5,
            crafting_materials: vector[b"Iron Ore".to_string()],
            enchantments: vector[],
            original_owner: player, current_owner: player,
            creation_timestamp: ctx.epoch(), last_used_timestamp: 0,
            total_battles: 0, victories: 0,
            is_tradeable: true, is_upgradeable: true, is_consumable: false,
            uses_remaining: none(),
            lore_text: b"Every hero's journey begins with a single step".to_string(),
            origin_story: b"Forged by the village blacksmith".to_string(),
            legendary_deeds: vector[],
        };

        let sword = collection.mint(
            cap, some(b"Iron Sword".to_string()),
            b"https://images.game.com/weapons/iron-sword.png".to_string(),
            some(b"A reliable starter weapon".to_string()),
            none(), some(sword_meta), ctx,
        );

        // Mint basic armor
        let armor_meta = GameItem<GAMING_NFT> {
            id: object::new(ctx),
            item_name: b"Leather Armor".to_string(),
            item_type: b"Armor".to_string(),
            description: b"Basic leather armor providing minimal protection".to_string(),
            level: 1, rarity: b"Common".to_string(), power_level: 20,
            durability: 80, max_durability: 80,
            attack_power: 0, defense_power: 10, magic_power: 0, speed_bonus: 0, critical_chance: 0,
            enhancement_level: 0, max_enhancement: 5,
            crafting_materials: vector[b"Leather".to_string()],
            enchantments: vector[],
            original_owner: player, current_owner: player,
            creation_timestamp: ctx.epoch(), last_used_timestamp: 0,
            total_battles: 0, victories: 0,
            is_tradeable: true, is_upgradeable: true, is_consumable: false,
            uses_remaining: none(),
            lore_text: b"Simple protection for the aspiring adventurer".to_string(),
            origin_story: b"Crafted by the village leatherworker".to_string(),
            legendary_deeds: vector[],
        };

        let armor = collection.mint(
            cap, some(b"Leather Armor".to_string()),
            b"https://images.game.com/armor/leather-armor.png".to_string(),
            some(b"Basic protection for new adventurers".to_string()),
            none(), some(armor_meta), ctx,
        );

        transfer::public_transfer(sword, player);
        transfer::public_transfer(armor, player);
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        let otw = GAMING_NFT {};
        init(otw, ctx);
    }
}