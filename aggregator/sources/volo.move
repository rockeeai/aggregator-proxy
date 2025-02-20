module rockee_aggregator::volo {

    use std::type_name;
    use std::type_name::TypeName;
    use sui::coin;
    use sui::coin::Coin;
    use sui::event;
    use sui::sui::SUI;
    use sui_system::sui_system::SuiSystemState;
    use vsui::cert::CERT;
    use vsui::native_pool::{NativePool, stake_non_entry};

    use rockee_aggregator::setting::{Self, Config};

    public struct VoloSwapEvent has copy, store, drop {
        amount_in: u64,
        amount_out: u64,
        coin_a: TypeName,
        coin_b: TypeName,
    }

    public fun swap_a2b(
        bird_config: &mut Config,
        pool: &mut NativePool,
        metadata: &mut vsui::cert::Metadata<CERT>,
        sui_system: &mut SuiSystemState,
        coin_input: Coin<SUI>,
        ctx: &mut TxContext,
    ): Coin<CERT> {
        let amount_in = coin::value(&coin_input);
        let r = stake_non_entry(pool, metadata, sui_system, coin_input, ctx);
        let amount_out = coin::value(&r);

        let (remainer, fee) = setting::pay_fee<CERT>(bird_config, r, ctx);

        event::emit(VoloSwapEvent {
            amount_in,
            amount_out: amount_out - fee,
            coin_a: type_name::get<SUI>(),
            coin_b: type_name::get<CERT>()
        });

        remainer
    }
}