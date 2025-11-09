#[allow(unused)]
module nft::errors;

#[test_only]
const ETypeNotFromModule: u64 = 101;
#[test_only]
const ECapReached: u64 = 102;
#[test_only]
const EVectorsNotEmpty: u64 = 103;
#[test_only]
const EWrongCollection: u64 = 104;
#[test_only]
const ENotDynamic: u64 = 105;
#[test_only]
const EDoesNotHaveAttributes: u64 = 106;
#[test_only]
const EAttributeNotAllowed: u64 = 107;
#[test_only]
const EAttributeTypeExists: u64 = 108;
#[test_only]
const ENotSameLength: u64 = 109;
#[test_only]
const ENotOneTimeWitness: u64 = 110;
#[test_only]
const ENotMetaBorrowable: u64 = 111;
#[test_only]
const EWrongCollectible: u64 = 112;
#[test_only]
const EWrongId: u64 = 113;

public(package) macro fun typeNotFromModule(): u64 {
    101
}
public(package) macro fun capReached(): u64 {
    102
}
public(package) macro fun vectorsNotEmpty(): u64 {
    103
}
public(package) macro fun wrongCollection(): u64 {
    104
}
public(package) macro fun notDynamic(): u64 {
    105
}

public(package) macro fun doesNotHaveAttributes(): u64 {
    106
}
public(package) macro fun attributeNotAllowed(): u64 {
    107
}
public(package) macro fun attributeTypeAlreadyExists(): u64 {
    108
}
public(package) macro fun notSameLength(): u64 {
    109
}
public(package) macro fun notOneTimeWitness(): u64 {
    110
}
public(package) macro fun notMetaBorrowable(): u64 {
    111
}
public(package) macro fun wrongCollectible(): u64 {
    112
}
public(package) macro fun wrongId(): u64 {
    113
}

public(package) macro fun wrongMetaId(): u64 {
    114
}

public(package) macro fun notBurnable(): u64 {
    115
}

public(package) macro fun listNotEmpty(): u64 {
    116
}
