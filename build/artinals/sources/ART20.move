module artinals::ART20 {
    use sui::url::{Self, Url};
    use sui::event;
    use std::string::{Self, String};
    use sui::dynamic_field as df;  
    use sui::package;
    use sui::display;
    use sui::table::{Self, Table};
    use sui::coin::{Self, Coin};
    use std::type_name::{Self, TypeName};
    use sui::clock::{Self, Clock};
    
    

    

    //Errors
    const E_MISMATCH_TOKENS_AND_URIS: u64 = 1;
    const E_NOT_CREATOR: u64 = 2;
    const E_TOKEN_NOT_MUTABLE: u64 = 3;
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
    const ASSET_ID_NOT_FOUND: u64 = 21;
    const E_INVALID_API_ENDPOINT: u64 = 22;
    const E_INVALID_ORACLE_ADDRESS: u64 = 23;
    const E_COLLECTION_NOT_MUTABLE: u64 = 24;
    const E_INVALID_SUPPLY: u64 = 25;
    const E_DUPLICATE_ASSET_ID: u64 = 26;
    const E_NOT_MINTABLE: u64 = 27;
    const E_INSUFFICIENT_TOKENS: u64 = 28;
    const E_INVALID_CATEGORY: u64 = 29;
const E_CATEGORY_NOT_FOUND: u64 = 30;
const E_CATEGORY_ALREADY_EXISTS: u64 = 31;
    

    // Add maximum limits
    const MAX_U64: u64 = 18446744073709551615;
    const MAX_SUPPLY: u64 = 1000000000; // 1 billion
    const MAX_BATCH_SIZE: u64 = 200;    // Maximum 200 NFTs per batch
    const E_NOT_DEPLOYER: u64 = 25;
    const E_INVALID_FEE: u64 = 26;
    const MAX_INITIAL_MINT: u64 = 1000;



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
    collection_id: ID,
    category: String,
}




    // One-Time-Witness for the module
    public struct ART20 has drop {}


    public struct AdminCap has key, store {
        id: UID,
        owner: address
    }

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
    is_mintable: bool,
    has_deny_list_authority: bool,
    value_source: Option<String>,  // Stores either API endpoint or oracle address
    is_api_source: bool 
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

public struct CollectionCreatedEvent has copy, drop {
    collection_id: ID,
    creator: address,
    name: String,
    description: String,
    initial_supply: u64,
    max_supply: u64,
    is_mutable: bool,
    has_deny_list_authority: bool,
    timestamp: u64
}



    // Define event for burning NFTs
    public struct BurnEvent has copy, drop {
        owner: address,
        id: ID,
    }

    public struct MetadataUpdateEvent has copy, drop {
    id: ID,
    new_name: String,
    new_description: String,
}

public struct CollectionValueSourceUpdated has copy, drop {
    collection_id: ID,
    is_api: bool,
    source: String,
    timestamp: u64
}



public struct LogoURIUpdateEvent has copy, drop {
    id: ID,
    artinals_id: u64,
    new_logo_uri: Url, // Change to Url type
}




public struct BatchTransferEvent has copy, drop {
    from: address,
    recipients: vector<address>,
    token_ids: vector<ID>,
    amounts: vector<u64>,
    collection_id: ID,
    timestamp: u64
}





public struct CollectionMintEvent has copy, drop {
    collection_id: ID,
    amount: u64,
    current_supply: u64,
    max_supply: u64,
    creator: address,
    timestamp: u64,
}

public struct AdditionalMintEvent has copy, drop {
    collection_id: ID,
    amount: u64,
    new_supply: u64,
    max_supply: u64,
    creator: address,
    timestamp: u64
}

public struct FeeConfig has key, store {
    id: UID,
    fee_amount: u64,
    fee_coin_type: TypeName,
    fee_collector: address,
    deployer: address
}


public struct CategoryRegistry has key {
    id: UID,
    categories: Table<String, Category>,
    admin: address
}

public struct Category has store {
    name: String,
    description: String,
    is_active: bool,
    created_at: u64
}


public struct CategoryCreated has copy, drop {
    name: String,
    description: String,
    timestamp: u64
}



public struct CategoryKey has copy, drop, store {}


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

        // Create and share the CategoryRegistry
    let category_registry = CategoryRegistry {
        id: object::new(ctx),
        categories: table::new<String, Category>(ctx),
        admin: tx_context::sender(ctx) // Set admin to deployer
    };
    transfer::share_object(category_registry);

    let admin_cap = AdminCap {
            id: object::new(ctx),
            owner: tx_context::sender(ctx)
        };
        transfer::transfer(admin_cap, tx_context::sender(ctx));
    

        

        // Create and share fee config
    let fee_config = FeeConfig {
        id: object::new(ctx),
        fee_amount: 0,  // Initial fee amount
        fee_coin_type: type_name::get<sui::sui::SUI>(), // Default to SUI
        fee_collector: tx_context::sender(ctx),
        deployer: tx_context::sender(ctx)
    };
    transfer::share_object(fee_config);


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

public entry fun set_fee<FeeType>(
    fee_config: &mut FeeConfig,
    new_fee_amount: u64,
    ctx: &mut TxContext
) {
    // Only deployer can set fee
    assert!(tx_context::sender(ctx) == fee_config.deployer, E_NOT_DEPLOYER);
    
    fee_config.fee_amount = new_fee_amount;
    fee_config.fee_coin_type = type_name::get<FeeType>();
}


public entry fun transfer_admin_cap(
        admin_cap: &mut AdminCap,
        new_owner: address,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == admin_cap.owner, E_NOT_DEPLOYER);
        admin_cap.owner = new_owner;
    }


   public entry fun mint_art20<FeeType>(
    name: vector<u8>, 
    description: vector<u8>, 
    initial_supply: u64,
    max_supply: u64,
    uri: vector<u8>, 
    logo_uri: vector<u8>, 
    category: String, // New parameter
    registry: &CategoryRegistry, // New parameter
    is_mutable: bool, 
    has_deny_list_authority: bool, 
    counter: &mut TokenIdCounter,
    fee_config: &FeeConfig,
    mut fee_payment: Coin<FeeType>,
    clock: &Clock,
    ctx: &mut TxContext
) {

     // Validate category exists and is active
    assert!(table::contains(&registry.categories, category), E_CATEGORY_NOT_FOUND);
    let cat = table::borrow(&registry.categories, category);
    assert!(cat.is_active, E_INVALID_CATEGORY);
    // Add batch size validation first
    assert!(initial_supply >= 0, E_INVALID_BATCH_SIZE);
    assert!(initial_supply <= MAX_INITIAL_MINT, E_MAX_BATCH_SIZE_EXCEEDED);

    // Handle fee payment
    let payment_value = coin::value(&fee_payment);
    
    if (fee_config.fee_amount > 0) {
        assert!(payment_value >= fee_config.fee_amount, E_INVALID_FEE);
        assert!(type_name::get<FeeType>() == fee_config.fee_coin_type, E_INVALID_FEE);
        
        // If payment is more than fee, return the excess
        if (payment_value > fee_config.fee_amount) {
            let refund_amount = payment_value - fee_config.fee_amount;
            let refund = coin::split(&mut fee_payment, refund_amount, ctx);
            transfer::public_transfer(refund, tx_context::sender(ctx));
        };
        
        // Transfer fee to collector
        transfer::public_transfer(fee_payment, fee_config.fee_collector);
    } else {
        // Return full payment if fee is 0
        transfer::public_transfer(fee_payment, tx_context::sender(ctx));
    };

    // Supply validations with proper error codes
    assert!(max_supply <= MAX_SUPPLY, E_MAX_SUPPLY_EXCEEDED);
    assert!(initial_supply <= MAX_SUPPLY, E_MAX_SUPPLY_EXCEEDED);
    assert!(max_supply == 0 || initial_supply <= max_supply, E_INVALID_SUPPLY);
    
    // Check counter overflow
    assert!(counter.last_id <= MAX_U64 - initial_supply, E_OVERFLOW);

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
        is_mintable: true,
        has_deny_list_authority,
        value_source: option::none(),
        is_api_source: false
    };

    // Calculate collection_id once
    let collection_id = object::uid_to_inner(&collection_cap.id);

    // Emit collection creation event
    event::emit(CollectionCreatedEvent {
        collection_id,
        creator: tx_context::sender(ctx),
        name: string::utf8(name),
        description: string::utf8(description),
        initial_supply,
        max_supply,
        is_mutable,
        has_deny_list_authority,
        timestamp: clock::timestamp_ms(clock)
    });

    // Emit collection mint event 
    event::emit(CollectionMintEvent {
        collection_id,
        amount: initial_supply,
        current_supply: initial_supply,
        max_supply,
        creator: tx_context::sender(ctx),
        timestamp: clock::timestamp_ms(clock)
    });

    // Initialize deny list as dynamic field
    df::add(
        &mut collection_cap.id, 
        DenyListKey {}, 
        create_deny_list(ctx)
    );

    let user_balance = UserBalance {
        id: object::new(ctx),
        collection_id,
        balance: initial_supply
    };

    // Create vector to store tokens before batch transfer
    let mut tokens = vector::empty<NFT>();

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
            collection_id,
            category: category, // Ensure category is bound correctly
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
            royalty: 0,
            asset_id: token.asset_id,
        });

        // Store token in vector
        vector::push_back(&mut tokens, token);
        i = i + 1;
    };

    // Batch transfer all tokens using immutable reference for checking
    while (!vector::is_empty(&tokens)) {
        let token = vector::pop_back(&mut tokens);
        transfer::transfer(token, tx_context::sender(ctx));
    };

    // Clean up
    vector::destroy_empty(tokens);

    transfer::share_object(collection_cap);
    transfer::transfer(user_balance, tx_context::sender(ctx));
}



    // New function to mint additional tokens (only for mintable NFTs)
   public entry fun mint_additional_art20(
    collection_cap: &mut CollectionCap,
    amount: u64,
    counter: &mut TokenIdCounter,
    user_balance: &mut UserBalance,
    clock: &Clock,
    ctx: &mut TxContext
) {
    assert!(collection_cap.is_mintable, E_NOT_MINTABLE);
    assert!(tx_context::sender(ctx) == collection_cap.creator, 2);
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
    collection_id,
    category: string::utf8(b""),
};


        event::emit(TransferEvent {
            from: tx_context::sender(ctx),
            to: tx_context::sender(ctx),
            id: object::uid_to_inner(&token.id),
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

    // Emit additional mint event
    event::emit(AdditionalMintEvent {
        collection_id,
        amount,
        new_supply: collection_cap.current_supply,
        max_supply: collection_cap.max_supply,
        creator: collection_cap.creator,
        timestamp: clock::timestamp_ms(clock)
    });
}


public entry fun freeze_minting(
    collection_cap: &mut CollectionCap,
    ctx: &mut TxContext
) {
    assert!(tx_context::sender(ctx) == collection_cap.creator, E_NOT_CREATOR);
    assert!(collection_cap.is_mintable, E_NOT_MINTABLE);
    collection_cap.is_mintable = false;
}


//  drop_collection_cap function
public fun drop_collection_cap(
    collection_cap: CollectionCap,
    ctx: &mut TxContext
) {
    // Verify the caller is the creator
    assert!(tx_context::sender(ctx) == collection_cap.creator, E_NOT_CREATOR);
    
    // Verify the current supply is 0
    assert!(collection_cap.current_supply == 0, E_NO_TOKENS_TO_BURN);

    let CollectionCap {
        mut id,
        max_supply: _,
        current_supply: _,
        creator: _,
        name: _,
        description: _,
        uri: _,
        logo_uri: _,
        is_mutable: _,
        is_mintable: _,
        has_deny_list_authority: _,
        value_source: _,
        is_api_source: _
    } = collection_cap;

    // Check and remove deny list if it exists
    if (df::exists_(&id, DenyListKey {})) {
        let deny_list = df::remove<DenyListKey, Table<address, bool>>(
            &mut id,
            DenyListKey {}
        );
        table::drop(deny_list);
    };
    
    object::delete(id);
}


public entry fun update_metadata_by_object(
    token: &mut NFT,
    collection_cap: &CollectionCap,
    mut new_name: Option<String>,
    mut new_description: Option<String>,
    mut new_uri: Option<vector<u8>>,
    mut new_logo_uri: Option<vector<u8>>,
    ctx: &mut TxContext
) {
    
    // Check permissions
    assert!(token.collection_id == get_collection_cap_id(collection_cap), E_COLLECTION_MISMATCH);
    assert!(collection_cap.is_mutable, E_TOKEN_NOT_MUTABLE); // Only check collection mutability
    assert!(tx_context::sender(ctx) == token.creator, E_NOT_CREATOR);
    

    // Update name if provided
    if (option::is_some(&new_name)) {
        let name = option::extract(&mut new_name);
        assert!(string::length(&name) <= 128, E_INVALID_LENGTH);
        token.name = name;
    };

    // Update description if provided
    if (option::is_some(&new_description)) {
        let description = option::extract(&mut new_description);
        assert!(string::length(&description) <= 1000, E_INVALID_LENGTH);
        token.description = description;
    };

    // Update URI if provided
    if (option::is_some(&new_uri)) {
        let uri = option::extract(&mut new_uri);
        assert!(vector::length(&uri) <= 256, E_INVALID_LENGTH);
        token.uri = url::new_unsafe_from_bytes(uri);
    };

    // Update logo URI if provided
    if (option::is_some(&new_logo_uri)) {
        let logo_uri = option::extract(&mut new_logo_uri);
        assert!(vector::length(&logo_uri) <= 256, E_INVALID_LENGTH);
        token.logo_uri = url::new_unsafe_from_bytes(logo_uri);
    };

    // Emit metadata update event
    event::emit(MetadataUpdateEvent {
        id: object::uid_to_inner(&token.id),
        new_name: token.name,
        new_description: token.description,
    });
}


public entry fun update_metadata_by_asset_id(
    collection_cap: &CollectionCap,
    mut nfts: vector<NFT>,
    asset_id: u64,
    mut new_name: Option<String>,
    mut new_description: Option<String>,
    mut new_uri: Option<vector<u8>>,
    mut new_logo_uri: Option<vector<u8>>,
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);
    let collection_id = get_collection_cap_id(collection_cap);

    // Validate metadata lengths before processing
    // String length validations
    if (option::is_some(&new_name)) {
        let name = option::borrow(&new_name);
        assert!(string::length(name) <= 128, E_INVALID_LENGTH);
        let name_bytes = string::as_bytes(name);
        assert!(vector::length(name_bytes) <= 128 * 4, E_INVALID_LENGTH);
        assert!(vector::length(name_bytes) > 0, E_INVALID_LENGTH);
    };

    if (option::is_some(&new_description)) {
        let description = option::borrow(&new_description);
        assert!(string::length(description) <= 1000, E_INVALID_LENGTH);
        let desc_bytes = string::as_bytes(description);
        assert!(vector::length(desc_bytes) <= 1000 * 4, E_INVALID_LENGTH);
        assert!(vector::length(desc_bytes) > 0, E_INVALID_LENGTH);
    };
    
    // URI validations
    if (option::is_some(&new_uri)) {
        let uri = option::borrow(&new_uri);
        assert!(vector::length(uri) <= 256, E_INVALID_LENGTH);
        assert!(vector::length(uri) > 0, E_INVALID_LENGTH);
    };

    if (option::is_some(&new_logo_uri)) {
        let logo_uri = option::borrow(&new_logo_uri);
        assert!(vector::length(logo_uri) <= 256, E_INVALID_LENGTH);
        assert!(vector::length(logo_uri) > 0, E_INVALID_LENGTH);
    };

    let mut updated_nfts = vector::empty();
    let mut found = false;

    while (!vector::is_empty(&nfts) && !found) {  // Added !found condition
        let mut nft = vector::pop_back(&mut nfts);
        
        if (nft.collection_id == collection_id && nft.asset_id == asset_id) {
            // Verify permissions
            assert!(collection_cap.is_mutable, E_TOKEN_NOT_MUTABLE);
            assert!(sender == nft.creator, E_NOT_CREATOR);

            // Update metadata fields
            if (option::is_some(&new_name)) {
                nft.name = option::extract(&mut new_name);
            };

            if (option::is_some(&new_description)) {
                nft.description = option::extract(&mut new_description);
            };

            if (option::is_some(&new_uri)) {
                nft.uri = url::new_unsafe_from_bytes(option::extract(&mut new_uri));
            };

            if (option::is_some(&new_logo_uri)) {
                nft.logo_uri = url::new_unsafe_from_bytes(option::extract(&mut new_logo_uri));
            };

            event::emit(MetadataUpdateEvent {
                id: object::uid_to_inner(&nft.id),
                new_name: nft.name,
                new_description: nft.description,
            });

            found = true;
        };

        vector::push_back(&mut updated_nfts, nft);
    };

    // Move remaining NFTs to updated_nfts without processing them
    while (!vector::is_empty(&nfts)) {
        vector::push_back(&mut updated_nfts, vector::pop_back(&mut nfts));
    };

    assert!(found, ASSET_ID_NOT_FOUND);

    // Return NFTs to sender
    while (!vector::is_empty(&updated_nfts)) {
        transfer::transfer(vector::pop_back(&mut updated_nfts), sender);
    };

    vector::destroy_empty(nfts);
    vector::destroy_empty(updated_nfts);
}


// New function to update Logo URI of a specific token
    public fun update_art20_image_uri(
    token: &mut NFT,
    collection_cap: &CollectionCap,
    new_logo_uri: vector<u8>, // Change this to vector<u8>
    ctx: &mut TxContext
) {
    assert!(token.collection_id == get_collection_cap_id(collection_cap), E_COLLECTION_MISMATCH);
    assert!(collection_cap.is_mutable, E_TOKEN_NOT_MUTABLE);
    assert!(tx_context::sender(ctx) == token.creator, E_NOT_CREATOR);

    token.logo_uri = url::new_unsafe_from_bytes(new_logo_uri); // Convert to Url

    event::emit(LogoURIUpdateEvent {
        id: object::uid_to_inner(&token.id),
        artinals_id: token.artinals_id,
        new_logo_uri: token.logo_uri,
    });
}



public entry fun batch_update_metadata(
    collection_cap: &CollectionCap,
    mut tokens: vector<NFT>,
    new_name: Option<String>,          
    new_description: Option<String>,    
    new_uri: Option<vector<u8>>,       
    new_logo_uri: Option<vector<u8>>,  
    ctx: &mut TxContext
) {
    let batch_size = vector::length(&tokens);
    let sender = tx_context::sender(ctx);
    let collection_id = get_collection_cap_id(collection_cap);

    // Validate lengths first
    if (option::is_some(&new_name)) {
        assert!(string::length(option::borrow(&new_name)) <= 128, E_INVALID_LENGTH);
    };
    if (option::is_some(&new_description)) {
        assert!(string::length(option::borrow(&new_description)) <= 1000, E_INVALID_LENGTH);
    };
    if (option::is_some(&new_uri)) {
        assert!(vector::length(option::borrow(&new_uri)) <= 256, E_INVALID_LENGTH);
    };
    if (option::is_some(&new_logo_uri)) {
        assert!(vector::length(option::borrow(&new_logo_uri)) <= 256, E_INVALID_LENGTH);
    };

    let mut i = 0;
    while (i < batch_size) {
        let token = vector::borrow_mut(&mut tokens, i);
        assert!(token.collection_id == collection_id, E_COLLECTION_MISMATCH);
        assert!(collection_cap.is_mutable, E_TOKEN_NOT_MUTABLE);
        assert!(sender == token.creator, E_NOT_CREATOR);

        // Update fields if provided
        if (option::is_some(&new_name)) {
            token.name = *option::borrow(&new_name);
        };
        if (option::is_some(&new_description)) {
            token.description = *option::borrow(&new_description);
        };
        if (option::is_some(&new_uri)) {
            token.uri = url::new_unsafe_from_bytes(*option::borrow(&new_uri));
        };
        if (option::is_some(&new_logo_uri)) {
            token.logo_uri = url::new_unsafe_from_bytes(*option::borrow(&new_logo_uri));
        };

        event::emit(MetadataUpdateEvent {
            id: object::uid_to_inner(&token.id),
            new_name: token.name,
            new_description: token.description,
        });

        i = i + 1;
    };

    // Return the updated tokens to sender
    while (!vector::is_empty(&tokens)) {
        let token = vector::pop_back(&mut tokens);
        transfer::transfer(token, sender);
    };

    vector::destroy_empty(tokens);
}

public entry fun batch_update_metadata_by_asset_ids(
    collection_cap: &CollectionCap,
    mut nfts: vector<NFT>,
    asset_ids: vector<u64>,
    new_name: Option<String>,
    new_description: Option<String>,
    new_uri: Option<vector<u8>>,
    new_logo_uri: Option<vector<u8>>,
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);
    let collection_id = get_collection_cap_id(collection_cap);
    let asset_count = vector::length(&asset_ids);
    
    // Validate batch size
    assert!(asset_count > 0 && asset_count <= MAX_BATCH_SIZE, E_INVALID_BATCH_SIZE);
    
    // Validate metadata lengths once before the loop
    // String length validations
    if (option::is_some(&new_name)) {
        let name = option::borrow(&new_name);
        assert!(string::length(name) <= 128, E_INVALID_LENGTH);
        // Additional UTF-8 validation
        let bytes = string::as_bytes(name);
        assert!(vector::length(bytes) <= 128 * 4, E_INVALID_LENGTH); // Max 4 bytes per UTF-8 char
        assert!(vector::length(bytes) > 0, E_INVALID_LENGTH); // Non-empty validation
    };

    if (option::is_some(&new_description)) {
        let description = option::borrow(&new_description);
        assert!(string::length(description) <= 1000, E_INVALID_LENGTH);
        // Additional UTF-8 validation
        let bytes = string::as_bytes(description);
        assert!(vector::length(bytes) <= 1000 * 4, E_INVALID_LENGTH); // Max 4 bytes per UTF-8 char
        assert!(vector::length(bytes) > 0, E_INVALID_LENGTH); // Non-empty validation
    };
    
    // URI validations
    if (option::is_some(&new_uri)) {
        let uri = option::borrow(&new_uri);
        assert!(vector::length(uri) <= 256, E_INVALID_LENGTH);
        assert!(vector::length(uri) > 0, E_INVALID_LENGTH); // Non-empty validation
    };

    if (option::is_some(&new_logo_uri)) {
        let logo_uri = option::borrow(&new_logo_uri);
        assert!(vector::length(logo_uri) <= 256, E_INVALID_LENGTH);
        assert!(vector::length(logo_uri) > 0, E_INVALID_LENGTH); // Non-empty validation
    };
    
    // Add duplicate check
    let mut processed_ids = table::new<u64, bool>(ctx);

    // Process each asset ID
    let mut i = 0;
    while (i < asset_count) {
        let asset_id = *vector::borrow(&asset_ids, i);

        // Check for duplicate asset_id
        assert!(!table::contains(&processed_ids, asset_id), E_DUPLICATE_ASSET_ID);
        table::add(&mut processed_ids, asset_id, true);

        let mut found = false;
        let mut updated_nfts = vector::empty();

        while (!vector::is_empty(&nfts)) {
            let mut nft = vector::pop_back(&mut nfts);
            
            if (!found && nft.collection_id == collection_id && nft.asset_id == asset_id) {
                assert!(collection_cap.is_mutable, E_TOKEN_NOT_MUTABLE);
                assert!(sender == nft.creator, E_NOT_CREATOR);

                // Update name with validated value
                if (option::is_some(&new_name)) {
                    nft.name = *option::borrow(&new_name);
                };

                // Update description with validated value
                if (option::is_some(&new_description)) {
                    nft.description = *option::borrow(&new_description);
                };

                // Update URI with validated value
                if (option::is_some(&new_uri)) {
                    nft.uri = url::new_unsafe_from_bytes(*option::borrow(&new_uri));
                };

                // Update logo URI with validated value
                if (option::is_some(&new_logo_uri)) {
                    nft.logo_uri = url::new_unsafe_from_bytes(*option::borrow(&new_logo_uri));
                };

                event::emit(MetadataUpdateEvent {
                    id: object::uid_to_inner(&nft.id),
                    new_name: nft.name,
                    new_description: nft.description,
                });

                found = true;
            };
            vector::push_back(&mut updated_nfts, nft);
        };

        // Restore NFTs from temporary vector
        while (!vector::is_empty(&updated_nfts)) {
            vector::push_back(&mut nfts, vector::pop_back(&mut updated_nfts));
        };
        vector::destroy_empty(updated_nfts);

        assert!(found, ASSET_ID_NOT_FOUND);
        i = i + 1;
    };

    // Clean up resources
    table::drop(processed_ids);

    // Return the updated NFTs to sender
    while (!vector::is_empty(&nfts)) {
        let nft = vector::pop_back(&mut nfts);
        transfer::transfer(nft, sender);
    };

    vector::destroy_empty(nfts);
}


// Batch burn tokens by asset IDs
public entry fun batch_burn_art20_by_asset_ids(
    collection_cap: &mut CollectionCap,
    mut nfts: vector<NFT>,
    mut user_balances: vector<UserBalance>,
    asset_ids: vector<u64>,
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);
    let collection_id = get_collection_cap_id(collection_cap);
    let asset_count = vector::length(&asset_ids);
    
    // Validate batch size
    assert!(asset_count > 0 && asset_count <= MAX_BATCH_SIZE, E_INVALID_BATCH_SIZE);
    assert!(collection_cap.current_supply >= asset_count, E_NO_TOKENS_TO_BURN);

    // Add duplicate check
    let mut processed_ids = table::new<u64, bool>(ctx);

    // Calculate total available balance
    let mut total_available = 0u64;
    let mut i = 0;
    let n = vector::length(&user_balances);
    while (i < n) {
        let balance = vector::borrow(&user_balances, i);
        total_available = safe_add(total_available, balance.balance);
        i = i + 1;
    };
    assert!(total_available >= asset_count, E_INSUFFICIENT_BALANCE);

    // Process each asset ID
    let mut i = 0;
    while (i < asset_count) {
        let asset_id = *vector::borrow(&asset_ids, i);
        
        // Check for duplicate asset_id
        assert!(!table::contains(&processed_ids, asset_id), E_DUPLICATE_ASSET_ID);
        table::add(&mut processed_ids, asset_id, true);

        let mut found = false;
        let mut updated_nfts = vector::empty();
        
        while (!vector::is_empty(&nfts)) {
            let nft = vector::pop_back(&mut nfts);
            
            if (!found && nft.collection_id == collection_id && nft.asset_id == asset_id) {
                assert!(sender == nft.creator, E_NOT_OWNER);
                
                // Update balances
                let mut balance_updated = false;
                let mut k = 0;
                while (k < vector::length(&user_balances)) {
                    let balance = vector::borrow_mut(&mut user_balances, k);
                    if (balance.balance > 0 && balance.collection_id == collection_id) {
                        balance.balance = safe_sub(balance.balance, 1);
                        balance_updated = true;
                        break
                    };
                    k = k + 1;
                };
                assert!(balance_updated, E_INSUFFICIENT_BALANCE);

                collection_cap.current_supply = safe_sub(collection_cap.current_supply, 1);
                
                event::emit(BurnEvent {
                    owner: sender,
                    id: object::uid_to_inner(&nft.id),
                   
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
                    collection_id: _, 
                    category: _ 
                } = nft;
                object::delete(id);
                found = true;
                continue;
            };
            vector::push_back(&mut updated_nfts, nft);
        };

        while (!vector::is_empty(&updated_nfts)) {
            vector::push_back(&mut nfts, vector::pop_back(&mut updated_nfts));
        };
        vector::destroy_empty(updated_nfts);

        assert!(found, ASSET_ID_NOT_FOUND);
        i = i + 1;
    };

    table::drop(processed_ids);

    // Process remaining balances
    let mut k = 0;
    while (k < vector::length(&user_balances)) {
        let balance = vector::borrow(&user_balances, k);
        if (get_user_balance_amount(balance) == 0) {
            let removed_balance = vector::remove(&mut user_balances, k);
            cleanup_empty_balance(removed_balance);
        } else {
            k = k + 1;
        };
    };

    // Return remaining NFTs and balances
    while (!vector::is_empty(&nfts)) {
        let nft = vector::pop_back(&mut nfts);
        transfer::transfer(nft, sender);
    };

    while (!vector::is_empty(&user_balances)) {
        let balance = vector::pop_back(&mut user_balances);
        transfer::transfer(balance, sender);
    };

    vector::destroy_empty(nfts);
    vector::destroy_empty(user_balances);
}


public entry fun freeze_collection_metadata(
    collection_cap: &mut CollectionCap,
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);
    assert!(sender == collection_cap.creator, E_NOT_CREATOR);
    assert!(collection_cap.is_mutable, E_COLLECTION_NOT_MUTABLE); // Better error code
    collection_cap.is_mutable = false;
    
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

// Batch add addresses to deny list
public entry fun add_to_deny_list(
    collection_cap: &mut CollectionCap,
    addrs: vector<address>,
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);
    let addr_count = vector::length(&addrs);
    
    // Basic validations
    assert!(addr_count > 0 && addr_count <= MAX_BATCH_SIZE, E_INVALID_BATCH_SIZE);
    assert!(sender == collection_cap.creator, E_NOT_CREATOR);
    assert!(collection_cap.has_deny_list_authority, E_INVALID_DENY_LIST_AUTHORITY);
    
    let collection_id = object::uid_to_inner(&collection_cap.id);
    
    let mut i = 0;
    while (i < addr_count) {
        let addr = *vector::borrow(&addrs, i);
        let deny_list = df::borrow_mut<DenyListKey, Table<address, bool>>(
            &mut collection_cap.id,
            DenyListKey {}
        );
        
        // Skip if address is already in deny list
        if (!table::contains(deny_list, addr)) {
            table::add(deny_list, addr, true);
            
            event::emit(DenyListStatusChanged {
                collection_id,
                address: addr,
                is_denied: true,
                changed_by: sender
            });
        };
        
        i = i + 1;
    };
}

public entry fun remove_from_deny_list(
    collection_cap: &mut CollectionCap,
    addrs: vector<address>,
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);
    let addr_count = vector::length(&addrs);
    
    // Basic validations
    assert!(addr_count > 0 && addr_count <= MAX_BATCH_SIZE, E_INVALID_BATCH_SIZE);
    assert!(sender == collection_cap.creator, E_NOT_CREATOR);
    assert!(collection_cap.has_deny_list_authority, E_INVALID_DENY_LIST_AUTHORITY);
    
    let collection_id = object::uid_to_inner(&collection_cap.id);
    
    let mut i = 0;
    while (i < addr_count) {
        let addr = *vector::borrow(&addrs, i);
        let deny_list = df::borrow_mut<DenyListKey, Table<address, bool>>(
            &mut collection_cap.id,
            DenyListKey {}
        );
        
        // Skip if address is not in deny list
        if (table::contains(deny_list, addr)) {
            table::remove(deny_list, addr);
            
            event::emit(DenyListStatusChanged {
                collection_id,
                address: addr,
                is_denied: false,
                changed_by: sender
            });
        };
        
        i = i + 1;
    };
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
public fun can_receive_art20(
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
    assert!(can_receive_art20(collection_cap, from), E_ADDRESS_DENIED);
    assert!(can_receive_art20(collection_cap, to), E_ADDRESS_DENIED);
}



// Update batch_transfer_tokens
public entry fun transfer_art20(
    mut tokens: vector<NFT>,
    recipients: vector<address>,
    collection_cap: &CollectionCap,
    mut sender_balances: vector<UserBalance>,
    clock: &Clock,
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);
    let token_count = vector::length(&tokens);
    let recipient_count = vector::length(&recipients);
    
    // Validate batch parameters
    assert!(token_count == recipient_count, E_INVALID_LENGTH);
    assert!(token_count <= MAX_BATCH_SIZE, E_MAX_BATCH_SIZE_EXCEEDED);
    assert!(token_count > 0, E_INVALID_BATCH_SIZE);
    
    // Calculate total available balance
    let mut total_available = 0u64;
    let mut i = 0;
    let n = vector::length(&sender_balances);
    while (i < n) {
        let balance = vector::borrow(&sender_balances, i);
        total_available = safe_add(total_available, balance.balance);
        i = i + 1;
    };
    
    // Verify sufficient total balance
    assert!(total_available >= token_count, E_INSUFFICIENT_BALANCE);
    
    // Check deny list for sender
    check_deny_list_restrictions(collection_cap, sender);
    
    // Prepare event data
    let mut token_ids = vector::empty<ID>();
    let mut amounts = vector::empty<u64>();
    let collection_id = object::uid_to_inner(&collection_cap.id);
    
    // Process each recipient
    let mut i = 0;
    while (i < recipient_count) {
        let recipient = *vector::borrow(&recipients, i);
        check_deny_list_restrictions(collection_cap, recipient);
        
        // Create recipient balance
        let recipient_balance = UserBalance {
            id: object::new(ctx),
            collection_id,
            balance: 1
        };
        
        // Pop token from tokens vector
        let token = vector::pop_back(&mut tokens);
        assert!(token.collection_id == collection_id, E_COLLECTION_MISMATCH);
        
        // Update sender balances
        let mut balance_updated = false;
let mut j = 0;
while (j < vector::length(&sender_balances)) {
        let balance = vector::borrow_mut(&mut sender_balances, j);
        // Add collection verification before updating balance
        if (balance.balance > 0 && balance.collection_id == collection_id) {
            balance.balance = safe_sub(balance.balance, 1);
            balance_updated = true;
            break
        };
        j = j + 1;
    };
        assert!(balance_updated, E_INSUFFICIENT_BALANCE);
        
        // Emit transfer event
        vector::push_back(&mut token_ids, object::uid_to_inner(&token.id));
        vector::push_back(&mut amounts, 1);
        event::emit(TransferEvent {
            from: sender,
            to: recipient,
            id: object::uid_to_inner(&token.id),
            royalty: 0,
            asset_id: token.asset_id,
        });
        
        // Transfer token and recipient balance
        transfer::transfer(token, recipient);
        transfer::transfer(recipient_balance, recipient);
        
        i = i + 1;
    };
    
    // Transfer remaining balances back to sender and delete empty ones
    let j = 0;
    while (j < vector::length(&sender_balances)) {
        let balance = vector::remove(&mut sender_balances, 0);
        if (balance.balance > 0) {
            transfer::transfer(balance, sender);
        } else {
            let UserBalance { id, .. } = balance;
            object::delete(id);
        }
        // Note: Since we're removing from index 0, the vector shrinks, so we don't increment j
    };
    
    // Clean up vectors
    vector::destroy_empty(tokens);
    vector::destroy_empty(sender_balances);
    
    // Emit batch event
    event::emit(BatchTransferEvent {
        from: sender,
        recipients,
        token_ids,
        amounts,
        collection_id,
        timestamp: clock::timestamp_ms(clock)
    });
}


// Modified burn_token to handle multiple balances
public entry fun burn_art20(
    token: NFT,
    collection_cap: &mut CollectionCap,
    user_balances: vector<UserBalance>,
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);
    assert!(sender == token.creator, E_NOT_OWNER);
    assert!(collection_cap.current_supply > 0, E_NO_TOKENS_TO_BURN);
    
    // Add verification that token belongs to collection
    assert!(token.collection_id == object::uid_to_inner(&collection_cap.id), E_COLLECTION_MISMATCH);
    
    let mut balances_mut = user_balances;
    let mut found = false;
    let mut used_balances = vector::empty<UserBalance>();
    
    while (!vector::is_empty(&balances_mut)) {
        let mut balance = vector::pop_back(&mut balances_mut);
        // Verify balance belongs to collection
        assert!(balance.collection_id == object::uid_to_inner(&collection_cap.id), E_COLLECTION_MISMATCH);
        
        if (!found && balance.balance > 0) {
            if (balance.balance == 1) {
                let UserBalance { id, collection_id: _, balance: _ } = balance;
                object::delete(id);
            } else {
                balance.balance = balance.balance - 1;
                vector::push_back(&mut used_balances, balance);
            };
            found = true;
        } else {
            vector::push_back(&mut used_balances, balance);
        }
    };
    
    assert!(found, E_INSUFFICIENT_BALANCE);
    
    // Return remaining balances
    while (!vector::is_empty(&used_balances)) {
        let balance = vector::pop_back(&mut used_balances);
        if (balance.balance > 0) {
            transfer::transfer(balance, sender);
        } else {
            let UserBalance { id, collection_id: _, balance: _ } = balance;
            object::delete(id);
        }
    };
    
    // Clean up balance vectors
    vector::destroy_empty(balances_mut);
    vector::destroy_empty(used_balances);
    
    // Burn the token
    collection_cap.current_supply = safe_sub(collection_cap.current_supply, 1);
    
    event::emit(BurnEvent {
        owner: sender,
        id: object::uid_to_inner(&token.id),
        
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
        collection_id: _, 
        category: _,
    } = token;
    
    object::delete(id);
}


    // Batch transfer function
   public entry fun batch_burn_art20(
    mut tokens: vector<NFT>,
    collection_cap: &mut CollectionCap,
    mut user_balances: vector<UserBalance>,
    ctx: &mut TxContext
) {
    let count = vector::length(&tokens);
    assert!(count <= MAX_BATCH_SIZE, E_MAX_BATCH_SIZE_EXCEEDED);

    // Calculate total balance
    let mut total_available = 0u64;
    let mut i = 0;
    let n = vector::length(&user_balances);
    while (i < n) {
        let balance = vector::borrow(&user_balances, i);
        total_available = safe_add(total_available, balance.balance);
        i = i + 1;
    };
    assert!(total_available >= count, E_INSUFFICIENT_BALANCE);
    assert!(collection_cap.current_supply >= count, E_NO_TOKENS_TO_BURN);

    let sender = tx_context::sender(ctx);
    let mut i = 0;
    while (i < count) {
        let token = vector::pop_back(&mut tokens);

        // Verify token belongs to collection
        assert!(token.collection_id == object::uid_to_inner(&collection_cap.id), E_COLLECTION_MISMATCH);

        // Decrement balance
        let mut balance_updated = false;
        let mut j = 0;
        while (j < vector::length(&user_balances)) {
            let balance = vector::borrow_mut(&mut user_balances, j);
            if (balance.balance > 0 && balance.collection_id == token.collection_id) {
                balance.balance = safe_sub(balance.balance, 1);
                balance_updated = true;
                break
            };
            j = j + 1;
        };
        assert!(balance_updated, E_INSUFFICIENT_BALANCE);

        // Burn the token
        burn_single_art20(token, collection_cap, ctx);

        i = i + 1;
    };

    // Transfer remaining balances back to sender and delete empty ones
    let j = 0;
    while (j < vector::length(&user_balances)) {
        let balance = vector::remove(&mut user_balances, 0);
        if (balance.balance > 0) {
            transfer::transfer(balance, sender);
        } else {
            let UserBalance { id, .. } = balance;
            object::delete(id);
        }
        // No need to increment j since vector shrinks
    };

    // Clean up vectors
    vector::destroy_empty(tokens);
    vector::destroy_empty(user_balances);
}

public entry fun set_collection_value_source(
    collection_cap: &mut CollectionCap,
    value_source: vector<u8>,
    is_api: bool,
    clock: &Clock,
    ctx: &mut TxContext
) {
    // Only creator can set value source
    assert!(tx_context::sender(ctx) == collection_cap.creator, E_NOT_CREATOR);
    
    // Convert value_source to string
    let source_str = string::utf8(value_source);
    
    // Validate the source based on type
    if (is_api) {
        // Basic validation for API endpoint
        // Must start with https:// and be less than 256 chars
        let source_bytes = string::as_bytes(&source_str);
        assert!(vector::length(source_bytes) <= 256, E_INVALID_LENGTH);
        
        // Validate that it starts with https://
        let https_prefix = b"https://";
        let prefix_len = vector::length(&https_prefix);
        assert!(vector::length(source_bytes) >= prefix_len, E_INVALID_API_ENDPOINT);
        
        let mut i = 0;
        let mut valid_prefix = true;
        while (i < prefix_len) {
            if (*vector::borrow(source_bytes, i) != *vector::borrow(&https_prefix, i)) {
                valid_prefix = false;
                break
            };
            i = i + 1;
        };
        assert!(valid_prefix, E_INVALID_API_ENDPOINT);
    } else {
        // Basic validation for oracle address
        // Must be 64 characters long (32 bytes in hex)
        assert!(
            string::length(&source_str) == 64,
            E_INVALID_ORACLE_ADDRESS
        );
    };
    
    // Update the value source
    if (option::is_none(&collection_cap.value_source)) {
        collection_cap.value_source = option::some(source_str);
    } else {
        *option::borrow_mut(&mut collection_cap.value_source) = source_str;
    };
    collection_cap.is_api_source = is_api;

    // Emit event
    event::emit(CollectionValueSourceUpdated {
        collection_id: object::uid_to_inner(&collection_cap.id),
        is_api,
        source: source_str,
        timestamp: clock::timestamp_ms(clock)
    });
}


public entry fun create_category(
    registry: &mut CategoryRegistry,
    name: String,
    description: String,
    clock: &Clock,
    ctx: &mut TxContext
) {
    assert!(tx_context::sender(ctx) == registry.admin, E_NOT_CREATOR);
    assert!(!table::contains(&registry.categories, name), E_CATEGORY_ALREADY_EXISTS);
    
    let category = Category {
        name: name,
        description: description,
        is_active: true,
        created_at: clock::timestamp_ms(clock)
    };
    
    table::add(&mut registry.categories, name, category);
    
    event::emit(CategoryCreated {
        name: name,
        description: description,
        timestamp: clock::timestamp_ms(clock)
    });
}



fun burn_single_art20(
    token: NFT,
    collection_cap: &mut CollectionCap,
    ctx: &TxContext
) {
    let sender = tx_context::sender(ctx);
    collection_cap.current_supply = safe_sub(collection_cap.current_supply, 1);
    
    event::emit(BurnEvent {
        owner: sender,
        id: object::uid_to_inner(&token.id),
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
        collection_id: _,
        category: _ // Added category field
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
    collection_cap: &CollectionCap,
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);
    let collection_id = get_collection_cap_id(collection_cap);
    let n = vector::length(&tokens);
    
    // Basic validations
    assert!(collection_cap.is_mutable, E_TOKEN_NOT_MUTABLE);
    assert!(n == vector::length(&new_logo_uris), E_MISMATCH_TOKENS_AND_URIS);
    assert!(n > 0 && n <= MAX_BATCH_SIZE, E_INVALID_BATCH_SIZE);
    
    // Add deny list check
    check_deny_list_restrictions(collection_cap, sender);

    // Validate all logo URIs lengths and structure first
    let mut i = 0;
    while (i < vector::length(&new_logo_uris)) {
        let logo_uri = vector::borrow(&new_logo_uris, i);
        // URI length validation
        assert!(vector::length(logo_uri) <= 256, E_INVALID_LENGTH);
        assert!(vector::length(logo_uri) > 0, E_INVALID_LENGTH);

        // Validate URI is valid bytes that can be converted to URL
        let _test_url = url::new_unsafe_from_bytes(*logo_uri);
        i = i + 1;
    };

    let mut updated_nfts = vector::empty<NFT>();
    let mut i = 0;
    while (i < n) {
        let mut token = vector::pop_back(&mut tokens);
        
        // Verify token belongs to collection
        assert!(token.collection_id == collection_id, E_COLLECTION_MISMATCH);
        // Verify ownership/creator
        assert!(sender == token.creator, E_NOT_CREATOR);

        // Get corresponding logo URI
        let new_logo_uri = *vector::borrow(&new_logo_uris, i);
        
        // Update logo URI
        token.logo_uri = url::new_unsafe_from_bytes(new_logo_uri);

        // Emit update event
        event::emit(LogoURIUpdateEvent {
            id: object::uid_to_inner(&token.id),
            artinals_id: token.artinals_id,
            new_logo_uri: token.logo_uri,
        });

        vector::push_back(&mut updated_nfts, token);
        i = i + 1;
    };

    // Return remaining unprocessed tokens
    while (!vector::is_empty(&tokens)) {
        let token = vector::pop_back(&mut tokens);
        vector::push_back(&mut updated_nfts, token);
    };

    // Return all tokens to sender
    while (!vector::is_empty(&updated_nfts)) {
        let token = vector::pop_back(&mut updated_nfts);
        transfer::transfer(token, sender);
    };

    // Clean up vectors
    vector::destroy_empty(tokens);
    vector::destroy_empty(updated_nfts);
}

// Single NFT logo URI update
public entry fun update_art20_image_uri_by_asset_id(
    collection_cap: &CollectionCap,
    mut nfts: vector<NFT>,
    asset_id: u64,
    new_logo_uri: vector<u8>,
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);
    let collection_id = get_collection_cap_id(collection_cap);
    
    // Basic validations
    assert!(collection_cap.is_mutable, E_TOKEN_NOT_MUTABLE);
    
    // Add deny list check
    check_deny_list_restrictions(collection_cap, sender);

    // URI length validation
    assert!(vector::length(&new_logo_uri) <= 256, E_INVALID_LENGTH);
    assert!(vector::length(&new_logo_uri) > 0, E_INVALID_LENGTH);

    // Validate URI is valid bytes that can be converted to URL
    let _test_url = url::new_unsafe_from_bytes(new_logo_uri);
    
    let mut updated_nfts = vector::empty<NFT>();
    let nft_count = vector::length(&nfts);
    let mut i = 0;
    let mut found = false;

    while (i < nft_count) {
        let mut token = vector::pop_back(&mut nfts);
        
        // Verify token belongs to collection and matches asset_id
        if (token.collection_id == collection_id && token.asset_id == asset_id && !found) {
            assert!(sender == token.creator, E_NOT_CREATOR);
            token.logo_uri = url::new_unsafe_from_bytes(new_logo_uri);

            event::emit(LogoURIUpdateEvent {
                id: object::uid_to_inner(&token.id),
                artinals_id: token.artinals_id,
                new_logo_uri: token.logo_uri,
            });

            found = true;
        };
        vector::push_back(&mut updated_nfts, token);
        i = i + 1;
    };

    assert!(found, ASSET_ID_NOT_FOUND);

    // Return NFTs to sender
    while (!vector::is_empty(&updated_nfts)) {
        let token = vector::pop_back(&mut updated_nfts);
        transfer::transfer(token, sender);
    };
    
    vector::destroy_empty(nfts);
    vector::destroy_empty(updated_nfts);
}

// Batch NFT logo URI update
public entry fun batch_update_art20_image_uri_by_asset_ids(
    collection_cap: &CollectionCap,
    mut nfts: vector<NFT>,
    asset_ids: vector<u64>,
    new_logo_uris: vector<vector<u8>>,
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);
    let collection_id = get_collection_cap_id(collection_cap);
    
    // Basic validations
    assert!(collection_cap.is_mutable, E_TOKEN_NOT_MUTABLE);
    
    // Add deny list check
    check_deny_list_restrictions(collection_cap, sender);
    
    let asset_count = vector::length(&asset_ids);
    assert!(asset_count == vector::length(&new_logo_uris), E_MISMATCH_TOKENS_AND_URIS);
    assert!(asset_count > 0 && asset_count <= MAX_BATCH_SIZE, E_INVALID_BATCH_SIZE);

    // Validate all logo URIs lengths first
    let mut i = 0;
    while (i < vector::length(&new_logo_uris)) {
        let logo_uri = vector::borrow(&new_logo_uris, i);
        assert!(vector::length(logo_uri) <= 256, E_INVALID_LENGTH);
        assert!(vector::length(logo_uri) > 0, E_INVALID_LENGTH);
        // Validate URI format
        let _test_url = url::new_unsafe_from_bytes(*logo_uri);
        i = i + 1;
    };

    // Add duplicate check
    let mut processed_ids = table::new<u64, bool>(ctx);

    let mut i = 0;
    while (i < asset_count) {
        let asset_id = *vector::borrow(&asset_ids, i);
        let new_logo_uri = vector::borrow(&new_logo_uris, i);

        // Check for duplicate asset_id
        assert!(!table::contains(&processed_ids, asset_id), E_DUPLICATE_ASSET_ID);
        table::add(&mut processed_ids, asset_id, true);

        let mut found = false;
        let mut updated_nfts = vector::empty();

        while (!vector::is_empty(&nfts)) {
            let mut nft = vector::pop_back(&mut nfts);
            
            if (!found && nft.collection_id == collection_id && nft.asset_id == asset_id) {
                assert!(sender == nft.creator, E_NOT_CREATOR);
                
                nft.logo_uri = url::new_unsafe_from_bytes(*new_logo_uri);

                event::emit(LogoURIUpdateEvent {
                    id: object::uid_to_inner(&nft.id),
                    artinals_id: nft.artinals_id,
                    new_logo_uri: nft.logo_uri,
                });

                found = true;
            };
            vector::push_back(&mut updated_nfts, nft);
        };

        // Restore NFTs from temporary vector
        while (!vector::is_empty(&updated_nfts)) {
            vector::push_back(&mut nfts, vector::pop_back(&mut updated_nfts));
        };
        vector::destroy_empty(updated_nfts);

        assert!(found, ASSET_ID_NOT_FOUND);
        i = i + 1;
    };

    // Clean up resources
    table::drop(processed_ids);

    // Return NFTs to sender
    while (!vector::is_empty(&nfts)) {
        let nft = vector::pop_back(&mut nfts);
        transfer::transfer(nft, sender);
    };

    vector::destroy_empty(nfts);
}

   
public entry fun transfer_art20_in_quantity(
    mut tokens: vector<NFT>,
    recipient: address, 
    quantity: u64, 
    collection_cap: &CollectionCap,
    sender_balances: vector<UserBalance>,
    clock: &Clock,
    ctx: &mut TxContext
) {
    assert!(quantity > 0, E_INVALID_BATCH_SIZE);
    let sender = tx_context::sender(ctx);
    validate_transfer(collection_cap, sender, recipient);
    let collection_id = object::uid_to_inner(&collection_cap.id);
    
    let sender_nft_count = vector::length(&tokens);
    assert!(sender_nft_count >= quantity, E_INSUFFICIENT_TOKENS);
    
    // Calculate total available balance
    let mut total_available = 0u64;
    let mut i = 0;
    let n = vector::length(&sender_balances);
    while (i < n) {
        let balance = vector::borrow(&sender_balances, i);
        total_available = safe_add(total_available, balance.balance);
        i = i + 1;
    };
    
    assert!(total_available >= quantity, E_INSUFFICIENT_BALANCE);
    
    // Create recipient balance
    let recipient_balance = UserBalance {
        id: object::new(ctx),
        collection_id: object::uid_to_inner(&collection_cap.id),
        balance: quantity
    };
    
    // Process sender balances
    let mut sender_balances_mut = sender_balances;
    let mut remaining_quantity = quantity;
    let mut used_balances = vector::empty<UserBalance>();
    
    while (remaining_quantity > 0) {
        let mut balance = vector::pop_back(&mut sender_balances_mut);
        assert!(balance.collection_id == collection_id, E_COLLECTION_MISMATCH);
        if (balance.balance <= remaining_quantity) {
            // Use entire balance
            remaining_quantity = remaining_quantity - balance.balance;
            let UserBalance { id, collection_id: _, balance: _ } = balance;
            object::delete(id);
        } else {
            // Use partial balance
            balance.balance = balance.balance - remaining_quantity;
            remaining_quantity = 0;
            vector::push_back(&mut used_balances, balance);
        };
    };
    
    // Return remaining balances
    while (!vector::is_empty(&sender_balances_mut)) {
        let balance = vector::pop_back(&mut sender_balances_mut);
        assert!(balance.collection_id == collection_id, E_COLLECTION_MISMATCH);
        vector::push_back(&mut used_balances, balance);
    };
    
    // Transfer updated balances back
    while (!vector::is_empty(&used_balances)) {
        let balance = vector::pop_back(&mut used_balances);
        if (balance.balance > 0) {
            transfer::transfer(balance, sender);
        } else {
            let UserBalance { id, collection_id: _, balance: _ } = balance;
            object::delete(id);
        }
    };
    
    // Transfer recipient balance
    transfer::transfer(recipient_balance, recipient);
    
    // Handle NFT transfers
    let mut token_ids = vector::empty<ID>();
    let mut amounts = vector::empty<u64>();
    let collection_id = object::uid_to_inner(&collection_cap.id);
    
    let mut i = 0;
    while (i < quantity) {
        let token = vector::pop_back(&mut tokens);
        assert!(collection_id == token.collection_id, E_COLLECTION_MISMATCH);
        
        vector::push_back(&mut token_ids, object::uid_to_inner(&token.id));
        vector::push_back(&mut amounts, 1);
        
        event::emit(TransferEvent {
            from: sender,
            to: recipient,
            id: object::uid_to_inner(&token.id),
            royalty: 0,
            asset_id: token.asset_id,
        });
        
        transfer::transfer(token, recipient);
        i = i + 1;
    };
    
    // Return remaining tokens
    while (!vector::is_empty(&tokens)) {
        let token = vector::pop_back(&mut tokens);
        transfer::transfer(token, sender);
    };
    
    // Clean up
    vector::destroy_empty(tokens);
    vector::destroy_empty(sender_balances_mut);
    vector::destroy_empty(used_balances);
    
    event::emit(BatchTransferEvent {
        from: sender,
        recipients: vector[recipient],
        token_ids,
        amounts,
        collection_id,
        timestamp: clock::timestamp_ms(clock)
    });
}

public entry fun transfer_art20_by_asset_ids(
    collection_cap: &CollectionCap,
    mut nfts: vector<NFT>,
    mut user_balances: vector<UserBalance>,
    asset_ids: vector<u64>,
    recipient: address,
    clock: &Clock,
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);
    let collection_id = get_collection_cap_id(collection_cap);
    let asset_count = vector::length(&asset_ids);

    // Use validate_transfer to check both addresses
    validate_transfer(collection_cap, sender, recipient);

    // Validate recipient is not in the deny list
    check_deny_list_restrictions(collection_cap, recipient);

    // Initialize vectors for transfer events
    let mut token_ids = vector::empty<ID>();
    let mut amounts = vector::empty<u64>();

    // Process each asset ID
    let mut i = 0;
    while (i < asset_count) {
        let asset_id = *vector::borrow(&asset_ids, i);

        // Get the NFT and its owner
        let (mut nft_id_opt, mut owner_opt) = get_nft_by_asset_id(collection_cap, &nfts, asset_id);

        // Ensure the NFT exists and is owned by the sender
        assert!(option::is_some(&nft_id_opt), ASSET_ID_NOT_FOUND);
        assert!(option::is_some(&owner_opt), E_NOT_OWNER);
        let nft_id = option::extract(&mut nft_id_opt);
        let owner = option::extract(&mut owner_opt);
        assert!(owner == sender, E_NOT_OWNER);

        // Locate and transfer the NFT
        let nft_count = vector::length(&nfts);
        let mut j = 0;
        let mut found = false;

        while (j < nft_count) {
            let token = vector::borrow_mut(&mut nfts, j);
            if (token.collection_id == collection_id && token.asset_id == asset_id && !found) {
                // Update user balances
                let mut balance_found = false;
                let mut k = 0;
                while (k < vector::length(&user_balances)) {
                    let balance = vector::borrow_mut(&mut user_balances, k);
                    if (balance.collection_id == collection_id && balance.balance > 0) {
                        balance.balance = safe_sub(balance.balance, 1);
                        balance_found = true;
                        break
                    };
                    k = k + 1;
                };
                assert!(balance_found, E_INSUFFICIENT_BALANCE);

                // Add event details
                vector::push_back(&mut token_ids, nft_id);
                vector::push_back(&mut amounts, 1);

                // Transfer the token to the recipient
                let nft = vector::remove(&mut nfts, j); // Explicitly remove the NFT
                transfer::transfer(nft, recipient);

                found = true;
                break;
            };
            j = j + 1;
        };
        assert!(found, ASSET_ID_NOT_FOUND);
        i = i + 1;
    };

    // Emit batch transfer event
    event::emit(BatchTransferEvent {
        from: sender,
        recipients: vector[recipient],
        token_ids,
        amounts,
        collection_id,
        timestamp: clock::timestamp_ms(clock),
    });

    // Process user balances and clean up empty ones
    let mut k = 0;
    while (k < vector::length(&user_balances)) {
        let balance = vector::borrow_mut(&mut user_balances, k);
        if (balance.balance == 0) {
            let removed_balance = vector::remove(&mut user_balances, k); // Explicitly remove the empty balance
            cleanup_empty_balance(removed_balance);
        } else {
            k = k + 1;
        }
    };

    // Transfer remaining balances back to the sender
    while (!vector::is_empty(&user_balances)) {
        let balance = vector::pop_back(&mut user_balances);
        transfer::transfer(balance, sender);
    };

    // Clean up vectors
    vector::destroy_empty(nfts);
    vector::destroy_empty(user_balances);
    vector::destroy_empty(token_ids);
    vector::destroy_empty(amounts);
}



public fun get_user_balance(user_balance: &UserBalance): u64 {
    user_balance.balance
}



public(package) fun create_user_balance(
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

public fun get_holder_info(
    nfts: &vector<NFT>,
    collection_cap: &CollectionCap,
    user_balances: &vector<UserBalance>,
    addr: address
): (
    // Collection Info
    ID, // collection_id
    address, // creator
    String, // collection name
    String, // collection description
    u64, // current supply
    u64, // max supply
    bool, // is_mutable
    // Holder Info
    u64, // total balance
    bool, // is denied
    bool, // has deny list
    bool, // deny list authority active
    u64,  // total deny list size
    vector<ID>, // nft_ids
    vector<u64>, // asset_ids
    vector<String>, // nft_names
    vector<String>, // nft_descriptions
    vector<Url>, // nft_uris
    vector<Url>, // nft_logo_uris
) {
    // Get collection info
    let collection_id = get_collection_cap_id(collection_cap);
    
    // Calculate total balance
    let mut total_balance = 0;
    let mut i = 0;
    let n = vector::length(user_balances);
    while (i < n) {
        let balance = vector::borrow(user_balances, i);
        if (get_user_balance_collection_id(balance) == collection_id) {
            total_balance = total_balance + get_user_balance_amount(balance);
        };
        i = i + 1;
    };

    // Get deny list information
    let has_deny_list = has_deny_list(collection_cap);
    let deny_list_authority = has_deny_list_authority(collection_cap);
    let is_denied = is_denied(collection_cap, addr);
    let deny_list_size = if (has_deny_list) {
        deny_list_size(collection_cap)
    } else {
        0
    };

    // Initialize vectors for NFT details
    let mut nft_ids = vector::empty<ID>();
    let mut asset_ids = vector::empty<u64>();
    let mut nft_names = vector::empty<String>();
    let mut nft_descriptions = vector::empty<String>();
    let mut nft_uris = vector::empty<Url>();
    let mut nft_logo_uris = vector::empty<Url>();

    // Collect NFT details
    let mut j = 0;
    let nft_count = vector::length(nfts);
    while (j < nft_count) {
        let nft = vector::borrow(nfts, j);
        if (nft.collection_id == collection_id) {
            vector::push_back(&mut nft_ids, object::uid_to_inner(&nft.id));
            vector::push_back(&mut asset_ids, nft.asset_id);
            vector::push_back(&mut nft_names, *&nft.name);
            vector::push_back(&mut nft_descriptions, *&nft.description);
            vector::push_back(&mut nft_uris, nft.uri);
            vector::push_back(&mut nft_logo_uris, nft.logo_uri);
        };
        j = j + 1;
    };

    (
        // Collection Info
        collection_id,
        collection_cap.creator,
        collection_cap.name,
        collection_cap.description,
        collection_cap.current_supply,
        collection_cap.max_supply,
        collection_cap.is_mutable,
        // Holder Info
        total_balance,
        is_denied,
        has_deny_list,
        deny_list_authority,
        deny_list_size,
        nft_ids,
        asset_ids,
        nft_names,
        nft_descriptions,
        nft_uris,
        nft_logo_uris,
    )
}

public fun get_nfts_by_asset_ids(
    collection_cap: &CollectionCap,
    nfts: &vector<NFT>,
    asset_ids: vector<u64>
): (
    vector<ID>, // nft_object_ids
    vector<address>, // owner_addresses
    vector<u64>, // found_asset_ids
    vector<u64> // not_found_asset_ids
) {
    let collection_id = get_collection_cap_id(collection_cap);
    
    // Initialize return vectors
    let mut nft_object_ids = vector::empty<ID>();
    let mut owner_addresses = vector::empty<address>();
    let mut found_asset_ids = vector::empty<u64>();
    let mut not_found_asset_ids = vector::empty<u64>();

    // Process each requested asset ID
    let asset_count = vector::length(&asset_ids);
    let mut i = 0;
    while (i < asset_count) {
        let asset_id = *vector::borrow(&asset_ids, i);
        let mut found = false;
        
        // Search through NFTs for matching asset ID
        let nft_count = vector::length(nfts);
        let mut j = 0;
        while (j < nft_count) {
            let nft = vector::borrow(nfts, j);
            
            // Check if NFT belongs to collection and matches asset ID
            if (nft.collection_id == collection_id && nft.asset_id == asset_id) {
                vector::push_back(&mut nft_object_ids, object::uid_to_inner(&nft.id));
                vector::push_back(&mut owner_addresses, nft.creator);
                vector::push_back(&mut found_asset_ids, asset_id);
                found = true;
                break
            };
            j = j + 1;
        };

        // Track unfound asset IDs
        if (!found) {
            vector::push_back(&mut not_found_asset_ids, asset_id);
        };

        i = i + 1;
    };

    (
        nft_object_ids,
        owner_addresses,
        found_asset_ids,
        not_found_asset_ids
    )
}

public fun get_collection_value_source(
    collection_cap: &CollectionCap
): (Option<String>, bool) {
    (
        *&collection_cap.value_source,
        collection_cap.is_api_source
    )
}

public fun get_all_categories(
   registry: &CategoryRegistry
): vector<String> {
   let mut result = vector::empty<String>();
   let categories = &registry.categories;
   
   let category_ref = table::borrow(categories, string::utf8(b""));
   vector::push_back(&mut result, *&category_ref.name);
   
   result 
}

// Single asset ID lookup version
public fun get_nft_by_asset_id(
    collection_cap: &CollectionCap,
    nfts: &vector<NFT>,
    asset_id: u64
): (Option<ID>, Option<address>) {
    let collection_id = get_collection_cap_id(collection_cap);
    
    let nft_count = vector::length(nfts);
    let mut i = 0;
    while (i < nft_count) {
        let nft = vector::borrow(nfts, i);
        if (nft.collection_id == collection_id && nft.asset_id == asset_id) {
            return (
                option::some(object::uid_to_inner(&nft.id)),
                option::some(nft.creator)
            )
        };
        i = i + 1;
    };

    (option::none(), option::none())
}

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

    // Function to update collection supply
    public fun update_collection_supply(cap: &mut CollectionCap, new_supply: u64) {
        cap.current_supply = new_supply;
    }

    // Getter for collection current supply if not already present
    public fun get_collection_current_supply(cap: &CollectionCap): u64 {
        cap.current_supply
    }

    // Getters 
    public fun get_user_balance_amount(balance: &UserBalance): u64 {
        balance.balance
    }

    public fun set_user_balance_amount(balance: &mut UserBalance, amount: u64) {
        balance.balance = amount;
    }

    public fun get_nft_id(nft: &NFT): ID {
        object::uid_to_inner(&nft.id)
    }

    /// Getter for the `asset_id` field.
    public fun get_nft_asset_id(nft: &NFT): u64 {
        nft.asset_id
    }

    public fun cleanup_empty_balance(balance: UserBalance) {
    assert!(get_user_balance_amount(&balance) == 0, E_INSUFFICIENT_BALANCE);
    let UserBalance { id, collection_id: _, balance: _ } = balance;
    object::delete(id);
}

// Basic getter that only requires CollectionCaps
public fun get_all_collection_ids(collection_caps: &vector<CollectionCap>): vector<ID> {
    let mut collection_ids = vector::empty<ID>();
    let cap_count = vector::length(collection_caps);
    let mut i = 0;
    
    while (i < cap_count) {
        let cap = vector::borrow(collection_caps, i);
        vector::push_back(&mut collection_ids, get_collection_cap_id(cap));
        i = i + 1;
    };
    
    collection_ids
}

// Comprehensive getter with all collection details
public fun get_collections_info(
    collection_caps: &vector<CollectionCap>
): (
    vector<ID>, // collection_ids
    vector<address>, // creators
    vector<String>, // names
    vector<String>, // descriptions
    vector<Url>, // uris
    vector<Url>, // logo_uris
    vector<u64>, // current_supplies
    vector<u64>, // max_supplies
    vector<bool>, // mutability_flags
    vector<bool>  // deny_list_authorities
) {
    let mut collection_ids = vector::empty<ID>();
    let mut creators = vector::empty<address>();
    let mut names = vector::empty<String>();
    let mut descriptions = vector::empty<String>();
    let mut uris = vector::empty<Url>();
    let mut logo_uris = vector::empty<Url>();
    let mut current_supplies = vector::empty<u64>();
    let mut max_supplies = vector::empty<u64>();
    let mut mutability_flags = vector::empty<bool>();
    let mut deny_list_authorities = vector::empty<bool>();
    
    let cap_count = vector::length(collection_caps);
    let mut i = 0;
    
    while (i < cap_count) {
        let cap = vector::borrow(collection_caps, i);
        
        vector::push_back(&mut collection_ids, get_collection_cap_id(cap));
        vector::push_back(&mut creators, cap.creator);
        vector::push_back(&mut names, *&cap.name);
        vector::push_back(&mut descriptions, *&cap.description);
        vector::push_back(&mut uris, cap.uri);
        vector::push_back(&mut logo_uris, cap.logo_uri);
        vector::push_back(&mut current_supplies, cap.current_supply);
        vector::push_back(&mut max_supplies, cap.max_supply);
        vector::push_back(&mut mutability_flags, cap.is_mutable);
        vector::push_back(&mut deny_list_authorities, cap.has_deny_list_authority);
        
        i = i + 1;
    };
    
    (
        collection_ids,
        creators,
        names,
        descriptions,
        uris,
        logo_uris,
        current_supplies,
        max_supplies,
        mutability_flags,
        deny_list_authorities
    )
}

// Get details for a specific collection
public fun get_collection_details(
    collection_cap: &CollectionCap
): (
    ID, // collection_id
    address, // creator
    String, // name
    String, // description
    Url, // uri
    Url, // logo_uri
    u64, // current_supply
    u64, // max_supply
    bool, // is_mutable
    bool, // has_deny_list_authority
    u64  // deny_list_size
) {
    (
        get_collection_cap_id(collection_cap),
        collection_cap.creator,
        *&collection_cap.name,
        *&collection_cap.description,
        collection_cap.uri,
        collection_cap.logo_uri,
        collection_cap.current_supply,
        collection_cap.max_supply,
        collection_cap.is_mutable,
        collection_cap.has_deny_list_authority,
        if (has_deny_list(collection_cap)) { deny_list_size(collection_cap) } else { 0 }
    )
}

// Additional helper to check if a collection exists
public fun collection_exists(
    collection_caps: &vector<CollectionCap>,
    collection_id: ID
): bool {
    let cap_count = vector::length(collection_caps);
    let mut i = 0;
    
    while (i < cap_count) {
        let cap = vector::borrow(collection_caps, i);
        if (get_collection_cap_id(cap) == collection_id) {
            return true
        };
        i = i + 1;
    };
    
    false
}

public fun get_category_info(
    registry: &CategoryRegistry,
    name: String
): (String, String, bool, u64) {
    let category = table::borrow(&registry.categories, name);
    (
        *&category.name,
        *&category.description,
        category.is_active,
        category.created_at
    )
}



public fun get_fee_info(fee_config: &FeeConfig): (u64, TypeName, address) {
    (fee_config.fee_amount, fee_config.fee_coin_type, fee_config.fee_collector)
}

public fun get_fee_amount(fee_config: &FeeConfig): u64 {
    fee_config.fee_amount
}

public fun get_fee_coin_type(fee_config: &FeeConfig): TypeName {
    fee_config.fee_coin_type
}

public fun verify_admin(admin_cap: &AdminCap, addr: address): bool {
        admin_cap.owner == addr
    }

}
