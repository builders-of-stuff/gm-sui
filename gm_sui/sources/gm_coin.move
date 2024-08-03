module gm_sui::gm_coin {
    use sui::coin::{Self, TreasuryCap};

    public struct GM_COIN has drop {}

    public struct TreasuryCapHolder has key {
        id: UID,
        treasury_cap: TreasuryCap<GM_COIN>
    }

    fun init(witness: GM_COIN, ctx: &mut TxContext) {
        let (treasury_cap, coin_metadata) = coin::create_currency(
            witness,
            9,
            b"GMC",
            b"GM Coin",
            b"gm",
            option::none(),
            ctx
        );

        transfer::public_freeze_object(coin_metadata);

        let treasury_cap_holder = TreasuryCapHolder {
            id: object::new(ctx),
            treasury_cap,
        };
        transfer::share_object(treasury_cap_holder);
    }

    public fun mint_one(
        treasury_cap_holder: &mut TreasuryCapHolder,
        ctx: &mut TxContext
    ) {
        let treasury_cap = &mut treasury_cap_holder.treasury_cap;

        coin::mint_and_transfer(treasury_cap, 1000000000, tx_context::sender(ctx), ctx)
    }
    
}
