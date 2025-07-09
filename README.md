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
- **Collectibles**: The NFTs themselves with flexible metadata and attributes
- **Attributes**: Modular traits that can be attached to or detached from collectibles

## Key Features

- **Flexible Meta-Type System**: Single parameter generic system with flexible metadata fields
- **Dynamic Attributes**: Join and split attributes from collectibles
- **Configurable Schema Validation**: `strict_schema` flag controls attribute validation behavior
- **Dynamic Attribute Support**: Collections with `strict_schema: false` support any attribute names without pre-registration
- **Flexible Metadata**: NFT struct includes flexible metadata fields for any use case
- **Flexible Supply**: Optional maximum supply limits
- **Transfer Policy Integration**: Built-in marketplace compliance
- **Standardize Display**: Customizable display objects for collectibles
- **Attribute Validation**: Verify attribute combinations through hashing
- **Comprehensive Events**: Full event system for off-chain indexing

## Usage Flow

1. Initialize a module with a one-time witness
2. Claim a collection ticket using `claim_ticket<OTW, T>`
3. Create a collection with the ticket using `create_collection<T>`
4. Mint collectibles and attributes using `mint<T>` and `mint_attribute<T>`
5. Manage attributes with `join_attribute<T>` and `split_attribute<T>`

### Usage Examples

#### Dynamic Schema (User-Generated Attributes)
```move
// Create collection with strict_schema = false for complete flexibility
let (cap, render_cap_opt) = ticket.create_collection<NFT_EXAMPLE>(
    registry,
    banner_url,
    map::empty<String, vector<String>>(), // Empty schema for dynamic attributes
    creator,
    true,   // dynamic: true
    false,  // burnable
    false,  // strict_schema: false - KEY FOR DYNAMIC LAYERS
    false,  // meta_borrowable
    ctx
);

// Mint with any attribute names (no pre-registration needed)
let nft = collection.mint(
    cap,
    some(b"My NFT".to_string()),
    image_url,
    some(b"Custom description".to_string()),
    map::empty<String, String>(), // No predefined attributes needed
    some(meta), // Custom metadata
    ctx
);

// Create dynamic attributes on-the-fly
let attribute = collection.mint_attribute(
    cap,
    some(attribute_image_url),
    b"Dragon Wings".to_string(), // Any attribute name
    b"Fire Dragon Wings".to_string(),
    some(attribute_meta),
    ctx
);
```

#### Strict Schema (Predefined Attributes)
```move
// Create collection with strict_schema = true for predefined attributes
let mut schema = map::empty<String, vector<String>>();
schema.insert(b"Background".to_string(), vector[b"Red Sky".to_string(), b"Blue Ocean".to_string()]);
schema.insert(b"Clothing".to_string(), vector[b"Jacket".to_string(), b"T-Shirt".to_string()]);

let (cap, render_cap_opt) = ticket.create_collection<NFT_EXAMPLE>(
    registry,
    banner_url,
    schema, // Predefined attribute schema
    creator,
    true,   // dynamic: true
    false,  // burnable
    true,   // strict_schema: true - ENFORCES SCHEMA
    false,  // meta_borrowable
    ctx
);

// Mint with predefined attribute names only
let attribute = collection.mint_attribute(
    cap,
    some(image_url),
    b"Background".to_string(), // Must match predefined fields
    b"Red Sky".to_string(),    // Must match predefined values
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
    // Configuration for attributes, supply limits, strict_schema flag, etc.
    attribute_fields: VecMap<String, vector<String>>,
    config: Config,
}
```

Container for collectibles with configurable properties. Uses single-parameter generics where `T` is the NFT type with flexible metadata.

### Collectible

```move
public struct Collectible<T: store> has key, store {
    id: UID,
    image_url: String,
    name: String,
    description: String,
    equipped: VecMap<String, ID>,
    attributes: VecMap<String, String>,
    meta: Option<T>,
}
```

The NFT objects that can have modular attributes attached. The `meta` field is flexible and can hold any metadata type.

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
- `create_collection<T>`: Create a new collection with configurable schema validation
- `mint<T>`: Mint a new collectible with flexible metadata
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

## Flexible Meta-Type System

The framework uses a single-parameter generic system with flexible metadata and configurable schema validation:

### Single-Parameter Generic System

**Flexible NFT Structure**: `Collection<T>` and `Collectible<T>`
- `T`: NFT type with flexible metadata fields
- Simplified API compared to two-parameter systems
- NFT struct itself is flexible to hold any metadata
- Better composability and easier integration

### Schema Validation Control

**Strict Schema** (`strict_schema: true`): Collections with predefined `attribute_fields`
- Attributes must be defined in the collection's allowed fields
- Values must match predefined options in the schema
- Enforces consistent attribute names across the collection
- Indexer-friendly with predictable schemas

**Dynamic Schema** (`strict_schema: false`): Complete attribute flexibility
- Supports any attribute names without pre-registration
- Perfect for user-generated content (e.g., "Dragon Wings", "Fire Sword")
- Enables dynamic trait systems

### Flexible Metadata Architecture

The single-parameter system with flexible metadata enables various use cases:

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

// Example usage patterns:
Collection<Nft<NFT_EXAMPLE>>     // Traditional approach
Collection<PixelArtMeta>         // Pixel art with custom metadata
Collection<CollectionMeta>       // Generated collections with rarity
```

### Dynamic Attribute Features

Attributes can be:
- Attached and detached if the collection is dynamic
- Created with custom metadata types
- Validated using hashing for proof mechanisms
- Named dynamically in flexible schema collections
- Organized in a `VecMap<String, vector<String>>` structure for better indexer compatibility

## Frontend Integration Examples

### Dynamic Layer Creation
```typescript
// Create a new layer attribute dynamically
const createLayerAttribute = async (layerName: string, layerValue: string, imageUrl?: string) => {
  const tx = await suiClient.moveCall({
    target: `${packageId}::collectible::mint_attribute`,
    arguments: [
      collection,
      collectionCap,
      imageUrl || null,
      layerName,    // e.g., "Background", "Clothing", "Accessory"
      layerValue,   // e.g., "Red Sky", "Blue Jacket", "Gold Chain"
      null,         // meta
      false         // meta_borrowable
    ]
  });
};

// Equip a layer to an NFT
const equipLayer = async (nftId: string, attributeId: string) => {
  const tx = await suiClient.moveCall({
    target: `${packageId}::collectible::join_attribute`,
    arguments: [collection, collectionCap, nftId, attributeId]
  });
};
```

## Access Control

The `CollectionCap<T>` provides ownership privileges for collection management, and can be revoked to make a collection immutable. The capability is tied to the NFT type `T`, ensuring proper access control.

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
