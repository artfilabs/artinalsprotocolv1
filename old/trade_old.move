module artinals::TRADE {
    use sui::coin::{Self, Coin};
    use sui::package;
    use sui::balance::{Self, Balance, Supply};
    use sui::event;
    use sui::table::{Self, Table};
    

    // Import from ART20
    use artinals::ART20::{Self, NFT, CollectionCap, UserBalance};

    // Error constants
    const E_INSUFFICIENT_LIQUIDITY: u64 = 1;
    // const E_INSUFFICIENT_INPUT: u64 = 2;
    const E_PRICE_IMPACT_TOO_HIGH: u64 = 3;
    const E_INVALID_POOL: u64 = 4;
    const E_INVALID_TOKEN_AMOUNT: u64 = 5;
    const E_INVALID_NFT_AMOUNT: u64 = 6;
    const E_POOL_NOT_ACTIVE: u64 = 7;
    const E_SLIPPAGE_EXCEEDED: u64 = 8;
    const E_INVALID_FEE: u64 = 9;
    const E_NOT_POOL_OWNER: u64 = 10;
    const E_ZERO_LIQUIDITY: u64 = 11;
    const E_INVALID_LP_TOKENS: u64 = 12;
    const E_INSUFFICIENT_BALANCE: u64 =13;
    const E_POOL_EXISTS: u64 = 14;
    const MAX_BATCH_SIZE: u64 = 100; // Maximum NFTs per operation
    const MIN_BATCH_SIZE: u64 = 1;   // Minimum NFTs per operation
    const E_COOLDOWN_NOT_EXPIRED: u64 = 15;
    const E_DIVIDE_BY_ZERO: u64 = 16;
    const E_MATH_OVERFLOW: u64 = 17;
    const E_INVALID_TRADE_SIZE: u64 = 18;
    const E_NO_FEES_TO_COLLECT: u64 = 19;
    const E_NOT_CONTRACT_OWNER: u64 = 20;
    

    // Pool limits and constants
    // Pool limits and constants
    const MAX_FEE_PERCENT: u64 = 1000; // 10% max fee (basis points)
    const MAX_U64: u64 = 18446744073709551615; // Maximum value for u64
    const MIN_LIQUIDITY: u64 = 1000;
    const PRICE_PRECISION: u64 = 1000000; // 6 decimal places
    const MAX_PRICE_IMPACT: u64 = 10000; // 10% max price impact (basis points)
    const MAX_SLIPPAGE: u64 = 500; // 5% max slippage allowed
    const EMERGENCY_COOLDOWN: u64 = 3600; // 1 hour cooldown
    const MAX_TOKEN_PER_TRADE: u64 = 1000000000; // 1 billion tokens max per trade
    const MIN_TOKEN_PER_TRADE: u64 = 100; // Minimum tokens per trade
    const MAX_SAMPLES: u64 = 24; // Keep 24 samples
    const DEFAULT_SAMPLE_PERIOD: u64 = 3600; // 1 hour in seconds   

    // One-Time-Witness for the module
    public struct TRADE has drop {}

    // LP Token for tracking liquidity shares
    public struct LPToken<phantom CURRENCY: store> has drop, store {}

    // Main trading pool structure
    public struct TradingPool<phantom CURRENCY: store> has key, store {
        id: UID,
        collection_id: ID,
        nft_reserve: u64,
        token_reserve: Balance<CURRENCY>,
        lp_supply: Supply<LPToken<CURRENCY>>,
        lp_shares: Balance<LPToken<CURRENCY>>,
        fee_percent: u64,
        min_price: u64,
        max_price: u64,
        is_active: bool,
        owner: address,
        last_block_timestamp: u64,
        total_volume_tokens: u64,
        total_volume_nfts: u64,
        last_trade_price: u64,   
        accumulated_fees: Balance<CURRENCY>,
        contract_owner_accumulated_fees: Balance<CURRENCY>,
        last_fee_distribution: u64,          
        total_fees_collected: u64,            
        pending_fees: u64,        
        nft_holdings: Table<u64, NFT>,
    }

public struct AdminCap has key {
    id: UID,
    owner: address,
    global_owner_fee: u64,
    total_fees_collected: u64,
    last_collection_time: u64
}

// Event for fee collection
public struct ContractOwnerFeeCollected<phantom CURRENCY: store> has copy, drop {
    pool_id: ID,
    amount: u64,
    owner: address,
    total_collected: u64,
    timestamp: u64
}

// Event for fee collection failure
public struct FeeCollectionFailed<phantom CURRENCY: store> has copy, drop {
    pool_id: ID,
    owner: address,
    reason: u64,
    timestamp: u64
}

    public struct CollectionPool<phantom CURRENCY: store> has key {
        id: UID,
        collection_id: ID,
        pool_id: Option<ID>,  // Track single pool ID
        active_pools: Table<ID, TradingPool<CURRENCY>>,
        total_volume: u64,
        total_nfts: u64,
        floor_price: u64,
        last_trade_price: u64,
        trades_24h: u64,
        last_trade_timestamp: u64,
        price_history: vector<TradePrice>
    }

public struct TradePrice has store, drop {
    price: u64,
    timestamp: u64,
    is_nft_to_token: bool 
}

public struct CollectionStats has copy, drop {
    total_pools: u64,
    total_volume: u64,
    total_nfts_locked: u64,
    floor_price: u64,
    highest_price: u64,
    average_price_24h: u64,
    total_trades_24h: u64
}

public struct CollectionStatUpdate<phantom CURRENCY: store> has copy, drop {
    collection_id: ID,
    total_pools: u64,
    total_volume: u64,
    floor_price: u64,
    nfts_locked: u64,
    timestamp: u64
}

    
    // User's liquidity position
     public struct LiquidityPosition<phantom CURRENCY: store> has key, store {
        id: UID,
        pool_id: ID,
        lp_tokens: Balance<LPToken<CURRENCY>>,
        nft_contributed: u64,
        tokens_contributed: u64,
        fees_earned: u64,
        last_update_timestamp: u64
    }

    // Events
   public struct PoolCreated<phantom CURRENCY: store> has copy, drop {
        pool_id: ID,
        collection_id: ID,
        initial_nft_reserve: u64,
        initial_token_reserve: u64,
        creator: address,
        fee_percent: u64
    }

    public struct LiquidityAdded<phantom CURRENCY: store> has copy, drop {
        pool_id: ID,
        provider: address,
        nft_amount: u64,
        token_amount: u64,
        lp_tokens_minted: u64
    }

    public struct LiquidityRemoved<phantom CURRENCY: store> has copy, drop {
        pool_id: ID,
        provider: address,
        nft_amount: u64,
        token_amount: u64,
        lp_tokens_burned: u64
    }

   public struct TradeExecuted<phantom CURRENCY: store> has copy, drop {
    pool_id: ID,
    trader: address,
    nft_amount: u64,
    token_amount: u64,
    is_buy: bool,
    price_impact: u64,
    timestamp: u64
}

    public struct CollectionTradeEvent<phantom CURRENCY: store> has copy, drop {
    collection_id: ID,
    pool_id: ID,
    price: u64,
    amount: u64,
    is_nft_to_token: bool,
    floor_price: u64
}

    public struct CollectionStatsUpdated<phantom CURRENCY: store> has copy, drop {
    collection_id: ID,
    new_floor_price: u64,
    total_volume: u64,
    total_nfts: u64
}

public struct PoolStatusChanged<phantom CURRENCY: store> has copy, drop {
    pool_id: ID,
    old_status: bool,
    new_status: bool,
    changed_by: address,
    timestamp: u64
}

public struct PoolFeesUpdated<phantom CURRENCY: store> has copy, drop {
    pool_id: ID,
    old_fee: u64,
    new_fee: u64,
    changed_by: address,
    timestamp: u64
}

// Price Oracle Integration
public struct PriceOracle<phantom CURRENCY: store> has key, store {
    id: UID,
    price_cumulative: u64,
    last_update_time: u64,
    price_samples: vector<u64>,
    sample_period: u64  // Period between samples (e.g., 3600 for hourly)
}




// Detailed Metrics Structures
public struct PoolMetrics<phantom CURRENCY: store> has key, store {
    id: UID,
    // Volume metrics
    total_volume_24h: u64,
    total_volume_7d: u64,
    peak_volume_24h: u64,
    
    // Trade metrics
    trade_count_24h: u64,
    unique_traders_24h: u64,
    average_trade_size: u64,
    
    // Price metrics
    last_price: u64,
    high_24h: u64,
    low_24h: u64,
    price_change_24h: u64,
    
    // Liquidity metrics
    total_liquidity_value: u64,
    liquidity_utilization: u64,
    lp_holder_count: u64,
    
    // Fee metrics
    total_fees_collected: u64,
    fees_24h: u64,
    effective_fee_rate: u64,
    
    // Time tracking
    last_update: u64,
    last_trade: u64,
    creation_time: u64
}

public struct SimpleMetrics<phantom CURRENCY: store> has key, store {
    id: UID,
    total_volume: u64,
    last_trade_price: u64,
    last_update_time: u64
}



// 6. Events for metric updates
public struct MetricsUpdated<phantom CURRENCY: store> has copy, drop {
    pool_id: ID,
    total_volume_24h: u64,
    price_change_24h: u64,
    liquidity_utilization: u64,
    unique_traders_24h: u64,
    timestamp: u64
}

public struct OraclePriceUpdate<phantom CURRENCY: store> has copy, drop {
    price: u64,
    twap: u64,
    timestamp: u64
}


public struct FeeCollected<phantom CURRENCY: store> has copy, drop {
    pool_id: ID,
    amount: u64,
    token_amount: u64,
    nft_amount: u64,
    timestamp: u64
}

// Event to log ownership transfer
public struct AdminCapOwnershipTransferred has copy, drop {
    old_owner: address,
    new_owner: address,
    timestamp: u64
}
   

    // Initialize function
   fun init(witness: TRADE, ctx: &mut TxContext) {
    let publisher = package::claim(witness, ctx);
    let admin_cap = AdminCap {
        id: object::new(ctx),
        owner: tx_context::sender(ctx),
        global_owner_fee: 0,  // Initial fee
        total_fees_collected: 0,
        last_collection_time: tx_context::epoch(ctx)
    };
    transfer::transfer(admin_cap, tx_context::sender(ctx));
    transfer::public_transfer(publisher, tx_context::sender(ctx));
}

    public entry fun register_collection<CURRENCY: store>(
    collection_cap: &CollectionCap,
    ctx: &mut TxContext
) {
    let collection_id = ART20::get_collection_cap_id(collection_cap);
    let collection_pool = CollectionPool<CURRENCY> {
        id: object::new(ctx),
        collection_id,
        pool_id: option::none(),
        active_pools: table::new(ctx),
        total_volume: 0,
        total_nfts: 0,
        floor_price: 0,
        last_trade_price: 0,
        trades_24h: 0,
        last_trade_timestamp: tx_context::epoch(ctx),
        price_history: vector::empty<TradePrice>()
    };
    transfer::share_object(collection_pool);
}

    // Create new trading pool
    public entry fun create_pool<CURRENCY: store>(
    collection_pool: &mut CollectionPool<CURRENCY>,
    collection_cap: &CollectionCap,
    initial_nfts: vector<NFT>,
    initial_tokens: Coin<CURRENCY>,
    user_balance: &mut UserBalance,
    fee_percent: u64,
    min_price: u64,
    max_price: u64,
    ctx: &mut TxContext
) {
    // Verify collection
    assert!(collection_pool.collection_id == ART20::get_collection_cap_id(collection_cap), E_INVALID_POOL);
    
    // Ensure no pool exists yet
    assert!(option::is_none(&collection_pool.pool_id), E_POOL_EXISTS);
    
    // Get initial NFT count
    let nft_count = vector::length(&initial_nfts);
    assert!(nft_count >= MIN_BATCH_SIZE && nft_count <= MAX_BATCH_SIZE, E_INVALID_NFT_AMOUNT);
    let token_amount = coin::value(&initial_tokens);
    
    // Basic validations
    assert!(nft_count > 0, E_INVALID_NFT_AMOUNT);
    assert!(token_amount > 0, E_INVALID_TOKEN_AMOUNT);
    assert!(fee_percent <= MAX_FEE_PERCENT, E_INVALID_FEE);
    assert!(min_price < max_price, E_INVALID_POOL);

    // Calculate price per NFT for validation
    let price_per_nft = token_amount / nft_count;
    assert!(price_per_nft >= min_price && price_per_nft <= max_price, E_INVALID_POOL);

    // Get user balance before mutation
    let current_balance = ART20::get_user_balance_amount(user_balance);
    assert!(current_balance >= nft_count, E_INSUFFICIENT_BALANCE);

    // Initialize price oracle
    let mut oracle = initialize_oracle<CURRENCY>(ctx);
    let price_per_nft = token_amount / nft_count;
    update_oracle(&mut oracle, price_per_nft, ctx);


    // Create NFT holdings table
    let mut nft_holdings = table::new<u64, NFT>(ctx);

    
    
    // Store NFTs in the holdings table
    let mut i = 0;
    let mut initial_nfts_mut = initial_nfts;
    while (i < nft_count) {
        let nft = vector::pop_back(&mut initial_nfts_mut);
        table::add(&mut nft_holdings, i + 1, nft);
        i = i + 1;
    };
    vector::destroy_empty(initial_nfts_mut);

    let token_reserve = coin::into_balance(initial_tokens);
    let token_reserve_value = balance::value(&token_reserve);
    
    // Create initial LP tokens with consideration for quantity
    let mut lp_supply = balance::create_supply(LPToken<CURRENCY> {});
    let lp_tokens_to_mint = calculate_initial_lp_tokens(nft_count, token_reserve_value);
    let lp_shares = balance::increase_supply(&mut lp_supply, lp_tokens_to_mint);

    // Update user balance
    ART20::set_user_balance_amount(
        user_balance,
        current_balance - nft_count
    );

    // Create pool
    let pool = TradingPool<CURRENCY> {
        id: object::new(ctx),
        collection_id: collection_pool.collection_id,
        nft_reserve: nft_count,
        token_reserve,
        lp_supply,
        lp_shares,
        fee_percent,
        min_price,
        max_price,
        is_active: true,
        owner: tx_context::sender(ctx),
        last_block_timestamp: tx_context::epoch(ctx),
        total_volume_tokens: 0,
        total_volume_nfts: 0,
        last_trade_price: price_per_nft,  // Initialize with initial price
        accumulated_fees: balance::zero(),
        contract_owner_accumulated_fees: balance::zero(), // Initialize here
        last_fee_distribution: tx_context::epoch(ctx),
        total_fees_collected: 0,
        pending_fees: 0,
        nft_holdings
    };

    // Store pool ID in collection
    option::fill(&mut collection_pool.pool_id, object::uid_to_inner(&pool.id));

    // Create LP position
    let lp_position = LiquidityPosition<CURRENCY> {
        id: object::new(ctx),
        pool_id: object::uid_to_inner(&pool.id),
        lp_tokens: balance::zero(),
        nft_contributed: nft_count,
        tokens_contributed: token_reserve_value,
        fees_earned: 0,
        last_update_timestamp: tx_context::epoch(ctx)
    };

    collection_pool.total_nfts = collection_pool.total_nfts + nft_count;

    
    
    // Update floor price if needed
    if (collection_pool.floor_price == 0 || min_price < collection_pool.floor_price) {
        collection_pool.floor_price = min_price;
    };

    // Extract required fields before moving the pool
    let pool_id = object::uid_to_inner(&pool.id);
    let collection_id = pool.collection_id;

    // Add pool to the table
    table::add(&mut collection_pool.active_pools, pool_id, pool);

    // Emit the PoolCreated event
    event::emit(PoolCreated<CURRENCY> {
        pool_id,
        collection_id,
        initial_nft_reserve: nft_count,
        initial_token_reserve: token_reserve_value,
        creator: tx_context::sender(ctx),
        fee_percent
    });

    transfer::share_object(oracle);
    // Transfer the LP position to the sender
    transfer::public_transfer(lp_position, tx_context::sender(ctx));
}

    // Add liquidity to pool
    // Add liquidity to pool with quantity support
public entry fun add_liquidity<CURRENCY: store>(
    collection_pool: &mut CollectionPool<CURRENCY>,
    pool: &mut TradingPool<CURRENCY>,
    nfts: vector<NFT>,
    tokens: Coin<CURRENCY>,
    user_balance: &mut UserBalance,
    min_lp_tokens: u64,
    ctx: &mut TxContext
) {
    // Verify this is the correct pool for the collection
    assert!(option::contains(&collection_pool.pool_id, &object::uid_to_inner(&pool.id)), E_INVALID_POOL);
    assert!(pool.is_active, E_POOL_NOT_ACTIVE);
    
    let nft_amount = vector::length(&nfts);
    assert!(nft_amount >= MIN_BATCH_SIZE && nft_amount <= MAX_BATCH_SIZE, E_INVALID_NFT_AMOUNT);
    let token_amount = coin::value(&tokens);
    
    // Basic validations
    assert!(nft_amount > 0, E_INVALID_NFT_AMOUNT);
    assert!(token_amount > 0, E_INVALID_TOKEN_AMOUNT);
    
    // Get balances before mutation
    let current_balance = ART20::get_user_balance_amount(user_balance);
    let user_collection_id = ART20::get_user_balance_collection_id(user_balance);
    
    // Verify user balance and collection
    assert!(current_balance >= nft_amount, E_INSUFFICIENT_BALANCE);
    assert!(user_collection_id == pool.collection_id, E_INVALID_POOL);

    // Calculate proportional amounts for the batch
    let token_per_nft = token_amount / nft_amount;
    let required_token_ratio = if (pool.nft_reserve == 0) {
        token_per_nft
    } else {
        (token_amount * pool.nft_reserve) / (nft_amount * pool.nft_reserve)
    };

    // Verify price bounds for the batch
    assert!(required_token_ratio >= pool.min_price && required_token_ratio <= pool.max_price, E_INVALID_POOL);

    // Calculate LP tokens for the batch
    let total_supply = balance::supply_value(&pool.lp_supply);
    let lp_tokens_to_mint = if (total_supply == 0) {
        calculate_initial_lp_tokens(nft_amount, token_amount)
    } else {
        // Scale LP tokens based on contribution proportion
        (nft_amount * total_supply) / pool.nft_reserve
    };

    assert!(lp_tokens_to_mint >= min_lp_tokens, E_INSUFFICIENT_LIQUIDITY);

    // Update user balance
    ART20::set_user_balance_amount(
        user_balance,
        current_balance - nft_amount
    );

    // Store NFTs in batch
    let mut i = 0;
    let mut nfts_mut = nfts;
    while (i < nft_amount) {
        let nft = vector::pop_back(&mut nfts_mut);
        table::add(&mut pool.nft_holdings, pool.nft_reserve + i + 1, nft);
        i = i + 1;
    };
    vector::destroy_empty(nfts_mut);

    // Bulk update pool state
    pool.nft_reserve = pool.nft_reserve + nft_amount;
    balance::join(&mut pool.token_reserve, coin::into_balance(tokens));
    let new_lp_tokens = balance::increase_supply(&mut pool.lp_supply, lp_tokens_to_mint);

    // Create LP position
    let lp_position = LiquidityPosition<CURRENCY> {
        id: object::new(ctx),
        pool_id: object::uid_to_inner(&pool.id),
        lp_tokens: new_lp_tokens,
        nft_contributed: nft_amount,
        tokens_contributed: token_amount,
        fees_earned: 0,
        last_update_timestamp: tx_context::epoch(ctx)
    };

    // Update collection stats
    collection_pool.total_nfts = collection_pool.total_nfts + nft_amount;
    
    // Emit collection stats update
    event::emit(CollectionStatsUpdated<CURRENCY> {
        collection_id: collection_pool.collection_id,
        new_floor_price: collection_pool.floor_price,
        total_volume: collection_pool.total_volume,
        total_nfts: collection_pool.total_nfts
    });

    // Emit liquidity added event
    event::emit(LiquidityAdded<CURRENCY> {
        pool_id: object::uid_to_inner(&pool.id),
        provider: tx_context::sender(ctx),
        nft_amount,
        token_amount,
        lp_tokens_minted: lp_tokens_to_mint
    });

    transfer::public_transfer(lp_position, tx_context::sender(ctx));
}


// Swap tokens for NFTs
public entry fun swap_tokens_for_nfts_with_slippage<CURRENCY: store>(
    oracle: &mut PriceOracle<CURRENCY>,
    collection_pool: &mut CollectionPool<CURRENCY>,
    pool: &mut TradingPool<CURRENCY>,
    admin_cap: &AdminCap,  // Add admin cap for contract owner fees
    tokens: Coin<CURRENCY>,
    user_balance: &mut UserBalance,
    quantity: u64,
    expected_price: u64,
    slippage_tolerance: u64,
    min_nfts_out: u64,
    ctx: &TxContext
) {
    // Basic validations
    assert!(table::contains(&collection_pool.active_pools, object::uid_to_inner(&pool.id)), E_INVALID_POOL);
    assert!(pool.is_active, E_POOL_NOT_ACTIVE);
    assert!(slippage_tolerance <= MAX_SLIPPAGE, E_SLIPPAGE_EXCEEDED);
    assert!(quantity > 0 && quantity <= pool.nft_reserve, E_INVALID_NFT_AMOUNT);
    assert!(quantity >= MIN_BATCH_SIZE && quantity <= MAX_BATCH_SIZE, E_INVALID_NFT_AMOUNT);
    
    let token_in = coin::value(&tokens);
    assert!(token_in >= MIN_TOKEN_PER_TRADE && token_in <= MAX_TOKEN_PER_TRADE, E_INVALID_TRADE_SIZE);

    // Calculate all fees
    let contract_owner_fee = (token_in * admin_cap.global_owner_fee) / 10000;
    let protocol_fee = (token_in * pool.fee_percent) / 10000;
    let total_fees = contract_owner_fee + protocol_fee;
    let remaining_amount = token_in - total_fees;

    // Verify batch slippage
    assert!(verify_batch_slippage(pool, expected_price, quantity, slippage_tolerance), E_SLIPPAGE_EXCEEDED);

    // Calculate outputs with remaining amount after fees
    let nfts_out = calculate_batch_output_amount(
        pool.nft_reserve,
        balance::value(&pool.token_reserve),
        remaining_amount,
        quantity,
        pool.fee_percent,
        true
    );
    assert!(nfts_out >= min_nfts_out, E_SLIPPAGE_EXCEEDED);

    // Calculate and verify price impact
    let price_impact = calculate_batch_price_impact(
        pool.nft_reserve,
        balance::value(&pool.token_reserve),
        remaining_amount,
        quantity,
        true
    );
    assert!(price_impact <= MAX_PRICE_IMPACT, E_PRICE_IMPACT_TOO_HIGH);

    // Update user balance
    let current_balance = ART20::get_user_balance_amount(user_balance);
    ART20::set_user_balance_amount(user_balance, current_balance + quantity);

    // Process tokens and fees
    let mut token_balance = coin::into_balance(tokens);
    let is_buy = true;
    
    // Split fees
    let contract_owner_fee_balance = balance::split(&mut token_balance, contract_owner_fee);
    let protocol_fee_balance = balance::split(&mut token_balance, protocol_fee);
    
    // Update fee accounting
    balance::join(&mut pool.contract_owner_accumulated_fees, contract_owner_fee_balance);
    balance::join(&mut pool.accumulated_fees, protocol_fee_balance);

    // Process NFT transfers
    let mut i = 0;
    while (i < quantity) {
        let nft = table::remove(&mut pool.nft_holdings, pool.nft_reserve - i);
        transfer::public_transfer(nft, tx_context::sender(ctx));
        i = i + 1;
    };

    // Update pool state
    pool.nft_reserve = pool.nft_reserve - quantity;
    balance::join(&mut pool.token_reserve, token_balance);
    pool.total_volume_tokens = pool.total_volume_tokens + token_in;
    pool.total_volume_nfts = pool.total_volume_nfts + quantity;

    // Oracle updates and validation
    let trade_price = remaining_amount / quantity;
    update_oracle(oracle, trade_price, ctx);
    let twap_price = get_twap(oracle, 24 * 3600, ctx);

    if (twap_price > 0) {
        let price_deviation = if (trade_price > twap_price) {
            ((trade_price - twap_price) * 10000) / twap_price
        } else {
            ((twap_price - trade_price) * 10000) / twap_price
        };
        assert!(price_deviation <= MAX_PRICE_IMPACT, E_PRICE_IMPACT_TOO_HIGH);
    };

    // Update collection stats
    pool.last_trade_price = trade_price;
    record_trade(collection_pool, trade_price, false, ctx);
    collection_pool.total_volume = collection_pool.total_volume + token_in;
    collection_pool.total_nfts = collection_pool.total_nfts - quantity;

    // Emit all relevant events
    event::emit(FeeCollected<CURRENCY> {
        pool_id: object::uid_to_inner(&pool.id),
        amount: total_fees,
        token_amount: token_in,
        nft_amount: quantity,
        timestamp: tx_context::epoch(ctx)
    });

    event::emit(ContractOwnerFeeCollected<CURRENCY> {
        pool_id: object::uid_to_inner(&pool.id),
        amount: contract_owner_fee,
        owner: admin_cap.owner,
        total_collected: admin_cap.total_fees_collected + contract_owner_fee,
        timestamp: tx_context::epoch(ctx)
    });

    event::emit(TradeExecuted<CURRENCY> {
        pool_id: object::uid_to_inner(&pool.id),
        trader: tx_context::sender(ctx),
        nft_amount: quantity,
        token_amount: token_in,
        is_buy: true,
        price_impact,
        timestamp: tx_context::epoch(ctx)
    });

    event::emit(OraclePriceUpdate<CURRENCY> {
        price: trade_price,
        twap: twap_price,
        timestamp: tx_context::epoch(ctx)
    });

    event::emit(CollectionTradeEvent<CURRENCY> {
    collection_id: pool.collection_id,
    pool_id: object::uid_to_inner(&pool.id),
    price: trade_price,
    amount: quantity, // Use the quantity of tokens/NFTs traded
    is_nft_to_token: is_buy, // true for NFT to token swaps
    floor_price: collection_pool.floor_price
});
}

   public entry fun swap_nfts_for_tokens_with_slippage<CURRENCY: store>(
    oracle: &mut PriceOracle<CURRENCY>,
    collection_pool: &mut CollectionPool<CURRENCY>,
    pool: &mut TradingPool<CURRENCY>,
    admin_cap: &AdminCap,  // Added admin_cap for contract owner fees
    nfts: vector<NFT>,
    user_balance: &mut UserBalance,
    expected_price: u64,
    slippage_tolerance: u64,
    min_tokens_out: u64,
    ctx: &mut TxContext
) {
    // Basic validations
    assert!(table::contains(&collection_pool.active_pools, object::uid_to_inner(&pool.id)), E_INVALID_POOL);
    assert!(pool.is_active, E_POOL_NOT_ACTIVE);
    assert!(slippage_tolerance <= MAX_SLIPPAGE, E_SLIPPAGE_EXCEEDED);
    
    let nft_quantity = vector::length(&nfts);
    assert!(nft_quantity > 0, E_INVALID_NFT_AMOUNT);
    assert!(nft_quantity >= MIN_BATCH_SIZE && nft_quantity <= MAX_BATCH_SIZE, E_INVALID_NFT_AMOUNT);
    
    // Verify batch slippage
    assert!(verify_batch_slippage(pool, expected_price, nft_quantity, slippage_tolerance), E_SLIPPAGE_EXCEEDED);
    
    // Verify balances and collection
    let current_balance = ART20::get_user_balance_amount(user_balance);
    let user_collection_id = ART20::get_user_balance_collection_id(user_balance);
    assert!(current_balance >= nft_quantity, E_INSUFFICIENT_BALANCE);
    assert!(user_collection_id == pool.collection_id, E_INVALID_POOL);

    let is_buy = false; // NFT to token trade

    // Calculate total output tokens and fees
    let token_reserve_value = balance::value(&pool.token_reserve);
    let total_tokens_out = calculate_batch_output_amount(
        token_reserve_value,
        pool.nft_reserve,
        nft_quantity,
        nft_quantity,
        pool.fee_percent,
        false
    );

    // Calculate contract owner fees
    let contract_owner_fee = (total_tokens_out * admin_cap.global_owner_fee) / 10000;
    let tokens_out = total_tokens_out - contract_owner_fee;
    assert!(tokens_out >= min_tokens_out, E_SLIPPAGE_EXCEEDED);

    // Calculate and verify price impact
    let price_impact = calculate_batch_price_impact(
        pool.nft_reserve,
        token_reserve_value,
        tokens_out,
        nft_quantity,
        false
    );
    assert!(price_impact <= MAX_PRICE_IMPACT, E_PRICE_IMPACT_TOO_HIGH);

    // Update user balance
    ART20::set_user_balance_amount(
        user_balance,
        current_balance - nft_quantity
    );

    // Process NFTs
    let mut i = 0;
    let mut nfts_mut = nfts;
    while (i < nft_quantity) {
        let nft = vector::pop_back(&mut nfts_mut);
        table::add(&mut pool.nft_holdings, pool.nft_reserve + i + 1, nft);
        i = i + 1;
    };
    vector::destroy_empty(nfts_mut);

    // Process tokens and fees
    let mut tokens_balance = balance::split(&mut pool.token_reserve, tokens_out);
    let fee_balance = balance::split(&mut tokens_balance, contract_owner_fee);
    
    // Update fee accounting
    balance::join(&mut pool.accumulated_fees, fee_balance);
    pool.total_fees_collected = pool.total_fees_collected + contract_owner_fee;

    // Transfer remaining tokens to user
    let tokens_out_coin = coin::from_balance(tokens_balance, ctx);
    transfer::public_transfer(tokens_out_coin, tx_context::sender(ctx));

    // Update pool state
    pool.nft_reserve = pool.nft_reserve + nft_quantity;
    pool.total_volume_tokens = pool.total_volume_tokens + total_tokens_out;
    pool.total_volume_nfts = pool.total_volume_nfts + nft_quantity;

    // Oracle updates and validation
    let trade_price = tokens_out / nft_quantity;
    update_oracle(oracle, trade_price, ctx);
    let twap_price = get_twap(oracle, 24 * 3600, ctx);

    if (twap_price > 0) {
        let price_deviation = if (trade_price > twap_price) {
            ((trade_price - twap_price) * 10000) / twap_price
        } else {
            ((twap_price - trade_price) * 10000) / twap_price
        };
        assert!(price_deviation <= MAX_PRICE_IMPACT, E_PRICE_IMPACT_TOO_HIGH);
    };

    // Update collection stats
    pool.last_trade_price = trade_price;
    record_trade(collection_pool, trade_price, true, ctx);
    collection_pool.total_volume = collection_pool.total_volume + tokens_out;
    collection_pool.total_nfts = collection_pool.total_nfts + nft_quantity;

    // Emit events
    event::emit(FeeCollected<CURRENCY> {
        pool_id: object::uid_to_inner(&pool.id),
        amount: contract_owner_fee,
        token_amount: total_tokens_out,
        nft_amount: nft_quantity,
        timestamp: tx_context::epoch(ctx)
    });

    event::emit(TradeExecuted<CURRENCY> {
        pool_id: object::uid_to_inner(&pool.id),
        trader: tx_context::sender(ctx),
        nft_amount: nft_quantity,
        token_amount: tokens_out,
        is_buy: false,
        price_impact,
        timestamp: tx_context::epoch(ctx)
    });

    event::emit(ContractOwnerFeeCollected<CURRENCY> {
        pool_id: object::uid_to_inner(&pool.id),
        amount: contract_owner_fee,
        owner: admin_cap.owner,
        total_collected: admin_cap.total_fees_collected + contract_owner_fee,
        timestamp: tx_context::epoch(ctx)
    });

    event::emit(OraclePriceUpdate<CURRENCY> {
        price: trade_price,
        twap: twap_price,
        timestamp: tx_context::epoch(ctx)
    });

   // Emit the trade event
    event::emit(CollectionTradeEvent<CURRENCY> {
        collection_id: pool.collection_id,
        pool_id: object::uid_to_inner(&pool.id),
        price: trade_price,
        amount: nft_quantity,
        is_nft_to_token: is_buy,
        floor_price: collection_pool.floor_price
    });
}

    
    
    // Remove liquidity from pool
public entry fun remove_liquidity<CURRENCY: store>(
    collection_pool: &mut CollectionPool<CURRENCY>,
    pool: &mut TradingPool<CURRENCY>,
    lp_position: &mut LiquidityPosition<CURRENCY>,
    lp_tokens_to_burn: u64,
    user_balance: &mut UserBalance,
    min_nfts: u64,
    min_tokens: u64,
    quantity: u64, // Add quantity parameter
    ctx: &mut TxContext
) {
    assert!(pool.is_active, E_POOL_NOT_ACTIVE);
    assert!(lp_tokens_to_burn > 0, E_INVALID_LP_TOKENS);
    assert!(quantity > 0 && quantity <= pool.nft_reserve, E_INVALID_NFT_AMOUNT);
    assert!(quantity >= MIN_BATCH_SIZE && quantity <= MAX_BATCH_SIZE, E_INVALID_NFT_AMOUNT);
    
    let total_supply = balance::supply_value(&pool.lp_supply);
    assert!(total_supply > 0, E_ZERO_LIQUIDITY);
    
    // Calculate proportional amounts based on quantity
    let nft_amount = (lp_tokens_to_burn * quantity * pool.nft_reserve) / (total_supply * quantity);
    let token_amount = (lp_tokens_to_burn * balance::value(&pool.token_reserve)) / total_supply;
    
    // Verify minimum amounts
    assert!(nft_amount >= min_nfts, E_INSUFFICIENT_LIQUIDITY);
    assert!(token_amount >= min_tokens, E_INSUFFICIENT_LIQUIDITY);
    
    
    // Verify position has enough LP tokens
    assert!(balance::value(&lp_position.lp_tokens) >= lp_tokens_to_burn, E_INSUFFICIENT_LIQUIDITY);
    
    // Update user balance for batch removal
    let current_balance = ART20::get_user_balance_amount(user_balance);
    ART20::set_user_balance_amount(user_balance, current_balance + nft_amount);
    
    // Transfer NFTs in batch
    let mut i = 0;
    while (i < nft_amount) {
        let nft = table::remove(&mut pool.nft_holdings, pool.nft_reserve - i);
        transfer::public_transfer(nft, tx_context::sender(ctx));
        i = i + 1;
    };
    
    // Transfer tokens in batch
    let tokens_out = coin::from_balance(
        balance::split(&mut pool.token_reserve, token_amount),
        ctx
    );
    transfer::public_transfer(tokens_out, tx_context::sender(ctx));
    
    // Update pool state for batch
    pool.nft_reserve = pool.nft_reserve - nft_amount;
    
    // Burn LP tokens
    let lp_tokens_balance = balance::split(&mut lp_position.lp_tokens, lp_tokens_to_burn);
    balance::decrease_supply(&mut pool.lp_supply, lp_tokens_balance);
    
    // Update LP position
    lp_position.nft_contributed = lp_position.nft_contributed - nft_amount;
    lp_position.tokens_contributed = lp_position.tokens_contributed - token_amount;
    lp_position.last_update_timestamp = tx_context::epoch(ctx);

    // Update collection stats for batch
    collection_pool.total_nfts = collection_pool.total_nfts - nft_amount;
    
    // Emit stats update for batch
    event::emit(CollectionStatsUpdated<CURRENCY> {
        collection_id: collection_pool.collection_id,
        new_floor_price: collection_pool.floor_price,
        total_volume: collection_pool.total_volume,
        total_nfts: collection_pool.total_nfts
    });
    
    // Emit liquidity removed event for batch
    event::emit(LiquidityRemoved<CURRENCY> {
        pool_id: object::uid_to_inner(&pool.id),
        provider: tx_context::sender(ctx),
        nft_amount,
        token_amount,
        lp_tokens_burned: lp_tokens_to_burn
    });
}

    // Pool management functions
   public entry fun update_pool_status<CURRENCY: store>(
    pool: &mut TradingPool<CURRENCY>,
    ctx: &mut TxContext
) {
    assert!(tx_context::sender(ctx) == pool.owner, E_NOT_POOL_OWNER);
    let old_status = pool.is_active;
    pool.is_active = !pool.is_active;
    
    event::emit(PoolStatusChanged<CURRENCY> {
        pool_id: object::uid_to_inner(&pool.id),
        old_status,
        new_status: pool.is_active,
        changed_by: tx_context::sender(ctx),
        timestamp: tx_context::epoch(ctx)
    });
}

public entry fun transfer_admin_cap(
    admin_cap: &mut AdminCap,      // Mutable reference to AdminCap
    new_owner: address,            // Address of the new owner
    ctx: &mut TxContext            // Transaction context
) {
    // 1. Validate that the caller is the current owner
    assert!(tx_context::sender(ctx) == admin_cap.owner, E_NOT_CONTRACT_OWNER);

    // 2. Ensure the new owner is not the zero address (for safety)
    assert!(new_owner != @0x0, E_INVALID_POOL); // Use @0x0 for zero address comparison

    // 3. Store the current owner before transferring ownership
    let old_owner = admin_cap.owner;

    // 4. Update the owner of the AdminCap
    admin_cap.owner = new_owner;

    // 5. Emit an event to log the ownership transfer
    event::emit(AdminCapOwnershipTransferred {
        old_owner,
        new_owner,
        timestamp: tx_context::epoch(ctx)
    });
}

fun validate_price_calculation(
    token_reserve: u64,
    nft_reserve: u64,
    price: u64
): bool {
    token_reserve > 0 && 
    nft_reserve > 0 && 
    price > 0 && 
    price <= MAX_U64 / PRICE_PRECISION
}

public fun check_pool_health_detailed<CURRENCY: store>(
    pool: &TradingPool<CURRENCY>
): (bool, bool, bool, bool) {
    let is_active = pool.is_active;
    let has_nfts = pool.nft_reserve > 0;
    let has_tokens = balance::value(&pool.token_reserve) > 0;
    let valid_price = validate_price_calculation(
        balance::value(&pool.token_reserve),
        pool.nft_reserve,
        get_spot_price(pool, true)
    );
    
    (is_active, has_nfts, has_tokens, valid_price)
}

public entry fun update_pool_fees<CURRENCY: store>(
    pool: &mut TradingPool<CURRENCY>,
    new_fee_percent: u64,
    ctx: &mut TxContext
) {
    assert!(tx_context::sender(ctx) == pool.owner, E_NOT_POOL_OWNER);
    assert!(new_fee_percent <= MAX_FEE_PERCENT, E_INVALID_FEE);
    
    let old_fee = pool.fee_percent;
    pool.fee_percent = new_fee_percent;
    
    event::emit(PoolFeesUpdated<CURRENCY> {
        pool_id: object::uid_to_inner(&pool.id),
        old_fee,
        new_fee: new_fee_percent,
        changed_by: tx_context::sender(ctx),
        timestamp: tx_context::epoch(ctx)
    });
}

    // View functions
    public fun get_pool_info<CURRENCY: store>(
        pool: &TradingPool<CURRENCY>
    ): (ID, u64, u64, u64, bool, u64, u64) {
        (
            pool.collection_id,
            pool.nft_reserve,
            balance::value(&pool.token_reserve),
            pool.fee_percent,
            pool.is_active,
            pool.total_volume_tokens,
            pool.total_volume_nfts
        )
    }

    public fun get_pool_details<CURRENCY: store>(
        pool: &TradingPool<CURRENCY>
    ): (u64, u64, u64, u64) {
        (
            pool.min_price,
            pool.max_price,
            pool.fee_percent,
            pool.last_block_timestamp
        )
    }

    public fun get_lp_position_info<CURRENCY: store>(
        position: &LiquidityPosition<CURRENCY>
    ): (ID, u64, u64, u64, u64) {
        (
            position.pool_id,
            balance::value(&position.lp_tokens),
            position.nft_contributed,
            position.tokens_contributed,
            position.fees_earned
        )
    }

    public fun get_lp_share_value<CURRENCY: store>(
        pool: &TradingPool<CURRENCY>,
        lp_tokens: u64
    ): (u64, u64) {
        let total_supply = balance::supply_value(&pool.lp_supply);
        let nft_value = (lp_tokens * pool.nft_reserve) / total_supply;
        let token_value = (lp_tokens * balance::value(&pool.token_reserve)) / total_supply;
        (nft_value, token_value)
    }

    public fun get_spot_price<CURRENCY: store>(
        pool: &TradingPool<CURRENCY>,
        is_buy: bool
    ): u64 {
        let token_reserve = balance::value(&pool.token_reserve);
        
        if (is_buy) {
            ((token_reserve * PRICE_PRECISION) / pool.nft_reserve) * 
            (10000 + pool.fee_percent) / 10000
        } else {
            ((token_reserve * PRICE_PRECISION) / pool.nft_reserve) * 
            10000 / (10000 + pool.fee_percent)
        }
    }

    public fun get_collection_stats<CURRENCY: store>(
    collection_pool: &CollectionPool<CURRENCY>,
    ctx: &TxContext
): CollectionStats {
    let stats = CollectionStats {
        total_pools: table::length(&collection_pool.active_pools),
        total_volume: collection_pool.total_volume,
        total_nfts_locked: collection_pool.total_nfts,
        floor_price: collection_pool.floor_price,
        highest_price: collection_pool.last_trade_price,
        average_price_24h: calculate_average_price_24h(collection_pool, ctx),
        total_trades_24h: get_trades_24h(collection_pool, ctx)
    };

    event::emit(CollectionStatUpdate<CURRENCY> {
        collection_id: collection_pool.collection_id,
        total_pools: table::length(&collection_pool.active_pools),
        total_volume: collection_pool.total_volume,
        floor_price: collection_pool.floor_price,
        nfts_locked: collection_pool.total_nfts,
        timestamp: tx_context::epoch(ctx)
    });

    stats
}

// Safe Math
fun safe_multiply(a: u64, b: u64): u64 {
    assert!(a == 0 || b <= MAX_U64 / a, E_MATH_OVERFLOW);
    a * b
}



fun safe_divide(a: u64, b: u64): u64 {
    assert!(b != 0, E_DIVIDE_BY_ZERO);
    a / b
}



public fun get_collection_price_info<CURRENCY: store>(
    collection_pool: &CollectionPool<CURRENCY>,
    ctx: &mut TxContext
): (u64, u64, u64) {
    (
        collection_pool.floor_price,
        collection_pool.last_trade_price,
        calculate_average_price_24h(collection_pool, ctx)
    )
}

public fun get_twap_price<CURRENCY: store>(
    pool: &TradingPool<CURRENCY>,
    oracle: &PriceOracle<CURRENCY>,
    ctx: &TxContext
): u64 {
    let current_time = tx_context::epoch(ctx);
    let time_elapsed = current_time - oracle.last_update_time;
    
    if (time_elapsed == 0 || vector::is_empty(&oracle.price_samples)) {
        pool.last_trade_price
    } else {
        oracle.price_cumulative / time_elapsed
    }
}

public fun update_metrics<CURRENCY: store>(
    metrics: &mut SimpleMetrics<CURRENCY>,
    volume: u64,
    price: u64,
    ctx: &TxContext
) {
    metrics.total_volume = metrics.total_volume + volume;
    metrics.last_trade_price = price;
    metrics.last_update_time = tx_context::epoch(ctx);
}

public fun initialize_metrics<CURRENCY: store>(
    ctx: &mut TxContext
): SimpleMetrics<CURRENCY> {
    SimpleMetrics<CURRENCY> {
        id: object::new(ctx),
        total_volume: 0,
        last_trade_price: 0,
        last_update_time: tx_context::epoch(ctx)
    }
}

// Price info with averaging
public fun get_price_metrics<CURRENCY: store>(
    collection_pool: &CollectionPool<CURRENCY>,
    ctx: &mut TxContext
): (u64, u64, u64, u64) {
    (
        collection_pool.floor_price,
        collection_pool.last_trade_price,
        calculate_average_price_24h(collection_pool, ctx),
        get_trades_24h(collection_pool, ctx)
    )
}

// Getting collection analytics
public fun get_collection_analytics<CURRENCY: store>(
    collection_pool: &CollectionPool<CURRENCY>,
    ctx: &mut TxContext
): (u64, u64, u64, u64, u64) {
    (
        collection_pool.total_volume,
        collection_pool.total_nfts,
        collection_pool.floor_price,
        calculate_average_price_24h(collection_pool, ctx),
        get_trades_24h(collection_pool, ctx)
    )
}

// Helper function to check if price is within 24h average range
public fun is_price_within_range<CURRENCY: store>(
    collection_pool: &CollectionPool<CURRENCY>,
    price: u64,
    deviation_percent: u64,
    ctx: &mut TxContext
): bool {
    let average_price = calculate_average_price_24h(collection_pool, ctx);
    let max_deviation = (average_price * deviation_percent) / 100;
    let min_price = if (average_price > max_deviation) {
        average_price - max_deviation
    } else {
        0
    };
    let max_price = average_price + max_deviation;
    
    price >= min_price && price <= max_price
}

    

    // Helper functions for price calculations
    public fun calculate_tokens_in_for_nfts_out<CURRENCY: store>(
    pool: &TradingPool<CURRENCY>,
    nfts_out: u64,
    quantity: u64
): u64 {
    let token_reserve = balance::value(&pool.token_reserve);
    let nft_reserve = pool.nft_reserve;
    
    let numerator = token_reserve * nfts_out * 10000 * quantity;
    let denominator = (nft_reserve - nfts_out) * (10000 - pool.fee_percent);
    
    (numerator / denominator) + 1
}

public fun calculate_nfts_in_for_tokens_out<CURRENCY: store>(
    pool: &TradingPool<CURRENCY>,
    tokens_out: u64,
    quantity: u64
): u64 {
    let token_reserve = balance::value(&pool.token_reserve);
    assert!(tokens_out < token_reserve, E_INSUFFICIENT_LIQUIDITY);
    
    let numerator = pool.nft_reserve * tokens_out * 10000 * quantity;
    let denominator = (token_reserve - tokens_out) * (10000 - pool.fee_percent);
    
    (numerator / denominator) + 1
}

    // Helper function to check if NFT exists in pool
    public fun has_nft<CURRENCY: store>(
        pool: &TradingPool<CURRENCY>,
        asset_id: u64
    ): bool {
        table::contains(&pool.nft_holdings, asset_id)
    }

    public fun get_nft_count<CURRENCY: store>(
        pool: &TradingPool<CURRENCY>
    ): u64 {
        pool.nft_reserve
    }

    // Helper function to get NFT from pool (borrow)
    public fun borrow_nft<CURRENCY: store>(
        pool: &TradingPool<CURRENCY>,
        asset_id: u64
    ): &NFT {
        table::borrow(&pool.nft_holdings, asset_id)
    }

    

    // Emergency functions
    public entry fun emergency_withdraw<CURRENCY: store>(
    pool: &mut TradingPool<CURRENCY>,
    ctx: &mut TxContext
) {
    assert!(tx_context::sender(ctx) == pool.owner, E_NOT_POOL_OWNER);
    
    // Transfer NFTs in batches for efficiency
    let mut remaining = pool.nft_reserve;
    let mut current_id = 1;
    
    while (remaining > 0) {
        let batch_size = if (remaining > MAX_BATCH_SIZE) { 
            MAX_BATCH_SIZE 
        } else { 
            remaining 
        };
        
        let mut processed = 0;
        while (processed < batch_size && current_id <= pool.nft_reserve) {
            if (table::contains(&pool.nft_holdings, current_id)) {
                let nft = table::remove(&mut pool.nft_holdings, current_id);
                transfer::public_transfer(nft, pool.owner);
                processed = processed + 1;
                remaining = remaining - 1;
            };
            current_id = current_id + 1;
        };
    };
    
    // Transfer all tokens to owner
    let tokens = coin::from_balance(
        balance::withdraw_all(&mut pool.token_reserve),
        ctx
    );
    transfer::public_transfer(tokens, pool.owner);
    
    pool.is_active = false;
}

public entry fun emergency_pause<CURRENCY: store>(
    pool: &mut TradingPool<CURRENCY>,
    ctx: &mut TxContext
) {
    assert!(tx_context::sender(ctx) == pool.owner, E_NOT_POOL_OWNER);
    assert!(pool.is_active, E_POOL_NOT_ACTIVE);
    
    pool.is_active = false;
    pool.last_block_timestamp = tx_context::epoch(ctx);
    
    event::emit(PoolStatusChanged<CURRENCY> {
        pool_id: object::uid_to_inner(&pool.id),
        old_status: true,
        new_status: false,
        changed_by: tx_context::sender(ctx),
        timestamp: tx_context::epoch(ctx)
    });
}

public entry fun resume_after_emergency<CURRENCY: store>(
    pool: &mut TradingPool<CURRENCY>,
    ctx: &mut TxContext
) {
    assert!(tx_context::sender(ctx) == pool.owner, E_NOT_POOL_OWNER);
    assert!(!pool.is_active, E_POOL_NOT_ACTIVE);
    assert!(
        tx_context::epoch(ctx) >= pool.last_block_timestamp + EMERGENCY_COOLDOWN,
        E_COOLDOWN_NOT_EXPIRED
    );
    
    pool.is_active = true;
    
    event::emit(PoolStatusChanged<CURRENCY> {
        pool_id: object::uid_to_inner(&pool.id),
        old_status: false,
        new_status: true,
        changed_by: tx_context::sender(ctx),
        timestamp: tx_context::epoch(ctx)
    });
}

    // helper Functions
    public fun verify_slippage<CURRENCY: store>(
        pool: &TradingPool<CURRENCY>,
        expected_price: u64,
        slippage_tolerance: u64
    ): bool {
        let current_price = get_spot_price(pool, true);
        let price_diff = if (current_price > expected_price) {
            current_price - expected_price
        } else {
            expected_price - current_price
        };
        
        (price_diff * 10000) / expected_price <= slippage_tolerance
    }

    public fun check_pool_health<CURRENCY: store>(
        pool: &TradingPool<CURRENCY>
    ): bool {
        pool.is_active && 
        pool.nft_reserve > 0 && 
        balance::value(&pool.token_reserve) > 0
    }

    public fun get_pool_tvl<CURRENCY: store>(
        pool: &TradingPool<CURRENCY>
    ): (u64, u64) {
        (pool.nft_reserve, balance::value(&pool.token_reserve))
    }

    public fun get_price_bounds_with_slippage(
        price: u64,
        slippage_tolerance: u64
    ): (u64, u64) {
        assert!(slippage_tolerance <= MAX_SLIPPAGE, E_SLIPPAGE_EXCEEDED);
        
        let max_slippage_amount = (price * slippage_tolerance) / 10000;
        let min_price = price - max_slippage_amount;
        let max_price = price + max_slippage_amount;
        
        (min_price, max_price)
    }



    fun calculate_average_price_24h<CURRENCY: store>(
    collection_pool: &CollectionPool<CURRENCY>,
    ctx: &TxContext 
): u64 {
    let current_time = tx_context::epoch(ctx);
    let mut total_price = 0u64;
    let mut count = 0u64;

    let prices = &collection_pool.price_history;
    let mut i = vector::length(prices);
    while (i > 0) {
        i = i - 1;
        let price_data = vector::borrow(prices, i);
        if (current_time - price_data.timestamp <= 24 * 60 * 60) {
            total_price = total_price + price_data.price;
            count = count + 1;
        }
    };

    if (count == 0) {
        collection_pool.last_trade_price
    } else {
        total_price / count
    }
}


// Implement trade counting for 24h window
fun get_trades_24h<CURRENCY: store>(
    collection_pool: &CollectionPool<CURRENCY>,
    ctx: &TxContext
): u64 {
    let current_time = tx_context::epoch(ctx);
    let day_ago = if (current_time > 24 * 60 * 60) {
        current_time - 24 * 60 * 60
    } else {
        0
    };
    
    let mut count = 0u64;
    let prices = &collection_pool.price_history;
    let mut i = vector::length(prices);
    while (i > 0) {
        i = i - 1;
        let price_data = vector::borrow(prices, i);
        if (price_data.timestamp > day_ago) {
            count = count + 1;
        }
    };
    
    count
}

// 7. Function to emit metrics events
public fun emit_metrics_event<CURRENCY: store>(
    pool: &TradingPool<CURRENCY>,
    metrics: &PoolMetrics<CURRENCY>,
    ctx: &TxContext
) {
    event::emit(MetricsUpdated<CURRENCY> {
        pool_id: object::uid_to_inner(&pool.id),
        total_volume_24h: metrics.total_volume_24h,
        price_change_24h: metrics.price_change_24h,
        liquidity_utilization: metrics.liquidity_utilization,
        unique_traders_24h: metrics.unique_traders_24h,
        timestamp: tx_context::epoch(ctx)
    });
}

// 8. Function to get formatted metrics
public fun get_formatted_metrics<CURRENCY: store>(
    metrics: &PoolMetrics<CURRENCY>
): (u64, u64, u64, u64, u64) {
    (
        metrics.total_volume_24h,
        metrics.trade_count_24h,
        metrics.high_24h,
        metrics.low_24h,
        metrics.liquidity_utilization
    )
}

// 9. Add metrics initialization function
public fun initialize_pool_metrics<CURRENCY: store>(
    ctx: &mut TxContext
): PoolMetrics<CURRENCY> {
    let current_time = tx_context::epoch(ctx);
    PoolMetrics<CURRENCY> {
        id: object::new(ctx),
        total_volume_24h: 0,
        total_volume_7d: 0,
        peak_volume_24h: 0,
        trade_count_24h: 0,
        unique_traders_24h: 0,
        average_trade_size: 0,
        last_price: 0,
        high_24h: 0,
        low_24h: 0,
        price_change_24h: 0,
        total_liquidity_value: 0,
        liquidity_utilization: 0,
        lp_holder_count: 0,
        total_fees_collected: 0,
        fees_24h: 0,
        effective_fee_rate: 0,
        last_update: current_time,
        last_trade: current_time,
        creation_time: current_time
    }
}

// 4. Implementation of metrics update functions
public fun update_pool_metrics<CURRENCY: store>(
    pool: &mut TradingPool<CURRENCY>,
    metrics: &mut PoolMetrics<CURRENCY>,
    ctx: &TxContext
) {
    let current_time = tx_context::epoch(ctx);
    let time_since_update = current_time - metrics.last_update;

    // Update 24h rolling metrics if needed
    if (time_since_update > 0) {
        update_24h_metrics(metrics, current_time);
    };

    // Calculate current metrics
    let (nft_value, token_value) = get_pool_tvl(pool);
    let current_price = get_spot_price(pool, true);
    
    // Update price metrics
    if (current_price > metrics.high_24h) {
        metrics.high_24h = current_price;
    };
    if (current_price < metrics.low_24h || metrics.low_24h == 0) {
        metrics.low_24h = current_price;
    };
    
    // Update liquidity metrics
    metrics.total_liquidity_value = token_value + (nft_value * current_price);
    metrics.liquidity_utilization = calculate_utilization(pool);
    
    // Update time tracking
    metrics.last_update = current_time;
}

// 5. Helper functions for metrics calculations
fun calculate_utilization<CURRENCY: store>(pool: &TradingPool<CURRENCY>): u64 {
    let total_possible_trades = pool.nft_reserve * (balance::value(&pool.token_reserve) / get_spot_price(pool, true));
    let actual_trades = pool.total_volume_nfts;
    
    if (total_possible_trades == 0) {
        0
    } else {
        (actual_trades * 10000) / total_possible_trades
    }
}

fun update_24h_metrics<CURRENCY: store>(
    metrics: &mut PoolMetrics<CURRENCY>,
    current_time: u64
) {
    let time_window = 24 * 60 * 60; // 24 hours in seconds
    if (current_time - metrics.last_update > time_window) {
        // Reset 24h metrics
        metrics.total_volume_24h = 0;
        metrics.trade_count_24h = 0;
        metrics.fees_24h = 0;
    };
}


// Add trade recording function
fun record_trade<CURRENCY: store>(
    collection_pool: &mut CollectionPool<CURRENCY>,
    price: u64,
    is_nft_to_token: bool,
    ctx: &TxContext  // Changed from &mut TxContext to &TxContext
) {
    let timestamp = tx_context::epoch(ctx);
    
    // Update trade stats
    collection_pool.last_trade_price = price;
    collection_pool.last_trade_timestamp = timestamp;
    collection_pool.trades_24h = collection_pool.trades_24h + 1;

    // Update floor price if needed
    if (price < collection_pool.floor_price) {
        collection_pool.floor_price = price;
        
        // Emit stats update event when floor price changes
        event::emit(CollectionStatsUpdated<CURRENCY> {
            collection_id: collection_pool.collection_id,
            new_floor_price: price,
            total_volume: collection_pool.total_volume,
            total_nfts: collection_pool.total_nfts
        });
    };

    // Add to price history
    vector::push_back(&mut collection_pool.price_history, TradePrice {
        price,
        timestamp,
        is_nft_to_token
    });

    // Prune old price history (older than 24h)
    let day_ago = if (timestamp > 24 * 60 * 60) {
        timestamp - 24 * 60 * 60
    } else {
        0
    };
    
    while (!vector::is_empty(&collection_pool.price_history)) {
        let first = vector::borrow(&collection_pool.price_history, 0);
        if (first.timestamp < day_ago) {
            vector::remove(&mut collection_pool.price_history, 0);
        } else {
            break
        }
    }
}

public fun get_collection_trades<CURRENCY: store>(
    collection_pool: &CollectionPool<CURRENCY>,
    ctx: &TxContext
): (vector<u64>, vector<bool>) {
    let mut prices = vector::empty<u64>();
    let mut trade_types = vector::empty<bool>();
    
    let price_history = &collection_pool.price_history;
    let current_time = tx_context::epoch(ctx);
    let mut i = vector::length(price_history);
    
    while (i > 0) {
        i = i - 1;
        let price_data = vector::borrow(price_history, i);
        if (current_time - price_data.timestamp <= 24 * 60 * 60) {
            vector::push_back(&mut prices, price_data.price);
            // Note: Since we don't store trade type in price history,
            // this is a placeholder. You might want to extend TradePrice
            // struct to include trade type if needed
            vector::push_back(&mut trade_types, false);
        }
    };

    (prices, trade_types)
}

// Helper to check if a trade would impact floor price
public fun would_impact_floor_price<CURRENCY: store>(
    collection_pool: &CollectionPool<CURRENCY>,
    trade_price: u64
): bool {
    trade_price < collection_pool.floor_price
}

public fun get_collection_pool<CURRENCY: store>(
    collection_pool: &CollectionPool<CURRENCY>
): Option<ID> {
    collection_pool.pool_id
}

public fun get_pool_exists<CURRENCY: store>(
    collection_pool: &CollectionPool<CURRENCY>
): bool {
    option::is_some(&collection_pool.pool_id)
}

fun calculate_batch_price_impact(
    nft_reserve: u64,
    token_reserve: u64,
    amount_in: u64,
    quantity: u64,
    is_buy: bool
): u64 {
    let initial_price = (token_reserve * PRICE_PRECISION) / nft_reserve;
    
    let new_token_reserve = if (is_buy) {
        token_reserve + amount_in
    } else {
        token_reserve - amount_in
    };
    
    let new_nft_reserve = if (is_buy) {
        nft_reserve - quantity
    } else {
        nft_reserve + quantity
    };
    
    let new_price = (new_token_reserve * PRICE_PRECISION) / new_nft_reserve;
    let price_diff = if (new_price > initial_price) {
        new_price - initial_price
    } else {
        initial_price - new_price
    };
    
    (price_diff * 10000) / initial_price
}


// Update output amount calculation for batch trades
fun calculate_batch_output_amount(
    reserve_in: u64,
    reserve_out: u64,
    amount_in: u64,
    quantity: u64,
    fee_percent: u64,
    is_buy: bool
): u64 {
    assert!(quantity > 0 && quantity <= MAX_BATCH_SIZE, E_INVALID_NFT_AMOUNT);
    
    let amount_in_with_fee = safe_multiply(amount_in, (10000 - fee_percent));
    let numerator = safe_multiply(amount_in_with_fee, reserve_out);
    let denominator = safe_multiply(reserve_in, 10000) + safe_multiply(amount_in_with_fee, quantity);
    
    if (is_buy) {
        safe_multiply(safe_divide(numerator, denominator), quantity) + 1
    } else {
        safe_multiply(safe_divide(numerator, denominator), quantity)
    }
}

// Add new function to verify slippage for batch trades
fun verify_batch_slippage<CURRENCY: store>(
    pool: &TradingPool<CURRENCY>,
    expected_price: u64,
    quantity: u64,
    slippage_tolerance: u64
): bool {
    let current_price = get_spot_price(pool, true) * quantity;
    let price_diff = if (current_price > expected_price) {
        current_price - expected_price
    } else {
        expected_price - current_price
    };
    
    (price_diff * 10000) / expected_price <= slippage_tolerance
}

// Helper function to calculate initial LP tokens based on quantity
fun calculate_initial_lp_tokens(nft_count: u64, token_amount: u64): u64 {
    let mut base_liquidity = MIN_LIQUIDITY;
    
    // Scale MIN_LIQUIDITY based on the quantity of NFTs provided
    // This ensures proportional LP tokens for larger initial deposits
    if (nft_count > 1) {
        base_liquidity = base_liquidity * nft_count;
    };
    
    // Additional scaling based on token amount per NFT
    let avg_token_per_nft = token_amount / nft_count;
    if (avg_token_per_nft > PRICE_PRECISION) {
        base_liquidity = base_liquidity * (avg_token_per_nft / PRICE_PRECISION);
    };
    
    base_liquidity
}

public fun initialize_oracle<CURRENCY: store>(
    ctx: &mut TxContext
): PriceOracle<CURRENCY> {
    PriceOracle<CURRENCY> {
        id: object::new(ctx),
        price_cumulative: 0,
        last_update_time: tx_context::epoch(ctx),
        price_samples: vector::empty(),
        sample_period: DEFAULT_SAMPLE_PERIOD
    }
}

public fun update_oracle<CURRENCY: store>(
    oracle: &mut PriceOracle<CURRENCY>,
    current_price: u64,
    ctx: &TxContext
) {
    let current_time = tx_context::epoch(ctx);
    let time_elapsed = current_time - oracle.last_update_time;

    if (time_elapsed >= oracle.sample_period) {
        // Add new price sample
        vector::push_back(&mut oracle.price_samples, current_price);
        
        // Keep only last MAX_SAMPLES samples
        if (vector::length(&oracle.price_samples) > MAX_SAMPLES) {
            vector::remove(&mut oracle.price_samples, 0);
        };

        // Update cumulative price
        oracle.price_cumulative = oracle.price_cumulative + (current_price * time_elapsed);
        oracle.last_update_time = current_time;
    };

    event::emit(OraclePriceUpdate<CURRENCY> {
        price: current_price,
        twap: get_twap(oracle, 24 * 3600, ctx),
        timestamp: tx_context::epoch(ctx)
    });
}

public fun get_twap<CURRENCY: store>(
    oracle: &PriceOracle<CURRENCY>,
    duration: u64,
    ctx: &TxContext
): u64 {
    let current_time = tx_context::epoch(ctx);
    let time_elapsed = current_time - oracle.last_update_time;
    
    if (time_elapsed == 0 || vector::is_empty(&oracle.price_samples)) {
        0
    } else {
        let samples = &oracle.price_samples;
        let samples_count = vector::length(samples);
        let mut total = 0u64;
        let mut i = 0;
        
        // Calculate average over specified duration
        while (i < samples_count && i < duration / oracle.sample_period) {
            total = total + *vector::borrow(samples, samples_count - i - 1);
            i = i + 1;
        };
        
        if (i > 0) { total / i } else { 0 }
    }
}

// Add price range functions
public fun get_price_range<CURRENCY: store>(
    oracle: &PriceOracle<CURRENCY>
): (u64, u64) {
    let samples = &oracle.price_samples;
    if (vector::is_empty(samples)) {
        (0, 0)
    } else {
        let mut min_price = *vector::borrow(samples, 0);
        let mut max_price = min_price;
        let len = vector::length(samples);
        let mut i = 1;
        
        while (i < len) {
            let price = *vector::borrow(samples, i);
            if (price < min_price) {
                min_price = price;
            };
            if (price > max_price) {
                max_price = price;
            };
            i = i + 1;
        };
        
        (min_price, max_price)
    }
}

public fun get_oracle_price_info<CURRENCY: store>(
    oracle: &PriceOracle<CURRENCY>,
    ctx: &TxContext
): (u64, u64, u64) {
    let (min_price, max_price) = get_price_range(oracle);
    let twap = get_twap(oracle, 24 * 3600, ctx);
    (min_price, max_price, twap)
}

public fun check_price_deviation<CURRENCY: store>(
    oracle: &PriceOracle<CURRENCY>,
    price: u64,
    ctx: &TxContext
): bool {
    let twap = get_twap(oracle, 24 * 3600, ctx);
    if (twap == 0) {
        true
    } else {
        let deviation = if (price > twap) {
            ((price - twap) * 10000) / twap
        } else {
            ((twap - price) * 10000) / twap
        };
        deviation <= MAX_PRICE_IMPACT
    }
}
    
public fun get_pending_fees<CURRENCY: store>(
    pool: &TradingPool<CURRENCY>,
    lp_position: &LiquidityPosition<CURRENCY>
): u64 {
    let total_lp = balance::supply_value(&pool.lp_supply);
    let user_lp = balance::value(&lp_position.lp_tokens);
    (user_lp * pool.pending_fees) / total_lp
}

// 7. Add function to check fee distribution eligibility
public fun is_fee_distribution_eligible<CURRENCY: store>(
    pool: &TradingPool<CURRENCY>,
    lp_position: &LiquidityPosition<CURRENCY>
): bool {
    let pending = get_pending_fees(pool, lp_position);
    pending > 0
}


public fun get_accumulated_fees<CURRENCY: store>(
    pool: &TradingPool<CURRENCY>
): u64 {
    balance::value(&pool.accumulated_fees)
}

public fun time_since_last_distribution<CURRENCY: store>(
    pool: &TradingPool<CURRENCY>,
    ctx: &TxContext
): u64 {
    tx_context::epoch(ctx) - pool.last_fee_distribution
}

public entry fun collect_contract_owner_fees<CURRENCY: store>(
    admin_cap: &mut AdminCap,
    pool: &mut TradingPool<CURRENCY>,
    ctx: &mut TxContext
) {
    // 1. Validate caller is contract owner
    assert!(tx_context::sender(ctx) == admin_cap.owner, E_NOT_CONTRACT_OWNER);
    let fee_amount = balance::value(&pool.contract_owner_accumulated_fees);
    assert!(fee_amount > 0, E_NO_FEES_TO_COLLECT);
    
    // 3. Get the current timestamp
    let current_time = tx_context::epoch(ctx);
    
    // 4. Withdraw all accumulated fees
    let fees = coin::from_balance(
        balance::withdraw_all(&mut pool.contract_owner_accumulated_fees),
        ctx
    );
    
    // 5. Update AdminCap stats
    admin_cap.total_fees_collected = admin_cap.total_fees_collected + fee_amount;
    admin_cap.last_collection_time = current_time;
    
    // 6. Transfer fees to contract owner
    transfer::public_transfer(fees, admin_cap.owner);
    
    // 7. Emit success event
    event::emit(ContractOwnerFeeCollected<CURRENCY> {
        pool_id: object::uid_to_inner(&pool.id),
        amount: fee_amount,
        owner: admin_cap.owner,
        total_collected: admin_cap.total_fees_collected,
        timestamp: current_time
    });
}

public entry fun transfer_contract_ownership(
    admin_cap: &mut AdminCap,
    new_owner: address,
    ctx: &mut TxContext
) {
    assert!(tx_context::sender(ctx) == admin_cap.owner, E_NOT_CONTRACT_OWNER);
    admin_cap.owner = new_owner;
}

// Safe fee collection with try-catch pattern
public fun try_collect_fees<CURRENCY: store>(
    admin_cap: &mut AdminCap,
    pool: &mut TradingPool<CURRENCY>,
    ctx: &mut TxContext
): bool {
    if (tx_context::sender(ctx) != admin_cap.owner) {
        event::emit(FeeCollectionFailed<CURRENCY> {
            pool_id: object::uid_to_inner(&pool.id),
            owner: tx_context::sender(ctx),
            reason: E_NOT_CONTRACT_OWNER,
            timestamp: tx_context::epoch(ctx)
        });
        return false
    };
    
    let fee_amount = balance::value(&pool.contract_owner_accumulated_fees);
    if (fee_amount == 0) {
        event::emit(FeeCollectionFailed<CURRENCY> {
            pool_id: object::uid_to_inner(&pool.id),
            owner: admin_cap.owner,
            reason: E_NO_FEES_TO_COLLECT,
            timestamp: tx_context::epoch(ctx)
        });
        return false
    };
    
    let current_time = tx_context::epoch(ctx);
    
    let fees = coin::from_balance(
        balance::withdraw_all(&mut pool.contract_owner_accumulated_fees),
        ctx
    );
    
    admin_cap.total_fees_collected = admin_cap.total_fees_collected + fee_amount;
    admin_cap.last_collection_time = current_time;
    
    transfer::public_transfer(fees, admin_cap.owner);
    
    event::emit(ContractOwnerFeeCollected<CURRENCY> {
        pool_id: object::uid_to_inner(&pool.id),
        amount: fee_amount,
        owner: admin_cap.owner,
        total_collected: admin_cap.total_fees_collected,
        timestamp: current_time
    });
    
    true
}

// View function to check available fees
public fun view_contract_owner_fees<CURRENCY: store>(
    pool: &TradingPool<CURRENCY>
): u64 {
    balance::value(&pool.contract_owner_accumulated_fees)
}

// View function to get fee collection history
public fun get_contract_owner_fee_info(
    admin_cap: &AdminCap
): (address, u64, u64, u64) {
    (
        admin_cap.owner,
        admin_cap.global_owner_fee,
        admin_cap.total_fees_collected,
        admin_cap.last_collection_time
    )
}

// Function to check if fees are ready to collect (optional cooldown)
public fun can_collect_fees(
    admin_cap: &AdminCap,
    ctx: &TxContext
): bool {
    let current_time = tx_context::epoch(ctx);
    // For example, add a 1-hour cooldown between collections
    current_time >= admin_cap.last_collection_time + 3600
}

}