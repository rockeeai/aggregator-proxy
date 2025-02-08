module rockee_aggregator::deepbook {
    use std::type_name::{Self, TypeName};

    use sui::coin::{Self, Coin};
    use sui::clock::Clock;
    use sui::event::emit;

    use deepbook::clob_v2::{Self, Pool};
    use deepbook::custodian_v2::AccountCap;

    use rockee_aggregator::setting::{Self, Config};
    use rockee_aggregator::utils::transfer_or_destroy_coin;

    const CLIENT_ID_BOND: u64 = 0;

    public struct DeepbookSwapEvent has copy, store, drop {
        pool: ID,
        amount_in: u64,
        amount_out: u64,
        a2b: bool,
        by_amount_in: bool,
        account_cap: ID,
        coin_a: TypeName,
        coin_b: TypeName,
    }

    public fun swap_a2b<CoinA, CoinB> (
        bird_config: &mut Config,
        pool: &mut Pool<CoinA, CoinB>,
        coin_a: Coin<CoinA>,
        account_cap: &AccountCap,
        clock: &Clock,
        ctx: &mut TxContext,
    ): Coin<CoinB> {
        let coin_b = coin::zero<CoinB>(ctx);
        let amount = coin::value(&coin_a);
        let (receive_a, receive_b, _) = clob_v2::swap_exact_base_for_quote<CoinA, CoinB>(
            pool,
            CLIENT_ID_BOND,
            account_cap,
            amount,
            coin_a,
            coin_b,
            clock,
            ctx
        );

        let swaped_coin_a_amount = coin::value(&receive_a);
        let swaped_coin_b_amount = coin::value(&receive_b);

        let amount_in = amount - swaped_coin_a_amount;
        let amount_out = swaped_coin_b_amount;

        let (remainer_b, fee) = setting::pay_fee<CoinB>(bird_config, receive_b, ctx);

        emit(DeepbookSwapEvent {
            pool: object::id(pool),
            a2b: true,
            by_amount_in: true,
            amount_in,
            amount_out: amount_out - fee,
            account_cap: object::id(account_cap),
            coin_a: type_name::get<CoinA>(),
            coin_b: type_name::get<CoinB>(),
        });

        transfer_or_destroy_coin<CoinA>(receive_a, ctx);
        
        remainer_b
    }

    public fun swap_b2a<CoinA, CoinB> (
        bird_config: &mut Config,
        pool: &mut Pool<CoinA, CoinB>,
        coin_b: Coin<CoinB>,
        account_cap: &AccountCap,
        clock: &Clock,
        ctx: &mut TxContext,
    ): Coin<CoinA> {
        let amount = coin::value(&coin_b);
        let (receive_a, receive_b, _) = clob_v2::swap_exact_quote_for_base(
            pool,
            CLIENT_ID_BOND,
            account_cap,
            amount,
            clock,
            coin_b,
            ctx
        );
        let swaped_coin_a_amount = coin::value(&receive_a);
        let swaped_coin_b_amount = coin::value(&receive_b);
        let amount_in = amount - swaped_coin_b_amount;
        let amount_out = swaped_coin_a_amount;

        let (remainer_a, fee) = setting::pay_fee<CoinA>(bird_config, receive_a, ctx);

        emit(DeepbookSwapEvent {
            pool: object::id(pool),
            a2b: false,
            by_amount_in: true,
            amount_in,
            amount_out: amount_out - fee,
            account_cap: object::id(account_cap),
            coin_a: type_name::get<CoinA>(),
            coin_b: type_name::get<CoinB>(),
        });
        transfer_or_destroy_coin<CoinB>(receive_b, ctx);
        
        remainer_a
    }

    #[allow(lint(self_transfer))]
    public fun transfer_account_cap(account_cap: AccountCap, ctx: &TxContext) {
        transfer::public_transfer(account_cap, tx_context::sender(ctx))
    }
}

