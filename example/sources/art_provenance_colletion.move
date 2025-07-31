module example::art_provenance {
    use nft::{collectible::{Self, CollectionCap, CollectionTicket, Collection}, registry::Registry};
    use std::{option::{none, some}, string::String};
    use sui::vec_map::{Self as map};

    // One-Time Witness for the art collection
    public struct ART_PROVENANCE has drop {}

    // Comprehensive art NFT with detailed provenance tracking
    public struct ArtPiece<phantom T> has key, store {
        id: UID,
        
        // Basic artwork information
        title: String,
        artist_name: String,
        artist_wallet: address,
        creation_date: String, // "YYYY-MM-DD" format
        medium: String, // "Oil on Canvas", "Digital Art", "Photography", etc.
        dimensions: String, // "24x36 inches" or "1920x1080 pixels"
        
        // Artistic details
        art_movement: String, // "Impressionism", "Digital Art", "Contemporary", etc.
        style: String, // "Abstract", "Realistic", "Surreal", etc.
        color_palette: vector<String>, // ["#FF0000", "#00FF00", "#0000FF"]
        dominant_colors: vector<String>,
        subject_matter: String, // "Portrait", "Landscape", "Still Life", etc.
        
        // Technical specifications
        resolution: Option<String>, // For digital art
        file_format: Option<String>, // "PNG", "JPEG", "SVG", etc.
        color_depth: Option<u64>, // 8, 16, 24, 32 bit
        dpi: Option<u64>, // Dots per inch for prints
        
        // Provenance and authenticity
        certificate_of_authenticity: String, // IPFS hash or URL
        provenance_chain: vector<String>, // Previous owners/exhibitions
        authentication_method: String, // "Artist Signature", "Digital Certificate", etc.
        blockchain_timestamp: u64,
        creation_location: String, // "Paris, France" or "Digital Studio"
        
        // Market and valuation
        initial_price: u64, // In smallest currency unit
        currency: String, // "SUI", "USD", "ETH"
        estimated_value: u64,
        last_sale_price: Option<u64>,
        last_sale_date: Option<u64>,
        
        // Exhibition and display history
        exhibitions: vector<String>, // Gallery names and dates
        publications: vector<String>, // Books, magazines, catalogs
        awards: vector<String>, // Art competitions and recognitions
        critical_reviews: vector<String>, // Art critic reviews
        
        // Physical properties (if applicable)
        condition: String, // "Excellent", "Good", "Fair", "Poor"
        conservation_history: vector<String>, // Restoration records
        storage_requirements: String, // Temperature, humidity, light conditions
        insurance_value: Option<u64>,
        
        // Digital properties
        metadata_standard: String, // "ERC-721", "Sui NFT", etc.
        ipfs_hash: Option<String>, // For decentralized storage
        backup_locations: vector<String>, // Additional storage locations
        
        // Rights and licensing
        copyright_holder: address,
        commercial_rights: bool, // Can be used commercially
        reproduction_rights: bool, // Can be reproduced
        display_rights: bool, // Can be displayed publicly
        licensing_terms: String,
        
        // Social and cultural context
        cultural_significance: String,
        historical_context: String,
        social_commentary: Option<String>,
        inspiration_sources: vector<String>,
        
        // Collection and series information
        series_name: Option<String>,
        series_number: Option<u64>,
        total_in_series: Option<u64>,
        related_works: vector<String>, // IDs of related artworks
    }

     // Initialize the art provenance collection
    fun init(otw: ART_PROVENANCE, ctx: &mut TxContext) {
        // Create ticket with max supply of 5,000 art pieces
        collectible::claim_ticket<ART_PROVENANCE, ArtPiece<ART_PROVENANCE>>(
            otw, 
            option::some(5000), 
            ctx
        );
    }

    // Create a comprehensive art collection with detailed categorization
    #[allow(lint(self_transfer))]
    public fun create_art_collection(
        ticket: CollectionTicket<ArtPiece<ART_PROVENANCE>>,
        registry: &Registry,
        ctx: &mut TxContext,
    ) {
        let mut fields = map::empty<String, vector<String>>();
        
        // Art mediums
        fields.insert(
            b"Medium".to_string(),
            vector[
                b"Oil on Canvas".to_string(), b"Acrylic on Canvas".to_string(), 
                b"Watercolor".to_string(), b"Digital Art".to_string(),
                b"Photography".to_string(), b"Mixed Media".to_string(),
                b"Sculpture".to_string(), b"Printmaking".to_string()
            ]
        );
        
        // Art movements
        fields.insert(
            b"Movement".to_string(),
            vector[
                b"Contemporary".to_string(), b"Modern".to_string(), b"Impressionism".to_string(),
                b"Abstract Expressionism".to_string(), b"Surrealism".to_string(),
                b"Pop Art".to_string(), b"Minimalism".to_string(), b"Digital Art".to_string()
            ]
        );
        
        // Subject matter
        fields.insert(
            b"Subject".to_string(),
            vector[
                b"Portrait".to_string(), b"Landscape".to_string(), b"Still Life".to_string(),
                b"Abstract".to_string(), b"Figurative".to_string(), b"Conceptual".to_string(),
                b"Nature".to_string(), b"Urban".to_string()
            ]
        );
        
        // Color themes
        fields.insert(
            b"ColorTheme".to_string(),
            vector[
                b"Monochromatic".to_string(), b"Warm Tones".to_string(), b"Cool Tones".to_string(),
                b"Vibrant".to_string(), b"Muted".to_string(), b"High Contrast".to_string(),
                b"Pastel".to_string(), b"Earth Tones".to_string()
            ]
        );

        let (cap, render_cap_opt) = ticket.create_collection<ArtPiece<ART_PROVENANCE>>(
            registry,
            b"https://art-gallery.com/provenance-collection".to_string(),
            fields,
            some(b"Digital Art Collective - Preserving Artistic Heritage".to_string()),
            false, // not dynamic - preserve artistic integrity
            false, // not burnable - preserve cultural heritage
            true,  // strict schema - maintain curatorial standards
            true,  // meta borrowable - allow museum loans
            ctx,
        );

        if (render_cap_opt.is_some()) {
            let render_cap = render_cap_opt.destroy_some();
            transfer::public_transfer(render_cap, ctx.sender());
        } else {
            option::destroy_none(render_cap_opt);
        };
        
        transfer::public_transfer(cap, ctx.sender());
    }

    // Mint a masterpiece with full provenance documentation
    #[allow(lint(self_transfer))]
    public fun mint_masterpiece(
        collection: &mut Collection<ArtPiece<ART_PROVENANCE>>,
        cap: &CollectionCap<ArtPiece<ART_PROVENANCE>>,
        title: String,
        artist_name: String,
        artist_wallet: address,
        ctx: &mut TxContext,
    ) {
        // Create medium attribute
        let medium_attr = collection.mint_attribute(
            cap,
            some(b"https://art-gallery.com/icons/oil-painting.png".to_string()),
            b"Medium".to_string(),
            b"Oil on Canvas".to_string(),
            none(),
            ctx,
        );

        // Create movement attribute
        let movement_attr = collection.mint_attribute(
            cap,
            some(b"https://art-gallery.com/icons/impressionism.png".to_string()),
            b"Movement".to_string(),
            b"Impressionism".to_string(),
            none(),
            ctx,
        );

        // Create comprehensive art metadata
        let art_meta = ArtPiece<ART_PROVENANCE> {
            id: object::new(ctx),
            
            title: title,
            artist_name: artist_name,
            artist_wallet: artist_wallet,
            creation_date: b"2024-01-15".to_string(),
            medium: b"Oil on Canvas".to_string(),
            dimensions: b"36x48 inches".to_string(),
            
            art_movement: b"Contemporary Impressionism".to_string(),
            style: b"Neo-Impressionist".to_string(),
            color_palette: vector[
                b"#4A90E2".to_string(), b"#F5A623".to_string(), b"#7ED321".to_string(),
                b"#D0021B".to_string(), b"#9013FE".to_string()
            ],
            dominant_colors: vector[b"Blue".to_string(), b"Gold".to_string()],
            subject_matter: b"Landscape with Water Lilies".to_string(),
            
            resolution: none(),
            file_format: none(),
            color_depth: none(),
            dpi: none(),
            
            certificate_of_authenticity: b"QmX7Kd9fJ2nR8sT3vW6yZ1aB4cE5fG7hI9jK0lM2nO3pQ4r".to_string(),
            provenance_chain: vector[
                b"Artist Studio (2024)".to_string(),
                b"First Owner - Digital Collector (2024)".to_string()
            ],
            authentication_method: b"Artist Digital Signature + Blockchain Certificate".to_string(),
            blockchain_timestamp: ctx.epoch(),
            creation_location: b"Artist Studio, San Francisco, CA".to_string(),
            
            initial_price: 50000000000, // 50 SUI in MIST
            currency: b"SUI".to_string(),
            estimated_value: 75000000000, // 75 SUI
            last_sale_price: none(),
            last_sale_date: none(),
            
            exhibitions: vector[
                b"Digital Renaissance Gallery - March 2024".to_string(),
                b"Contemporary Visions Exhibition - April 2024".to_string()
            ],
            publications: vector[
                b"Digital Art Quarterly - Issue 15".to_string(),
                b"Modern Masters Catalog 2024".to_string()
            ],
            awards: vector[
                b"Best Digital Impressionist Work 2024".to_string(),
                b"People's Choice Award - Digital Art Fair".to_string()
            ],
            critical_reviews: vector[
                b"A masterful blend of traditional technique and digital innovation - Art Critic Weekly".to_string()
            ],
            
            condition: b"Mint Condition".to_string(),
            conservation_history: vector[],
            storage_requirements: b"Digital preservation on IPFS and Arweave".to_string(),
            insurance_value: some(100000000000), // 100 SUI
            
            metadata_standard: b"Sui NFT Standard".to_string(),
            ipfs_hash: some(b"QmY8Le0fK3oS4uW7xZ2bC5dF6gH8iJ0kL1mN3oP4qR5sT6v".to_string()),
            backup_locations: vector[
                b"IPFS".to_string(), 
                b"Arweave".to_string(), 
                b"Artist Personal Archive".to_string()
            ],
            
            copyright_holder: artist_wallet,
            commercial_rights: false,
            reproduction_rights: false,
            display_rights: true,
            licensing_terms: b"Display rights granted, commercial use prohibited".to_string(),
            
            cultural_significance: b"Represents the evolution of impressionist techniques in the digital age".to_string(),
            historical_context: b"Created during the NFT renaissance of 2024".to_string(),
            social_commentary: some(b"Commentary on the intersection of nature and technology".to_string()),
            inspiration_sources: vector[
                b"Claude Monet's Water Lilies series".to_string(),
                b"Digital art pioneers".to_string(),
                b"Environmental conservation movement".to_string()
            ],
            
            series_name: some(b"Digital Impressions".to_string()),
            series_number: some(1),
            total_in_series: some(10),
            related_works: vector[],
        };

        let nft = collection.mint(
            cap,
            some(title),
            b"https://art-gallery.com/masterpieces/digital-water-lilies.jpg".to_string(),
            some(b"A stunning contemporary interpretation of impressionist water lily paintings, bridging traditional artistry with digital innovation".to_string()),
            some(vector[medium_attr, movement_attr]),
            some(art_meta),
            ctx,
        );

        transfer::public_transfer(nft, ctx.sender());
    }

    // Mint a photography series with detailed technical specifications
    #[allow(lint(self_transfer))]
    public fun mint_photography_series(
        collection: &mut Collection<ArtPiece<ART_PROVENANCE>>,
        cap: &CollectionCap<ArtPiece<ART_PROVENANCE>>,
        series_name: String,
        photographer: address,
        series_count: u64,
        ctx: &mut TxContext,
    ) {
        let mut i = 1;
        while (i <= series_count) {
            let photo_title = {
                let mut title = series_name;
                title.append_utf8(b" #");
                title.append_utf8(std::bcs::to_bytes(&i));
                title
            };

            let photo_meta = ArtPiece<ART_PROVENANCE> {
                id: object::new(ctx),
                
                title: photo_title,
                artist_name: b"Master Photographer".to_string(),
                artist_wallet: photographer,
                creation_date: b"2024-02-20".to_string(),
                medium: b"Digital Photography".to_string(),
                dimensions: b"4000x6000 pixels".to_string(),
                
                art_movement: b"Contemporary Photography".to_string(),
                style: b"Documentary".to_string(),
                color_palette: vector[
                    b"#2C3E50".to_string(), b"#ECF0F1".to_string(), b"#E74C3C".to_string()
                ],
                dominant_colors: vector[b"Blue".to_string(), b"White".to_string(), b"Red".to_string()],
                subject_matter: b"Urban Landscape".to_string(),
                
                resolution: some(b"4000x6000".to_string()),
                file_format: some(b"RAW/JPEG".to_string()),
                color_depth: some(24),
                dpi: some(300),
                
                certificate_of_authenticity: b"QmZ9Nf1gH2iJ3kL4mN5oP6qR7sT8uV9wX0yA1bC2dE3fG4h".to_string(),
                provenance_chain: vector[
                    b"Photographer's Studio (2024)".to_string()
                ],
                authentication_method: b"Digital Signature + EXIF Data Verification".to_string(),
                blockchain_timestamp: ctx.epoch(),
                creation_location: b"New York City, NY".to_string(),
                
                initial_price: 10000000000, // 10 SUI
                currency: b"SUI".to_string(),
                estimated_value: 15000000000, // 15 SUI
                last_sale_price: none(),
                last_sale_date: none(),
                
                exhibitions: vector[],
                publications: vector[],
                awards: vector[],
                critical_reviews: vector[],
                
                condition: b"Digital Original".to_string(),
                conservation_history: vector[],
                storage_requirements: b"High-resolution digital preservation".to_string(),
                insurance_value: some(20000000000), // 20 SUI
                
                metadata_standard: b"Sui NFT Standard".to_string(),
                ipfs_hash: some(b"QmA2Bf3cD4eF5gH6iJ7kL8mN9oP0qR1sT2uV3wX4yZ5aB6c".to_string()),
                backup_locations: vector[b"IPFS".to_string(), b"Photographer Archive".to_string()],
                
                copyright_holder: photographer,
                commercial_rights: true,
                reproduction_rights: false,
                display_rights: true,
                licensing_terms: b"Limited commercial use permitted with attribution".to_string(),
                
                cultural_significance: b"Documents urban transformation in the 21st century".to_string(),
                historical_context: b"Part of ongoing documentation of urban change".to_string(),
                social_commentary: some(b"Explores themes of gentrification and community".to_string()),
                inspiration_sources: vector[
                    b"Street Photography Masters".to_string(),
                    b"Urban Sociology".to_string()
                ],
                
                series_name: some(series_name),
                series_number: some(i),
                total_in_series: some(series_count),
                related_works: vector[],
            };

            let nft = collection.mint(
                cap,
                some(photo_title),
                b"https://photography-gallery.com/urban-series/photo.jpg".to_string(),
                some(b"A compelling documentary photograph capturing urban life and transformation".to_string()),
                none(),
                some(photo_meta),
                ctx,
            );

            transfer::public_transfer(nft, photographer);
            i = i + 1;
        };
    }

    // Mint a simple art piece for emerging artists
    #[allow(lint(self_transfer))]
    public fun mint_emerging_artist_work(
        collection: &mut Collection<ArtPiece<ART_PROVENANCE>>,
        cap: &CollectionCap<ArtPiece<ART_PROVENANCE>>,
        title: String,
        artist: address,
        medium: String,
        price: u64,
        ctx: &mut TxContext,
    ) {
        let simple_art_meta = ArtPiece<ART_PROVENANCE> {
            id: object::new(ctx),
            
            title: title,
            artist_name: b"Emerging Artist".to_string(),
            artist_wallet: artist,
            creation_date: b"2024-03-01".to_string(),
            medium: medium,
            dimensions: b"12x16 inches".to_string(),
            
            art_movement: b"Contemporary".to_string(),
            style: b"Personal Expression".to_string(),
            color_palette: vector[],
            dominant_colors: vector[],
            subject_matter: b"Abstract Expression".to_string(),
            
            resolution: none(), file_format: none(), color_depth: none(), dpi: none(),
            
            certificate_of_authenticity: b"Basic Digital Certificate".to_string(),
            provenance_chain: vector[b"Artist Studio (2024)".to_string()],
            authentication_method: b"Artist Digital Signature".to_string(),
            blockchain_timestamp: ctx.epoch(),
            creation_location: b"Home Studio".to_string(),
            
            initial_price: price,
            currency: b"SUI".to_string(),
            estimated_value: price,
            last_sale_price: none(), last_sale_date: none(),
            
            exhibitions: vector[], publications: vector[], awards: vector[], critical_reviews: vector[],
            
            condition: b"Excellent".to_string(),
            conservation_history: vector[],
            storage_requirements: b"Standard digital preservation".to_string(),
            insurance_value: none(),
            
            metadata_standard: b"Sui NFT Standard".to_string(),
            ipfs_hash: none(),
            backup_locations: vector[b"Artist Archive".to_string()],
            
            copyright_holder: artist,
            commercial_rights: true, reproduction_rights: false, display_rights: true,
            licensing_terms: b"Standard artist rights retained".to_string(),
            
            cultural_significance: b"Represents emerging artistic voice".to_string(),
            historical_context: b"Created during artist's early career".to_string(),
            social_commentary: none(),
            inspiration_sources: vector[b"Personal Experience".to_string()],
            
            series_name: none(), series_number: none(), total_in_series: none(), related_works: vector[],
        };

        let nft = collection.mint(
            cap, some(title),
            b"https://emerging-artists.com/artwork.jpg".to_string(),
            some(b"An authentic expression from an emerging artist".to_string()),
            none(), some(simple_art_meta), ctx,
        );

        transfer::public_transfer(nft, artist);
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        let otw = ART_PROVENANCE {};
        init(otw, ctx);
    }
}