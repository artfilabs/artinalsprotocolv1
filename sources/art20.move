module artinals::ART20 {
    use sui::url::{Self, Url};
    use sui::event;
    use std::string::{Self, String};
    use sui::dynamic_field as df;  
    use sui::package;
    use sui::display;
    use sui::table::{Self, Table};

    

    //Errors
    const E_MISMATCH_TOKENS_AND_URIS: u64 = 1;
    const E_NOT_CREATOR: u64 = 2;
    const E_TOKEN_NOT_MUTABLE: u64 = 3;
    const E_METADATA_FROZEN: u64 = 4;
    const E_NOT_OWNER: u64 = 5;
    const E_NO_TOKENS_TO_BURN: u64 = 6;
    const E_COLLECTION_MISMATCH: u64 = 8;
    const E_INSUFFICIENT_BALANCE: u64 = 9;
    const E_ADDRESS_DENIED: u64 = 12;
    const E_INVALID_DENY_LIST_AUTHORITY: u64 = 13;
    const E_DENY_LIST_ALREADY_EXISTS: u64 = 14;
    const E_INVALID_LENGTH: u64 = 15;
    const E_INVALID_BATCH_SIZE: u64 = 16;
    const E_OVERFLOW: u64 = 18;
    const E_MAX_SUPPLY_EXCEEDED: u64 = 19;
    const E_MAX_BATCH_SIZE_EXCEEDED: u64 = 20;

    // Add maximum limits
    const MAX_U64: u64 = 18446744073709551615;
    const MAX_SUPPLY: u64 = 1000000000; // 1 billion
    const MAX_BATCH_SIZE: u64 = 200;    // Maximum 100 NFTs per batch



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
    public struct ART20 has drop {}

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





fun safe_add(a: u64, b: u64): u64 {
    assert!(a <= MAX_U64 - b, E_OVERFLOW);
    a + b
}

fun safe_sub(a: u64, b: u64): u64 {
    assert!(a >= b, E_INSUFFICIENT_BALANCE);
    a - b
}

    

// Initialize the TokenIdCounter
    fun init(witness: ART20, ctx: &mut TxContext) {
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

public fun create_user_balance(
        collection_id: ID,
        balance: u64,
        ctx: &mut TxContext
    ): UserBalance {
        UserBalance {
            id: object::new(ctx),
            collection_id,
            balance
        }
    }

// View functions

// Helper function to check if NFT exists in sale


public fun get_collection_id(nft: &NFT): ID {
    // Since NFT struct has collection_id field
    nft.collection_id
}


    public fun get_user_balance_id(balance: &UserBalance): ID {
        object::uid_to_inner(&balance.id)
    }

    public fun get_user_balance_collection_id(balance: &UserBalance): ID {
        balance.collection_id
    }


    // Add getters for NFT

    public fun get_nft_collection_id(nft: &NFT): ID {
        nft.collection_id
    }

    public fun get_nft_creator(nft: &NFT): address {
        nft.creator
    }

    // Add getters for CollectionCap
    public fun get_collection_cap_id(cap: &CollectionCap): ID {
        object::uid_to_inner(&cap.id)
    }

    public fun verify_collection_match(collection_cap: &CollectionCap, user_balance: &UserBalance): bool {
        get_collection_cap_id(collection_cap) == get_user_balance_collection_id(user_balance)
    }

    // Add function to update collection supply
    public fun update_collection_supply(cap: &mut CollectionCap, new_supply: u64) {
        cap.current_supply = new_supply;
    }

    // Add getter for collection current supply if not already present
    public fun get_collection_current_supply(cap: &CollectionCap): u64 {
        cap.current_supply
    }

    // Make sure these getters are available
    public fun get_user_balance_amount(balance: &UserBalance): u64 {
        balance.balance
    }

    public fun set_user_balance_amount(balance: &mut UserBalance, amount: u64) {
        balance.balance = amount;
    }

    public fun get_nft_id(nft: &NFT): ID {
        object::uid_to_inner(&nft.id)
    }

}