module rockee_aggregator::flowx_clmm {
    use std::type_name::{Self, TypeName};
    use sui::{event::emit, clock::Clock, coin::{Self, Coin}, balance};

    use flowx_clmm::{pool::{swap, pay}, versioned::Versioned, pool_manager::{PoolRegistry, borrow_mut_pool}, tick_math};

    use rockee_aggregator::setting::{Self, Config};

    public struct FlowxClmmSwapEvent has copy, store, drop {
        pool: ID,
        amount_in: u64,
        amount_out: u64,
        a2b: bool,
        by_amount_in: bool,
        coin_a: TypeName,
        coin_b: TypeName,
    }

    public fun swap_a2b<CoinA, CoinB>(
        bird_config: &mut Config,
        pool_register: &mut PoolRegistry,
        fee: u64,
        coin_a: Coin<CoinA>,
        versioned: &Versioned,
        clock: &Clock,
        ctx: &mut TxContext,
    ): Coin<CoinB> {
        let pool = borrow_mut_pool(pool_register, fee);
        let amount_in = coin::value(&coin_a);
        let (receive_balance_a, receive_balance_b, receipt) = swap<CoinA, CoinB>(
            pool,
            true,
            true,
            amount_in,
            tick_math::min_sqrt_price() + 1,
            versioned,
            clock,
            ctx,
        );
        let amount_out = balance::value(&receive_balance_b);

        balance::destroy_zero(receive_balance_a);
        let balance_a = coin::into_balance(coin_a);
        let balance_b = balance::zero<CoinB>();
        pay<CoinA, CoinB>(pool, receipt, balance_a, balance_b, versioned, ctx);
        let coin_b = coin::from_balance(receive_balance_b, ctx);

        let (remainer_b, fee) = setting::pay_fee<CoinB>(bird_config, coin_b, ctx);

        emit(FlowxClmmSwapEvent {
            pool: object::id(pool),
            amount_in,
            amount_out: amount_out - fee,
            a2b: true,
            by_amount_in: true,
            coin_a: type_name::get<CoinA>(),
            coin_b: type_name::get<CoinB>(),
        });

        remainer_b
    }

    public fun swap_b2a<CoinA, CoinB>(
        bird_config: &mut Config,
        pool_register: &mut PoolRegistry,
        fee: u64,
        coin_b: Coin<CoinB>,
        versioned: &Versioned,
        clock: &Clock,
        ctx: &mut TxContext,
    ): Coin<CoinA> {
        let pool = borrow_mut_pool(pool_register, fee);
        let amount_in = coin::value(&coin_b);
        let (receive_balance_a, receive_balance_b, receipt) = swap<CoinA, CoinB>(
            pool,
            false,
            true,
            amount_in,
            tick_math::max_sqrt_price() - 1,
            versioned,
            clock,
            ctx,
        );
        let amount_out = balance::value(&receive_balance_a);

        balance::destroy_zero(receive_balance_b);
        let balance_a = balance::zero<CoinA>();
        let balance_b = coin::into_balance(coin_b);

        pay<CoinA, CoinB>(pool, receipt, balance_a, balance_b, versioned, ctx);

        let coin_a = coin::from_balance(receive_balance_a, ctx);

        let (remainer_a, fee) = setting::pay_fee<CoinA>(bird_config, coin_a, ctx);

        emit(FlowxClmmSwapEvent {
            pool: object::id(pool),
            amount_in,
            amount_out: amount_out - fee,
            a2b: false,
            by_amount_in: true,
            coin_a: type_name::get<CoinA>(),
            coin_b: type_name::get<CoinB>(),
        });

        remainer_a
    }
}
