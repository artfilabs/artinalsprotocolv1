module artinals::SALE {
    use artinals::ART20;
    use sui::event;
    use std::string::{Self, String};
    use sui::dynamic_field as df;
    use sui::table::{Self, Table};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::url::Url;

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
    const ASSET_ID_NOT_FOUND: u64 = 26;

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

    // Event for sale status change
public struct SaleStatusChanged<phantom CURRENCY> has copy, drop {
    sale_id: ID,
    is_active: bool,
    changed_by: address,
    timestamp: u64
}

    public struct PriceUpdated<phantom CURRENCY> has copy, drop {
    sale_id: ID,
    new_price: u64
}


public struct SaleNFTKey<phantom CURRENCY> has copy, store, drop {
    asset_id: u64
}

// Metadata struct to store NFT sale information
public struct SaleNFTData has store {
    asset_id: u64,
    is_reserved: bool,
    listing_id: ID,
    price: u64
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
public struct NFTSale<phantom CURRENCY> has key, store {
    id: UID,
    price_per_nft: u64,
    currency_balance: Balance<CURRENCY>,
    creator: address,
    collection_id: ID,
    is_active: bool,
    nft_count: u64,
    asset_ids: vector<u64>,
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
    reserved_nfts: Table<u64, bool> // Track which NFTs are reserved for the sale
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
    listing_id: ID,  // Unique ID for the listing
    sale_id: ID,     // Reference to parent sale
    asset_id: u64,   // NFT asset ID
    price: u64,      // Listing price
    original_owner: address,  // Address of NFT owner
    logo_uri: Url,   // NFT logo URI
    name: String,    // NFT name
    description: String // NFT description
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

    public struct PriceUpdateEvent<phantom CURRENCY> has copy, drop {
    sale_id: ID,
    old_price: u64,
    new_price: u64,
    changed_by: address,
    timestamp: u64,
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

fun safe_mul(a: u64, b: u64): u64 {
    if (a == 0 || b == 0) {
        return 0
    };
    assert!(a <= MAX_U64 / b, E_OVERFLOW);
    a * b
}

    

// NFT Sale functions
public entry fun create_nft_sale<CURRENCY>(
    mut nft_asset_ids: vector<u64>, // Instead of NFT objects, we take asset IDs
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
    mut sender_balances: vector<UserBalance>,
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);
    let nft_amount = vector::length(&nft_asset_ids);

    // Validation checks
    assert!(price_per_nft <= MAX_PRICE, E_MAX_PRICE_EXCEEDED);
    assert!(price_per_nft > 0, E_INVALID_PRICE);
    assert!(nft_amount <= MAX_BATCH_SIZE, E_MAX_BATCH_SIZE_EXCEEDED);
    assert!(nft_amount > 0, E_NO_TOKENS_TO_BURN);

    // Calculate total available balance
    let mut total_available = 0u64;
    let mut i = 0;
    let n = vector::length(&sender_balances);
    while (i < n) {
        let balance = vector::borrow(&sender_balances, i);
        total_available = safe_add(total_available, ART20::get_user_balance_amount(balance));
        i = i + 1;
    };

    // Verify sufficient total balance
    assert!(total_available >= nft_amount, E_INSUFFICIENT_BALANCE);

    // Create sale object
    let mut sale = NFTSale<CURRENCY> {
        id: object::new(ctx),
        price_per_nft,
        currency_balance: balance::zero(),
        creator: sender,
        collection_id: ART20::get_collection_cap_id(collection_cap),
        is_active: true,
        nft_count: nft_amount,
        asset_ids: vector::empty(),
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
        reserved_nfts: table::new(ctx)
    };

    let sale_id = object::uid_to_inner(&sale.id);

    // Update sender balances
    let mut remaining_amount = nft_amount;
    let mut i = 0;
    while (i < vector::length(&sender_balances) && remaining_amount > 0) {
        let balance = vector::borrow_mut(&mut sender_balances, i);
        let current_balance = ART20::get_user_balance_amount(balance);
        
        if (current_balance > 0) {
            if (current_balance <= remaining_amount) {
                remaining_amount = remaining_amount - current_balance;
                ART20::set_user_balance_amount(balance, 0);
            } else {
                ART20::set_user_balance_amount(balance, current_balance - remaining_amount);
                remaining_amount = 0;
            };
        };
        i = i + 1;
    };

    // Process asset IDs
    while (!vector::is_empty(&nft_asset_ids)) {
        let asset_id = vector::pop_back(&mut nft_asset_ids);
        
        // Mark NFT as reserved in the sale
        table::add(&mut sale.reserved_nfts, asset_id, true);
        vector::push_back(&mut sale.asset_ids, asset_id);

        // Emit listing event
        event::emit(NFTListingEvent<CURRENCY> {
            sale_id,
            listing_id: sale_id,
            asset_id,
            price: price_per_nft
        });
    };

    // Return remaining balances to sender
    while (!vector::is_empty(&sender_balances)) {
        let balance = vector::pop_back(&mut sender_balances);
        if (ART20::get_user_balance_amount(&balance) > 0) {
            transfer::public_transfer(balance, sender);
        } else {
            ART20::cleanup_empty_balance(balance);
        };
    };

    // Clean up vectors
    vector::destroy_empty(nft_asset_ids);
    vector::destroy_empty(sender_balances);

    // Emit sale creation event
    event::emit(SaleCreated<CURRENCY> {
        sale_id,
        creator: sender,
        nft_count: nft_amount,
        price_per_nft,
        collection_id: sale.collection_id
    });

    // Share the sale object
    transfer::public_share_object(sale);
}



// Purchase NFTs from a sale
public entry fun purchase_nfts<CURRENCY>(
    sale: &mut NFTSale<CURRENCY>,
    payment: Coin<CURRENCY>,
    mut asset_ids: vector<u64>,
    collection_cap: &CollectionCap,
    ctx: &mut TxContext
) {
    let buyer = tx_context::sender(ctx);

    // Validate sale state and buyer
    assert!(sale.is_active, E_SALE_NOT_ACTIVE);
    assert!(!ART20::is_denied(collection_cap, buyer), E_ADDRESS_DENIED);

    let purchase_count = vector::length(&asset_ids);
    assert!(purchase_count > 0 && purchase_count <= MAX_BATCH_SIZE, E_INVALID_BATCH_SIZE);

    // Calculate total cost and validate payment
    let total_cost = safe_mul(sale.price_per_nft, purchase_count);
    let payment_amount = coin::value(&payment);
    assert!(payment_amount >= total_cost, E_INSUFFICIENT_BALANCE);

    // Create buyer's balance object
    let buyer_balance = ART20::create_user_balance(
        sale.collection_id,
        purchase_count,
        ctx
    );

    // Process payment
    let mut payment_mut = payment;
    let paid = coin::split(&mut payment_mut, total_cost, ctx);
    balance::join(&mut sale.currency_balance, coin::into_balance(paid));

    // Return excess payment if any
    if (coin::value(&payment_mut) > 0) {
        transfer::public_transfer(payment_mut, buyer);
    } else {
        coin::destroy_zero(payment_mut);
    };

    // Track purchased NFTs for event emission
    let mut purchased_ids = vector::empty<ID>();

    // Process each asset ID purchase
    while (!vector::is_empty(&asset_ids)) {
        let asset_id = vector::pop_back(&mut asset_ids);
        let sale_key = SaleNFTKey<CURRENCY> { asset_id };
        
        // Verify NFT exists in sale
        assert!(df::exists_(&sale.id, sale_key), E_INVALID_ASSET_ID);
        
        // Get and verify sale data
        let sale_data = df::borrow_mut<SaleNFTKey<CURRENCY>, SaleNFTData>(
            &mut sale.id,
            sale_key
        );
        
        // Verify NFT is not already reserved
        assert!(!sale_data.is_reserved, E_SALE_NOT_ACTIVE);
        
        // Mark as reserved
        sale_data.is_reserved = true;

        // Update sale state
        sale.nft_count = safe_sub(sale.nft_count, 1);

        // Remove asset ID from available assets
        remove_asset_id_from_vector(&mut sale.asset_ids, asset_id);

        // Record purchase for event emission
        vector::push_back(&mut purchased_ids, sale_data.listing_id);

        // Emit transfer event
        event::emit(TransferEvent {
            from: sale.creator,
            to: buyer,
            id: sale_data.listing_id,
            amount: 1,
            royalty: 0,
            asset_id
        });
    };

    // Transfer balance object to buyer
    transfer::public_transfer(buyer_balance, buyer);

    // Emit purchase event
    event::emit(NFTPurchased<CURRENCY> {
        sale_id: object::uid_to_inner(&sale.id),
        buyer,
        nft_ids: purchased_ids,
        amount_paid: total_cost
    });

    // Clean up vectors
    vector::destroy_empty(asset_ids);
    vector::destroy_empty(purchased_ids);
}


// Add more NFTs to an existing sale with enhanced debug events
public entry fun add_nfts_to_sale<CURRENCY>(
    sale: &mut NFTSale<CURRENCY>,
    mut nft_asset_ids: vector<u64>,  // Added 'mut' here
    collection_cap: &mut CollectionCap,
    mut sender_balances: vector<UserBalance>,
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);
    let sale_id = object::uid_to_inner(&sale.id);

    // Basic validations
    assert!(sender == sale.creator, E_NOT_CREATOR);
    assert!(sale.is_active, E_SALE_NOT_ACTIVE);
    
    let nft_amount = vector::length(&nft_asset_ids);
    assert!(nft_amount > 0 && nft_amount <= MAX_BATCH_SIZE, E_INVALID_BATCH_SIZE);

    // Verify new total won't exceed maximum supply
    let new_total_count = safe_add(sale.nft_count, nft_amount);
    assert!(new_total_count <= MAX_SUPPLY, E_MAX_SUPPLY_EXCEEDED);

    // Calculate total available balance
    let mut total_available = 0u64;
    let mut i = 0;
    let n = vector::length(&sender_balances);
    while (i < n) {
        let balance = vector::borrow(&sender_balances, i);
        total_available = safe_add(total_available, ART20::get_user_balance_amount(balance));
        i = i + 1;
    };

    // Verify sufficient total balance
    assert!(total_available >= nft_amount, E_INSUFFICIENT_BALANCE);

    // Verify collection matches
    assert!(ART20::get_collection_cap_id(collection_cap) == sale.collection_id, E_COLLECTION_MISMATCH);

    // Create vectors for tracking
    let mut token_ids = vector::empty<ID>();
    let mut amounts = vector::empty<u64>();

    // Process balances
    let mut remaining = nft_amount;
    let mut i = 0;
    while (i < vector::length(&sender_balances) && remaining > 0) {
        let balance = vector::borrow_mut(&mut sender_balances, i);
        let current_amount = ART20::get_user_balance_amount(balance);

        if (current_amount > 0) {
            if (current_amount <= remaining) {
                remaining = remaining - current_amount;
                ART20::set_user_balance_amount(balance, 0);
            } else {
                ART20::set_user_balance_amount(balance, current_amount - remaining);
                remaining = 0;
            };
        };
        i = i + 1;
    };

    // Process each asset ID
    while (!vector::is_empty(&nft_asset_ids)) {
        let asset_id = vector::pop_back(&mut nft_asset_ids);
        
        // Verify this asset ID isn't already in the sale
        let sale_key = SaleNFTKey<CURRENCY> { asset_id };
        assert!(!df::exists_(&sale.id, sale_key), E_INVALID_ASSET_ID);

        // Generate a unique listing ID
        let listing_id = object::new(ctx);
        let listing_id_inner = object::uid_to_inner(&listing_id);
        object::delete(listing_id);

        // Create and add sale data
        let sale_data = SaleNFTData {
            asset_id,
            is_reserved: false,
            listing_id: listing_id_inner,
            price: sale.price_per_nft
        };

        // Add to sale using dynamic fields
        df::add(&mut sale.id, sale_key, sale_data);
        vector::push_back(&mut sale.asset_ids, asset_id);

        // Track for events
        vector::push_back(&mut token_ids, listing_id_inner);
        vector::push_back(&mut amounts, 1);

        // Emit listing event
        event::emit(NFTListingEvent<CURRENCY> {
            sale_id,
            listing_id: listing_id_inner,
            asset_id,
            price: sale.price_per_nft
        });
    };

    // Return remaining balances to sender
    while (!vector::is_empty(&sender_balances)) {
        let balance = vector::pop_back(&mut sender_balances);
        if (ART20::get_user_balance_amount(&balance) > 0) {
            transfer::public_transfer(balance, sender);
        } else {
            ART20::cleanup_empty_balance(balance);
        };
    };

    // Clean up vectors
    vector::destroy_empty(nft_asset_ids);
    vector::destroy_empty(sender_balances);

    // Update sale nft count
    sale.nft_count = new_total_count;

    // Emit batch transfer event
    event::emit(BatchTransferEvent {
        from: sender,
        recipients: vector[sender],
        token_ids,
        amounts,
        collection_id: sale.collection_id,
        timestamp: tx_context::epoch(ctx)
    });

    // Emit sale update event
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
    collection_cap: &CollectionCap, // Added collection_cap for authorization checks
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);
    
    // Verify sender is creator and not denied
    assert!(sender == sale.creator, E_NOT_CREATOR);
    assert!(!ART20::is_denied(collection_cap, sender), E_ADDRESS_DENIED);
    
    let balance_value = balance::value(&sale.currency_balance);
    assert!(balance_value > 0, E_NO_CURRENCY_BALANCE);
    
    // Input validation
    let recipient_count = vector::length(&recipients);
    assert!(recipient_count > 0, E_EMPTY_RECIPIENTS);
    assert!(recipient_count == vector::length(&percentages), E_INVALID_PERCENTAGE);
    
    // Verify all recipients are not denied
    let mut i = 0;
    while (i < recipient_count) {
        let recipient = *vector::borrow(&recipients, i);
        assert!(!ART20::is_denied(collection_cap, recipient), E_ADDRESS_DENIED);
        i = i + 1;
    };
    
    // Validate percentages sum to 100
    let mut percentage_sum = 0u64;
    let mut i = 0;
    while (i < vector::length(&percentages)) {
        let percentage = *vector::borrow(&percentages, i);
        assert!(percentage > 0 && percentage <= 100, E_INVALID_PERCENTAGE);
        percentage_sum = safe_add(percentage_sum, percentage);
        i = i + 1;
    };
    assert!(percentage_sum == 100, E_PERCENTAGE_SUM_MISMATCH);
    
    event::emit(DebugEvent {
        message: string::utf8(b"Starting currency withdrawal"),
        token_id: object::uid_to_inner(&sale.id),
        sender,
        recipient: sender
    });
    
    // Track total withdrawn amount for verification
    let mut total_withdrawn = 0u64;
    
    // Process each recipient
    i = 0;
    while (i < recipient_count) {
        let recipient = *vector::borrow(&recipients, i);
        let percentage = *vector::borrow(&percentages, i);
        
        // Calculate amount for this recipient using safe math
        let recipient_amount = (balance_value * percentage) / 100;
        assert!(recipient_amount > 0, E_INVALID_PERCENTAGE);
        
        // Update total withdrawn
        total_withdrawn = safe_add(total_withdrawn, recipient_amount);
        assert!(total_withdrawn <= balance_value, E_OVERFLOW);
        
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
    
    // Verify all funds were distributed correctly
    assert!(balance::value(&sale.currency_balance) == balance_value - total_withdrawn, E_OVERFLOW);
    
    // Emit the main withdrawal event
    event::emit(CurrencyWithdrawn<CURRENCY> {
        sale_id: object::uid_to_inner(&sale.id),
        amount: total_withdrawn,
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
    mut asset_ids: vector<u64>,  // Added 'mut' here
    collection_cap: &mut CollectionCap,
    mut sender_balances: vector<UserBalance>,
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);

    // Verify sender is the creator of the sale
    assert!(sender == sale.creator, E_NOT_CREATOR);

    // Verify sale is active
    assert!(sale.is_active, E_SALE_NOT_ACTIVE);

    // Verify collection matches
    assert!(ART20::get_collection_cap_id(collection_cap) == sale.collection_id, E_COLLECTION_MISMATCH);

    let remove_amount = vector::length(&asset_ids);
    assert!(remove_amount > 0, E_INVALID_BATCH_SIZE);
    assert!(remove_amount <= MAX_BATCH_SIZE, E_MAX_BATCH_SIZE_EXCEEDED);
    assert!(remove_amount <= sale.nft_count, E_INVALID_BATCH_SIZE);

    // Track removed NFTs for event emission
    let mut removed_ids = vector::empty<ID>();
    let mut removed_amounts = vector::empty<u64>();

    // Process each asset ID removal
    while (!vector::is_empty(&asset_ids)) {
        let asset_id = vector::pop_back(&mut asset_ids);
        let sale_key = SaleNFTKey<CURRENCY> { asset_id };

        // Verify NFT exists in sale
        assert!(df::exists_(&sale.id, sale_key), E_INVALID_ASSET_ID);

        // Get and verify sale data
        let sale_data: &SaleNFTData = df::borrow(&sale.id, sale_key);
        assert!(!sale_data.is_reserved, E_SALE_NOT_ACTIVE);

        // Record removal for event emission
        vector::push_back(&mut removed_ids, sale_data.listing_id);
        vector::push_back(&mut removed_amounts, 1);

        // Remove NFT data from sale
        let sale_data = df::remove(&mut sale.id, sale_key);
        let SaleNFTData { asset_id: _, is_reserved: _, listing_id: _, price: _ } = sale_data;

        // Remove asset ID from available assets
        remove_asset_id_from_vector(&mut sale.asset_ids, asset_id);
    };

    // Create new balance for removed NFTs
    let new_balance = ART20::create_user_balance(
        sale.collection_id,
        remove_amount,
        ctx
    );

    // Update existing sender balances if needed
    let mut i = 0;
    while (i < vector::length(&sender_balances)) {
        let balance = vector::borrow_mut(&mut sender_balances, i);
        if (ART20::get_user_balance_collection_id(balance) == sale.collection_id) {
            // Adjust existing balance
            let current_amount = ART20::get_user_balance_amount(balance);
            if (current_amount == 0) {
                let removed_balance = vector::remove(&mut sender_balances, i);
                ART20::cleanup_empty_balance(removed_balance);
            };
        };
        i = i + 1;
    };

    // Update sale's NFT count
    sale.nft_count = safe_sub(sale.nft_count, remove_amount);

    // Transfer new balance to sender
    transfer::public_transfer(new_balance, sender);

    // Return remaining balances to sender
    while (!vector::is_empty(&sender_balances)) {
        let balance = vector::pop_back(&mut sender_balances);
        if (ART20::get_user_balance_amount(&balance) > 0) {
            transfer::public_transfer(balance, sender);
        } else {
            ART20::cleanup_empty_balance(balance);
        };
    };

    // Emit batch transfer event
    event::emit(BatchTransferEvent {
        from: sender,
        recipients: vector[sender],
        token_ids: removed_ids,
        amounts: removed_amounts,
        collection_id: sale.collection_id,
        timestamp: tx_context::epoch(ctx)
    });

    // Clean up vectors
    vector::destroy_empty(asset_ids);
    vector::destroy_empty(removed_ids);
    vector::destroy_empty(removed_amounts);
    vector::destroy_empty(sender_balances);
}



// Add close sale functionality
public entry fun close_sale<CURRENCY>(
    sale: &mut NFTSale<CURRENCY>,
    collection_cap: &CollectionCap,  // Added for authorization checks
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);
    
    // Verify sender is creator and not denied
    assert!(sender == sale.creator, E_NOT_CREATOR);
    assert!(!ART20::is_denied(collection_cap, sender), E_ADDRESS_DENIED);
    
    // Verify sale is active
    assert!(sale.is_active, E_SALE_NOT_ACTIVE);
    
    // Verify collection matches
    assert!(ART20::get_collection_cap_id(collection_cap) == sale.collection_id, E_COLLECTION_MISMATCH);
    
    // Debug event for operation start
    event::emit(DebugEvent {
        message: string::utf8(b"Closing sale"),
        token_id: object::uid_to_inner(&sale.id),
        sender,
        recipient: sender
    });
    
    // Set sale as inactive
    sale.is_active = false;
    
    // Emit status change event
    event::emit(SaleStatusChanged<CURRENCY> {
        sale_id: object::uid_to_inner(&sale.id),
        is_active: false,
        changed_by: sender,
        timestamp: tx_context::epoch(ctx)
    });
    
    // Debug event for operation completion
    event::emit(DebugEvent {
        message: string::utf8(b"Sale closed successfully"),
        token_id: object::uid_to_inner(&sale.id),
        sender,
        recipient: sender
    });
}

public entry fun reopen_sale<CURRENCY>(
    sale: &mut NFTSale<CURRENCY>,
    collection_cap: &CollectionCap,  // Added for authorization checks
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);
    
    // Verify sender is creator and not denied
    assert!(sender == sale.creator, E_NOT_CREATOR);
    assert!(!ART20::is_denied(collection_cap, sender), E_ADDRESS_DENIED);
    
    // Verify sale is not active
    assert!(!sale.is_active, E_SALE_ALREADY_ACTIVE);
    
    // Verify collection matches
    assert!(ART20::get_collection_cap_id(collection_cap) == sale.collection_id, E_COLLECTION_MISMATCH);
    
    // Debug event for operation start
    event::emit(DebugEvent {
        message: string::utf8(b"Reopening sale"),
        token_id: object::uid_to_inner(&sale.id),
        sender,
        recipient: sender
    });
    
    // Verify there are NFTs in the sale
    assert!(sale.nft_count > 0, E_NO_TOKENS_TO_BURN);
    
    // Set sale as active
    sale.is_active = true;
    
    // Emit status change event
    event::emit(SaleStatusChanged<CURRENCY> {
        sale_id: object::uid_to_inner(&sale.id),
        is_active: true,
        changed_by: sender,
        timestamp: tx_context::epoch(ctx)
    });
    
    // Debug event for operation completion
    event::emit(DebugEvent {
        message: string::utf8(b"Sale reopened successfully"),
        token_id: object::uid_to_inner(&sale.id),
        sender,
        recipient: sender
    });
}

// Function to update price
public entry fun update_sale_price<CURRENCY>(
    sale: &mut NFTSale<CURRENCY>,
    new_price: u64,
    collection_cap: &CollectionCap,
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);
    
    // Verify sender is creator and not denied
    assert!(sender == sale.creator, E_NOT_CREATOR);
    assert!(!ART20::is_denied(collection_cap, sender), E_ADDRESS_DENIED);
    
    // Verify sale is active
    assert!(sale.is_active, E_SALE_NOT_ACTIVE);
    
    // Verify collection matches
    assert!(ART20::get_collection_cap_id(collection_cap) == sale.collection_id, E_COLLECTION_MISMATCH);
    
    // Validate new price
    assert!(new_price > 0, E_INVALID_PRICE);
    assert!(new_price <= MAX_PRICE, E_MAX_PRICE_EXCEEDED);
    assert!(new_price != sale.price_per_nft, E_INVALID_PRICE); // Prevent unnecessary updates
    
    // Debug event for operation start
    event::emit(DebugEvent {
        message: string::utf8(b"Updating sale price"),
        token_id: object::uid_to_inner(&sale.id),
        sender,
        recipient: sender
    });
    
    // Store old price for event
    let old_price = sale.price_per_nft;
    
    // Update price
    sale.price_per_nft = new_price;
    
    // Emit detailed price update event
    event::emit(PriceUpdateEvent<CURRENCY> {
        sale_id: object::uid_to_inner(&sale.id),
        old_price,
        new_price,
        changed_by: sender,
        timestamp: tx_context::epoch(ctx),
        collection_id: sale.collection_id
    });
    
    // Also emit standard price updated event for backwards compatibility
    event::emit(PriceUpdated<CURRENCY> {
        sale_id: object::uid_to_inner(&sale.id),
        new_price
    });
    
    // Debug event for operation completion
    event::emit(DebugEvent {
        message: string::utf8(b"Sale price updated successfully"),
        token_id: object::uid_to_inner(&sale.id),
        sender,
        recipient: sender
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




public fun borrow_nft<CURRENCY>(
    sale: &NFTSale<CURRENCY>,
    asset_id: u64
): &SaleNFTData {
    let sale_key = SaleNFTKey<CURRENCY> { asset_id };
    assert!(df::exists_(&sale.id, sale_key), E_INVALID_ASSET_ID);
    df::borrow(&sale.id, sale_key)
}

// Helper function to borrow NFT mutably from sale
public fun borrow_nft_mut<CURRENCY>(
    sale: &mut NFTSale<CURRENCY>,
    asset_id: u64
): &mut SaleNFTData {
    let sale_key = SaleNFTKey<CURRENCY> { asset_id };
    assert!(df::exists_(&sale.id, sale_key), E_INVALID_ASSET_ID);
    df::borrow_mut(&mut sale.id, sale_key)
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
public fun get_nft_from_listing<CURRENCY>(
    listing: &NFTListing<CURRENCY>
): (ID, ID, u64, u64, address, String, String, Url) {
    (
        listing.listing_id,
        listing.sale_id,
        listing.asset_id,
        listing.price,
        listing.original_owner,
        listing.name,
        listing.description,
        listing.logo_uri
    )
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

fun remove_asset_id_from_vector(asset_ids: &mut vector<u64>, asset_id: u64) {
    let mut i = 0;
    let len = vector::length(asset_ids);
    let mut found = false;
    while (i < len) {
        if (*vector::borrow(asset_ids, i) == asset_id) {
            vector::swap_remove(asset_ids, i);
            found = true;
            break
        };
        i = i + 1;
    };
    // If asset_id was not found, raise an error
    assert!(found, ASSET_ID_NOT_FOUND);
}

public fun get_available_asset_ids<CURRENCY>(sale: &NFTSale<CURRENCY>): &vector<u64> {
    &sale.asset_ids
}


}