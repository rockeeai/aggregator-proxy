module rockee_aggregator::flowx_amm {
    use std::type_name::{Self, TypeName};

    use sui::coin::{Self, Coin};
    use sui::event::emit;

    use flowx_amm::router::swap_exact_input_direct;
    use flowx_amm::factory::Container;

    use rockee_aggregator::setting::{Self, Config};

    public struct FlowxSwapEvent has copy, store, drop {
        amount_in: u64,
        amount_out: u64,
        a2b: bool,
        by_amount_in: bool,
        coin_a: TypeName,
        coin_b: TypeName,
    }

    public fun swap_a2b<CoinA, CoinB>(
        bird_config: &mut Config,
        container: &mut Container,
        coin_a: Coin<CoinA>,
        ctx: &mut TxContext,
    ): Coin<CoinB> {
        let amount_in = coin::value(&coin_a);
        let coin_b = swap_exact_input_direct<CoinA, CoinB>(
            container,
            coin_a,
            ctx,
        );
        let amount_out = coin::value(&coin_b);

        let (remainer_b, fee) = setting::pay_fee<CoinB>(bird_config, coin_b, ctx);

        emit(FlowxSwapEvent {
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
        container: &mut Container,
        coin_b: Coin<CoinB>,
        ctx: &mut TxContext,
    ): Coin<CoinA> {
        let amount_in = coin::value(&coin_b);
        let coin_a = swap_exact_input_direct<CoinB, CoinA>(
            container,
            coin_b,
            ctx
        );
        let amount_out = coin::value(&coin_a);

        let (remainer_a, fee) = setting::pay_fee<CoinA>(bird_config, coin_a, ctx);
        emit(FlowxSwapEvent {
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
