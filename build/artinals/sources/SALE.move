module artinals::SALE {
    use artinals::ART20;
    use sui::event;
    use std::string::{Self, String};
    use sui::dynamic_field as df;  
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};

    // Import types from ART20 module
    use artinals::ART20::{NFT, CollectionCap, UserBalance, AdminCap};


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
    const E_BALANCE_CREATION_FAILED: u64 = 27;
    const E_BALANCE_TRANSFER_FAILED: u64 = 28;
    const E_NOT_ADMIN: u64 = 29;
    const E_NO_TOKENS_TO_SELL: u64 = 30;
    

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
    nft_count: u64,  // Track number of NFTs instead of storing them directly
    asset_ids: vector<u64>,
    creator_name: String,
    sale_title: String,
    width_cm: Option<u64>,     // Optional
    height_cm: Option<u64>,    // Optional
    creation_year: Option<u64>, // Optional
    medium: Option<String>,     // Optional
    provenance: Option<String>, // Optional
    authenticity: Option<String>, // Optional
    signature: Option<String>,  // Optional
    about_sale: String,
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


public entry fun verify_upgrade(
        admin_cap: &AdminCap,
        ctx: &mut TxContext
    ) {
        assert!(ART20::verify_admin(admin_cap, tx_context::sender(ctx)), E_NOT_ADMIN);
       
    }


    

// NFT Sale functions
public entry fun create_nft_sale<CURRENCY>(
    mut nfts: vector<NFT>,
    nft_amount: u64,
    price_per_nft: u64,
    creator_name: vector<u8>,
    sale_title: vector<u8>,
    width_cm: Option<u64>,
    height_cm: Option<u64>,
    creation_year: Option<u64>,
    medium: Option<vector<u8>>,
    provenance: Option<vector<u8>>,
    authenticity: Option<vector<u8>>,
    signature: Option<vector<u8>>,
    about_sale: vector<u8>,
    collection_cap: &mut CollectionCap,
    mut sender_balances: vector<UserBalance>,
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);

    // Price validation
    assert!(price_per_nft <= MAX_PRICE, E_MAX_PRICE_EXCEEDED);
    assert!(price_per_nft > 0, E_INVALID_PRICE);
    assert!(nft_amount <= MAX_BATCH_SIZE, E_MAX_BATCH_SIZE_EXCEEDED);

    let nft_length = vector::length(&nfts);
    assert!(nft_length >= nft_amount, E_NO_TOKENS_TO_SELL);

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

    // Get collection verification using ART20 getters
    let first_nft = vector::borrow(&nfts, 0);
    let collection_id = ART20::get_nft_collection_id(first_nft);

    // Verify collection matches
    assert!(ART20::get_collection_cap_id(collection_cap) == collection_id, E_COLLECTION_MISMATCH);

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
        creator_name: string::utf8(creator_name),
        sale_title: string::utf8(sale_title),
        width_cm: width_cm,
        height_cm: height_cm,
        creation_year: creation_year,
        medium: if (option::is_some(&medium)) { 
            option::some(string::utf8(option::destroy_some(medium))) 
        } else { 
            option::none() 
        },
        provenance: if (option::is_some(&provenance)) { 
            option::some(string::utf8(option::destroy_some(provenance))) 
        } else { 
            option::none() 
        },
        authenticity: if (option::is_some(&authenticity)) { 
            option::some(string::utf8(option::destroy_some(authenticity))) 
        } else { 
            option::none() 
        },
        signature: if (option::is_some(&signature)) { 
            option::some(string::utf8(option::destroy_some(signature))) 
        } else { 
            option::none() 
        },
        about_sale: string::utf8(about_sale),
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
                // Use entire balance
                remaining_amount = remaining_amount - current_balance;
                ART20::set_user_balance_amount(balance, 0);
            } else {
                // Split balance
                ART20::set_user_balance_amount(balance, current_balance - remaining_amount);
                remaining_amount = 0;
            };
        };
        i = i + 1;
    };

    // Process NFTs
    let mut i = 0;
    while (i < nft_amount) {
        let nft = vector::pop_back(&mut nfts);
        let asset_id = ART20::get_nft_asset_id(&nft);

        df::add(&mut sale.id, NFTFieldKey<CURRENCY> { asset_id }, nft);
        vector::push_back(&mut sale.asset_ids, asset_id);

        event::emit(NFTListingEvent<CURRENCY> {
            sale_id,
            listing_id: sale_id,
            asset_id,
            price: price_per_nft
        });

        i = i + 1;
    };
    
    // Return remaining balances and clean up empty ones
    while (!vector::is_empty(&sender_balances)) {
        let balance = vector::pop_back(&mut sender_balances);
        if (ART20::get_user_balance_amount(&balance) > 0) {
            transfer::public_transfer(balance, sender);
        } else {
            ART20::cleanup_empty_balance(balance);
        };
    };
    
    // Return remaining NFTs
    while (!vector::is_empty(&nfts)) {
        let nft = vector::pop_back(&mut nfts);
        transfer::public_transfer(nft, sender);
    };
    
    // Clean up vectors
    vector::destroy_empty(nfts);
    vector::destroy_empty(sender_balances);
    
    event::emit(SaleCreated<CURRENCY> {
        sale_id,
        creator: sender,
        nft_count: nft_amount,
        price_per_nft,
        collection_id
    });
    
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

    // Validate sale state
    assert!(sale.is_active, E_SALE_NOT_ACTIVE);
    assert!(!ART20::is_denied(collection_cap, buyer), E_ADDRESS_DENIED);

    let purchase_count = vector::length(&asset_ids);
    assert!(purchase_count > 0 && purchase_count <= MAX_BATCH_SIZE, E_INVALID_BATCH_SIZE);

    let total_cost = safe_mul(sale.price_per_nft, purchase_count);
    let payment_amount = coin::value(&payment);
    assert!(payment_amount >= total_cost, E_INSUFFICIENT_BALANCE);

    // Validate asset IDs and ensure they exist in the sale
    let mut i = 0;
    while (i < purchase_count) {
        let asset_id = *vector::borrow(&asset_ids, i);
        assert!(vector::contains(&sale.asset_ids, &asset_id), E_INVALID_ASSET_ID);
        assert!(df::exists_(&sale.id, NFTFieldKey<CURRENCY> { asset_id }), E_INVALID_ASSET_ID);
        i = i + 1;
    };

    // Process payment
    let mut payment_mut = payment;
    let paid = coin::split(&mut payment_mut, total_cost, ctx);
    balance::join(&mut sale.currency_balance, coin::into_balance(paid));

    if (coin::value(&payment_mut) > 0) {
        transfer::public_transfer(payment_mut, buyer);
    } else {
        coin::destroy_zero(payment_mut);
    };

    // Create and transfer UserBalance - NEW ADDITION
    let buyer_balance = ART20::create_user_balance(
        sale.collection_id,
        purchase_count,
        ctx
    );
    assert!(ART20::get_user_balance_amount(&buyer_balance) == purchase_count, E_BALANCE_CREATION_FAILED);

    assert!(ART20::get_user_balance_collection_id(&buyer_balance) == sale.collection_id, E_BALANCE_TRANSFER_FAILED);
    
    // Transfer the balance object to buyer
    transfer::public_transfer(buyer_balance, buyer);

    // Transfer NFTs to buyer and remove them from sale
    while (!vector::is_empty(&asset_ids)) {
        let asset_id = vector::pop_back(&mut asset_ids);
        assert!(df::exists_(&sale.id, NFTFieldKey<CURRENCY> { asset_id }), E_INVALID_ASSET_ID);

        // Remove the NFT from the dynamic field
        let nft = df::remove(&mut sale.id, NFTFieldKey<CURRENCY> { asset_id });
        let nft_id = ART20::get_nft_id(&nft);

        // Transfer NFT directly to the buyer
        transfer::public_transfer(nft, buyer);

        // Remove the asset ID from sale.asset_ids using `vector::swap_remove`
        let mut found = false;
        let mut idx = 0;
        while (idx < vector::length(&sale.asset_ids)) {
            if (*vector::borrow(&sale.asset_ids, idx) == asset_id) {
                vector::swap_remove(&mut sale.asset_ids, idx);
                found = true;
                break
            };
            idx = idx + 1;
        };

        // Ensure the asset ID was found and removed
        assert!(found, ASSET_ID_NOT_FOUND);

        // Emit transfer event for the NFT
        event::emit(TransferEvent {
            from: sale.creator,
            to: buyer,
            id: nft_id,
            amount: 1,
            royalty: 0,
            asset_id
        });

        // Update the sale's NFT count
        sale.nft_count = safe_sub(sale.nft_count, 1);
    };

    // Emit purchase event
    event::emit(NFTPurchased<CURRENCY> {
        sale_id: object::uid_to_inner(&sale.id),
        buyer,
        nft_ids: vector::empty<ID>(),
        amount_paid: total_cost
    });
}


// Add more NFTs to an existing sale with enhanced debug events
public entry fun add_nfts_to_sale<CURRENCY>(
    sale: &mut NFTSale<CURRENCY>,
    mut nfts: vector<NFT>,
    asset_ids: vector<u64>,  // Added to specify which NFTs to add
    collection_cap: &mut CollectionCap,
    mut sender_balances: vector<UserBalance>,
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);
    let sale_id = object::uid_to_inner(&sale.id);

    assert!(sender == sale.creator, E_NOT_CREATOR);
    assert!(sale.is_active, E_SALE_NOT_ACTIVE);

    let nft_amount = vector::length(&asset_ids);
    let nft_length = vector::length(&nfts);

    assert!(nft_length >= nft_amount, E_NO_TOKENS_TO_BURN);
    assert!(nft_amount <= MAX_BATCH_SIZE, E_MAX_BATCH_SIZE_EXCEEDED);

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

    let first_nft = vector::borrow(&nfts, 0);
    assert!(ART20::get_nft_collection_id(first_nft) == sale.collection_id, E_COLLECTION_MISMATCH);

    // Verify collection matches
    assert!(ART20::get_collection_cap_id(collection_cap) == sale.collection_id, E_COLLECTION_MISMATCH);

    // Create vectors for tracking
    let mut token_ids = vector::empty<ID>();
    let mut amounts = vector::empty<u64>();

    // Process NFTs and update balances
    let mut remaining = nft_amount;
    let mut j = 0;
    while (j < vector::length(&sender_balances) && remaining > 0) {
        let balance = vector::borrow_mut(&mut sender_balances, j);
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
        j = j + 1;
    };

    // Process each NFT according to asset_ids
    let mut i = 0;
    while (i < nft_amount) {
        let nft = vector::pop_back(&mut nfts);

        // Verify NFT belongs to collection
        assert!(ART20::get_nft_collection_id(&nft) == sale.collection_id, E_COLLECTION_MISMATCH);

        // Get NFT ID for tracking
        let nft_id = ART20::get_nft_id(&nft);
        vector::push_back(&mut token_ids, nft_id);
        vector::push_back(&mut amounts, 1);

        // Add NFT to sale
        let asset_id = ART20::get_nft_asset_id(&nft);
        df::add(&mut sale.id, NFTFieldKey<CURRENCY> { asset_id }, nft);
        vector::push_back(&mut sale.asset_ids, asset_id);

        event::emit(NFTListingEvent<CURRENCY> {
            sale_id,
            listing_id: sale_id,
            asset_id: asset_id,
            price: sale.price_per_nft
        });

        i = i + 1;
    };

    // Return remaining NFTs
    while (!vector::is_empty(&nfts)) {
        let nft = vector::pop_back(&mut nfts);
        transfer::public_transfer(nft, sender);
    };

    // Return remaining balances to sender
    while (!vector::is_empty(&sender_balances)) {
        let balance = vector::pop_back(&mut sender_balances);
        transfer::public_transfer(balance, sender);
    };

    // Clean up vectors
    vector::destroy_empty(nfts);
    vector::destroy_empty(sender_balances);

    // Update sale nft count
    sale.nft_count = safe_add(sale.nft_count, nft_amount);

    // Emit batch transfer event
    event::emit(BatchTransferEvent {
        from: sender,
        recipients: vector[sender],  // Changed to use sender instead of sale address
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
    asset_ids: vector<u64>, // Asset IDs to remove
    collection_cap: &mut CollectionCap, // Collection verification
    mut sender_balances: vector<UserBalance>, // Balances to adjust
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);

    // Verify sender is the creator of the sale
    assert!(sender == sale.creator, E_NOT_CREATOR);

    // Verify sale is active
    assert!(sale.is_active, E_SALE_NOT_ACTIVE);

    // Validate collection matches
    assert!(ART20::get_collection_cap_id(collection_cap) == sale.collection_id, E_COLLECTION_MISMATCH);

    // Number of NFTs to remove
    let remove_amount = vector::length(&asset_ids);
    assert!(remove_amount > 0, E_INVALID_BATCH_SIZE);
    assert!(remove_amount <= MAX_BATCH_SIZE, E_MAX_BATCH_SIZE_EXCEEDED);
    assert!(remove_amount <= sale.nft_count, E_INVALID_BATCH_SIZE);

    // Debug: Starting the removal process
    event::emit(DebugEvent {
        message: string::utf8(b"Starting remove_nfts_from_sale"),
        token_id: object::uid_to_inner(&sale.id),
        sender,
        recipient: sender
    });

    let mut i = 0;
    while (i < remove_amount) {
        let asset_id = *vector::borrow(&asset_ids, i);

        // Debug: Log asset ID being processed
        event::emit(DebugEvent {
            message: string::utf8(b"Processing asset ID"),
            token_id: object::uid_to_inner(&sale.id),
            sender,
            recipient: sender
        });

        // Verify asset ID exists in sale.asset_ids
        if (!vector::contains(&sale.asset_ids, &asset_id)) {
            event::emit(DebugEvent {
                message: string::utf8(b"Asset ID not found in sale.asset_ids"),
                token_id: object::uid_to_inner(&sale.id),
                sender,
                recipient: sender
            });
        };
        assert!(vector::contains(&sale.asset_ids, &asset_id), E_INVALID_ASSET_ID);

        // Verify asset ID exists in dynamic fields
        if (!df::exists_(&sale.id, NFTFieldKey<CURRENCY> { asset_id })) {
            event::emit(DebugEvent {
                message: string::utf8(b"Asset ID not found in dynamic fields"),
                token_id: object::uid_to_inner(&sale.id),
                sender,
                recipient: sender
            });
        };
        assert!(df::exists_(&sale.id, NFTFieldKey<CURRENCY> { asset_id }), E_INVALID_ASSET_ID);

        // Remove asset ID from dynamic fields
        let nft: NFT = df::remove(&mut sale.id, NFTFieldKey<CURRENCY> { asset_id });

        // Remove asset ID from sale.asset_ids vector
        remove_asset_id_from_vector(&mut sale.asset_ids, asset_id);

        // Transfer NFT back to sender
        transfer::public_transfer(nft, sender);

        i = i + 1;
    };

    // Adjust sender balances
    let mut remaining_amount = remove_amount;
    let mut j = 0;
    while (j < vector::length(&sender_balances) && remaining_amount > 0) {
        let balance = vector::borrow_mut(&mut sender_balances, j);
        let current_amount = ART20::get_user_balance_amount(balance);

        if (current_amount < remaining_amount) {
            ART20::set_user_balance_amount(balance, 0);
            remaining_amount = safe_sub(remaining_amount, current_amount);
        } else {
            ART20::set_user_balance_amount(balance, safe_sub(current_amount, remaining_amount));
            remaining_amount = 0;
        };

        j = j + 1;
    };

    // Create a new balance if remaining_amount > 0
    if (remaining_amount > 0) {
        let new_balance = ART20::create_user_balance(
            sale.collection_id,
            remaining_amount,
            ctx
        );
        transfer::public_transfer(new_balance, sender);
    };

    // Explicitly return all sender balances
    while (!vector::is_empty(&sender_balances)) {
        let balance = vector::pop_back(&mut sender_balances);
        transfer::public_transfer(balance, sender);
    };

    // Update sale's NFT count
    sale.nft_count = safe_sub(sale.nft_count, remove_amount);

    // Emit event for the batch transfer
    event::emit(BatchTransferEvent {
        from: sender,
        recipients: vector[sender],
        token_ids: vector::empty(), // Adjust as needed for actual token IDs
        amounts: vector::empty(), // Adjust as needed
        collection_id: sale.collection_id,
        timestamp: tx_context::epoch(ctx)
    });

    // Debug: Successfully removed NFTs
    event::emit(DebugEvent {
        message: string::utf8(b"Successfully removed NFTs from sale"),
        token_id: object::uid_to_inner(&sale.id),
        sender,
        recipient: sender
    });

    // Explicitly destroy the now-empty sender_balances vector
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

public fun get_creator_name<CURRENCY>(sale: &NFTSale<CURRENCY>): String {
    sale.creator_name
}

public fun get_sale_title<CURRENCY>(sale: &NFTSale<CURRENCY>): String {
    sale.sale_title
}

public fun get_dimensions<CURRENCY>(sale: &NFTSale<CURRENCY>): (Option<u64>, Option<u64>) {
    (sale.width_cm, sale.height_cm)
}

public fun get_creation_year<CURRENCY>(sale: &NFTSale<CURRENCY>): Option<u64> {
    sale.creation_year
}

public fun get_price_per_nft<CURRENCY>(sale: &NFTSale<CURRENCY>): u64 {
    sale.price_per_nft
}

public fun get_medium<CURRENCY>(sale: &NFTSale<CURRENCY>): Option<String> {
    sale.medium
}

public fun get_provenance<CURRENCY>(sale: &NFTSale<CURRENCY>): Option<String> {
    sale.provenance
}

public fun get_authenticity<CURRENCY>(sale: &NFTSale<CURRENCY>): Option<String> {
    sale.authenticity
}

public fun get_signature<CURRENCY>(sale: &NFTSale<CURRENCY>): Option<String> {
    sale.signature
}
public fun get_about_sale<CURRENCY>(sale: &NFTSale<CURRENCY>): String {
    sale.about_sale
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