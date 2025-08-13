#[allow(lint(self_transfer))]
module sui_nft::marketplace {
    use sui::event;
    use sui::table::{Self, Table};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui_nft::sui_nft::{TheSavagePet, AdminCap};
    use sui::package;
    use sui::display;
    use std::string;

    // =============== Constants ===============
    const ROYALTY_PERCENTAGE: u64 = 3; // %3 royalty
    const CREATOR: address = @creator;

    // =============== Error Codes ===============
    const ENFTNotFound: u64 = 1;
    const ENotOwner: u64 = 2;
    const EInsufficientPayment: u64 = 3;
    const ENotListed: u64 = 4;
    const EAlreadyListed: u64 = 5;

    // =============== Structs ===============
    
    /// Main marketplace structure that holds all NFTs and listings
    #[allow(lint(coin_field))]
    public struct Marketplace has key, store {
        id: UID,
        items: Table<ID, address>, // NFT ID -> Owner address
        listings: Table<ID, ListingInfo>, // NFT ID -> Listing Info
        nfts: Table<ID, TheSavagePet>, // NFT ID -> NFT Object
        profits: Coin<SUI>, // Marketplace accumulated profits
        total_items: u64, // Total items in marketplace
        total_sales: u64, // Total completed sales
        total_volume: u64, // Total trading volume in SUI
    }

    /// Information about an NFT listing
    public struct ListingInfo has store, copy, drop {
        price: u64,
        seller: address,
        listed_at: u64, // epoch timestamp
    }

    public struct MARKETPLACE has drop {}

    // =============== Events ===============
    
    public struct MarketplaceCreated has copy, drop {
        marketplace_id: ID,
        creator: address,
    }

    public struct NFTPlaced has copy, drop {
        marketplace_id: ID,
        nft_id: ID,
        owner: address,
    }

    public struct NFTListed has copy, drop {
        marketplace_id: ID,
        nft_id: ID,
        price: u64,
        seller: address,
    }

    public struct NFTDelisted has copy, drop {
        marketplace_id: ID,
        nft_id: ID,
        seller: address,
    }

    public struct NFTSold has copy, drop {
        marketplace_id: ID,
        nft_id: ID,
        price: u64,
        seller: address,
        buyer: address,
    }

    public struct NFTWithdrawn has copy, drop {
        marketplace_id: ID,
        nft_id: ID,
        owner: address,
    }

    public struct ProfitsWithdrawn has copy, drop {
        marketplace_id: ID,
        amount: u64,
        recipient: address,
    }

    

    /// Initialize the marketplace (called by admin)
    fun init (otw: MARKETPLACE, ctx: &mut TxContext){

        let publisher = package::claim(otw, ctx);
        let mut display = display::new<Marketplace>(&publisher, ctx);

        let marketplace = Marketplace {
            id: object::new(ctx),
            items: table::new(ctx),
            listings: table::new(ctx),
            nfts: table::new(ctx),
            profits: coin::zero<SUI>(ctx),
            total_items: 0,
            total_sales: 0,
            total_volume: 0,
        };

        display::add(&mut display, string::utf8(b"id"), string::utf8(b"{id}"));
        display::add(&mut display, string::utf8(b"total_items"), string::utf8(b"{total_items}"));
        display::add(&mut display, string::utf8(b"total_sales"), string::utf8(b"{total_sales}"));
        display::add(&mut display, string::utf8(b"total_volume"), string::utf8(b"{total_volume}"));
        display::update_version(&mut display);

        let marketplace_id = object::id(&marketplace);
        
        event::emit(MarketplaceCreated {
            marketplace_id,
            creator: tx_context::sender(ctx),
        });
        transfer::public_transfer(display, ctx.sender());
        transfer::public_transfer(publisher, ctx.sender());
        transfer::public_share_object(marketplace);
    }
    
    // =============== Public Functions ===============

    /// Place an NFT in the marketplace (doesn't list it for sale)
    public fun place_nft(
        marketplace: &mut Marketplace,
        nft: TheSavagePet,
        ctx: &mut TxContext,
    ) {
        let nft_id = object::id(&nft);
        let sender = tx_context::sender(ctx);
        
        // Add NFT to marketplace
        table::add(&mut marketplace.items, nft_id, sender);
        table::add(&mut marketplace.nfts, nft_id, nft);
        marketplace.total_items = marketplace.total_items + 1;

        event::emit(NFTPlaced {
            marketplace_id: object::id(marketplace),
            nft_id,
            owner: sender,
        });
    }

    /// List an NFT for sale (NFT must already be in marketplace)
    public fun list_nft(
        marketplace: &mut Marketplace,
        nft_id: ID,
        price: u64,
        ctx: &mut TxContext,
    ) {
        let sender = tx_context::sender(ctx);
        
        // Check if NFT exists and sender is owner
        assert!(table::contains(&marketplace.items, nft_id), ENFTNotFound);
        let owner = table::borrow(&marketplace.items, nft_id);
        assert!(*owner == sender, ENotOwner);
        
        // Check if already listed
        assert!(!table::contains(&marketplace.listings, nft_id), EAlreadyListed);

        let listing = ListingInfo {
            price,
            seller: sender,
            listed_at: tx_context::epoch(ctx),
        };

        table::add(&mut marketplace.listings, nft_id, listing);

        event::emit(NFTListed {
            marketplace_id: object::id(marketplace),
            nft_id,
            price,
            seller: sender,
        });
    }

    /// Place and list NFT in one transaction
    public fun place_and_list_nft(
        marketplace: &mut Marketplace,
        nft: TheSavagePet,
        price: u64,
        ctx: &mut TxContext,
    ) {
        let nft_id = object::id(&nft);
        let sender = tx_context::sender(ctx);
        
        // Place NFT
        table::add(&mut marketplace.items, nft_id, sender);
        table::add(&mut marketplace.nfts, nft_id, nft);
        marketplace.total_items = marketplace.total_items + 1;

        // List NFT
        let listing = ListingInfo {
            price,
            seller: sender,
            listed_at: tx_context::epoch(ctx),
        };
        table::add(&mut marketplace.listings, nft_id, listing);

        event::emit(NFTPlaced {
            marketplace_id: object::id(marketplace),
            nft_id,
            owner: sender,
        });

        event::emit(NFTListed {
            marketplace_id: object::id(marketplace),
            nft_id,
            price,
            seller: sender,
        });
    }

    /// Remove NFT from listing (but keep in marketplace)
    public fun delist_nft(
        marketplace: &mut Marketplace,
        nft_id: ID,
        ctx: &mut TxContext,
    ) {
        let sender = tx_context::sender(ctx);
        
        // Check if NFT is listed and sender is owner
        assert!(table::contains(&marketplace.listings, nft_id), ENotListed);
        let listing = table::borrow(&marketplace.listings, nft_id);
        assert!(listing.seller == sender, ENotOwner);

        table::remove(&mut marketplace.listings, nft_id);

        event::emit(NFTDelisted {
            marketplace_id: object::id(marketplace),
            nft_id,
            seller: sender,
        });
    }

    /// Purchase a listed NFT
    public fun purchase_nft(
        marketplace: &mut Marketplace,
        nft_id: ID,
        mut payment: Coin<SUI>,
        ctx: &mut TxContext,
    ): TheSavagePet {
        let buyer = tx_context::sender(ctx);
        
        // Check if NFT is listed
        assert!(table::contains(&marketplace.listings, nft_id), ENotListed);
        let listing = table::remove(&mut marketplace.listings, nft_id);
        
        // Check payment amount
        let paid_amount = coin::value(&payment);
        assert!(paid_amount >= listing.price, EInsufficientPayment);

        // Handle change if overpaid
        if (paid_amount > listing.price) {
            let change = coin::split(&mut payment, paid_amount - listing.price, ctx);
            transfer::public_transfer(change, buyer);
        };

        // Calculate royalty and seller payment
        let royalty_amount = (listing.price * ROYALTY_PERCENTAGE) / 100;
        let seller_amount = listing.price - royalty_amount;

        // Send royalty to creator
        if (royalty_amount > 0) {
            let royalty_coin = coin::split(&mut payment, royalty_amount, ctx);
            transfer::public_transfer(royalty_coin, CREATOR);
        };

        // Send payment to seller
        let seller_payment = coin::split(&mut payment, seller_amount, ctx);
        transfer::public_transfer(seller_payment, listing.seller);

        // Add remaining coins to marketplace profits
        coin::join(&mut marketplace.profits, payment);

        // Remove NFT from marketplace and transfer ownership
        table::remove(&mut marketplace.items, nft_id);
        let nft = table::remove(&mut marketplace.nfts, nft_id);
        
        // Update marketplace stats
        marketplace.total_sales = marketplace.total_sales + 1;
        marketplace.total_volume = marketplace.total_volume + listing.price;

        event::emit(NFTSold {
            marketplace_id: object::id(marketplace),
            nft_id,
            price: listing.price,
            seller: listing.seller,
            buyer,
        });

        nft
    }

    /// Withdraw NFT from marketplace (must not be listed)
    public fun withdraw_nft(
        marketplace: &mut Marketplace,
        nft_id: ID,
        ctx: &mut TxContext,
    ): TheSavagePet {
        let sender = tx_context::sender(ctx);
        
        // Check if NFT exists and sender is owner
        assert!(table::contains(&marketplace.items, nft_id), ENFTNotFound);
        let owner = table::borrow(&marketplace.items, nft_id);
        assert!(*owner == sender, ENotOwner);

        // Remove from listing if listed
        if (table::contains(&marketplace.listings, nft_id)) {
            table::remove(&mut marketplace.listings, nft_id);
        };

        // Remove NFT from marketplace
        table::remove(&mut marketplace.items, nft_id);
        let nft = table::remove(&mut marketplace.nfts, nft_id);
        marketplace.total_items = marketplace.total_items - 1;

        event::emit(NFTWithdrawn {
            marketplace_id: object::id(marketplace),
            nft_id,
            owner: sender,
        });

        nft
    }

    /// Update listing price
    public fun update_listing_price(
        marketplace: &mut Marketplace,
        nft_id: ID,
        new_price: u64,
        ctx: &mut TxContext,
    ) {
        let sender = tx_context::sender(ctx);
        
        // Check if NFT is listed and sender is owner
        assert!(table::contains(&marketplace.listings, nft_id), ENotListed);
        let listing = table::borrow_mut(&mut marketplace.listings, nft_id);
        assert!(listing.seller == sender, ENotOwner);

        // Update price
        listing.price = new_price;
        listing.listed_at = tx_context::epoch(ctx);

        event::emit(NFTListed {
            marketplace_id: object::id(marketplace),
            nft_id,
            price: new_price,
            seller: sender,
        });
    }

    /// Withdraw marketplace profits (admin only)
    public fun withdraw_profits(
        _: &AdminCap,
        marketplace: &mut Marketplace,
        amount: Option<u64>,
        ctx: &mut TxContext,
    ): Coin<SUI> {
        let withdraw_amount = if (option::is_some(&amount)) {
            *option::borrow(&amount)
        } else {
            coin::value(&marketplace.profits)
        };

        let withdrawn = coin::split(&mut marketplace.profits, withdraw_amount, ctx);

        event::emit(ProfitsWithdrawn {
            marketplace_id: object::id(marketplace),
            amount: withdraw_amount,
            recipient: tx_context::sender(ctx),
        });

        withdrawn
    }

    // =============== Query Functions ===============

    /// Check if NFT is in marketplace
    public fun is_nft_in_marketplace(marketplace: &Marketplace, nft_id: ID): bool {
        table::contains(&marketplace.items, nft_id)
    }

    /// Check if NFT is listed for sale
    public fun is_nft_listed(marketplace: &Marketplace, nft_id: ID): bool {
        table::contains(&marketplace.listings, nft_id)
    }

    /// Get NFT listing price
    public fun get_listing_price(marketplace: &Marketplace, nft_id: ID): Option<u64> {
        if (table::contains(&marketplace.listings, nft_id)) {
            let listing = table::borrow(&marketplace.listings, nft_id);
            option::some(listing.price)
        } else {
            option::none()
        }
    }

    /// Get NFT listing info
    public fun get_listing_info(marketplace: &Marketplace, nft_id: ID): Option<ListingInfo> {
        if (table::contains(&marketplace.listings, nft_id)) {
            option::some(*table::borrow(&marketplace.listings, nft_id))
        } else {
            option::none()
        }
    }

    /// Get NFT owner in marketplace
    public fun get_nft_owner(marketplace: &Marketplace, nft_id: ID): Option<address> {
        if (table::contains(&marketplace.items, nft_id)) {
            option::some(*table::borrow(&marketplace.items, nft_id))
        } else {
            option::none()
        }
    }

    /// Get marketplace stats
    public fun get_marketplace_stats(marketplace: &Marketplace): (u64, u64, u64, u64) {
        (
            marketplace.total_items,
            marketplace.total_sales,
            marketplace.total_volume,
            coin::value(&marketplace.profits)
        )
    }

    /// Get marketplace profits amount
    public fun get_profits_amount(marketplace: &Marketplace): u64 {
        coin::value(&marketplace.profits)
    }

    // =============== Helper Functions ===============

    /// Calculate royalty amount for a given price
    public fun calculate_royalty(price: u64): u64 {
        (price * ROYALTY_PERCENTAGE) / 100
    }

    /// Calculate seller amount after royalty
    public fun calculate_seller_amount(price: u64): u64 {
        price - calculate_royalty(price)
    }

    /// Get royalty percentage
    public fun get_royalty_percentage(): u64 {
        ROYALTY_PERCENTAGE
    }
}