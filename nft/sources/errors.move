#[allow(unused)]
module nft::errors {
    #[test_only]
    const ETypeNotFromModule: u64 = 1;
    #[test_only]
    const ECapReached: u64 = 2;
    #[test_only]
    const EVectorsNotEmpty: u64 = 3;
    #[test_only]
    const EWrongCollection: u64 = 4;
    #[test_only]
    const ENotDynamic: u64 = 5;
    #[test_only]
    const EDoesNotHaveAttributes: u64 = 6;
    #[test_only]
    const EAttributeNotAllowed: u64 = 7;
    #[test_only]
    const EAttributeTypeExists: u64 = 8;
    #[test_only]
    const ENotSameLength: u64 = 9;
    #[test_only]
    const ENotOneTimeWitness: u64 = 10;
    #[test_only]
    const ENotMetaBorrowable: u64 = 11;
    #[test_only]
    const EWrongCollectible: u64 = 12;

    public(package) macro fun typeNotFromModule(): u64 {
        1
    }
    public(package) macro fun capReached(): u64 {
        2
    }
    public(package) macro fun vectorsNotEmpty(): u64 {
        3
    }
    public(package) macro fun wrongCollection(): u64 {
        4
    }
    public(package) macro fun notDynamic(): u64 {
        5
    }

    public(package) macro fun doesNotHaveAttributes(): u64 {
        6
    }
    public(package) macro fun attributeNotAllowed(): u64 {
        7
    }
    public(package) macro fun attributeTypeAlreadyExists(): u64 {
        8
    }
    public(package) macro fun notSameLength(): u64 {
        9
    }
    public(package) macro fun notOneTimeWitness(): u64 {
        10
    }
    public(package) macro fun notMetaBorrowable(): u64 {
        11
    }
    public(package) macro fun wrongCollectible(): u64 {
        12
    }
}
