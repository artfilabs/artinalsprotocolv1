module artinals::BURN {
    
    use sui::event;
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use artinals::ART20::{Self, NFT, CollectionCap, UserBalance};

    // Error constants
    const E_NOT_CREATOR: u64 = 1;
    const E_INSUFFICIENT_BALANCE: u64 = 2;
    const E_ZERO_REWARD: u64 = 3;
    const E_POOL_NOT_ACTIVE: u64 = 4;
    const E_INSUFFICIENT_REWARD_BALANCE: u64 = 5;
    const E_OVERFLOW: u64 = 6;
    const E_POOL_ALREADY_ACTIVE: u64 = 7;
    const E_CURRENT_SUPPLY_NOT_ZERO: u64 = 8;
    const E_COLLECTION_MISMATCH: u64 = 9;

    // Safe math max values
    const MAX_U64: u64 = 18446744073709551615;

    // Structs
    public struct BurnPool<phantom REWARD> has key {
        id: UID,
        creator: address,
        reward_balance: Balance<REWARD>,
        reward_per_burn: u64,
        total_burns: u64,
        total_rewards_distributed: u64,
        is_active: bool,
    }

    // Events
    public struct PoolCreated<phantom REWARD> has copy, drop {
        pool_id: ID,
        creator: address,
        initial_balance: u64,
        reward_per_burn: u64
    }

    public struct NFTBurned has copy, drop {
        burner: address,
        nft_id: ID,
        collection_id: ID
    }

    public struct RewardClaimed<phantom REWARD> has copy, drop {
        burner: address,
        amount: u64,
        pool_id: ID
    }

    public struct BalanceAdded<phantom REWARD> has copy, drop {
        pool_id: ID,
        amount: u64,
        new_balance: u64
    }

    public struct BalanceRemoved<phantom REWARD> has copy, drop {
        pool_id: ID,
        amount: u64,
        remaining_balance: u64
    }

    public struct PoolDestroyed<phantom REWARD> has copy, drop {
        pool_id: ID,
        remaining_balance: u64
    }

    public struct PoolStatusChanged<phantom REWARD> has copy, drop {
        pool_id: ID,
        is_active: bool
    }

    public struct DropPool<phantom REWARD> has key {
    id: UID,
    creator: address,
    reward_balance: Balance<REWARD>,
    reward_per_drop: u64,
    total_drops: u64,
    total_rewards_distributed: u64,
    is_active: bool,
}

// Add new events
public struct DropPoolCreated<phantom REWARD> has copy, drop {
    pool_id: ID,
    creator: address,
    initial_balance: u64,
    reward_per_drop: u64
}

public struct CollectionDropped has copy, drop {
    dropper: address,
    collection_id: ID,
    reward_amount: u64
}

    // Safe math functions
    fun safe_add(a: u64, b: u64): u64 {
        assert!(a <= MAX_U64 - b, E_OVERFLOW);
        a + b
    }

    // Create a new burn pool
    public entry fun create_burn_pool<REWARD>(
    reward: &mut Coin<REWARD>,     // Changed to &mut to split from it
    amount: u64,                   // Added amount parameter
    reward_per_burn: u64,
    ctx: &mut TxContext
) {
    // Check available balance
    let reward_balance = coin::value(reward);
    assert!(reward_balance >= amount, E_INSUFFICIENT_BALANCE);
    assert!(amount > 0, E_INSUFFICIENT_BALANCE);
    assert!(reward_per_burn > 0, E_ZERO_REWARD);

    // Split the specified amount from the input coin
    let pool_coin = coin::split(reward, amount, ctx);

    let pool = BurnPool<REWARD> {
        id: object::new(ctx),
        creator: tx_context::sender(ctx),
        reward_balance: coin::into_balance(pool_coin),  // Use the split amount
        reward_per_burn,
        total_burns: 0,
        total_rewards_distributed: 0,
        is_active: true
    };

    let pool_id = object::uid_to_inner(&pool.id);

    event::emit(PoolCreated<REWARD> {
        pool_id,
        creator: tx_context::sender(ctx),
        initial_balance: amount,
        reward_per_burn
    });

    transfer::share_object(pool);
}

    // Burn NFT and claim reward
    public entry fun burn_and_claim<REWARD>(
    pool: &mut BurnPool<REWARD>,
    nft: NFT,
    collection_cap: &mut CollectionCap,  // Changed from & to &mut
    balance: UserBalance,                // Changed from &mut UserBalance to UserBalance
    ctx: &mut TxContext
) {
    // Verify pool is active
    assert!(pool.is_active, E_POOL_NOT_ACTIVE);

    // Verify sufficient reward balance
    let reward_balance = balance::value(&pool.reward_balance);
    assert!(reward_balance >= pool.reward_per_burn, E_INSUFFICIENT_REWARD_BALANCE);

    // Get NFT details before burning
    let nft_id = ART20::get_nft_id(&nft);
    let collection_id = ART20::get_nft_collection_id(&nft);

    // Create reward coin
    let reward = coin::from_balance(
        balance::split(&mut pool.reward_balance, pool.reward_per_burn),
        ctx
    );

    // Update pool stats safely
    pool.total_burns = safe_add(pool.total_burns, 1);
    pool.total_rewards_distributed = safe_add(
        pool.total_rewards_distributed,
        pool.reward_per_burn
    );

    // Emit burn event
    event::emit(NFTBurned {
        burner: tx_context::sender(ctx),
        nft_id,
        collection_id
    });

    // Emit reward event
    event::emit(RewardClaimed<REWARD> {
        burner: tx_context::sender(ctx),
        amount: pool.reward_per_burn,
        pool_id: object::uid_to_inner(&pool.id)
    });

    // Transfer reward to burner
    transfer::public_transfer(reward, tx_context::sender(ctx));

    // Burn the NFT using ART20's burn function
    // Now passing balance directly in vector, not dereferencing
    ART20::burn_art20(nft, collection_cap, vector[balance], ctx);
}

    // Add more rewards to the pool
    public entry fun add_rewards<REWARD>(
    pool: &mut BurnPool<REWARD>,
    payment: Coin<REWARD>,
    ctx: &mut TxContext
) {
    assert!(tx_context::sender(ctx) == pool.creator, E_NOT_CREATOR);
    
    let amount = coin::value(&payment);
    assert!(amount > 0, E_INSUFFICIENT_BALANCE);

    // Remove unused old_balance variable
    balance::join(&mut pool.reward_balance, coin::into_balance(payment));

    event::emit(BalanceAdded<REWARD> {
        pool_id: object::uid_to_inner(&pool.id),
        amount,
        new_balance: balance::value(&pool.reward_balance)
    });
}

    // Remove rewards from the pool
    public entry fun remove_rewards<REWARD>(
        pool: &mut BurnPool<REWARD>,
        amount: u64,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == pool.creator, E_NOT_CREATOR);
        
        let balance_value = balance::value(&pool.reward_balance);
        assert!(balance_value >= amount, E_INSUFFICIENT_BALANCE);

        let payment = coin::from_balance(
            balance::split(&mut pool.reward_balance, amount),
            ctx
        );

        event::emit(BalanceRemoved<REWARD> {
            pool_id: object::uid_to_inner(&pool.id),
            amount,
            remaining_balance: balance::value(&pool.reward_balance)
        });

        transfer::public_transfer(payment, pool.creator);
    }

    // Deactivate pool
    public entry fun deactivate_pool<REWARD>(
        pool: &mut BurnPool<REWARD>,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == pool.creator, E_NOT_CREATOR);
        assert!(pool.is_active, E_POOL_NOT_ACTIVE);

        pool.is_active = false;

        event::emit(PoolStatusChanged<REWARD> {
            pool_id: object::uid_to_inner(&pool.id),
            is_active: false
        });
    }

    // Reactivate pool
    public entry fun reactivate_pool<REWARD>(
        pool: &mut BurnPool<REWARD>,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == pool.creator, E_NOT_CREATOR);
        assert!(!pool.is_active, E_POOL_ALREADY_ACTIVE);

        pool.is_active = true;

        event::emit(PoolStatusChanged<REWARD> {
            pool_id: object::uid_to_inner(&pool.id),
            is_active: true
        });
    }

    // Destroy pool and reclaim remaining balance
    public entry fun destroy_pool<REWARD>(
        pool: BurnPool<REWARD>,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == pool.creator, E_NOT_CREATOR);

        let BurnPool {
            id,
            creator: _,
            reward_balance,
            reward_per_burn: _,
            total_burns: _,
            total_rewards_distributed: _,
            is_active: _
        } = pool;

        let remaining_balance = balance::value(&reward_balance);
        
        event::emit(PoolDestroyed<REWARD> {
            pool_id: object::uid_to_inner(&id),
            remaining_balance
        });

        // Return remaining balance to creator if any
        if (remaining_balance > 0) {
            transfer::public_transfer(
                coin::from_balance(reward_balance, ctx),
                tx_context::sender(ctx)
            );
        } else {
            balance::destroy_zero(reward_balance);
        };

        object::delete(id);
    }


    public entry fun create_drop_pool<REWARD>(
    reward: &mut Coin<REWARD>,
    amount: u64,
    reward_per_drop: u64,
    ctx: &mut TxContext
) {
    // Check available balance
    let reward_balance = coin::value(reward);
    assert!(reward_balance >= amount, E_INSUFFICIENT_BALANCE);
    assert!(amount > 0, E_INSUFFICIENT_BALANCE);
    assert!(reward_per_drop > 0, E_ZERO_REWARD);

    // Split the specified amount from the input coin
    let pool_coin = coin::split(reward, amount, ctx);

    let pool = DropPool<REWARD> {
        id: object::new(ctx),
        creator: tx_context::sender(ctx),
        reward_balance: coin::into_balance(pool_coin),
        reward_per_drop,
        total_drops: 0,
        total_rewards_distributed: 0,
        is_active: true
    };

    let pool_id = object::uid_to_inner(&pool.id);

    event::emit(DropPoolCreated<REWARD> {
        pool_id,
        creator: tx_context::sender(ctx),
        initial_balance: amount,
        reward_per_drop
    });

    transfer::share_object(pool);
}

// Drop collection and claim reward
public entry fun drop_and_claim<REWARD>(
    pool: &mut DropPool<REWARD>,
    collection_cap: CollectionCap,
    mut user_balances: vector<UserBalance>, // Added mut here
    ctx: &mut TxContext
) {
    // Verify pool is active
    assert!(pool.is_active, E_POOL_NOT_ACTIVE);

    // Verify collection has zero supply before dropping
    assert!(ART20::get_collection_current_supply(&collection_cap) == 0, E_CURRENT_SUPPLY_NOT_ZERO);

    // Get collection ID
    let collection_id = ART20::get_collection_cap_id(&collection_cap);

    // Verify sufficient reward balance
    let reward_balance = balance::value(&pool.reward_balance);
    assert!(reward_balance >= pool.reward_per_drop, E_INSUFFICIENT_REWARD_BALANCE);

    // Create reward coin
    let reward = coin::from_balance(
        balance::split(&mut pool.reward_balance, pool.reward_per_drop),
        ctx
    );

    // Update pool stats safely
    pool.total_drops = safe_add(pool.total_drops, 1);
    pool.total_rewards_distributed = safe_add(
        pool.total_rewards_distributed,
        pool.reward_per_drop
    );

    // Emit drop event
    event::emit(CollectionDropped {
        dropper: tx_context::sender(ctx),
        collection_id,
        reward_amount: pool.reward_per_drop
    });

    // Transfer reward to dropper
    transfer::public_transfer(reward, tx_context::sender(ctx));

    // Drop the collection
    ART20::drop_collection_cap(collection_cap, ctx);

    // Clean up user balances
    while (!vector::is_empty(&user_balances)) {
        let balance = vector::pop_back(&mut user_balances);
        assert!(ART20::get_user_balance_collection_id(&balance) == collection_id, E_COLLECTION_MISMATCH);
        ART20::cleanup_empty_balance(balance);
    };
    
    vector::destroy_empty(user_balances);
}

// Add rewards to drop pool
public entry fun add_drop_rewards<REWARD>(
    pool: &mut DropPool<REWARD>,
    payment: Coin<REWARD>,
    ctx: &mut TxContext
) {
    assert!(tx_context::sender(ctx) == pool.creator, E_NOT_CREATOR);
    let amount = coin::value(&payment);
    assert!(amount > 0, E_INSUFFICIENT_BALANCE);
    balance::join(&mut pool.reward_balance, coin::into_balance(payment));
    
    event::emit(BalanceAdded<REWARD> {
        pool_id: object::uid_to_inner(&pool.id),
        amount,
        new_balance: balance::value(&pool.reward_balance)
    });
}

// Remove rewards from drop pool
public entry fun remove_drop_rewards<REWARD>(
    pool: &mut DropPool<REWARD>,
    amount: u64,
    ctx: &mut TxContext
) {
    assert!(tx_context::sender(ctx) == pool.creator, E_NOT_CREATOR);
    let balance_value = balance::value(&pool.reward_balance);
    assert!(balance_value >= amount, E_INSUFFICIENT_BALANCE);

    let payment = coin::from_balance(
        balance::split(&mut pool.reward_balance, amount),
        ctx
    );

    event::emit(BalanceRemoved<REWARD> {
        pool_id: object::uid_to_inner(&pool.id),
        amount,
        remaining_balance: balance::value(&pool.reward_balance)
    });

    transfer::public_transfer(payment, pool.creator);
}

// View functions for drop pool
public fun get_drop_pool_info<REWARD>(pool: &DropPool<REWARD>): (address, u64, u64, u64, u64, bool) {
    (
        pool.creator,
        balance::value(&pool.reward_balance),
        pool.reward_per_drop,
        pool.total_drops,
        pool.total_rewards_distributed,
        pool.is_active
    )
}

    // View functions
    public fun get_pool_info<REWARD>(pool: &BurnPool<REWARD>): (address, u64, u64, u64, u64, bool) {
        (
            pool.creator,
            balance::value(&pool.reward_balance),
            pool.reward_per_burn,
            pool.total_burns,
            pool.total_rewards_distributed,
            pool.is_active
        )
    }

    public fun is_pool_active<REWARD>(pool: &BurnPool<REWARD>): bool {
        pool.is_active
    }

    public fun get_reward_per_burn<REWARD>(pool: &BurnPool<REWARD>): u64 {
        pool.reward_per_burn
    }

    public fun get_pool_balance<REWARD>(pool: &BurnPool<REWARD>): u64 {
        balance::value(&pool.reward_balance)
    }
}