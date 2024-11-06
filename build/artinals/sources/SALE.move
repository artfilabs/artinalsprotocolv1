module artinals::SALE {
    use artinals::ART20;
    use sui::event;
    use std::string::{Self, String};
    use sui::dynamic_field as df;  
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};

    // Import types from ART20 module
    use artinals::ART20::{NFT, CollectionCap, UserBalance};
    
    

    //Errors
    const E_NO_TOKENS_TO_BURN: u64 = 6;
    const E_NOT_CREATOR: u64 = 2;
    const E_INVALID_PRICE: u64 = 7;
    const E_COLLECTION_MISMATCH: u64 = 8;
    const E_INSUFFICIENT_BALANCE: u64 = 9;
    const E_SALE_NOT_ACTIVE: u64 = 10;
    const E_SALE_ALREADY_ACTIVE: u64 = 11;
    const E_ADDRESS_DENIED: u64 = 12;
    const E_INVALID_BATCH_SIZE: u64 = 16;
    const E_INVALID_ASSET_ID: u64 = 17;
    const E_OVERFLOW: u64 = 18;
    const E_MAX_SUPPLY_EXCEEDED: u64 = 19;
    const E_MAX_BATCH_SIZE_EXCEEDED: u64 = 20;
    const E_MAX_PRICE_EXCEEDED: u64 = 21;
    const E_NO_CURRENCY_BALANCE: u64 = 22;
    const E_INVALID_PERCENTAGE: u64 = 23;
    const E_PERCENTAGE_SUM_MISMATCH: u64 = 24;
    const E_EMPTY_RECIPIENTS: u64 = 25;

    // Add maximum limits
    const MAX_U64: u64 = 18446744073709551615;
    const MAX_SUPPLY: u64 = 1000000000; // 1 billion
    const MAX_BATCH_SIZE: u64 = 200;    // Maximum 100 NFTs per batch
    const MAX_PRICE: u64 = 10000000000000000000; // 1 trillion (adjust based on currency decimals)



    




    // One-Time-Witness for the module
    public struct SALE has drop {}


    // Define events for transfers, approvals, etc.
    public struct TransferEvent has copy, drop {
        from: address,
        to: address,
        id: ID,
        amount: u64,
        royalty: u64,
        asset_id: u64, // Unique asset ID within the collection
    }

    public struct BatchTransferEvent has copy, drop {
        from: address,
        recipients: vector<address>,
        token_ids: vector<ID>,
        amounts: vector<u64>,
        collection_id: ID,
        timestamp: u64
    }

    public struct PriceUpdated<phantom CURRENCY> has copy, drop {
    sale_id: ID,
    new_price: u64
}

// Use imported is_denied function
    public fun check_deny_list(collection_cap: &CollectionCap, addr: address): bool {
        ART20::is_denied(collection_cap, addr)
    }


    // Define event for burning NFTs
    

public struct DebugEvent has copy, drop {
    message: String,
    token_id: ID,
    sender: address,
    recipient: address,
}



// Sale object to track NFT listings
public struct NFTSale<phantom CURRENCY> has key {
    id: UID,
    price_per_nft: u64,
    currency_balance: Balance<CURRENCY>,
    creator: address,
    collection_id: ID,
    is_active: bool,
    nft_count: u64,  // Track number of NFTs instead of storing them directly
    artist_name: String,
    artwork_title: String,
    width_cm: u64,
    height_cm: u64,
    creation_year: u64,
    medium: String,
    provenance: String,
    authenticity: String,
    signature: String,
    about_artwork: String,
}


public struct NFTListingEvent<phantom CURRENCY> has copy, drop {
    sale_id: ID,
    listing_id: ID,
    asset_id: u64,
    price: u64
}

// Updated NFTListing struct with phantom type parameter
public struct NFTListing<phantom CURRENCY> has key, store {
    id: UID,
    nft: NFT,
    sale_id: ID,
    asset_id: u64,
    price: u64
}

public struct NFTFieldKey<phantom CURRENCY> has copy, store, drop {
    asset_id: u64
}


// Events
// Update events to be generic too
    public struct SaleCreated<phantom CURRENCY> has copy, drop {
        sale_id: ID,
        creator: address,
        nft_count: u64,
        price_per_nft: u64,
        collection_id: ID
    }

    public struct NFTPurchased<phantom CURRENCY> has copy, drop {
        sale_id: ID,
        buyer: address,
        nft_ids: vector<ID>,
        amount_paid: u64
    }



public struct CurrencyWithdrawn<phantom CURRENCY> has copy, drop {
    sale_id: ID,
    amount: u64,
    recipient: address
}

public struct CurrencyWithdrawSplit<phantom CURRENCY> has copy, drop {
    sale_id: ID,
    recipient: address,
    amount: u64,
    percentage: u64
}


fun safe_add(a: u64, b: u64): u64 {
    assert!(a <= MAX_U64 - b, E_OVERFLOW);
    a + b
}

fun safe_sub(a: u64, b: u64): u64 {
    assert!(a >= b, E_INSUFFICIENT_BALANCE);
    a - b
}

    

// NFT Sale functions
public entry fun create_nft_sale<CURRENCY>(
        mut nfts: vector<NFT>,
        nft_amount: u64,
        price_per_nft: u64,
        artist_name: vector<u8>,
        artwork_title: vector<u8>,
        width_cm: u64,
        height_cm: u64,
        creation_year: u64,
        medium: vector<u8>,
        provenance: vector<u8>,
        authenticity: vector<u8>,
        signature: vector<u8>,
        about_artwork: vector<u8>,
        collection_cap: &mut CollectionCap,
        user_balance: &mut UserBalance,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        
        // Price validation
        assert!(price_per_nft <= MAX_PRICE, E_MAX_PRICE_EXCEEDED);
        assert!(price_per_nft > 0, E_INVALID_PRICE);
        assert!(nft_amount <= MAX_BATCH_SIZE, E_MAX_BATCH_SIZE_EXCEEDED);
        
        let nft_length = vector::length(&nfts);
        assert!(nft_length >= nft_amount, E_NO_TOKENS_TO_BURN);
        
        // Get collection verification using ART20 getters
        let first_nft = vector::borrow(&nfts, 0);
        let collection_id = ART20::get_nft_collection_id(first_nft);
        
        // Verify collection matches
        assert!(ART20::get_collection_cap_id(collection_cap) == collection_id, E_COLLECTION_MISMATCH);
        assert!(ART20::get_user_balance_collection_id(user_balance) == collection_id, E_COLLECTION_MISMATCH);
        assert!(ART20::get_user_balance_amount(user_balance) >= nft_amount, E_INSUFFICIENT_BALANCE);
        
        // Update collection supply
        let current_supply = ART20::get_collection_current_supply(collection_cap);
let new_supply = safe_add(current_supply, nft_amount);
ART20::update_collection_supply(collection_cap, new_supply);

        // Create sale object
        let mut sale = NFTSale<CURRENCY> {
            id: object::new(ctx),
            price_per_nft,
            currency_balance: balance::zero(),
            creator: sender,
            collection_id,
            is_active: true,
            nft_count: nft_amount,
            artist_name: string::utf8(artist_name),
            artwork_title: string::utf8(artwork_title),
            width_cm,
            height_cm,
            creation_year,
            medium: string::utf8(medium),
            provenance: string::utf8(provenance),
            authenticity: string::utf8(authenticity),
            signature: string::utf8(signature),
            about_artwork: string::utf8(about_artwork),
        };

        let sale_id = object::uid_to_inner(&sale.id);
        
        // Process NFTs
        let mut i = 0;
        while (i < nft_amount) {
            let nft = vector::pop_back(&mut nfts);
            df::add(&mut sale.id, NFTFieldKey<CURRENCY> { asset_id: i + 1 }, nft);
            
            event::emit(NFTListingEvent<CURRENCY> {
                sale_id,
                listing_id: sale_id,
                asset_id: i + 1,
                price: price_per_nft
            });
            
            i = i + 1;
        };
        
        // Return remaining NFTs
        while (!vector::is_empty(&nfts)) {
            let nft = vector::pop_back(&mut nfts);
            transfer::public_transfer(nft, sender);
        };
        vector::destroy_empty(nfts);
        
        let current_supply = ART20::get_collection_current_supply(collection_cap);
let new_supply = safe_add(current_supply, nft_amount);
ART20::update_collection_supply(collection_cap, new_supply);
        
        event::emit(SaleCreated<CURRENCY> {
            sale_id,
            creator: sender,
            nft_count: nft_amount,
            price_per_nft,
            collection_id
        });
        
        transfer::share_object(sale);
    }

// Purchase NFTs from a sale
public entry fun purchase_nfts<CURRENCY>(
        sale: &mut NFTSale<CURRENCY>,
        payment: Coin<CURRENCY>,
        asset_id: u64,
        collection_cap: &CollectionCap,
        ctx: &mut TxContext
    ) {
        let buyer = tx_context::sender(ctx);
        
        assert!(sale.is_active, E_SALE_NOT_ACTIVE);
        assert!(!ART20::is_denied(collection_cap, buyer), E_ADDRESS_DENIED);
        
        // Verify asset_id is valid
        assert!(asset_id > 0 && asset_id <= sale.nft_count, E_INVALID_ASSET_ID);
        assert!(df::exists_(&sale.id, NFTFieldKey<CURRENCY> { asset_id }), E_INVALID_ASSET_ID);
        
        // Verify price and process payment
        let payment_amount = coin::value(&payment);
        assert!(payment_amount >= sale.price_per_nft, E_INSUFFICIENT_BALANCE);
        
        // Get NFT from sale with proper type annotations
        let nft: NFT = df::remove(&mut sale.id, NFTFieldKey<CURRENCY> { asset_id });
        let nft_id = ART20::get_nft_id(&nft);
        
        // Process payment
        let mut payment_mut = payment;
        let paid = coin::split(&mut payment_mut, sale.price_per_nft, ctx);
        balance::join(&mut sale.currency_balance, coin::into_balance(paid));
        
        // Handle excess payment
        if (coin::value(&payment_mut) > 0) {
            transfer::public_transfer(payment_mut, buyer);
        } else {
            coin::destroy_zero(payment_mut);
        };
        
        // Create buyer balance through ART20
        let buyer_balance = ART20::create_user_balance(
            sale.collection_id,
            1,
            ctx
        );
        
        // Emit purchase event
        event::emit(NFTPurchased<CURRENCY> {
            sale_id: object::uid_to_inner(&sale.id),
            buyer,
            nft_ids: vector[nft_id],
            amount_paid: sale.price_per_nft
        });
        
        // Transfer balance and NFT to buyer
        transfer::public_transfer(buyer_balance, buyer);
        transfer::public_transfer(nft, buyer);
        
        // Update sale NFT count
        sale.nft_count = sale.nft_count - 1;
    }

// Add more NFTs to an existing sale with enhanced debug events
public entry fun add_nfts_to_sale<CURRENCY>(
        sale: &mut NFTSale<CURRENCY>,
        mut nfts: vector<NFT>,
        nft_amount: u64,
        collection_cap: &mut CollectionCap,
        user_balance: &mut UserBalance,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let sale_id = object::uid_to_inner(&sale.id);
        
        assert!(sender == sale.creator, E_NOT_CREATOR);
        assert!(sale.is_active, E_SALE_NOT_ACTIVE);
        
        let new_total_count = safe_add(sale.nft_count, nft_amount);
        assert!(new_total_count <= MAX_SUPPLY, E_MAX_SUPPLY_EXCEEDED);
        assert!(nft_amount <= MAX_BATCH_SIZE, E_MAX_BATCH_SIZE_EXCEEDED);
        
        let nft_length = vector::length(&nfts);
        assert!(nft_length >= nft_amount, E_NO_TOKENS_TO_BURN);
        
        let first_nft = vector::borrow(&nfts, 0);
        assert!(ART20::get_nft_collection_id(first_nft) == sale.collection_id, E_COLLECTION_MISMATCH);
        
        // Verify collection and balance using ART20 getters
        assert!(ART20::get_collection_cap_id(collection_cap) == sale.collection_id, E_COLLECTION_MISMATCH);
        assert!(ART20::get_user_balance_collection_id(user_balance) == sale.collection_id, E_COLLECTION_MISMATCH);
        assert!(ART20::get_user_balance_amount(user_balance) >= nft_amount, E_INSUFFICIENT_BALANCE);

        // Update collection supply first
        let current_supply = ART20::get_collection_current_supply(collection_cap);
        let new_supply = safe_add(current_supply, nft_amount);
        ART20::update_collection_supply(collection_cap, new_supply);
        
        let mut i = 0;
        while (i < nft_amount) {
            let nft = vector::pop_back(&mut nfts);
            let asset_id = sale.nft_count + i + 1;
            
            assert!(ART20::get_nft_collection_id(&nft) == sale.collection_id, E_COLLECTION_MISMATCH);
            
            df::add(&mut sale.id, NFTFieldKey<CURRENCY> { asset_id }, nft);
            
            event::emit(NFTListingEvent<CURRENCY> {
                sale_id,
                listing_id: sale_id,
                asset_id,
                price: sale.price_per_nft
            });
            
            i = i + 1;
        };
        
        while (!vector::is_empty(&nfts)) {
            let nft = vector::pop_back(&mut nfts);
            transfer::public_transfer(nft, sender);
        };
        vector::destroy_empty(nfts);
        
        // Update balances using ART20 functions
        let current_balance = ART20::get_user_balance_amount(user_balance);
let new_balance = safe_sub(current_balance, nft_amount);
ART20::set_user_balance_amount(user_balance, new_balance);
        
        sale.nft_count = safe_add(sale.nft_count, nft_amount);
        
        event::emit(SaleCreated<CURRENCY> {
            sale_id,
            creator: sender,
            nft_count: nft_amount,
            price_per_nft: sale.price_per_nft,
            collection_id: sale.collection_id
        });
    }

    // Update withdrawal function to be generic
    public entry fun withdraw_currency<CURRENCY>(
    sale: &mut NFTSale<CURRENCY>,
    recipients: vector<address>,
    percentages: vector<u64>,
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);
    assert!(sender == sale.creator, E_NOT_CREATOR);
    
    let balance_value = balance::value(&sale.currency_balance);
    assert!(balance_value > 0, E_NO_CURRENCY_BALANCE);
    
    // Input validation
    let recipient_count = vector::length(&recipients);
    assert!(recipient_count > 0, E_EMPTY_RECIPIENTS);
    assert!(recipient_count == vector::length(&percentages), E_INVALID_PERCENTAGE);
    
    // Validate percentages sum to 100
    let mut percentage_sum = 0u64;
    let mut i = 0;
    while (i < vector::length(&percentages)) {
        let percentage = *vector::borrow(&percentages, i);
        percentage_sum = percentage_sum + percentage;
        i = i + 1;
    };
    assert!(percentage_sum == 100, E_PERCENTAGE_SUM_MISMATCH);
    
    // Debug event for starting withdrawal
    event::emit(DebugEvent {
        message: string::utf8(b"Starting currency withdrawal"),
        token_id: object::uid_to_inner(&sale.id),
        sender,
        recipient: sender
    });
    
    // Process each recipient
    i = 0;
    while (i < recipient_count) {
        let recipient = *vector::borrow(&recipients, i);
        let percentage = *vector::borrow(&percentages, i);
        
        // Calculate amount for this recipient using safe math
        let recipient_amount = (balance_value * percentage) / 100;
        assert!(recipient_amount > 0, E_INVALID_PERCENTAGE);
        
        // Split and transfer the amount
        let withdrawn = balance::split(&mut sale.currency_balance, recipient_amount);
        let payment = coin::from_balance(withdrawn, ctx);
        
        // Emit split payment event
        event::emit(CurrencyWithdrawSplit<CURRENCY> {
            sale_id: object::uid_to_inner(&sale.id),
            recipient,
            amount: recipient_amount,
            percentage
        });
        
        // Debug event for individual transfer
        event::emit(DebugEvent {
            message: string::utf8(b"Processing split payment"),
            token_id: object::uid_to_inner(&sale.id),
            sender,
            recipient
        });
        
        // Transfer to recipient
        transfer::public_transfer(payment, recipient);
        
        i = i + 1;
    };
    
    // Emit the main withdrawal event
    event::emit(CurrencyWithdrawn<CURRENCY> {
        sale_id: object::uid_to_inner(&sale.id),
        amount: balance_value,
        recipient: sender
    });
    
    // Final success debug event
    event::emit(DebugEvent {
        message: string::utf8(b"Currency withdrawal completed successfully"),
        token_id: object::uid_to_inner(&sale.id),
        sender,
        recipient: sender
    });
}

public entry fun remove_nfts_from_sale<CURRENCY>(
        sale: &mut NFTSale<CURRENCY>,
        amount: u64,
        user_balance: &mut UserBalance,
        collection_cap: &mut CollectionCap,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);

        // Verify sender is creator
        assert!(sender == sale.creator, E_NOT_CREATOR);
        assert!(sale.is_active, E_SALE_NOT_ACTIVE);
        assert!(amount > 0 && amount <= sale.nft_count, E_INVALID_BATCH_SIZE);

        let mut i = 0;
        let mut token_ids = vector::empty<ID>();
        let mut amounts = vector::empty<u64>();

        while (i < amount) {
            let asset_id = sale.nft_count - i;
            let nft: NFT = df::remove(&mut sale.id, NFTFieldKey<CURRENCY> { asset_id });

            // Get NFT ID using ART20 getter
            let nft_id = ART20::get_nft_id(&nft);
            vector::push_back(&mut token_ids, nft_id);
            vector::push_back(&mut amounts, 1);

            transfer::public_transfer(nft, sender);
            i = i + 1;
        };

        // Update sale count
        sale.nft_count = safe_sub(sale.nft_count, amount);

        // Update user balance using ART20 functions
        let current_balance = ART20::get_user_balance_amount(user_balance);
        let new_balance = safe_add(current_balance, amount);
        ART20::set_user_balance_amount(user_balance, new_balance);

        // Update collection cap using ART20
        let current_supply = ART20::get_collection_current_supply(collection_cap);
let new_supply = safe_sub(current_supply, amount);
ART20::update_collection_supply(collection_cap, new_supply);

        // Emit batch transfer event
        event::emit(BatchTransferEvent {
            from: sender,
            recipients: vector[sender],
            token_ids,
            amounts,
            collection_id: sale.collection_id,
            timestamp: tx_context::epoch(ctx)
        });
    }

// Add close sale functionality
public entry fun close_sale<CURRENCY>(
    sale: &mut NFTSale<CURRENCY>,
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);
    assert!(sender == sale.creator, E_NOT_CREATOR);
    
    // Set sale as inactive
    sale.is_active = false;
}

// Add reopen sale functionality
public entry fun reopen_sale<CURRENCY>(
    sale: &mut NFTSale<CURRENCY>,
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);
    assert!(sender == sale.creator, E_NOT_CREATOR);
    assert!(!sale.is_active, E_SALE_ALREADY_ACTIVE);
    
    // Set sale as active
    sale.is_active = true;
}

// Add function to update price
public entry fun update_sale_price<CURRENCY>(
    sale: &mut NFTSale<CURRENCY>,
    new_price: u64,
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);
    assert!(sender == sale.creator, E_NOT_CREATOR);
    assert!(new_price > 0, E_INVALID_PRICE);

    sale.price_per_nft = new_price;

    event::emit(PriceUpdated<CURRENCY> {
        sale_id: object::uid_to_inner(&sale.id),
        new_price
    });
}


// View functions

// Helper function to check if NFT exists in sale
public fun has_nft<CURRENCY>(sale: &NFTSale<CURRENCY>, asset_id: u64): bool {
    df::exists_(&sale.id, NFTFieldKey<CURRENCY> { asset_id })
}

// Helper function to get NFT count
public fun get_nft_count<CURRENCY>(sale: &NFTSale<CURRENCY>): u64 {
    sale.nft_count
}

public fun get_collection_id(nft: &NFT): ID {
        ART20::get_nft_collection_id(nft)
    }

// Helper function to check if NFT exists in sale
public fun has_nft_in_sale<CURRENCY>(
    sale: &NFTSale<CURRENCY>,
    asset_id: u64
): bool {
    df::exists_(&sale.id, NFTFieldKey<CURRENCY> { asset_id })
}

// Helper function to get NFT count in sale
public fun get_available_nft_count<CURRENCY>(
    sale: &NFTSale<CURRENCY>
): u64 {
    sale.nft_count
}



public fun add_nft_to_sale<CURRENCY>(
    sale: &mut NFTSale<CURRENCY>,
    nft: NFT,
    asset_id: u64,
    ctx: &mut TxContext
) {
    // Use ctx in debug event
    let sale_id = object::uid_to_inner(&sale.id);
    let sender = tx_context::sender(ctx);
    
    // Add debug event using ctx
    event::emit(DebugEvent {
        message: string::utf8(b"Adding NFT to sale"),
        token_id: sale_id,
        sender,
        recipient: sender
    });

    // Add NFT as dynamic field with proper type annotations
    df::add(&mut sale.id, NFTFieldKey<CURRENCY> { asset_id }, nft);

    // Emit listing event
    event::emit(NFTListingEvent<CURRENCY> {
        sale_id,
        listing_id: sale_id,
        asset_id,
        price: sale.price_per_nft
    });
}

public fun borrow_nft<CURRENCY>(
    sale: &NFTSale<CURRENCY>,
    asset_id: u64
): &NFT {
    df::borrow(&sale.id, NFTFieldKey<CURRENCY> { asset_id })
}

// Helper function to borrow NFT mutably from sale
public fun borrow_nft_mut<CURRENCY>(
    sale: &mut NFTSale<CURRENCY>,
    asset_id: u64
): &mut NFT {
    df::borrow_mut(&mut sale.id, NFTFieldKey<CURRENCY> { asset_id })
}

public fun verify_collection_match(
    sale_collection_id: ID,
    nft_collection_id: ID,
    balance_collection_id: ID
) {
    assert!(sale_collection_id == nft_collection_id, E_COLLECTION_MISMATCH);
    assert!(sale_collection_id == balance_collection_id, E_COLLECTION_MISMATCH);
}

public fun get_sale_listings<CURRENCY>(
    sale: &NFTSale<CURRENCY>
): u64 {
    sale.nft_count
}

// Add a view function to get full sale status
public fun get_full_sale_status<CURRENCY>(
    sale: &NFTSale<CURRENCY>
): (address, u64, u64, ID, bool, u64) {
    (
        sale.creator,
        sale.nft_count,
        sale.price_per_nft,
        sale.collection_id,
        sale.is_active,
        balance::value(&sale.currency_balance)
    )
}

public fun get_sale_info<CURRENCY>(
    sale: &NFTSale<CURRENCY>
): (address, u64, u64, ID, bool) {
    (
        sale.creator,
        sale.nft_count,
        sale.price_per_nft,
        sale.collection_id,
        sale.is_active
    )
}

public fun validate_percentages(percentages: &vector<u64>): bool {
    let mut sum = 0u64;
    let mut i = 0;
    let len = vector::length(percentages);
    
    while (i < len) {
        sum = sum + *vector::borrow(percentages, i);
        i = i + 1;
    };
    
    sum == 100
}

// Helper function to calculate split amount
public fun calculate_split_amount(total: u64, percentage: u64): u64 {
    (total * percentage) / 100
}

    public fun get_sale_balance<CURRENCY>(sale: &NFTSale<CURRENCY>): u64 {
        balance::value(&sale.currency_balance)
    }

   public fun get_nft_info(nft: &NFT): (ID, ID, address) {
        (
            ART20::get_nft_id(nft),
            ART20::get_nft_collection_id(nft),
            ART20::get_nft_creator(nft)
        )
    }

// Helper function to verify listing belongs to sale
public fun verify_listing<CURRENCY>(
    sale: &NFTSale<CURRENCY>,
    listing: &NFTListing<CURRENCY>,
    asset_id: u64
): bool {
    listing.sale_id == object::uid_to_inner(&sale.id) &&
    listing.asset_id == asset_id &&
    listing.price == sale.price_per_nft
}

// Helper function to get listing details
public fun get_listing_details<CURRENCY>(
    listing: &NFTListing<CURRENCY>
): (ID, u64, u64) {
    (
        listing.sale_id,
        listing.asset_id,
        listing.price
    )
}

// Helper function to check if NFT can be removed from sale
public fun can_remove_from_sale<CURRENCY>(
    sale: &NFTSale<CURRENCY>,
    listing: &NFTListing<CURRENCY>,
    addr: address
): bool {
    sale.is_active && 
    sale.creator == addr &&
    listing.sale_id == object::uid_to_inner(&sale.id)
}

public fun get_sale_nft_count<CURRENCY>(sale: &NFTSale<CURRENCY>): u64 {
    sale.nft_count
}

// Helper function to get NFT from listing
public fun get_nft_from_listing<CURRENCY>(listing: &NFTListing<CURRENCY>): &NFT {
    &listing.nft
}

// Helper function to get asset ID from listing
public fun get_listing_asset_id<CURRENCY>(listing: &NFTListing<CURRENCY>): u64 {
    listing.asset_id
}

// Helper function to get listing price
public fun get_listing_price<CURRENCY>(listing: &NFTListing<CURRENCY>): u64 {
    listing.price
}

public fun is_sale_creator<CURRENCY>(sale: &NFTSale<CURRENCY>, addr: address): bool {
    sale.creator == addr
}

public fun get_artist_name<CURRENCY>(sale: &NFTSale<CURRENCY>): String {
    sale.artist_name
}

public fun get_artwork_title<CURRENCY>(sale: &NFTSale<CURRENCY>): String {
    sale.artwork_title
}

public fun get_dimensions<CURRENCY>(sale: &NFTSale<CURRENCY>): (u64, u64) {
    (sale.width_cm, sale.height_cm)
}

public fun get_creation_year<CURRENCY>(sale: &NFTSale<CURRENCY>): u64 {
    sale.creation_year
}

public fun get_price_per_nft<CURRENCY>(sale: &NFTSale<CURRENCY>): u64 {
    sale.price_per_nft
}

public fun get_medium<CURRENCY>(sale: &NFTSale<CURRENCY>): String {
    sale.medium
}

public fun get_provenance<CURRENCY>(sale: &NFTSale<CURRENCY>): String {
    sale.provenance
}

public fun get_authenticity<CURRENCY>(sale: &NFTSale<CURRENCY>): String {
    sale.authenticity
}

public fun get_signature<CURRENCY>(sale: &NFTSale<CURRENCY>): String {
    sale.signature
}

public fun get_about_artwork<CURRENCY>(sale: &NFTSale<CURRENCY>): String {
    sale.about_artwork
}



}