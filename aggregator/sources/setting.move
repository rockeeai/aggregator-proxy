module rockee_aggregator::setting {
    use sui::transfer::{public_transfer, public_share_object};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};

    use std::type_name::{Self, TypeName};
    use sui::bag::{Self as bag, Bag};

    use sui::event::emit;

    const EFeeConfigInvalid: u64 = 1000;
    const ETypeNotExist: u64 = 1001;

    const DENOMINATOR: u64 = 10000000;

    public struct SETTING has drop {}

    public struct AdminCap has key, store {
        id: UID,
    }

    public struct Config has store, key {
        id: UID,
        enable: bool,
        fee_rate: u64,
        balances: Bag,
    }

    public struct ReceiveFeeEvent has copy, drop {
        amount: u64,
        type_name: TypeName,
    }
    public struct UpdateFeeRateEvent has copy, drop {
        old_fee_rate: u64,
        new_fee_rate: u64,
    }
    public struct UpdateFeeStatus has copy, drop {
        current_status: bool,
        new_status: bool,
    }
    public struct ClaimFeeEvent has copy, drop {
        amount: u64,
        type_name: TypeName,
    }

    fun init(_witness: SETTING, ctx: &mut TxContext) {
        let config = Config {
            id: object::new(ctx), 
            enable: true,
            fee_rate: 5000, //0.05%
            balances: bag::new(ctx),
        };
        public_share_object(config);

        public_transfer(AdminCap { id: object::new(ctx) }, ctx.sender());
    }

    public fun update_fee_rate(_adminCap: &AdminCap, config: &mut Config, fee_rate: u64) {
        assert!(fee_rate > 1000, EFeeConfigInvalid);
        let old_fee_rate = config.fee_rate;
        config.fee_rate = fee_rate;
        let event = UpdateFeeRateEvent{
            old_fee_rate : old_fee_rate, 
            new_fee_rate : fee_rate,
        };
        emit<UpdateFeeRateEvent>(event)
    }

    public fun update_fee_status(_adminCap: &AdminCap, config: &mut Config, status: bool) {
        let current_status = config.enable;
        config.enable = status;
        let event = UpdateFeeStatus{
            current_status,
            new_status: status,
        };
        emit<UpdateFeeStatus>(event)
    }

    public fun pay_fee<T>(config: &mut Config, coin: Coin<T>, ctx: &mut TxContext): (Coin<T>, u64) {
        if (!config.enable) {
            return (coin, 0)
        };
        let coinType = type_name::get<T>();
        let mut balance = coin::into_balance(coin);
        let fee_amount = mul_div_floor(balance::value(&balance), config.fee_rate, DENOMINATOR);
        let fee_balance = balance::split<T>(&mut balance, fee_amount);
        if (bag::contains<TypeName>(&config.balances, coinType)) {
            balance::join<T>(bag::borrow_mut<TypeName, Balance<T>>(&mut config.balances, coinType), fee_balance);
        } else {
            bag::add<TypeName, Balance<T>>(&mut config.balances, coinType, fee_balance);
        };
        let event = ReceiveFeeEvent{
            amount: fee_amount, 
            type_name: coinType,
        };
        emit<ReceiveFeeEvent>(event);

        (coin::from_balance(balance, ctx), fee_amount)
    }

    #[allow(lint(self_transfer))]
    public fun claim_fee<T>(_adminCap: &AdminCap, config: &mut Config, ctx: &mut TxContext) {
        let coinType = type_name::get<T>();
        assert!(bag::contains<TypeName>(&config.balances, coinType), ETypeNotExist);
        let fee = bag::remove<TypeName, Balance<T>>(&mut config.balances, coinType);
        let fee_amount = balance::value<T>(&fee);
        public_transfer<coin::Coin<T>>(coin::from_balance<T>(fee, ctx), ctx.sender());
        let event = ClaimFeeEvent{
            amount: fee_amount, 
            type_name: coinType,
        };
        emit<ClaimFeeEvent>(event);
    }

    public fun full_mul(arg0: u64, arg1: u64) : u128 {
        (arg0 as u128) * (arg1 as u128)
    }
    
    public fun mul_div_ceil(arg0: u64, arg1: u64, arg2: u64) : u64 {
        ((full_mul(arg0, arg1) + (arg2 as u128) - 1) / (arg2 as u128)) as u64
    }
    
    public fun mul_div_floor(arg0: u64, arg1: u64, arg2: u64) : u64 {
        (full_mul(arg0, arg1) / (arg2 as u128)) as u64
    }
}
