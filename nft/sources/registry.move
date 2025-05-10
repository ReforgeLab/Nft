module nft::registry {
    use sui::package::{Self, Publisher};

    /// Centralized registry to provide access to system features of
    /// the Collectible.
    public struct Registry has key {
        id: UID,
        publisher: Publisher,
    }

    public struct REGISTRY has drop {}

    /// Create the centralized Registry of Collectibles to provide access
    /// to the Publisher functionality of the Collectible.
    fun init(otw: REGISTRY, ctx: &mut TxContext) {
        transfer::share_object(Registry {
            id: object::new(ctx),
            publisher: package::claim(otw, ctx),
        })
    }

    public(package) fun borrow_publisher(self: &Registry): &Publisher {
        &self.publisher
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        let otw = REGISTRY {};
        init(otw, ctx);
    }
}
