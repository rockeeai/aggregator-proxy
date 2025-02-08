module rockee_aggregator::aftermath {
    use std::type_name::{Self, TypeName};
    use sui::coin::{Self, Coin};
    use sui::event::emit;

    use aftermath_amm::pool::Pool;
    use aftermath_amm::pool_registry::PoolRegistry;
    use aftermath_amm::swap::swap_exact_in;
    use protocol_fee_vault::vault::ProtocolFeeVault;
    use treasury::treasury::Treasury;
    use insurance_fund::insurance_fund::InsuranceFund;
    use referral_vault::referral_vault::ReferralVault;

    use rockee_aggregator::setting::{Self, Config};

    public struct AftermathSwapEvent has copy, store, drop {
        pool: ID,
        amount_in: u64,
        amount_out: u64,
        a2b: bool,
        by_amount_in: bool,
        coin_a: TypeName,
        coin_b: TypeName,
    }

    public fun swap_a2b<CoinA, CoinB, Fee>(
        bird_config: &mut Config,
        pool: &mut Pool<Fee>,
        pool_registry: &PoolRegistry,
        vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        expect_amount_out: u64,
        slippage: u64,
        coin_a: Coin<CoinA>,
        ctx: &mut TxContext,
    ): Coin<CoinB> {
        let amount_in = coin::value(&coin_a);
        let coin_b = swap_exact_in<Fee, CoinA, CoinB>(
            pool,
            pool_registry,
            vault,
            treasury,
            insurance_fund,
            referral_vault,
            coin_a,
            expect_amount_out,
            slippage,
            ctx,
        );
        let amount_out = coin::value(&coin_b);

        let (remainer_b, fee) = setting::pay_fee<CoinB>(bird_config, coin_b, ctx);

        emit(AftermathSwapEvent {
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

    public fun swap_b2a<CoinA, CoinB, Fee>(
        bird_config: &mut Config,
        pool: &mut Pool<Fee>,
        pool_registry: &PoolRegistry,
        vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        expect_amount_out: u64,
        slippage: u64,
        coin_b: Coin<CoinB>,
        ctx: &mut TxContext,
    ): Coin<CoinA> {
        let amount_in = coin::value(&coin_b);
        let coin_a = swap_exact_in<Fee, CoinB, CoinA>(
            pool,
            pool_registry,
            vault,
            treasury,
            insurance_fund,
            referral_vault,
            coin_b,
            expect_amount_out,
            slippage,
            ctx
        );
        let amount_out = coin::value(&coin_a);
        let (remainer_a, fee) = setting::pay_fee<CoinA>(bird_config, coin_a, ctx);

        emit(AftermathSwapEvent {
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
