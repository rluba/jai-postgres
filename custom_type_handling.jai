Pg_Type_Handler :: #type (name: string, info: *Type_Info, slot: *u8, col_type: Pq_Type, len: int, data: *u8, row: int, col: int) -> bool;

register_pg_type_handler :: (oid: Oid, name: string, handler: Pg_Type_Handler) -> (success: bool) {

    for pg_custom_type_handlers {
        
        if it.oid == oid {
            return false;
        }
    }

    array_add(*pg_custom_type_handlers, .{
            oid = oid,
            name = copy_string(name),
            handler = handler,
        },
    );

    return true;
}

remove_pg_type_handler :: (oid: Oid) -> (success: bool) {
    
    for pg_custom_type_handlers {
        
        if it.oid == oid {
            remove it;
            return true;
        }
    }

    return false;
}

Pg_Type_Handler_Record :: struct {
    oid: Oid;
    name: string;
    handler: Pg_Type_Handler;
}

pg_custom_type_handlers: [..]Pg_Type_Handler_Record;
