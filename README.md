# Collectible Standard for Sui

A comprehensive NFT/collectible standard implementation for the Sui blockchain.

It aims to provide a similar experience as when to create a Coin/Token in Sui, but for NFTs. The goal is to create a standard that is easy to use and understand, while also being flexible enough to accommodate a wide range of use cases.

## How to Install
This is under development so it exists only on testnet for now
Add this in your Move.toml file under [dependencies]:
<!-- ### Mainnet -->
```toml
nft = { git = "https://github.com/ReforgeLab/Nft.git", subdir = "nft", rev = "main" }
```

<!-- ### Testnet  -->
<!-- ```toml -->
<!-- nft = { git = "https://github.com/ReforgeLab/Nft.git", subdir = "nft", rev = "testnet" } -->
<!---->
<!-- ``` -->
## Registry objects
Testnet = 0xba427918c9c0336847df003b8b8ec3c6e5f3b4c52d2b4ea5e2abec932556c520

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
- **Flexible Metadata Architecture**: Generic type system where `T` can be any metadata type
- **Dynamic Attribute Names**: Collections with empty `attribute_fields` support any attribute names without pre-registration
- **Multiple Metadata Types**: Different collections can use different metadata structures (`PixelArtMeta`, `CollectionMeta`, etc.)
- **Flexible Supply**: Optional maximum supply limits
- **Transfer Policy Integration**: Built-in marketplace compliance
- **Standardize Display**: Customizable display objects for collectibles
- **Schema Flexibility**: Choose between strict (predefined attributes) or flexible (any attributes) schemas
- **Attribute Validation**: Verify attribute combinations through hashing
- **Comprehensive Events**: Full event system for off-chain indexing

## Usage Flow

1. Initialize a module with a one-time witness
2. Claim a collection ticket using `claim_ticket<OTW, T>`
3. Create a collection with the ticket using `create_collection<T>`
4. Mint collectibles and attributes using `mint<T>` and `mint_attribute<T>`
5. Manage attributes with `join_attribute<T>` and `split_attribute<T>`

### Usage Examples

#### Flexible Schema (Dynamic Attributes)
```move
// Create collection with empty attribute_fields for any attributes
let (collection, cap) = ticket.create_collection(
    registry,
    banner_url,
    vector[], // Empty = flexible schema
    creator,
    false, true, false, ctx
);

// Mint with any attribute names
let nft = collection.mint(
    cap,
    some(b"My NFT".to_string()),
    image_url,
    some(b"Custom description".to_string()),
    none(), // No predefined attributes needed
    some(pixel_art_meta), // Custom metadata
    ctx
);
```

#### Strict Schema (Predefined Attributes)
```move
// Create collection with predefined attributes
let (collection, cap) = ticket.create_collection(
    registry,
    banner_url,
    vector[b"Hat".to_string(), b"Background".to_string()], // Strict schema
    creator,
    false, true, false, ctx
);

// Mint with predefined attribute names only
let attribute = collection.mint_attribute(
    cap,
    some(image_url),
    b"Hat".to_string(), // Must match predefined fields
    b"Cowboy Hat".to_string(),
    some(attribute_meta),
    ctx
);
```

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

## Flexible Metadata & Attribute System

The framework supports both strict and flexible attribute schemas:

### Schema Types

**Strict Schema**: Collections with predefined `attribute_fields`
- Attributes must be defined in the collection's allowed fields
- Enforces consistent attribute names across the collection
- Traditional approach for standardized collections

**Flexible Schema**: Collections with empty `attribute_fields`
- Supports any attribute names without pre-registration
- Perfect for user-generated content (e.g., "Dragon Wings", "Fire Sword")
- Ideal for pixel art editors and creative platforms

### Metadata Architecture

The generic type system allows different metadata types:

```move
// Traditional NFT metadata
public struct Nft<phantom T> has key, store {
    id: UID,
    name: String,
    // ... other fields
}

// Pixel art specific metadata
public struct PixelArtMeta has store, drop {
    attribute_names: vector<String>,
    attribute_values: vector<String>,
    creator: address,
    editing_tool: String,
    layer_count: u64,
}

// Collection-specific metadata
public struct CollectionMeta has store, drop {
    rarity_tier: String,
    rarity_score: u64,
    generation_batch: u64,
    trait_rules_applied: vector<String>,
}
```

### Dynamic Attribute Features

Attributes can be:
- Attached and detached if the collection is dynamic
- Created with custom metadata types
- Validated using hashing for proof mechanisms
- Named dynamically in flexible schema collections

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

Before creating a Pull Request, please fork the project and create your PR from the forked repository.

Please make sure to describe your PR clearly, detailing the changes made and any relevant context.

If you're unsure about something or want to discuss a potential change, feel free to open an issue first.

Thank you for helping make Reforges NFT Standard better!

## Acknowledgments

Special thanks to the Mysten Labs team for their pioneering work on the original collectible module in their testnet repository. While that implementation has been deprecated, it provided valuable insights and inspiration for the architecture of this standard. This project builds upon their foundational concepts while introducing new features and improvements to create a more comprehensive collectible standard for the Sui ecosystem.

## Todos
- [ ] Add Walrus storage options
    - [ ] Research if I could create a transfer policy for Walrus, where a small fee for each transfer is paid towards Walrus storage
- [ ] Create a transfer policy rule for when to update the image_url when the collection is dynamic.
- [ ] Add a calculate rarity score function (getter)
- [ ] Create more extensive example guides
- [ ] Add more robust tests
- [ ] Refactor codebase for better readability and maintainability

## Longterm Goals
- Creating a rendering backend server for images that is open for anyone to host.
<!-- - [ ] Research on if/should integrate Atomas AI into the standard.  -->
