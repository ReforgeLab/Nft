#[test_only]
module example::nft_tests {
    use example::nft_example::{Self, NFT_EXAMPLE, Nft};
    use nft::{collectible::CollectionTicket, registry::{Self, Registry}};
    use sui::{test_scenario, test_utils::destroy};

    // const ENotImplemented: u64 = 0;
    const Alice: address = @0x1ABE;

    #[test]
    fun test_nft_factory() {
        let mut scen = test_scenario::begin(Alice);
        scen.next_tx(Alice);

        registry::test_init(scen.ctx());
        scen.next_tx(Alice);

        let registry = scen.take_shared<Registry>();

        nft_example::test_init(scen.ctx());
        scen.next_tx(Alice);

        let ticket = scen.take_from_address<CollectionTicket<Nft<NFT_EXAMPLE>>>(Alice);

        nft_example::collection_init(
            ticket,
            &registry,
            scen.ctx(),
        );

        destroy(registry);
        scen.end();
    }
}
