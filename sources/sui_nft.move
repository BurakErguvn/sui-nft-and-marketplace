module sui_nft::sui_nft {
    use std::string::String;
    use sui::url::{Self,Url};
    use sui::event;
    use sui::vec_map::{Self, VecMap};
    use sui::table::Table;
    use sui::display;
    use sui::package;
    use std::string;
    use sui::table;

    const MAX_SUPPLY: u64 = 7777;
    const EMaxSupplyReached: u64 = 1;
    const CREATOR: address = @creator;

    public struct AdminCap has store, key {
        id: UID,
    }

    public struct SUI_NFT has drop {}

    public struct TheSavagePetRegistry has key{
        id: UID,
        name: String,
        max_supply: u64,
        total_minted: u64,
        max_mint_per_address: u64,
        addresses_minted: Table<address, u64>,
    }

    public struct TheSavagePet has key, store {
        id: UID,
        name: String,
        description: String,
        image_url: Url,
        attributes: VecMap<String, String>,
        creator: address,
    }

    public struct TheSavagePetMintEvent has drop,copy {
        nft_id: ID,
        name: String,
        owner: address,
    }

    public struct TheSavagePetBurnEvent has drop,copy {
        nft_id: ID,
        name: String,
        owner: address,
    }

    #[allow(lint(share_owned))]
    fun init (
        otw: SUI_NFT,
        ctx: &mut TxContext,
    ) {
        let publisher = package::claim(otw, ctx);
        let mut display = display::new<TheSavagePet>(&publisher, ctx);

        display::add(&mut display, string::utf8(b"name"),string::utf8(b"{name}"));
        display::add(&mut display, string::utf8(b"description"), string::utf8(b"{description}"));
        display::add(&mut display, string::utf8(b"image_url"), string::utf8(b"{image_url}"));
        display::add(&mut display, string::utf8(b"creator"), string::utf8(b"{creator}"));
        display::update_version(&mut display);
        
        let admin_cap = AdminCap {
            id: object::new(ctx),
        };
        let registry = TheSavagePetRegistry {
            id: object::new(ctx),
            name: string::utf8(b"The Savage Pet"),
            max_supply: MAX_SUPPLY,
            total_minted: 0,
            max_mint_per_address: 3,
            addresses_minted: table::new(ctx),
        };

        transfer::public_transfer(display, ctx.sender());
        transfer::public_transfer(publisher, ctx.sender());
        transfer::public_transfer(admin_cap, ctx.sender());
        transfer::share_object(registry);
    }

    #[allow(lint(self_transfer))]
    // Mint a new NFT
    public fun mint(
        registry: &mut TheSavagePetRegistry,
        name: String,
        image_url: String,
        attribute_keys: vector<String>,
        attribute_values: vector<String>,
        ctx: &mut TxContext
    ) {
        assert!(registry.total_minted < 7777,EMaxSupplyReached);
        
        // Attribute'ları VecMap'e dönüştür
        let mut attributes = vec_map::empty<String, String>();
        let mut i = 0;
        while (i < vector::length(&attribute_keys)) {
            let key = *vector::borrow(&attribute_keys, i);
            let value = *vector::borrow(&attribute_values, i);
            vec_map::insert(&mut attributes, key, value);
            i = i + 1;
        };

        registry.total_minted = registry.total_minted + 1;
        
        let id = object::new(ctx);
        let nft_id = object::uid_to_inner(&id);
        
        let nft = TheSavagePet {
            id,
            name,
            description: string::utf8(b"An NFT from The Savage Pet collection."),
            image_url: url::new_unsafe_from_bytes(*string::as_bytes(&image_url)),
            attributes,
            creator: tx_context::sender(ctx),
        };

        // Mint event'ini emit et
        event::emit(TheSavagePetMintEvent {
            nft_id,
            name,
            owner: ctx.sender(),
        });

        transfer::public_transfer(nft, ctx.sender());
    }

    // Burn an NFT
    public fun burn (
        _ : &AdminCap,
        nft: TheSavagePet,
        ctx: &mut TxContext,
    ) {
        let nft_id = object::id(&nft);
        event::emit(TheSavagePetBurnEvent {
            nft_id: nft_id,
            name: nft.name,
            owner: ctx.sender(),
        });

        let TheSavagePet { id, name: _, description: _, image_url: _, attributes: _, creator: _ } = nft;
        object::delete(id);
    }

    public fun get_nft_details(nft: &TheSavagePet): (ID, String, String, Url, address) {// Get details of an NFT
        (
            object::id(nft),
            nft.name,
            nft.description,
            nft.image_url,
            nft.creator
        )
    }

    public fun get_nft_id(nft: &TheSavagePet): ID {// Get the ID of an NFT
        object::id(nft)
    }

    public fun get_nft_name(nft: &TheSavagePet): String {// Get the name of an NFT
        nft.name
    }

    public fun get_nft_attributes(nft: &TheSavagePet): &VecMap<String, String> {// Get the attributes of an NFT
        &nft.attributes
    }

    public fun get_multiple_nft_ids(nfts: &vector<TheSavagePet>): vector<ID> {// Get the IDs of multiple NFTs
        let mut ids = vector::empty<ID>();
        let mut i = 0;
        while (i < vector::length(nfts)) {
            let nft = vector::borrow(nfts, i);
            vector::push_back(&mut ids, object::id(nft));
            i = i + 1;
        };
        ids
    }

}