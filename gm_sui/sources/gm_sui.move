module gm_sui::gm {
    use sui::object_table::{Self, ObjectTable};
    use std::string::String;
    
    public struct AdminCap has key {
        id: UID
    }

    public struct GmTracker has key, store {
        id: UID,
        // timestamp ms
        epoch_start: u64,
        gms: ObjectTable<String, Gm>,
    }

    public struct Gm has key, store {
        id: UID,
        sender: address,
        message: String,
        timezone: String
    }

    fun init(ctx: &mut TxContext) {
        let admin_cap = AdminCap {
            id: object::new(ctx)
        };
        let gm_tracker = GmTracker {
            id: object::new(ctx),
            epoch_start: tx_context::epoch_timestamp_ms(ctx),
            gms: object_table::new(ctx),
        };

        transfer::transfer(admin_cap, tx_context::sender(ctx));
        transfer::public_share_object(gm_tracker);
    }

    public fun new_gm(key: String, message: String, timezone: String, gm_tracker: &mut GmTracker, ctx: &mut TxContext) {
        let gm = Gm {
            id: object::new(ctx),
            sender: tx_context::sender(ctx),
            message: message,
            timezone: timezone,
        };

        object_table::add(&mut gm_tracker.gms, key, gm);
    }

    
}
