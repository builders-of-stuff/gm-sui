module gm_sui::gm {
    use sui::object_table::{Self, ObjectTable};
    use std::string::String;

    use gm_sui::gm_coin::{Self, TreasuryCapHolder};
    
    public struct AdminCap has key {
        id: UID
    }

    public struct GmTracker has key, store {
        id: UID,
        gms: ObjectTable<String, Gm>,
        epoch_start_timestamp: u64,
    }

    public struct Gm has key, store {
        id: UID,
        sender: address,
        message: String,
        timestamp: u64,
    }

    fun init(ctx: &mut TxContext) {
        let admin_cap = AdminCap {
            id: object::new(ctx)
        };

        let gm_tracker = GmTracker {
            id: object::new(ctx),
            gms: object_table::new(ctx),
            epoch_start_timestamp: tx_context::epoch_timestamp_ms(ctx),
        };

        transfer::transfer(admin_cap, tx_context::sender(ctx));
        transfer::public_share_object(gm_tracker);
    }

    public fun new_gm(
        key: String,
        message: String,
        timestamp: u64,
        gm_tracker: &mut GmTracker,
        treasury_cap_holder: &mut TreasuryCapHolder,
        ctx: &mut TxContext
    ) {
        let gm = Gm {
            id: object::new(ctx),
            sender: tx_context::sender(ctx),
            message: message,
            timestamp: timestamp,
        };

        object_table::add(&mut gm_tracker.gms, key, gm);
        gm_coin::mint_one(treasury_cap_holder, ctx);
    }
}
