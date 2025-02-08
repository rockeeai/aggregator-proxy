module rockee_aggregator::bluemove {
    use std::type_name::{Self, TypeName};
    use sui::coin::{Self, Coin};
    use sui::event::emit;
    use bluemove::router::swap_exact_input_;
    use bluemove::swap::Dex_Info;

    use rockee_aggregator::setting::{Self, Config};

    public struct BlueMoveSwapEvent has copy, store, drop {
        amount_in: u64,
        amount_out: u64,
        a2b: bool,
        by_amount_in: bool,
        coin_a: TypeName,
        coin_b: TypeName,
    }

    public fun swap_a2b<CoinA, CoinB>(
        bird_config: &mut Config,
        dex_info: &mut Dex_Info,
        coin_a: Coin<CoinA>,
        ctx: &mut TxContext,
    ): Coin<CoinB> {
        let amount_in = coin::value(&coin_a);
        let coin_b = swap_exact_input_<CoinA, CoinB>(
            amount_in,
            coin_a,
            0,
            dex_info,
            ctx,
        );
        let amount_out = coin::value(&coin_b);

        let (remainer_b, fee) = setting::pay_fee<CoinB>(bird_config, coin_b, ctx);

        emit(BlueMoveSwapEvent {
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
        dex_info: &mut Dex_Info,
        coin_b: Coin<CoinB>,
        ctx: &mut TxContext,
    ): Coin<CoinA> {
        let amount_in = coin::value(&coin_b);
        let coin_a = swap_exact_input_<CoinB, CoinA>(
            amount_in,
            coin_b,
            0,
            dex_info,
            ctx,
        );
        let amount_out = coin::value(&coin_a);
        let (remainer_a, fee) = setting::pay_fee<CoinA>(bird_config, coin_a, ctx);

        emit(BlueMoveSwapEvent {
            amount_in,
            amount_out: amount_out - fee,
            a2b: false,
            by_amount_in: false,
            coin_a: type_name::get<CoinA>(),
            coin_b: type_name::get<CoinB>(),
        });


        remainer_a
        
    }
}
