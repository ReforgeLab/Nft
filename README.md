# Collectible Standard for Sui

A comprehensive NFT/collectible standard implementation for the Sui blockchain.

## How to Install
Add this in your Move.toml file under [dependencies]:
```toml
nft = { git = "https://github.com/Reblixt/sui-move.git", subdir = "nft", rev = "main" }
```
## Motivation

This contract addresses the lack of a generally agreed NFT/collectible standard in the Sui blockchain ecosystem. It draws inspiration from and credits the Mystenlab team's deprecated collectible contract in their testnet package.

## Architecture

The collectible standard implements a flexible and extensible framework for NFTs with the following components:

- **Registry**: Central access point for system features
- **Collections**: Containers for related collectibles with configurable properties
- **Collectibles**: The NFTs themselves with customizable attributes
- **Attributes**: Modular traits that can be attached to or detached from collectibles

## Key Features

- **Dynamic Attributes**: Join and split attributes from collectibles
- **Flexible Supply**: Optional maximum supply limits
- **Transfer Policy Integration**: Built-in marketplace compliance
- **Standardize Display**: Customizable display objects for collectibles
- **Custom Metadata**: Support for project-specific metadata types
- **Attribute Validation**: Verify attribute combinations through hashing
- **Comprehensive Events**: Full event system for off-chain indexing

## Usage Flow

1. Initialize a module with a one-time witness
2. Claim a collection ticket using `claim_ticket<OTW, T>`
3. Create a collection with the ticket using `create_collection<T>`
4. Mint collectibles and attributes using `mint<T>` and `mint_attribute<T>`
5. Manage attributes with `join_attribute<T>` and `split_attribute<T>`

## Core Components

### Registry

```move
public struct Registry has key {
    id: UID,
    publisher: Publisher,
}
```

The central registry that provides access to system features.

### Collection

```move
public struct Collection<T: store> has key, store {
    id: UID,
    // Contains references to Publisher, Display objects, and TransferPolicyCap
    // Configuration for attributes, supply limits, etc.
}
```

Container for collectibles with configurable properties.

### Collectible

```move
public struct Collectible<T: store> has key, store {
    id: UID,
    image_url: String,
    name: Option<String>,
    description: Option<String>,
    equipped: VecMap<String, ID>,
    attributes: Option<VecMap<String, String>>,
    meta: Option<T>,
}
```

The NFT objects that can have modular attributes attached.

### Attribute

```move
public struct Attribute<T> has key, store {
    id: UID,
    image_url: Option<String>,
    key: String, // Background, Cloth, etc.
    value: String, // red-sky, jacket, etc.
    meta: Option<T>,
    meta_borrowable: bool,
}
```

Modular traits that can be attached to collectibles.

## Key Functions

- `claim_ticket<OTW, T>`: Get a collection creation ticket
- `create_collection<T>`: Create a new collection
- `mint<T>`: Mint a new collectible
- `mint_attribute<T>`: Create a new attribute
- `join_attribute<T>`: Attach an attribute to a collectible
- `split_attribute<T>`: Remove an attribute from a collectible
- `validate_attribute<T>`: Verify attribute combinations
- `revoke_ownership<T>`: Make a collection immutable

## Events

The contract emits comprehensive events for all major operations including:
- Collection creation
- Collectible minting
- Attribute minting, joining, and splitting
- Ownership revocation
- Collectible destruction
- Metadata edits

## Attribute System

The attribute system enables dynamic composition of collectible traits. Attributes:
- Must be defined in the collection's allowed fields
- Can be attached and detached if the collection is dynamic
- Can be validated using hashing for proof mechanisms

## Access Control

The `CollectionCap<T>` provides ownership privileges for collection management, and can be revoked to make a collection immutable.


## Acknowledgments

Special thanks to the Mysten Labs team for their pioneering work on the original collectible module in their testnet repository. While that implementation has been deprecated, it provided valuable insights and inspiration for the architecture of this standard. This project builds upon their foundational concepts while introducing new features and improvements to create a more comprehensive collectible standard for the Sui ecosystem.
