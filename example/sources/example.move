module example::example_nft {
    use std::string::String;
    use sui::object;

    public struct Attribute has key, store {
        id: object::UID,
        key: String,
        value: String,
    }

    public struct Nft has key, store {
        id: object::UID,
        image: String,
        name: String,
        description: String,
        rarity: u64,
        attributes: vector<Attribute>,
    }

    public struct MintEvent has copy, drop {
        nft_id: ID,
    }

    public struct MintAttributeEvent has copy, drop {
        attribute: ID,
    }
}
