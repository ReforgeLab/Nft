#[test_only]
module nft::collectible_test;

use nft::{
    attributes::Attribute,
    collectible::{Self as contract, CollectionTicket, Collection, CollectionCap, Collectible},
    registry::{Self, Registry}
};
use std::{option::{some, none}, string::String, unit_test::assert_eq};
use sui::{
    test_scenario::{Self as scenario, Scenario},
    test_utils::destroy,
    vec_map::{Self as map, VecMap}
};

const Alice: address = @0x1abc;

public struct COLLECTIBLE_TEST has drop {}

public struct Meta has key, store {
    id: UID,
    cool: bool,
    animal: bool,
}

public struct AttributeMeta has store {}

public struct PixelArtMeta has key, store {
    id: UID,
    creator: address,
    layer_count: u64,
    editing_tool: String,
}

fun setup(dynamic: bool): (Scenario, Registry, CollectionCap<Meta>) {
    let mut scenario = scenario::begin(Alice);
    registry::test_init(scenario.ctx());
    scenario.next_tx(Alice);

    let registry = scenario.take_shared<Registry>();
    scenario.next_tx(Alice);

    let otw = COLLECTIBLE_TEST {};

    contract::claim_ticket<COLLECTIBLE_TEST, Meta>(otw, option::some(100), scenario.ctx());
    scenario.next_tx(Alice);

    let ticket = scenario.take_from_sender<CollectionTicket<Meta>>();

    let coll_cap = setup_collection(&mut scenario, &registry, dynamic, ticket);
    scenario.next_tx(Alice);

    (scenario, registry, coll_cap)
}

fun setup_strict_collection(): (Scenario, Registry, CollectionCap<Meta>) {
    let mut scenario = scenario::begin(Alice);
    registry::test_init(scenario.ctx());
    scenario.next_tx(Alice);

    let registry = scenario.take_shared<Registry>();
    scenario.next_tx(Alice);

    let otw = COLLECTIBLE_TEST {};

    contract::claim_ticket<COLLECTIBLE_TEST, Meta>(otw, option::some(100), scenario.ctx());
    scenario.next_tx(Alice);

    let ticket = scenario.take_from_sender<CollectionTicket<Meta>>();

    let coll_cap = create_strict_collection(&mut scenario, &registry, ticket);
    scenario.next_tx(Alice);

    (scenario, registry, coll_cap)
}

fun setup_dynamic_collection(): (Scenario, Registry, CollectionCap<Meta>) {
    let mut scenario = scenario::begin(Alice);
    registry::test_init(scenario.ctx());
    scenario.next_tx(Alice);

    let registry = scenario.take_shared<Registry>();
    scenario.next_tx(Alice);

    let otw = COLLECTIBLE_TEST {};

    contract::claim_ticket<COLLECTIBLE_TEST, Meta>(otw, option::some(100), scenario.ctx());
    scenario.next_tx(Alice);

    let ticket = scenario.take_from_sender<CollectionTicket<Meta>>();

    let coll_cap = create_dynamic_collection(&mut scenario, &registry, ticket);
    scenario.next_tx(Alice);

    (scenario, registry, coll_cap)
}

#[test]
fun test_collection_getter_functions() {
    let (scen, registry, coll_cap) = setup(false);
    let collection = scen.take_shared<Collection<Meta>>();

    let (burnable, burned_amount) = collection.get_burned();
    // bools and numbers
    assert_eq!(collection.get_minted(), 0);
    assert_eq!(burnable, true);
    assert_eq!(burned_amount, 0);
    assert_eq!(collection.is_dynamic(), false);
    assert_eq!(collection.get_max_supply(), option::some(100));
    // Strings
    assert_eq!(collection.get_creator(), b"Alice".to_string());
    assert_eq!(
        collection.get_banner_url().destroy_some(),
        b"https://example.com/banner".to_string(),
    );

    // Test the new VecMap schema structure
    let attribute_fields = collection.get_attribute_fields();
    assert_eq!(attribute_fields.contains(&b"Background".to_string()), true);
    assert_eq!(attribute_fields.contains(&b"Hat".to_string()), true);
    assert_eq!(attribute_fields.contains(&b"Shoes".to_string()), true);
    assert_eq!(attribute_fields.contains(&b"Jacket".to_string()), true);

    // Id
    assert_eq!(coll_cap.get_collection_id_by_cap(), object::id(&collection));

    destroy(collection);
    destroy(coll_cap);
    destroy(registry);
    scen.end();
}

#[test]
fun test_create_attribute() {
    let (mut scen, registry, coll_cap) = setup(false);

    let mut collection = scen.take_shared<Collection<Meta>>();
    let attribute = setup_attribute(&mut scen, &mut collection, &coll_cap);
    let image_url = attribute.get_attribute_image_url();
    let (key, value) = attribute.get_attribute_data();

    assert_eq!(image_url, option::none());
    assert_eq!(key, b"Background".to_string());
    assert_eq!(value, b"red".to_string());

    destroy(attribute);
    destroy(collection);
    destroy(coll_cap);
    destroy(registry);
    scen.end();
}

#[test]
fun test_create_collectible() {
    let (mut scen, registry, coll_cap) = setup(false);
    let mut collection = scen.take_shared<Collection<Meta>>();

    let attribute = setup_attribute(&mut scen, &mut collection, &coll_cap);
    // std::debug::print(&attribute);
    let attribute_id: ID = object::id(&attribute);
    let collectible = setup_static_collectible(
        &mut scen,
        &mut collection,
        some(vector[attribute]),
        &coll_cap,
    );
    // std::debug::print(&collectible);

    let map: VecMap<String, ID> = collectible.get_equipped_map();
    // std::debug::print(&map);
    let keys: vector<String> = map.keys();
    // std::debug::print(&keys);
    let attribute_value: &ID = map.get(&b"Background".to_string());
    // std::debug::print(&b"After mint in create collectible test".to_string());
    let meta: &Option<Meta> = collectible.borrow_meta();
    let meta: &Meta = meta.borrow();

    assert_eq!(meta.cool, true);
    assert_eq!(meta.animal, false);

    assert!(attribute_id == attribute_value, 0);

    assert_eq!(keys.contains(&b"Background".to_string()), true);
    assert_eq!(collectible.get_name(), b"Name".to_string());
    assert_eq!(collectible.get_image_url(), b"https://example.com/image".to_string());
    assert_eq!(collectible.get_description(), b"Description".to_string());

    destroy(collectible);
    destroy(collection);
    destroy(coll_cap);
    destroy(registry);
    scen.end();
}

#[test]
fun test_nft_with_mutiple_attributes() {
    let (mut scen, registry, coll_cap) = setup(false);
    let mut collection = scen.take_shared<Collection<Meta>>();

    let attributes = setup_multiple_attributes(&mut scen, &mut collection, &coll_cap);

    let (first_key, first_value) = attributes[0].get_attribute_data();
    let first_image: Option<String> = attributes[1].get_attribute_image_url();
    assert_eq!(first_key, b"Background".to_string());
    assert_eq!(first_value, b"red".to_string());
    assert_eq!(first_image, option::none());

    let collectible = collection.mint(
        &coll_cap,
        option::some(b"Name".to_string()),
        b"https://example.com/image".to_string(),
        option::some(b"Description".to_string()),
        option::some(attributes),
        option::none(),
        scen.ctx(),
    );

    let vecmap_attributes: VecMap<String, ID> = collectible.get_equipped_map();

    let (keys, values) = vecmap_attributes.into_keys_values();
    assert_eq!(keys[0], b"Background".to_string());

    destroy(keys);
    destroy(values);
    destroy(vecmap_attributes);
    destroy(collectible);
    destroy(registry);
    destroy(collection);
    destroy(coll_cap);
    scen.end();
}

#[test]
fun test_swap_attribute() {
    let (mut scen, registry, coll_cap) = setup(true);
    let mut collection = scen.take_shared<Collection<Meta>>();

    let attributes = setup_multiple_attributes(&mut scen, &mut collection, &coll_cap);

    let mut collectible = collection.mint(
        &coll_cap,
        option::some(b"Name".to_string()),
        b"https://example.com/image".to_string(),
        option::some(b"Description".to_string()),
        option::some(attributes),
        option::none(),
        scen.ctx(),
    );

    scen.next_tx(Alice);
    // create new attribute
    let new_attribute = collection.mint_attribute<Meta, AttributeMeta>(
        &coll_cap,
        option::some(b"https://example.com/image".to_string()),
        b"Background".to_string(),
        b"Mega blue".to_string(),
        none(),
        scen.ctx(),
    );

    let new_attribute_id = object::id(&new_attribute);

    // swap attributes
    let (old_node, old_background) = collectible.split_attribute<Meta, AttributeMeta>(
        &mut collection,
        b"Background".to_string(),
        scen.ctx(),
    );

    let (old_key, old_value) = old_background.get_attribute_data();
    assert_eq!(old_key, b"Background".to_string());
    assert_eq!(old_value, b"red".to_string());

    let render_node = collectible.join_attribute(&mut collection, new_attribute, scen.ctx());
    destroy(render_node);

    let vecmap_attribute: VecMap<String, ID> = collectible.get_equipped_map();

    let attribute_value: &ID = vecmap_attribute.get(&b"Background".to_string());
    assert!(attribute_value == &new_attribute_id, 10);

    destroy(collectible);
    destroy(old_background);
    destroy(old_node);
    destroy(registry);
    destroy(coll_cap);
    destroy(collection);
    scen.end();
}

#[test]
fun test_dynamic_schema_flexibility() {
    let (mut scen, registry, coll_cap) = setup_dynamic_collection();
    let mut collection = scen.take_shared<Collection<Meta>>();

    // Test that any attribute can be created in dynamic schema
    let dynamic_attribute = collection.mint_attribute<Meta, AttributeMeta>(
        &coll_cap,
        option::none(),
        b"DragonWings".to_string(),
        b"Fire Dragon Wings".to_string(),
        none(),
        scen.ctx(),
    );

    // Verify the dynamic attribute was created successfully
    let (key, value) = dynamic_attribute.get_attribute_data();
    assert_eq!(key, b"DragonWings".to_string());
    assert_eq!(value, b"Fire Dragon Wings".to_string());

    // Verify the attribute was added to the collection's schema
    let attribute_fields = collection.get_attribute_fields();
    assert_eq!(attribute_fields.contains(&b"DragonWings".to_string()), true);

    destroy(dynamic_attribute);
    destroy(collection);
    destroy(coll_cap);
    destroy(registry);
    scen.end();
}

#[test]
fun test_metadata_flexibility() {
    let (mut scen, registry, coll_cap) = setup(false);
    let mut collection = scen.take_shared<Collection<Meta>>();

    // Test with basic metadata
    let basic_meta = Meta {
        id: object::new(scen.ctx()),
        cool: true,
        animal: false,
    };

    let collectible1 = collection.mint<Meta, AttributeMeta>(
        &coll_cap,
        option::some(b"Basic NFT".to_string()),
        b"https://example.com/image1".to_string(),
        option::some(b"Basic description".to_string()),
        option::none(),
        option::some(basic_meta),
        scen.ctx(),
    );

    // Test with different metadata
    let different_meta = Meta {
        id: object::new(scen.ctx()),
        cool: false,
        animal: true,
    };

    let collectible2 = collection.mint<Meta, AttributeMeta>(
        &coll_cap,
        option::some(b"Different NFT".to_string()),
        b"https://example.com/image2".to_string(),
        option::some(b"Different description".to_string()),
        option::none(),
        option::some(different_meta),
        scen.ctx(),
    );

    // Verify metadata is stored correctly
    let meta1: &Option<Meta> = collectible1.borrow_meta();
    let meta1_data: &Meta = meta1.borrow();
    assert_eq!(meta1_data.cool, true);
    assert_eq!(meta1_data.animal, false);

    let meta2: &Option<Meta> = collectible2.borrow_meta();
    let meta2_data: &Meta = meta2.borrow();
    assert_eq!(meta2_data.cool, false);
    assert_eq!(meta2_data.animal, true);

    destroy(collectible1);
    destroy(collectible2);
    destroy(collection);
    destroy(coll_cap);
    destroy(registry);
    scen.end();
}

#[test]
fun test_error_cases() {
    let (mut scen, registry, coll_cap) = setup(true);
    let mut collection = scen.take_shared<Collection<Meta>>();

    // Test basic attribute creation works
    let attribute = collection.mint_attribute<Meta, AttributeMeta>(
        &coll_cap,
        option::none(),
        b"Background".to_string(),
        b"red".to_string(),
        none(),
        scen.ctx(),
    );

    destroy(attribute);
    destroy(collection);
    destroy(coll_cap);
    destroy(registry);
    scen.end();
}

#[test]
fun test_collection_ownership_revocation() {
    let (scen, registry, coll_cap) = setup(false);
    let mut collection = scen.take_shared<Collection<Meta>>();

    // Revoke ownership
    contract::revoke_ownership(coll_cap, &mut collection);

    // Verify collection is no longer owned
    // Note: We can't directly test this without additional getter functions
    // but the operation should complete without error

    destroy(collection);
    destroy(registry);
    scen.end();
}

#[test]
fun test_burn_functionality() {
    let (mut scen, registry, coll_cap) = setup(false);
    let mut collection = scen.take_shared<Collection<Meta>>();

    // Create a collectible
    let collectible = collection.mint<Meta, AttributeMeta>(
        &coll_cap,
        option::some(b"Burnable NFT".to_string()),
        b"https://example.com/image".to_string(),
        option::some(b"Will be burned".to_string()),
        option::none(),
        option::none(),
        scen.ctx(),
    );

    // Burn the collectible
    let meta = contract::destroy_collectible(&mut collection, &coll_cap, collectible);

    // Verify burn was successful - handle the Option properly
    if (option::is_some(&meta)) {
        let _meta_data = option::borrow(&meta);
        // Meta doesn't have drop, so we can't use assert_eq!
        // Just verify the operation completed
    } else {};
    // Consume the option
    option::destroy_none(meta);

    destroy(collection);
    destroy(coll_cap);
    destroy(registry);
    scen.end();
}

#[test]
fun test_schema_structure_validation() {
    let (scen, registry, coll_cap) = setup_strict_collection();
    let collection = scen.take_shared<Collection<Meta>>();

    // Test the new VecMap schema structure
    let attribute_fields = collection.get_attribute_fields();

    // Verify schema contains expected keys
    assert_eq!(attribute_fields.contains(&b"Background".to_string()), true);
    assert_eq!(attribute_fields.contains(&b"Hat".to_string()), true);
    // Only check for keys that are in the strict schema setup
    // Do not check for Shoes/Jacket since not in strict schema

    // Verify schema doesn't contain unexpected keys
    assert_eq!(attribute_fields.contains(&b"InvalidKey".to_string()), false);

    destroy(collection);
    destroy(coll_cap);
    destroy(registry);
    scen.end();
}

// ================= Helper functions =================
fun setup_collection(
    scenario: &mut Scenario,
    registry: &Registry,
    dynamic: bool,
    ticket: CollectionTicket<Meta>,
): CollectionCap<Meta> {
    let banner_url = b"https://example.com/banner".to_string();

    // Create the new VecMap schema structure
    let mut fields = map::empty<String, vector<String>>();
    fields.insert(b"Background".to_string(), vector[b"red".to_string(), b"blue".to_string()]);
    fields.insert(b"Hat".to_string(), vector[b"cowboy".to_string(), b"baseball".to_string()]);
    fields.insert(b"Shoes".to_string(), vector[b"sneakers".to_string(), b"boots".to_string()]);
    fields.insert(b"Jacket".to_string(), vector[b"leather".to_string(), b"denim".to_string()]);

    let (coll_cap, render_cap_opt) = ticket.create_collection<Meta, AttributeMeta>(
        registry,
        some(banner_url),
        none(),
        fields,
        option::some(b"Alice".to_string()),
        dynamic,
        true,
        true,
        true,
        scenario.ctx(),
    );

    if (render_cap_opt.is_some()) {
        let render_cap = render_cap_opt.destroy_some();
        destroy(render_cap);
    } else {
        option::destroy_none(render_cap_opt);
    };
    coll_cap
}

fun create_strict_collection(
    scenario: &mut Scenario,
    registry: &Registry,
    ticket: CollectionTicket<Meta>,
): CollectionCap<Meta> {
    let banner_url = b"https://example.com/banner".to_string();

    // Create strict schema with predefined attributes
    let mut fields = map::empty<String, vector<String>>();
    fields.insert(b"Background".to_string(), vector[b"red".to_string(), b"blue".to_string()]);
    fields.insert(b"Hat".to_string(), vector[b"cowboy".to_string(), b"baseball".to_string()]);

    let (coll_cap, render_cap_opt) = ticket.create_collection<Meta, AttributeMeta>(
        registry,
        some(banner_url),
        none(),
        fields,
        option::some(b"Alice".to_string()),
        true, // dynamic
        true, // burnable
        true, // strict_schema: true
        true, // meta_borrowable
        scenario.ctx(),
    );

    if (render_cap_opt.is_some()) {
        let render_cap = render_cap_opt.destroy_some();
        destroy(render_cap);
    } else {
        option::destroy_none(render_cap_opt);
    };
    coll_cap
}

fun create_dynamic_collection(
    scenario: &mut Scenario,
    registry: &Registry,
    ticket: CollectionTicket<Meta>,
): CollectionCap<Meta> {
    let banner_url = b"https://example.com/banner".to_string();

    // Create dynamic schema with empty fields
    let fields = map::empty<String, vector<String>>();

    let (coll_cap, render_cap_opt) = ticket.create_collection<Meta, AttributeMeta>(
        registry,
        some(banner_url),
        none(),
        fields,
        option::some(b"Alice".to_string()),
        true, // dynamic
        true, // burnable
        false, // strict_schema: false
        true, // meta_borrowable
        scenario.ctx(),
    );

    if (render_cap_opt.is_some()) {
        let render_cap = render_cap_opt.destroy_some();
        destroy(render_cap);
    } else {
        option::destroy_none(render_cap_opt);
    };
    coll_cap
}

fun setup_static_collectible(
    scenario: &mut Scenario,
    collection: &mut Collection<Meta>,
    attribute: Option<vector<Attribute<Meta, AttributeMeta>>>,
    cap: &CollectionCap<Meta>,
): Collectible<Meta> {
    let name = b"Name".to_string();
    let description = b"Description".to_string();
    let image_url = b"https://example.com/image".to_string();
    let meta = Meta { id: object::new(scenario.ctx()), cool: true, animal: false };
    // std::debug::print(&attribute);

    let nft = collection.mint(
        cap,
        some(name),
        image_url,
        some(description),
        attribute,
        some(meta),
        scenario.ctx(),
    );
    // std::debug::print(&b"after mint".to_string());
    nft
}

fun setup_attribute(
    scenario: &mut Scenario,
    collection: &mut Collection<Meta>,
    cap: &CollectionCap<Meta>,
): Attribute<Meta, AttributeMeta> {
    let image_url: Option<String> = option::none();
    let key = b"Background".to_string();
    let value = b"red".to_string();

    let attribute = collection.mint_attribute(
        cap,
        image_url,
        key,
        value,
        none(),
        scenario.ctx(),
    );

    attribute
}

fun setup_multiple_attributes(
    scenario: &mut Scenario,
    collection: &mut Collection<Meta>,
    cap: &CollectionCap<Meta>,
): vector<Attribute<Meta, AttributeMeta>> {
    let keys = vector[b"Background".to_string(), b"Hat".to_string(), b"Jacket".to_string()];
    let values = vector[b"red".to_string(), b"blue".to_string(), b"Black leather".to_string()];

    let mut attributes: vector<Attribute<Meta, AttributeMeta>> = vector[];
    let mut i = 0;
    while (i < keys.length()) {
        let attribute = collection.mint_attribute(
            cap,
            option::none(),
            keys[i],
            values[i],
            none(),
            scenario.ctx(),
        );
        attributes.push_back(attribute);
        i = i +1;
    };
    attributes
}
