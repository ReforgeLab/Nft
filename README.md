# Collectible Standard for Sui

A comprehensive NFT/collectible standard implementation for the Sui blockchain.

It aims to provide a similar experience as when to create a Coin/Token in Sui, but for NFTs. The goal is to create a standard that is easy to use and understand, while also being flexible enough to accommodate a wide range of use cases.

## How to Install
Add this in your Move.toml file under [dependencies]: 
<!-- ### Mainnet -->
<!-- ```toml -->
<!-- nft = { git = "https://github.com/ReforgeLab/Nft.git", subdir = "nft", rev = "main" } -->
<!-- ``` -->

### Testnet 
```toml
nft = { git = "https://github.com/ReforgeLab/Nft.git", subdir = "nft", rev = "testnet" }

```
## Registry objects
<!-- Mainnet = 0x580675c057dc922989f32f565bae595d943e482327829bbd01203c3355b3a060 -->
Testnet = 0x1fff6743212f9d1ba37064dbc1469b9c7454ffbd6ff9a79abcc189b450f5f551

## Motivation

This contract addresses the lack of a generally agreed NFT/collectible standard in the Sui blockchain ecosystem. It draws inspiration from and credits the Mystenlab team's deprecated collectible contract in their testnet package.

## Example 
There is a simple [example](./example/sources/example_nft.move) contract that demonstrates how to use the collectible standard. It is located in the [example](./example/sources/example_nft.move) folder. The example contract shows how to create a collection, mint collectibles and attributes.

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

## ❤️ Support & Appreciation

Thank you for using **Reforges NFT Standard**! 

If this NFT Standard has helped you or your project, please consider showing your appreciation. Your support helps me dedicate more time to improving the standard, adding new features, and keeping it up-to-date with the evolving Sui ecosystem. Think of it as **buying me a coffee** to fuel future development and more contributions to the community! ☕

**Sui Wallet for Donations:**
*(Accepts SUI and other Sui-based tokens)*
0x3bb508b8c66b5d737cf975724c7b309b240d00c9f356e52d389270236d576236

Every little bit helps and is greatly appreciated! Thank you for your support!

## 🤝 Contributing

Any contributions you make to **Reforges NFT Standard** are **greatly appreciated**!

We welcome contributions of all kinds:
*   🐛 Reporting a bug
*   💡 Suggesting an enhancement or new feature
*   📝 Improving documentation
*   💻 Submitting a pull request with code changes

**Everyone is free and encouraged to open a Pull Request (PR)!**

Please make sure to describe your PR clearly, detailing the changes made and any relevant context.

If you're unsure about something or want to discuss a potential change, feel free to open an issue first.

Thank you for helping make Reforges NFT Standard better!

## Acknowledgments

Special thanks to the Mysten Labs team for their pioneering work on the original collectible module in their testnet repository. While that implementation has been deprecated, it provided valuable insights and inspiration for the architecture of this standard. This project builds upon their foundational concepts while introducing new features and improvements to create a more comprehensive collectible standard for the Sui ecosystem.

## Todos
- [ ] Add Walrus storage options
    - [ ] Create a transfer policy for Walrus, each time a transfer is made, a small fee is paid towards the Walrus storage
- [ ] Create more extensive examples guides 
- [ ] Add more robust tests
- [ ] Add a way to update image_url if the collection in dynamic.
