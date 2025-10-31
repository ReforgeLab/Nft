module nft::collection;

use nft::{
    attributes::Attribute,
    collectible::Collectible,
    errors,
    registry::Registry,
    render::{Self, RenderCap}
};
use std::string::String;
use sui::{
    borrow::{Self, Referent, Borrow},
    display::{Self, Display},
    event::emit,
    package::{Self, Publisher},
    transfer_policy::{Self as policy, TransferPolicyCap},
    vec_map::VecMap
};

public struct Config has copy, store {
    // Max mintable collectibles
    max_supply: Option<u32>,
    // How many collectibles have been minted
    minted: u32,
    // How many collectibles have been burned
    burned: u32,
    // If the collection is owned by the creator
    owned: bool,
    // If the collection is burnable
    burnable: bool,
    // If the collection is dynamic and attributes can be equipped or unequipped
    dynamic: bool,
    // If true, only predefined attributes from the schema are allowed
    strict_schema: bool,
    // If the meta is borrowable, if true consider the risks of it and its usecase
    meta_borrowable: bool,
}

public struct Collection<T: store> has key, store {
    id: UID,
    // Stored objects
    publisher: Referent<Publisher>,
    display_collectible: Referent<Display<Collectible<T>>>,
    display_attribute: Referent<Display<Attribute<T>>>,
    policy_cap_collectible: Referent<TransferPolicyCap<Collectible<T>>>,
    policy_cap_attribute: Referent<TransferPolicyCap<Attribute<T>>>,
    // Data fields
    attribute_fields: VecMap<String, vector<String>>,
    banner_url: String,
    creator: Option<String>,
    config: Config,
}

public struct CollectionCap<phantom T: store> has key, store {
    id: UID,
    collection: ID,
}

public struct CollectionTicket<phantom T: store> has key, store {
    id: UID,
    publisher: Publisher,
    max_supply: Option<u32>,
}

// ================== Events ===============

public struct TicketClaimed has copy, drop {
    ticket_id: ID,
    creator: address,
}

public struct CollectionCreated has copy, drop {
    collection_id: ID,
    collection_cap_id: ID,
    max_supply: Option<u32>,
    creator: address,
    attributes_fields: vector<String>,
    banner_url: String,
    dynamic: bool,
    burnable: bool,
}

public struct RevokeOwnership has copy, drop {
    collection_id: ID,
    collection_cap_id: ID,
}

/// Called in the external module initializer. Sends a `CollectionTicket`
/// to the transaction sender which then enables them to initialize the
/// Collection.
///
/// - The OTW parameter is a One-Time-Witness;
/// - The T parameter is the expected Metadata / custom type to use for
/// the Collection;
#[allow(lint(self_transfer))]
public fun claim_ticket<OTW: drop, T: store>(
    otw: OTW,
    max_supply: Option<u32>,
    ctx: &mut TxContext,
) {
    assert!(sui::types::is_one_time_witness(&otw), errors::notOneTimeWitness!());
    let sender = ctx.sender();

    let publisher = package::claim(otw, ctx);

    assert!(package::from_module<T>(&publisher), errors::typeNotFromModule!());
    let ticket = CollectionTicket<T> {
        id: object::new(ctx),
        publisher,
        max_supply,
    };

    emit(TicketClaimed {
        ticket_id: object::id(&ticket),
        creator: sender,
    });

    transfer::transfer(ticket, sender);
}

#[allow(lint(share_owned))]
public fun create_collection<T: store>(
    ticket: CollectionTicket<T>,
    registry: &Registry,
    banner_url: String,
    fields: VecMap<String, vector<String>>,
    creator: Option<String>,
    dynamic: bool,
    burnable: bool,
    strict_schema: bool,
    meta_borrowable: bool,
    ctx: &mut TxContext,
): (CollectionCap<T>, Option<RenderCap<T>>) {
    let CollectionTicket { id, publisher, max_supply } = ticket;
    object::delete(id);

    let mut display_collectible = display::new<Collectible<T>>(
        registry.borrow_publisher(),
        ctx,
    );
    let display_attribute = display::new<Attribute<T>>(registry.borrow_publisher(), ctx);
    let (policy_collectible, policy_cap_collectible) = policy::new<Collectible<T>>(
        registry.borrow_publisher(),
        ctx,
    );
    let (policy_attribute, policy_cap_attribute) = policy::new<Attribute<T>>(
        registry.borrow_publisher(),
        ctx,
    );

    let collection_uid = object::new(ctx);
    let collection_id = collection_uid.to_inner();
    setup_collectible_display<T>(&mut display_collectible, collection_id);

    transfer::public_share_object(policy_collectible);
    transfer::public_share_object(policy_attribute);

    let config = Config {
        max_supply,
        minted: 0,
        burned: 0,
        owned: true,
        burnable,
        dynamic,
        strict_schema,
        meta_borrowable,
    };

    let collection = Collection<T> {
        id: collection_uid,
        display_collectible: borrow::new(display_collectible, ctx),
        display_attribute: borrow::new(display_attribute, ctx),
        policy_cap_collectible: borrow::new(policy_cap_collectible, ctx),
        policy_cap_attribute: borrow::new(policy_cap_attribute, ctx),
        publisher: borrow::new(publisher, ctx),
        banner_url,
        attribute_fields: fields,
        creator,
        config,
    };

    let cap = CollectionCap<T> {
        id: object::new(ctx),
        collection: collection_id,
    };

    emit(CollectionCreated {
        collection_id,
        collection_cap_id: object::id(&cap),
        max_supply,
        creator: ctx.sender(),
        attributes_fields: vector[],
        banner_url,
        dynamic,
        burnable,
    });
    transfer::share_object(collection);
    if (dynamic) {
        (cap, option::some(render::new(collection_id, object::new(ctx))))
    } else {
        (cap, option::none())
    }
}

public fun revoke_ownership<T: store>(cap: CollectionCap<T>, collection: &mut Collection<T>) {
    let collection_id = object::id(collection);
    cap.assert_correct_collection(collection_id);

    collection.config.owned = false;
    let CollectionCap<T> { id, .. } = cap;
    emit(RevokeOwnership {
        collection_id: collection_id,
        collection_cap_id: id.to_inner(),
    });
    id.delete();
}

public(package) fun mint_check<T: store>(self: &mut Collection<T>, cap: &CollectionCap<T>) {
    cap.assert_correct_collection(self.id.to_inner());
    assert!(
        option::is_none(&self.config.max_supply) || *option::borrow(&self.config.max_supply) > self.config.minted,
        errors::capReached!(),
    );
    self.config.minted = self.config.minted + 1;
}

fun assert_correct_collection<T: store>(self: &CollectionCap<T>, id: ID) {
    assert!(self.collection == id, errors::wrongCollection!());
}

fun assert_attribute_check<T: store>(self: &Collection<T>, key: &String) {
    if (self.config.strict_schema) {
        // Validate against predefined schema
        assert!(self.attribute_fields.contains(key), errors::attributeNotAllowed!());
        return
    };
    // If not strict schema, allow any attributes (no validation needed)
}

fun assert_dynamic<T: store>(self: &Collection<T>) {
    assert!(self.config.dynamic, errors::notDynamic!());
}

fun setup_collectible_display<T: store>(display: &mut Display<Collectible<T>>, collection_id: ID) {
    display.add(b"collection_id".to_string(), collection_id.to_address().to_string());
    display.add(b"name".to_string(), b"{name}".to_string());
    display.add(b"image_url".to_string(), b"{image_url}".to_string());
    display.add(b"description".to_string(), b"{description}".to_string());
    display.add(b"attributes".to_string(), b"{attributes}".to_string());
    display.add(b"equipped".to_string(), b"{equipped}".to_string());
    display.update_version();
}
