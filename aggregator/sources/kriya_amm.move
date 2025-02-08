module rockee_aggregator::kriya_amm {
    use std::type_name::{Self, TypeName};

    use sui::coin::{Self, Coin};
    use sui::event::emit;

    use kriya_amm::spot_dex::{Pool, swap_token_x, swap_token_y};

    use rockee_aggregator::setting::{Self, Config};

    public struct KriyaAmmSwapEvent has copy, store, drop {
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
        pool: &mut Pool<CoinA, CoinB>,
        coin_a: Coin<CoinA>,
        ctx: &mut TxContext,
    ): Coin<CoinB> {
        let amount_in = coin::value(&coin_a);
        let coin_b = swap_token_x<CoinA, CoinB>(
            pool,
            coin_a,
            amount_in,
            0,
            ctx,
        );
        let amount_out = coin::value(&coin_b);

        let (remainer_b, fee) = setting::pay_fee<CoinB>(bird_config,  coin_b, ctx);

        emit(KriyaAmmSwapEvent {
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
        pool: &mut Pool<CoinA, CoinB>,
        coin_b: Coin<CoinB>,
        ctx: &mut TxContext,
    ): Coin<CoinA> {
        let amount_in = coin::value(&coin_b);
        let coin_a = swap_token_y<CoinA, CoinB>(
            pool,
            coin_b,
            amount_in,
            0,
            ctx
        );
        let amount_out = coin::value(&coin_a);

        let (remainer_a, fee) = setting::pay_fee<CoinA>(bird_config, coin_a, ctx);

        emit(KriyaAmmSwapEvent {
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
