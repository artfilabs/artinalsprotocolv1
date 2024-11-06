module artinals::ARTINALS {
    use sui::url::{Self, Url};
    use sui::event;
    use std::string::{Self, String};
    use sui::dynamic_field as df;  
    use sui::package;
    use sui::display;
    use sui::table::{Self, Table};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    
    

    //Errors
    const E_MISMATCH_TOKENS_AND_URIS: u64 = 1;
    const E_NOT_CREATOR: u64 = 2;
    const E_TOKEN_NOT_MUTABLE: u64 = 3;
    const E_METADATA_FROZEN: u64 = 4;
    const E_NOT_OWNER: u64 = 5;
    const E_NO_TOKENS_TO_BURN: u64 = 6;
    const E_INVALID_PRICE: u64 = 7;
    const E_COLLECTION_MISMATCH: u64 = 8;
    const E_INSUFFICIENT_BALANCE: u64 = 9;
    const E_SALE_NOT_ACTIVE: u64 = 10;
    const E_SALE_ALREADY_ACTIVE: u64 = 11;
    const E_ADDRESS_DENIED: u64 = 12;
    const E_INVALID_DENY_LIST_AUTHORITY: u64 = 13;
    const E_DENY_LIST_ALREADY_EXISTS: u64 = 14;
    const E_INVALID_LENGTH: u64 = 15;
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



    // Define the token structure
  public struct NFT has key, store {
    id: UID,
    artinals_id: u64,
    creator: address,
    name: String,
    description: String,
    uri: Url,
    logo_uri: Url,
    asset_id: u64,
    max_supply: u64,
    is_mutable: bool,
    metadata_frozen: bool,
    collection_id: ID,
}




    // One-Time-Witness for the module
    public struct ARTINALS has drop {}

    public struct DenyListStatusEvent has copy, drop {
    collection_id: ID,
    address: address,
    is_denied: bool,
}


    public struct DenyListAuthorityRevokedEvent has copy, drop {
    collection_id: ID,
}

    // Define events for transfers, approvals, etc.
    public struct TransferEvent has copy, drop {
        from: address,
        to: address,
        id: ID,
        amount: u64,
        royalty: u64,
        asset_id: u64, // Unique asset ID within the collection
    }

    public struct PriceUpdated<phantom CURRENCY> has copy, drop {
    sale_id: ID,
    new_price: u64
}

    public struct CollectionCap has key, store {
    id: UID,
    max_supply: u64,
    current_supply: u64,
    creator: address,
    name: String,
    description: String,
    uri: Url,
    logo_uri: Url,
    is_mutable: bool,
    has_deny_list_authority: bool,
}

public struct UserBalance has key, store {
    id: UID,
    collection_id: ID,
    balance: u64
}


public fun create_deny_list(ctx: &mut TxContext): Table<address, bool> {
    table::new<address, bool>(ctx)
}


public struct TokenIdCounter has key {
        id: UID,
        last_id: u64,
    }


public struct DenyListKey has copy, drop, store {}

// Add a new event for deny list status changes
public struct DenyListStatusChanged has copy, drop {
    collection_id: ID,
    address: address,
    is_denied: bool,
    changed_by: address
}

public struct NFTMintedEvent has copy, drop {
    id: ID,
    artinals_id: u64,
    creator: address,
    name: String,
    asset_id: u64,
}



    // Define event for burning NFTs
    public struct BurnEvent has copy, drop {
        owner: address,
        id: ID,
        amount: u64,
    }

    public struct MetadataUpdateEvent has copy, drop {
    id: ID,
    new_name: String,
    new_description: String,
}

public struct MutabilityChangeEvent has copy, drop {
    id: ID,
    is_mutable: bool,
}


public struct MetadataFrozenEvent has copy, drop {
    id: ID,
}


public struct LogoURIUpdateEvent has copy, drop {
    id: ID,
    artinals_id: u64,
    new_logo_uri: Url, // Change to Url type
}


public struct DebugEvent has copy, drop {
    message: String,
    token_id: ID,
    sender: address,
    recipient: address,
}

public struct BatchTransferEvent has copy, drop {
    from: address,
    recipients: vector<address>,
    token_ids: vector<ID>,
    amounts: vector<u64>,
    collection_id: ID,
    timestamp: u64
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

    

// Initialize the TokenIdCounter
    fun init(witness: ARTINALS, ctx: &mut TxContext) {
        let publisher = package::claim(witness, ctx);
    
        let keys = vector[
            string::utf8(b"name"),
            string::utf8(b"description"),
            string::utf8(b"image_url"),
            string::utf8(b"creator"),
            string::utf8(b"project_url"),
        ];
        let values = vector[
            string::utf8(b"{name}"),
            string::utf8(b"{description}"),
            string::utf8(b"{logo_uri}"),
            string::utf8(b"{creator}"),
            string::utf8(b"{uri}"),
        ];
        let mut display = display::new_with_fields<NFT>(
            &publisher, keys, values, ctx
        );
        display::update_version(&mut display);

        transfer::public_transfer(publisher, tx_context::sender(ctx));
        transfer::public_transfer(display, tx_context::sender(ctx));

        let counter = TokenIdCounter {
            id: object::new(ctx),
            last_id: 0,
        };
        transfer::share_object(counter);
    }

    public fun initialize_deny_list(
    collection_cap: &mut CollectionCap,
    ctx: &mut TxContext
) {
    assert!(tx_context::sender(ctx) == collection_cap.creator, E_NOT_CREATOR);
    assert!(collection_cap.has_deny_list_authority, E_INVALID_DENY_LIST_AUTHORITY);
    assert!(!has_deny_list(collection_cap), E_DENY_LIST_ALREADY_EXISTS);
    
    df::add(
        &mut collection_cap.id,
        DenyListKey {},
        table::new<address, bool>(ctx)
    );
}


   public entry fun mint_token(
    name: vector<u8>, 
    description: vector<u8>, 
    initial_supply: u64,
    max_supply: u64,
    uri: vector<u8>, 
    logo_uri: vector<u8>, 
    is_mutable: bool, 
    has_deny_list_authority: bool, 
    counter: &mut TokenIdCounter,
    ctx: &mut TxContext
) {

    // Add maximum supply check
    assert!(max_supply <= MAX_SUPPLY, E_MAX_SUPPLY_EXCEEDED);
    assert!(initial_supply <= MAX_SUPPLY, E_MAX_SUPPLY_EXCEEDED);
    
    // Safe arithmetic for supplies
    assert!(initial_supply > 0, 1);
    assert!(max_supply == 0 || initial_supply <= max_supply, 2);
    
    // Check counter overflow
    assert!(counter.last_id <= MAX_U64 - initial_supply, E_OVERFLOW);

    assert!(initial_supply > 0, 1);
    assert!(max_supply == 0 || initial_supply <= max_supply, 2);

    counter.last_id = safe_add(counter.last_id, 1);


    let mut collection_cap = CollectionCap {
        id: object::new(ctx),
        max_supply,
        current_supply: initial_supply,
        creator: tx_context::sender(ctx),
        name: string::utf8(name),
        description: string::utf8(description),
        uri: url::new_unsafe_from_bytes(uri),
        logo_uri: url::new_unsafe_from_bytes(logo_uri),
        is_mutable,
        has_deny_list_authority,
    };

    // Initialize deny list as dynamic field with mutable collection_cap
    df::add(
        &mut collection_cap.id, 
        DenyListKey {}, // Remove dummy_field
        create_deny_list(ctx)
    );

    let collection_id = object::uid_to_inner(&collection_cap.id);

    let user_balance = UserBalance {
        id: object::new(ctx),
        collection_id,
        balance: initial_supply
    };

    let mut i = 0;
    while (i < initial_supply) {
        counter.last_id = counter.last_id + 1;
        let artinals_id = counter.last_id;

        let token = NFT {
            id: object::new(ctx),
            artinals_id,
            creator: tx_context::sender(ctx),
            name: string::utf8(name),
            description: string::utf8(description),
            uri: url::new_unsafe_from_bytes(uri),
            logo_uri: url::new_unsafe_from_bytes(logo_uri),
            asset_id: i + 1,
            max_supply,
            is_mutable,
            metadata_frozen: false,
            collection_id,
        };

        event::emit(NFTMintedEvent {
            id: object::uid_to_inner(&token.id),
            artinals_id: token.artinals_id,
            creator: token.creator,
            name: token.name,
            asset_id: token.asset_id,
        });

        event::emit(TransferEvent {
            from: tx_context::sender(ctx),
            to: tx_context::sender(ctx),
            id: object::uid_to_inner(&token.id),
            amount: 1,
            royalty: 0,
            asset_id: token.asset_id,
        });

        transfer::transfer(token, tx_context::sender(ctx));
        i = i + 1;
    };

    transfer::transfer(collection_cap, tx_context::sender(ctx));
    transfer::transfer(user_balance, tx_context::sender(ctx));
}


    // New function to mint additional tokens (only for mintable NFTs)
   public entry fun mint_additional(
    collection_cap: &mut CollectionCap,
    amount: u64,
    counter: &mut TokenIdCounter,
    user_balance: &mut UserBalance,
    ctx: &mut TxContext
) {
    assert!(tx_context::sender(ctx) == collection_cap.creator, 1);
    assert!(collection_cap.max_supply == 0 || collection_cap.current_supply + amount <= collection_cap.max_supply, 2);
    assert!(user_balance.collection_id == object::uid_to_inner(&collection_cap.id), 0);
    
    user_balance.balance = user_balance.balance + amount;
    let collection_id = object::uid_to_inner(&collection_cap.id);

    let mut i = 0;
    while (i < amount) {
        counter.last_id = counter.last_id + 1;
        let artinals_id = counter.last_id;

        let token = NFT {
            id: object::new(ctx),
            artinals_id,
            creator: collection_cap.creator,
            name: collection_cap.name,
            description: collection_cap.description,
            uri: collection_cap.uri,
            logo_uri: collection_cap.logo_uri,
            asset_id: collection_cap.current_supply + i + 1,
            max_supply: collection_cap.max_supply,
            is_mutable: collection_cap.is_mutable,
            metadata_frozen: false,
            collection_id,
        };

        event::emit(TransferEvent {
            from: tx_context::sender(ctx),
            to: tx_context::sender(ctx),
            id: object::uid_to_inner(&token.id),
            amount: 1,
            royalty: 0,
            asset_id: token.asset_id,
        });

        event::emit(NFTMintedEvent {
            id: object::uid_to_inner(&token.id),
            artinals_id: token.artinals_id,
            creator: token.creator,
            name: token.name,
            asset_id: token.asset_id,
        });

        transfer::transfer(token, tx_context::sender(ctx));
        i = i + 1;
    };

    collection_cap.current_supply = collection_cap.current_supply + amount;
}


//  drop_collection_cap function
public fun drop_collection_cap(collection_cap: CollectionCap) {
    let CollectionCap {
        mut id,  // Declare id as mutable here
        max_supply: _,
        current_supply: _,
        creator: _,
        name: _,
        description: _,
        uri: _,
        logo_uri: _,
        is_mutable: _,
        has_deny_list_authority: _,
    } = collection_cap;

    // Check and remove deny list if it exists
    if (df::exists_(&id, DenyListKey {})) {
        let deny_list = df::remove<DenyListKey, Table<address, bool>>(
            &mut id,  // Now we can mutably borrow id
            DenyListKey {}
        );
        table::drop(deny_list);
    };
    
    object::delete(id);
}


public fun update_metadata(
    token: &mut NFT,
    new_name: String,
    new_description: String,
    new_uri: vector<u8>,  // Change this to vector<u8>
    new_logo_uri: vector<u8>, // Change this to vector<u8>
    ctx: &mut TxContext
) {
    // Size limits for metadata
    assert!(string::length(&new_name) <= 128, E_INVALID_LENGTH);
    assert!(string::length(&new_description) <= 1000, E_INVALID_LENGTH);
    assert!(vector::length(&new_uri) <= 256, E_INVALID_LENGTH);
    assert!(vector::length(&new_logo_uri) <= 256, E_INVALID_LENGTH);

    assert!(token.is_mutable, 1); // Error if token is not mutable
    assert!(!token.metadata_frozen, 2); // Error if metadata is frozen
    assert!(tx_context::sender(ctx) == token.creator, 3); // Only creator can update

    token.name = new_name;
    token.description = new_description;
    token.uri = url::new_unsafe_from_bytes(new_uri); // Convert to Url
    token.logo_uri = url::new_unsafe_from_bytes(new_logo_uri); // Convert to Url

    // Emit an event for metadata update
    event::emit(MetadataUpdateEvent {
        id: object::uid_to_inner(&token.id),
        new_name: new_name,
        new_description: new_description,
    });
}

// New function to update Logo URI of a specific token
    public fun update_token_logo_uri(
    token: &mut NFT,
    new_logo_uri: vector<u8>, // Change this to vector<u8>
    ctx: &mut TxContext
) {
    assert!(tx_context::sender(ctx) == token.creator, 1); // Only creator can update
    assert!(token.is_mutable, 2); // Token must be mutable
    assert!(!token.metadata_frozen, 3); // Metadata must not be frozen

    token.logo_uri = url::new_unsafe_from_bytes(new_logo_uri); // Convert to Url

    event::emit(LogoURIUpdateEvent {
        id: object::uid_to_inner(&token.id),
        artinals_id: token.artinals_id,
        new_logo_uri: token.logo_uri,
    });
}


public fun toggle_mutability(token: &mut NFT, ctx: &mut TxContext) {
    assert!(tx_context::sender(ctx) == token.creator, 1); // Only creator can toggle
    token.is_mutable = !token.is_mutable;

    // Optionally, emit an event for mutability change
    event::emit(MutabilityChangeEvent {
        id: object::uid_to_inner(&token.id),
        is_mutable: token.is_mutable,
    });
}


public fun freeze_metadata(token: &mut NFT, ctx: &mut TxContext) {
    assert!(tx_context::sender(ctx) == token.creator, 1); // Only creator can freeze
    assert!(!token.metadata_frozen, 2); // Cannot freeze if already frozen
    token.metadata_frozen = true;
    token.is_mutable = false; // Once frozen, metadata is immutable

    event::emit(MetadataFrozenEvent {
        id: object::uid_to_inner(&token.id),
    });
}


// Update add_to_deny_list function to check collection authority
public entry fun add_to_deny_list(
    collection_cap: &mut CollectionCap,
    addr: address,
    ctx: &mut TxContext
) {
    assert!(tx_context::sender(ctx) == collection_cap.creator, E_NOT_CREATOR);
    assert!(collection_cap.has_deny_list_authority, E_INVALID_DENY_LIST_AUTHORITY);
    
    let deny_list = df::borrow_mut<DenyListKey, Table<address, bool>>(
        &mut collection_cap.id,
        DenyListKey {}  // Updated to use new DenyListKey
    );
    
    table::add(deny_list, addr, true);

    event::emit(DenyListStatusChanged {
        collection_id: object::uid_to_inner(&collection_cap.id),
        address: addr,
        is_denied: true,
        changed_by: tx_context::sender(ctx)
    });
}

public fun has_deny_list_authority(collection_cap: &CollectionCap): bool {
    collection_cap.has_deny_list_authority
}


public fun is_denied(collection_cap: &CollectionCap, addr: address): bool {
    if (!has_deny_list(collection_cap)) {
        return false
    };
    
    let deny_list = df::borrow<DenyListKey, Table<address, bool>>(
        &collection_cap.id,
        DenyListKey {}  // Updated to use new DenyListKey
    );
    
    table::contains(deny_list, addr)
}

public entry fun remove_from_deny_list(
    collection_cap: &mut CollectionCap,
    addr: address,
    ctx: &mut TxContext
) {
    assert!(tx_context::sender(ctx) == collection_cap.creator, E_NOT_CREATOR);
    assert!(collection_cap.has_deny_list_authority, E_INVALID_DENY_LIST_AUTHORITY);
    
    let deny_list = df::borrow_mut<DenyListKey, Table<address, bool>>(
        &mut collection_cap.id,
        DenyListKey {}  // Updated to use new DenyListKey
    );
    
    table::remove(deny_list, addr);

    event::emit(DenyListStatusChanged {
        collection_id: object::uid_to_inner(&collection_cap.id),
        address: addr,
        is_denied: false,
        changed_by: tx_context::sender(ctx)
    });
}

public fun has_deny_list(collection_cap: &CollectionCap): bool {
    df::exists_(&collection_cap.id, DenyListKey {})  // Updated to use new DenyListKey
}

public fun deny_list_size(collection_cap: &CollectionCap): u64 {
    let deny_list = df::borrow<DenyListKey, Table<address, bool>>(
        &collection_cap.id,
        DenyListKey {}  // Updated to use new DenyListKey without dummy_field
    );
    table::length(deny_list)
}


// Add this helper function
public fun check_deny_list_restrictions(
    collection_cap: &CollectionCap,
    addr: address
) {
    assert!(!is_denied(collection_cap, addr), E_ADDRESS_DENIED);
}

public fun revoke_deny_list_authority(
    collection_cap: &mut CollectionCap,
    ctx: &mut TxContext
) {
    assert!(tx_context::sender(ctx) == collection_cap.creator, 1);
    assert!(collection_cap.has_deny_list_authority, 2);
    collection_cap.has_deny_list_authority = false;

    event::emit(DenyListAuthorityRevokedEvent {
        collection_id: object::uid_to_inner(&collection_cap.id),
    });
}

// Update deny list status function
public fun emit_deny_list_status(
    collection_cap: &CollectionCap,
    addr: address
) {
    event::emit(DenyListStatusEvent {
        collection_id: object::uid_to_inner(&collection_cap.id),
        address: addr,
        is_denied: is_denied(collection_cap, addr)
    });
}

    // Transfer a token
    public entry fun transfer_token(
    token: NFT,
    recipient: address,
    collection_cap: &CollectionCap,
    sender_balance: &mut UserBalance,
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);

    // Check deny list restrictions
    check_deny_list_restrictions(collection_cap, sender);
    check_deny_list_restrictions(collection_cap, recipient);

    // Get token ID before any moves
    let token_id = object::uid_to_inner(&token.id);

    // Log initial state
    log_debug_event(b"Transfer attempt - Initial State", &token, sender, recipient);

    // Check deny list using collection_cap
    assert!(!is_denied(collection_cap, sender), 3);
    assert!(!is_denied(collection_cap, recipient), 4);

    log_debug_event(b"Deny list checks passed", &token, sender, recipient);

    // Update sender's balance
    assert!(sender_balance.collection_id == token_id, 0);
    sender_balance.balance = sender_balance.balance - 1;

    // Create recipient's balance
    let recipient_balance = UserBalance {
        id: object::new(ctx),
        collection_id: sender_balance.collection_id,
        balance: 1
    };
    transfer::transfer(recipient_balance, recipient);

    // Emit transfer event (without royalty)
    event::emit(TransferEvent {
        from: sender,
        to: recipient,
        id: token_id,
        amount: 1,
        royalty: 0,
        asset_id: token.asset_id,
    });

    // Log final state before transfer
    log_debug_event(b"Pre-transfer state - Final log", &token, sender, recipient);

    // Perform the transfer
    transfer::public_transfer(token, recipient);

    // Emit completion event
    event::emit(DebugEvent {
        message: string::utf8(b"Transfer completed"),
        token_id,
        sender,
        recipient,
    });
}

public fun get_deny_list_status(
    collection_cap: &CollectionCap,
    addr: address
): bool {
    if (!has_deny_list(collection_cap)) {
        return false
    };
    is_denied(collection_cap, addr)
}


// Helper function to safely get deny list size (with error handling)
public fun get_deny_list_size_safe(collection_cap: &CollectionCap): u64 {
    if (!has_deny_list(collection_cap)) {
        return 0
    };
    deny_list_size(collection_cap)
}



// Helper function to check if address can receive tokens
public fun can_receive_tokens(
    collection_cap: &CollectionCap,
    addr: address
): bool {
    !is_denied(collection_cap, addr)
}

// Helper function to validate transfers
public fun validate_transfer(
    collection_cap: &CollectionCap,
    from: address,
    to: address
) {
    assert!(can_receive_tokens(collection_cap, from), E_ADDRESS_DENIED);
    assert!(can_receive_tokens(collection_cap, to), E_ADDRESS_DENIED);
}


// Helper function for logging debug events
fun log_debug_event(message: vector<u8>, token: &NFT, sender: address, recipient: address) {
    event::emit(DebugEvent {
        message: string::utf8(message),
        token_id: object::uid_to_inner(&token.id),
        sender: sender,
        recipient: recipient,
    });
}

// Update batch_transfer_tokens
public entry fun batch_transfer_tokens(
    tokens: vector<NFT>,
    recipients: vector<address>,
    collection_cap: &CollectionCap,
    sender_balance: &mut UserBalance,
    ctx: &mut TxContext
) {
    // Get sender's address
    let sender = tx_context::sender(ctx);
    
    // 1. Initial validations with safe checks
    let token_count = vector::length(&tokens);
    let recipient_count = vector::length(&recipients);
    
    // Ensure vectors have matching lengths and are within limits
    assert!(token_count == recipient_count, E_INVALID_LENGTH);
    assert!(token_count <= MAX_BATCH_SIZE, E_MAX_BATCH_SIZE_EXCEEDED);
    assert!(token_count > 0, E_INVALID_BATCH_SIZE);
    
    // Ensure sender has sufficient balance with safe checks
    assert!(sender_balance.balance >= token_count, E_INSUFFICIENT_BALANCE);
    
    // 2. Deny list checks for sender
    check_deny_list_restrictions(collection_cap, sender);
    
    // 3. Prepare event data with safe initialization
    let mut token_ids = vector::empty<ID>();
    let mut amounts = vector::empty<u64>();
    let collection_id = object::uid_to_inner(&collection_cap.id);
    
    // 4. Store a mutable copy of tokens vector
    let mut tokens_mut = tokens;
    
    // 5. Process each transfer with safe operations
    let mut i = 0;
    while (i < recipient_count) {
        // Get recipient and validate
        let recipient = *vector::borrow(&recipients, i);
        
        // Check deny list for recipient
        check_deny_list_restrictions(collection_cap, recipient);
        
        // Get the token to transfer
        let token = vector::pop_back(&mut tokens_mut);
        
        // Verify token belongs to the correct collection
        assert!(token.collection_id == collection_id, E_COLLECTION_MISMATCH);
        
        // Create recipient balance if needed
        let recipient_balance = UserBalance {
            id: object::new(ctx),
            collection_id: token.collection_id,
            balance: 1
        };
        
        // Store token ID for event tracking
        vector::push_back(&mut token_ids, object::uid_to_inner(&token.id));
        vector::push_back(&mut amounts, 1);
        
        // Log transfer attempt
        log_debug_event(
            b"Processing batch transfer",
            &token,
            sender,
            recipient
        );
        
        // Emit individual transfer event
        event::emit(TransferEvent {
            from: sender,
            to: recipient,
            id: object::uid_to_inner(&token.id),
            amount: 1,
            royalty: 0,
            asset_id: token.asset_id,
        });
        
        // Transfer balance and token to recipient
        transfer::transfer(recipient_balance, recipient);
        transfer::public_transfer(token, recipient);
        
        // Safe increment
        assert!(i < MAX_U64, E_OVERFLOW);
        i = i + 1;
    };
    
    // 6. Update sender's balance with safe arithmetic
    sender_balance.balance = safe_sub(sender_balance.balance, token_count);
    
    // 7. Clean up the empty vector
    vector::destroy_empty(tokens_mut);
    
    // 8. Emit batch transfer event
    event::emit(BatchTransferEvent {
        from: sender,
        recipients: recipients,
        token_ids,
        amounts,
        collection_id,
        timestamp: tx_context::epoch(ctx)
    });
}


    // Batch transfer function
   public entry fun batch_burn_tokens(
    tokens: vector<NFT>,
    collection_cap: &mut CollectionCap,
    user_balance: &mut UserBalance,
    ctx: &mut TxContext
) {
    let count = vector::length(&tokens);
    assert!(count <= MAX_BATCH_SIZE, E_MAX_BATCH_SIZE_EXCEEDED);

    // Safe balance checks
    assert!(user_balance.balance >= count, E_INSUFFICIENT_BALANCE);
    assert!(collection_cap.current_supply >= count, E_NO_TOKENS_TO_BURN);

    let mut tokens_mut = tokens;
    let n = vector::length(&tokens_mut);

    
    
    let mut i = 0;
    while (i < n) {
        let token = vector::pop_back(&mut tokens_mut);
        
        // Check if the token belongs to the correct collection and user balance
        assert!(user_balance.collection_id == token.collection_id, 0);
        assert!(object::uid_to_inner(&collection_cap.id) == token.collection_id, 0);
        
        burn_token(token, collection_cap, user_balance, ctx);
        i = i + 1;
    };

    // Destroy the empty vector
    vector::destroy_empty(tokens_mut);
}


    // Burn a token
    public entry fun burn_token(
    token: NFT,
    collection_cap: &mut CollectionCap,
    user_balance: &mut UserBalance,
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);
    
    assert!(sender == token.creator, E_NOT_OWNER);
    assert!(collection_cap.current_supply > 0, E_NO_TOKENS_TO_BURN);
    assert!(user_balance.collection_id == token.collection_id, 0);
    
    // Safe balance updates
    user_balance.balance = safe_sub(user_balance.balance, 1);
    collection_cap.current_supply = safe_sub(collection_cap.current_supply, 1);
    
    event::emit(BurnEvent {
        owner: sender,
        id: object::uid_to_inner(&token.id),
        amount: 1,
    });
    
    let NFT { 
        id, 
        artinals_id: _, 
        creator: _, 
        name: _, 
        description: _, 
        uri: _, 
        logo_uri: _, 
        asset_id: _, 
        max_supply: _, 
        is_mutable: _, 
        metadata_frozen: _, 
        collection_id: _ 
    } = token;
    
    object::delete(id);
}



    public fun get_current_supply(cap: &CollectionCap): u64 {
    cap.current_supply
}

// The get_max_supply function can still work with both NFT and CollectionCap
public fun get_max_supply(item: &NFT): u64 {
    item.max_supply
}

    public fun get_collection_current_supply(cap: &CollectionCap): u64 {
        cap.current_supply
    }

    public fun get_collection_max_supply(cap: &CollectionCap): u64 {
    cap.max_supply
}

public entry fun batch_update_token_logo_uri(
    mut tokens: vector<NFT>,
    new_logo_uris: vector<vector<u8>>,
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);
    let n = vector::length(&tokens);
    
    // Ensure the number of tokens matches the number of new logo URIs
    assert!(n == vector::length(&new_logo_uris), E_MISMATCH_TOKENS_AND_URIS);

    let mut i = 0;
    while (i < n) {
        let token = vector::borrow_mut(&mut tokens, i);
        let new_logo_uri = *vector::borrow(&new_logo_uris, i);

        // Check if the sender is the creator of the token
        assert!(sender == token.creator, E_NOT_CREATOR);

        // Check if the token is mutable and not frozen
        assert!(token.is_mutable, E_TOKEN_NOT_MUTABLE);
        assert!(!token.metadata_frozen, E_METADATA_FROZEN);

        // Update the logo URI
        token.logo_uri = url::new_unsafe_from_bytes(new_logo_uri);

        // Emit an event for the logo URI update
        event::emit(LogoURIUpdateEvent {
            id: object::uid_to_inner(&token.id),
            artinals_id: token.artinals_id,
            new_logo_uri: token.logo_uri,
        });

        i = i + 1;
    };

    // Transfer the updated tokens back to the sender
    while (!vector::is_empty(&tokens)) {
        let token = vector::pop_back(&mut tokens);
        transfer::public_transfer(token, sender);
    };

    // Destroy the empty vector
    vector::destroy_empty(tokens);
}

   
public entry fun transfer_existing_nfts_by_quantity(
    mut tokens: vector<NFT>,
    recipient: address, 
    quantity: u64, 
    collection_cap: &CollectionCap,
    sender_balance: &mut UserBalance,
    ctx: &mut TxContext
) {
    // Get sender address
    let sender = tx_context::sender(ctx);
    
    // Use helper function for deny list validation
    validate_transfer(collection_cap, sender, recipient);
    
    // Log validation event
    log_debug_event(
        b"Deny list validation passed",
        vector::borrow(&tokens, 0),
        sender,
        recipient
    );
    
    // Ensure that the sender has enough NFTs to transfer
    let sender_nft_count = vector::length(&tokens);
    assert!(sender_nft_count >= quantity, E_NO_TOKENS_TO_BURN);

    // Create recipient balance object
    let recipient_balance = UserBalance {
        id: object::new(ctx),
        collection_id: sender_balance.collection_id,
        balance: quantity
    };

    // Update sender's balance
    sender_balance.balance = sender_balance.balance - quantity;

    // Transfer balance object to recipient
    transfer::transfer(recipient_balance, recipient);

    // Prepare event data
    let mut token_ids = vector::empty<ID>();
    let mut amounts = vector::empty<u64>();
    let collection_id = object::uid_to_inner(&collection_cap.id);

    let mut i = 0;
    while (i < quantity) {
        let token = vector::pop_back(&mut tokens);
        
        // Verify token belongs to the same collection
        assert!(
            collection_id == token.collection_id,
            E_COLLECTION_MISMATCH
        );

        // Store IDs for batch event
        vector::push_back(&mut token_ids, object::uid_to_inner(&token.id));
        vector::push_back(&mut amounts, 1);

        // Emit individual transfer event
        event::emit(TransferEvent {
    from: sender,
    to: recipient,
    id: object::uid_to_inner(&token.id),
    amount: 1,
    royalty: 0,  // Set to 0 since we removed royalties
    asset_id: token.asset_id,
    });

        // Log transfer attempt
        log_debug_event(
            b"Batch transfer token attempt",
            &token,
            sender,
            recipient
        );

        // Transfer the NFT to the recipient
        transfer::public_transfer(token, recipient);

        i = i + 1;
    };

    // Clean up the empty vector
    vector::destroy_empty(tokens);

    // Emit batch transfer event
    event::emit(BatchTransferEvent {
        from: sender,
        recipients: vector[recipient],
        token_ids,
        amounts,
        collection_id,
        timestamp: tx_context::epoch(ctx)
    });

}

public fun get_user_balance(user_balance: &UserBalance): u64 {
    user_balance.balance
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
    collection_cap: &CollectionCap,
    user_balance: &mut UserBalance,
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);
    
    // Initial debug event
    event::emit(DebugEvent {
        message: string::utf8(b"Starting create_nft_sale process"),
        token_id: object::uid_to_inner(&user_balance.id),
        sender,
        recipient: sender
    });
    
    // Price validation
    assert!(price_per_nft <= MAX_PRICE, E_MAX_PRICE_EXCEEDED);
    assert!(price_per_nft > 0, E_INVALID_PRICE);
    
    // Batch size validation
    assert!(nft_amount <= MAX_BATCH_SIZE, E_MAX_BATCH_SIZE_EXCEEDED);
    
    // Verify inputs
    let nft_length = vector::length(&nfts);
    assert!(nft_length >= nft_amount, E_NO_TOKENS_TO_BURN);
    
    // Get collection verification from first NFT
    let first_nft = vector::borrow(&nfts, 0);
    let collection_id = get_collection_id(first_nft);
    
    // Verify collection matches
    assert!(object::uid_to_inner(&collection_cap.id) == collection_id, E_COLLECTION_MISMATCH);
    
    // Balance validation
    assert!(user_balance.collection_id == collection_id, E_COLLECTION_MISMATCH);
    assert!(user_balance.balance >= nft_amount, E_INSUFFICIENT_BALANCE);
    
    // Create sale object with proper type annotations and mutability
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
    
    // Process NFTs and add them to sale
    let mut i = 0;
    while (i < nft_amount) {
        let nft = vector::pop_back(&mut nfts);
        
        // Verify NFT collection
        assert!(get_collection_id(&nft) == collection_id, E_COLLECTION_MISMATCH);
        
        // Add NFT directly as dynamic field
        df::add(&mut sale.id, NFTFieldKey<CURRENCY> { asset_id: i + 1 }, nft);
        
        // Emit listing creation event
        event::emit(NFTListingEvent<CURRENCY> {
            sale_id,
            listing_id: sale_id,
            asset_id: i + 1,
            price: price_per_nft
        });
        
        i = i + 1;
    };
    
    // Return remaining NFTs to sender
    while (!vector::is_empty(&nfts)) {  // Removed mut since is_empty only needs immutable reference
        let nft = vector::pop_back(&mut nfts);
        transfer::public_transfer(nft, sender);
    };
    vector::destroy_empty(nfts);
    
    // Update user balance
    user_balance.balance = safe_sub(user_balance.balance, nft_amount);
    
    // Emit sale creation event
    event::emit(SaleCreated<CURRENCY> {
        sale_id,
        creator: sender,
        nft_count: nft_amount,
        price_per_nft,
        collection_id
    });
    
    // Debug event for completion
    event::emit(DebugEvent {
        message: string::utf8(b"Sale creation completed successfully"),
        token_id: sale_id,
        sender,
        recipient: sender
    });
    
    // Share the sale object
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
    assert!(sale.is_active, E_SALE_NOT_ACTIVE);
    let buyer = tx_context::sender(ctx);
    
    // Verify deny list
    assert!(!is_denied(collection_cap, buyer), E_ADDRESS_DENIED);
    
    // Verify asset_id is valid
    assert!(asset_id > 0 && asset_id <= sale.nft_count, E_INVALID_ASSET_ID);
    assert!(df::exists_(&sale.id, NFTFieldKey<CURRENCY> { asset_id }), E_INVALID_ASSET_ID);
    
    // Verify price and process payment
    let payment_amount = coin::value(&payment);
    assert!(payment_amount >= sale.price_per_nft, E_INSUFFICIENT_BALANCE);
    
    // Get NFT from sale with proper type annotations
    let nft: NFT = df::remove(&mut sale.id, NFTFieldKey<CURRENCY> { asset_id });
    let nft_id = object::uid_to_inner(&nft.id);
    
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
    
    // Create buyer balance
    let buyer_balance = UserBalance {
        id: object::new(ctx),
        collection_id: sale.collection_id,
        balance: 1
    };
    
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
    collection_cap: &CollectionCap,
    user_balance: &mut UserBalance,
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);
    let sale_id = object::uid_to_inner(&sale.id);
    
    // Initial debug event
    event::emit(DebugEvent {
        message: string::utf8(b"Starting add_nfts_to_sale process"),
        token_id: sale_id,
        sender,
        recipient: sender
    });
    
    // Verify sender is sale creator
    assert!(sender == sale.creator, E_NOT_CREATOR);
    assert!(sale.is_active, E_SALE_NOT_ACTIVE);
    
    // Check for potential overflow in nft_count
    let new_total_count = safe_add(sale.nft_count, nft_amount);
    assert!(new_total_count <= MAX_SUPPLY, E_MAX_SUPPLY_EXCEEDED);
    
    // Batch size validation
    assert!(nft_amount <= MAX_BATCH_SIZE, E_MAX_BATCH_SIZE_EXCEEDED);
    
    // Verify input vector length
    let nft_length = vector::length(&nfts);
    assert!(nft_length >= nft_amount, E_NO_TOKENS_TO_BURN);
    
    // Collection verification from first NFT
    let first_nft = vector::borrow(&nfts, 0);
    let collection_id = get_collection_id(first_nft);
    
    // Verify collection matches
    assert!(sale.collection_id == collection_id, E_COLLECTION_MISMATCH);
    assert!(object::uid_to_inner(&collection_cap.id) == collection_id, E_COLLECTION_MISMATCH);
    
    // Balance validation
    assert!(user_balance.collection_id == collection_id, E_COLLECTION_MISMATCH);
    assert!(user_balance.balance >= nft_amount, E_INSUFFICIENT_BALANCE);
    
    // Process NFTs and add them as child objects
    let mut i = 0;
    while (i < nft_amount) {
        let nft = vector::pop_back(&mut nfts);
        let asset_id = sale.nft_count + i + 1;
        
        // Verify NFT collection
        assert!(get_collection_id(&nft) == collection_id, E_COLLECTION_MISMATCH);
        
        // Add NFT directly as dynamic field (child object)
        df::add(&mut sale.id, NFTFieldKey<CURRENCY> { asset_id }, nft);
        
        // Emit listing creation event
        event::emit(NFTListingEvent<CURRENCY> {
            sale_id,
            listing_id: sale_id,
            asset_id,
            price: sale.price_per_nft
        });
        
        i = i + 1;
    };
    
    // Return remaining NFTs to sender
    while (!vector::is_empty(&nfts)) {
        let nft = vector::pop_back(&mut nfts);
        transfer::public_transfer(nft, sender);
    };
    vector::destroy_empty(nfts);
    
    // Update user balance and sale NFT count using safe arithmetic
    user_balance.balance = safe_sub(user_balance.balance, nft_amount);
    sale.nft_count = safe_add(sale.nft_count, nft_amount);
    
    // Emit event for NFTs added to sale
    event::emit(SaleCreated<CURRENCY> {
        sale_id,
        creator: sender,
        nft_count: nft_amount,
        price_per_nft: sale.price_per_nft,
        collection_id
    });
    
    // Final success debug event
    event::emit(DebugEvent {
        message: string::utf8(b"Successfully completed adding NFTs to sale"),
        token_id: sale_id,
        sender,
        recipient: sender
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
        // Add type annotations for remove
        let nft: NFT = df::remove(&mut sale.id, NFTFieldKey<CURRENCY> { asset_id });

        // Store ID for event
        vector::push_back(&mut token_ids, object::uid_to_inner(&nft.id));
        vector::push_back(&mut amounts, 1);

        // Transfer NFT back to creator using public_transfer
        transfer::public_transfer(nft, sender);
        
        i = i + 1;
    };

    // Update balances using safe arithmetic
    sale.nft_count = safe_sub(sale.nft_count, amount);
    user_balance.balance = safe_add(user_balance.balance, amount);
    collection_cap.current_supply = safe_sub(collection_cap.current_supply, amount);

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
    // Since NFT struct has collection_id field
    nft.collection_id
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
        object::uid_to_inner(&nft.id),
        nft.collection_id,
        nft.creator
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