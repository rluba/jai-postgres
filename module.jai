connect :: (conn_str: string) -> *PGconn, success: bool {
    conn_c_str := to_c_string(conn_str);
    defer free(conn_c_str);
    conn := PQconnectStart(conn_c_str);
    if PQstatus(conn) == ConnStatusType.CONNECTION_BAD {
        log_error("Couldn’t start connecting\n");
        return conn, false;
    }

    result := PQconnectPoll(conn);
    while result != PostgresPollingStatusType.PGRES_POLLING_OK && result != PostgresPollingStatusType.PGRES_POLLING_FAILED {
        newResult := PQconnectPoll(conn);
        // if (result != newResult) {
        //     print("Connecting… %\n", result);
        // }
        result = newResult;
    }

    if result == PostgresPollingStatusType.PGRES_POLLING_FAILED {
        log_error("Couldn’t connect: %\n", PQstatus(conn));
        return conn, false;
    }
    return conn, true;
}

disconnect :: (conn: *PGconn) {
    if conn {
        PQfinish(conn);
    }
}

// Execute a statement and parse the result
execute :: (conn: *PGconn, $T: Type, command: string, args: .. Any, $ignore_unknown := false) -> [] T, success: bool {
    success := send_query(conn, command, ..args);
    if !success return .[], false;

    query_res := get_last_query_result(conn);
    defer PQclear(query_res);

    has_results: bool;
    results: [] T;
    has_results, success = check_query_result(query_res);
    if !success        return results, false;

    if has_results {
        results, success = get_results(query_res, T, ignore_unknown);
    }
    return results, success;
}

// Execute a statement without parsing the result (eg. for DELETE et al)
execute :: (conn: *PGconn, command: string, args: .. Any) -> success: bool {
    success := send_query(conn, command, ..args);
    if !success false;

    query_res := get_last_query_result(conn);
    defer PQclear(query_res);

    has_results: bool;
    has_results, success = check_query_result(query_res);

    return success;
}

send_query :: (conn: *PGconn, command: string, args: .. Any) -> success: bool {
    pool: Pool;
    set_allocators(*pool);
    defer release(*pool);

    push_allocator(pool_allocator_proc, *pool);

    param_types   := NewArray(args.count, Oid, initialized = false);
    param_values  := NewArray(args.count, *u8, initialized = false);
    param_lengths := NewArray(args.count, s32, initialized = false);
    param_formats := NewArray(args.count, s32, initialized = false);

    for arg, index: args {
        if arg.type.type == {
            case Type_Info_Tag.INTEGER;
                info := cast(*Type_Info_Integer) arg.type;
                // @ToDo: implement unsigned ints
                assert(info.signed, "Unsigned not yet supported");
                be_value := cast(*u8) alloc(info.runtime_size);
                if info.runtime_size == {
                    case 2;
                        param_types[index] = cast(Oid) Pq_Type.INT2;
                        be_val := hton(<<(cast(*s16) arg.value_pointer));
                        memcpy(be_value, *be_val, info.runtime_size);
                    case 4;
                        param_types[index] = cast(Oid) Pq_Type.INT4;
                        be_val := hton(<<(cast(*s32) arg.value_pointer));
                        memcpy(be_value, *be_val, info.runtime_size);
                    case 8;
                        param_types[index] = cast(Oid) Pq_Type.INT8;
                        be_val := hton(<<(cast(*s64) arg.value_pointer));
                        memcpy(be_value, *be_val, info.runtime_size);
                    case;
                        assert(false);
                }
                param_values[index] = be_value;
                param_lengths[index] = cast(s32) info.runtime_size;
                param_formats[index] = 1;

            case Type_Info_Tag.FLOAT;
                be_value := cast(*u8) alloc(arg.type.runtime_size);
                if arg.type.runtime_size == 4 {
                    param_types[index] = cast(Oid) Pq_Type.FLOAT4;
                    be_val := hton(<<(cast(*float) arg.value_pointer));
                    memcpy(be_value, *be_val, arg.type.runtime_size);
                }
                if arg.type.runtime_size == 8 {
                    param_types[index] = cast(Oid) Pq_Type.FLOAT8;
                    be_val := hton(<<(cast(*float64) arg.value_pointer));
                    memcpy(be_value, *be_val, arg.type.runtime_size);
                }
                param_values[index] = be_value;
                param_lengths[index] = cast(s32) arg.type.runtime_size;
                param_formats[index] = 1;

            case Type_Info_Tag.STRING;
                str := cast(*string) arg.value_pointer;
                param_types[index] = cast(Oid) Pq_Type.VARCHAR;
                param_values[index] = str.data;
                param_lengths[index] = cast(s32) str.count;
                param_formats[index] = 1;

            // ToDo: Struct as Jsonb?
            // ToDo: Array?

            case;
                // @ToDo: Implement
                log_error("Unsupported param type: %", arg.type.type);
                return false;
        }
    }

    c_command := to_c_string(command);

    result: int;
    if args.count == 0 {
        result = PQsendQuery(conn, c_command);
    } else {
        result = PQsendQueryParams(conn, c_command, cast(s32) args.count, param_types.data, param_values.data, param_lengths.data, param_formats.data, 1);
    }
    if result == 0 {
        error_message: string;
        error_message.data = PQerrorMessage(conn);
        error_message.count = c_style_strlen(error_message.data);
        log_error("Could not send query: %", error_message);
        return false;
    }

    return true;
}


get_last_query_result :: (conn: *PGconn) -> *PGresult {
    query_result: *PGresult;
    while true {
        latest_result := PQgetResult(conn);
        if latest_result == null break;
        if query_result PQclear(query_result);
        query_result = latest_result;
    }

    return query_result;
}

check_query_result :: (query_res: *PGresult) -> has_results: bool, success: bool {
    res_status := PQresultStatus(query_res);
    if res_status == {
        case ExecStatusType.PGRES_EMPTY_QUERY;
            return false, true;
        case ExecStatusType.PGRES_COMMAND_OK;
            return false, true;
        case ExecStatusType.PGRES_TUPLES_OK;
            return true, true;
        case ExecStatusType.PGRES_FATAL_ERROR;
            error_message: string;
            error_message.data = PQresultErrorMessage(query_res);
            error_message.count = c_style_strlen(error_message.data);
            log_error("Fatal error: %", error_message);
            return false, false;
        case;
            log_error("Query result status: %", res_status);
            return false, false;
    }
}

get_results :: (query_res: *PGresult, $T: Type, $ignore_unknown := false) -> [] T, success: bool {
    raw_result, success := get_results(query_res, type_info(T), ignore_unknown);
    return xx raw_result, success;
}

get_results :: (query_res: *PGresult, info: *Type_Info, ignore_unknown := false) -> Array_View_64, success: bool {
    // @ToDo: Allow to cast single-column results directly to primitive types
    assert(info.type == .STRUCT);
    info_struct := cast(*Type_Info_Struct) info;

    num_tuples := PQntuples(query_res);
    results: Array_View_64;
    results.data = alloc(info.runtime_size * num_tuples);
    results.count = num_tuples;
    initializer := info_struct.initializer;
    if !initializer {
        memset(results.data, 0, info.runtime_size * num_tuples);
    }

    num_columns := PQnfields(query_res);
    column_members := NewArray(num_columns, *Type_Info_Struct_Member, initialized = false);
    defer array_free(column_members);

    for col: 0..num_columns - 1 {
        name: string;
        name.data = PQfname(query_res, col);
        name.count = c_style_strlen(name.data);
        member := get_field(info_struct, name);
        if !ignore_unknown && !member {
            log_error("Column \"%\" has no corresponding member in struct type \"%\"", name, <<info_struct);
            return results, false;
        }
        column_members[col] = member;
    }

    for row: 0..num_tuples - 1 {
        row_data := results.data + (info.runtime_size * row);
        if initializer initializer(row_data);

        for col: 0..num_columns - 1 {
            member := column_members[col];
            if !member    continue;

            if PQgetisnull(query_res, row, col) {
                // @ToDo: Handle pointer member types and null them
                // We keep the value as default instead, atm.
            } else {
                type := PQftype(query_res, col);
                len := PQgetlength(query_res, row, col);
                data := PQgetvalue(query_res, row, col);
                slot := row_data + member.offset_in_bytes;
                success := assign_member(member.name, member.type, slot, cast(Pq_Type) type, len, data, row, col);
                if !success        return results, false;
            }
        }
    }

    return results, true;
}

#scope_module

assign_member :: (name: string, info: *Type_Info, slot: *u8, col_type: Pq_Type, len: int, data: *u8, row: int, col: int) -> bool {
    if col_type == {
        case .INT2;
            // Explicitly throwing away 48 bits.
            val := ntoh(<< cast(*s16) data);
            return write_integer(col, name, info, slot, col_type, val);

        case .INT4;
            // Explicitly throwing away 32 bits.
            val := ntoh(<< cast(*s32) data);
            return write_integer(col, name, info, slot, col_type, val);

        case .INT8;
            val := ntoh(<< cast(*s64) data);
            return write_integer(col, name, info, slot, col_type, val);

        case .FLOAT8; // Note: We get this as a string!
            if info.type != Type_Info_Tag.FLOAT {
                log_error("Error: Trying to write float column % into member field \"%\" of type %", col, name, info.type);
                return false;
            }

            strval: string;
            strval.data = data;
            strval.count = len;
            success: bool;
            if info.runtime_size == 4 {
                << (cast(*float) slot), success = string_to_float(strval);
            } else {
                assert(info.runtime_size == 8);
                << (cast(*float64) slot), success = string_to_float64(strval);
            }
            assert(success, "Could not parse string \"%\" as float", strval);
            return true;

        case .NUMERIC;
            if info.type != Type_Info_Tag.STRING {
                log_error("Error: Trying to write numeric column % into member field \"%\" of type %", col, name, info.type);
                return false;
            }
            << (cast(*string) slot) = str_from_numeric(data, len, row, col);
            return true;

        case .BOOL;
            assert(len == 1);
            if info.type != Type_Info_Tag.BOOL {
                log_error("Error: Trying to write bool column % into member field \"%\" of type %", col, name, info.type);
                return false;
            }

            val := << cast(*u8) data;
            << (cast(*bool) slot) = (val != 0);
            return true;

        case .CHAR; #through;
        case .BPCHAR; #through;
        case .VARCHAR; #through;
        case .TEXT;
            val: string;
            val.data = data;
            val.count = len;
            write_string_value(col, name, info, slot, col_type, val, is_custom = false);
            return true;

        case .TIMESTAMP;
            val := ntoh(<< cast(*s64) data);
            // shift from 2000 to 1970
            val += 946_684_800_000000;
            if info.type == .STRING {
                ts: timespec;
                ts.tv_sec = val / 1_000_000;
                ts.tv_nsec = (val % 1_000_000) * 1000;
                apollo := timespec_to_apollo(ts);
                calendar := to_calendar(apollo);
                iso := calendar_to_iso_string(calendar);
                return write_string_value(col, name, info, slot, col_type, iso, is_custom = false);
            } else {
                // @ToDO, @Incomplete: Support a special structure that keeps track of is_utc flag?
                return write_integer(col, name, info, slot, col_type, val);
            }

        case .TIMESTAMPTZ;
            val := ntoh(<< cast(*s64) data);
            // shift from 2000 to 1970
            val += 946_684_800_000000;
            // @ToDO, @Incomplete: Support a special structure that keeps track of is_utc flag?
            return write_integer(col, name, info, slot, col_type, val);

        case;
            if cast(s64) col_type > enum_highest_value(Pq_Type) {
                // Seems to be a custom type. Try to interpret it as a string
                val: string;
                val.data = data;
                val.count = len;
                return write_string_value(col, name, info, slot, col_type, val, is_custom = true);
            } else {
                log_error("Error: column % type % (with length %) is not yet implemented (for member %)", col, col_type, len, name);
            }
            return false;
    }
}

write_string_value :: (col: int, name: string, info: *Type_Info, slot: *void, col_type: Pq_Type, value: string, is_custom: bool) -> bool {
    if info.type == {
        case .STRING;
            << (cast(*string) slot) = copy_string(value);
            return true;
        case .ENUM;
            info_enum := cast(*Type_Info_Enum) info;
            for info_enum.names {
                if it == value {
                    return write_integer(col, name, info_enum.internal_type, slot, col_type, info_enum.values[it_index]);
                }
            }

            log_error("Error: Could not find an enum value for value \"%\" of column % for member field \"%\"", value, col, name);
            return false;
        case;
            if is_custom {
                log_error("Error: Trying to write custom type of column % into member field \"%\" of type %", col, name, info.type);
            } else {
                log_error("Error: Trying to write column % of type % into member field \"%\" of type %", col, col_type, name, info.type);
            }
            return false;
    }
}

write_integer :: (col: int, name: string, info: *Type_Info, pointer: *void, col_type: Pq_Type, value: s64) -> bool {
    if info.type != Type_Info_Tag.INTEGER {
        log_error("Error: Trying to write column % of type % as an integer into member field \"%\" of type %", col, col_type, name, info.type);
        return false;
    }
    int_info := cast(*Type_Info_Integer) info;

    if int_info.signed {
        valid, low, high := range_check_and_store(value, int_info, pointer);

        if !valid {
            log_error("Value % of column % is out of range for \"%\". (The value must be between % and %.)", value, col, name, low, high);
            return false;
        }
    } else {
        valid, low, high := range_check_and_store(cast(u64) value, int_info, pointer);  // Different overload from the above!

        if !valid {
            log_error("Value % of column % is out of range for \"%\". (The value must be between % and %.)", value, col, name, low, high);
            return false;
        }
    }

    return true;
}

range_check_and_store :: (value: $T, info: *Type_Info_Integer, pointer: *void) -> (success: bool, low: T, high: T) {
    #assert((T == u64) || (T == s64));

    size := info.runtime_size;

    #if T == u64 {
        low, high := unsigned_integer_range_from_size(size);
        if (value < low) || (value > high)  return false, low, high;

        store(pointer, value, size);
        return true, low, high;
    } else {
        low, high := signed_integer_range_from_size(size);
        if (value < low) || (value > high)  return false, low, high;

        store(pointer, value, size);
        return true, low, high;
    }

    store :: (pointer: *void, value: T, size: int) {
        if size == {
            case 1;
                << cast(*s8)  pointer = xx,no_check value;
            case 2;
                << cast(*s16) pointer = xx,no_check value;
            case 4;
                << cast(*s32) pointer = xx,no_check value;
            case 8;
                << cast(*s64) pointer = xx,no_check value;
            case;
            assert(false);
        }
    }
}

signed_integer_range_from_size :: (size_in_bytes: int) -> (low: s64, high: s64) {
    assert((size_in_bytes == 1) || (size_in_bytes == 2) || (size_in_bytes == 4) || (size_in_bytes == 8));

    high := (1 << (size_in_bytes*8-1)) - 1;
    low  := ~high;

    return low, high;
}

unsigned_integer_range_from_size :: (size_in_bytes: int) -> (low: u64, high: u64) {
    assert((size_in_bytes == 1) || (size_in_bytes == 2) || (size_in_bytes == 4) || (size_in_bytes == 8));

    high: u64 = ---;
    if size_in_bytes == 8 {
        high = cast(u64) 0xffff_ffff_ffff_ffff;  // Hardcode 8 to prevent unpredictable behavior due to platform-specific details. In the future the outcome of << will be language-defined in all cases.
    } else {
        high = cast(u64) (1 << (size_in_bytes*8)) - 1;  // @CompilerBug: Why do we need to cast the 1? That is dumb.
    }

    return 0, high;
}

str_from_numeric :: (data: *u8, len: int, row: int, col: int) -> string, success: bool {
    if len < 8 {
        log_error("Invalid numeric length at row % col %: %", row, col, len);
        return "", false;
    }

    num_digits := ntoh(<< cast(*u16) data);
    weight := ntoh(<< cast(*s16) (data + 2));
    sign := ntoh(<< cast(*u16) (data + 4));
    dscale := ntoh(<< cast(*u16) (data + 6));
    if len != num_digits * 2 + 8 {
        log_error("Invalid numeric length at row % col %: %", row, col, len);
        return "", false;
    }
    if dscale > 0x3fff {
        log_error("Invalid numeric dscale at row % col %: %", row, col, dscale);
        return "", false;
    }

    builder: String_Builder;
    defer free_buffers(*builder);

    if sign == {
        case 0x0000;

        case 0x4000;
            append(*builder, "-");

        case 0xc000;
            append(*builder, "NaN");

        case;
            log_error("Invalid numeric sign at row % col%: %", row, col, sign);
            return "", false;
    }

    index := 0;
    if weight >= 0 && num_digits {
        min_digits := 1;
        while weight >= 0 && index < num_digits {
            digit := ntoh(<< cast(*s16) (data + 8 + index * 2));
            print_to_builder(*builder, "%", formatInt(digit, minimum_digits=min_digits));
            min_digits = 4;
            weight -= 1;
            index += 1;
        }
        while weight >= 0 {
            append(*builder, "0000");
            weight -= 1;
        }
    } else {
        append(*builder, "0");
    }

    if dscale != 0     append(*builder, ".");
    dec_len := 0;

    omitted := -1 - weight;
    if omitted > 0 {
        zeros: int;
        if 4 * omitted > cast(s32) dscale {
            zeros = dscale;
        } else {
            zeros = 4 * omitted;
        }
        print_to_builder(*builder, "%", formatInt(0, minimum_digits=zeros));
        dec_len += zeros;
    }
    min_digits := 4;
    while index < num_digits {
        digit := ntoh(<< cast(*s16) (data + 8 + index * 2));
        if dec_len + 4 > dscale {
            remaining := dscale - dec_len;
            assert(remaining > 0, "Unexpected number of remaining digits: %", remaining);
            for 1..(4 - remaining)     digit /= 10;
            min_digits = remaining;
        }
        print_to_builder(*builder, "%", formatInt(digit, minimum_digits=min_digits));
        index += 1;
        dec_len += min_digits;
    }
    if (dec_len < dscale) {
        print_to_builder(*builder, "%", formatInt(0, minimum_digits=dscale-dec_len));
    }

    return builder_to_string(*builder), true;
}

#import "Basic";
#import "Pool";

#load "byte_order.jai";
#load "pq_types.jai";

#if OS == .WINDOWS {
    #assert(false); // No Windows bindings yet
    // #load "bindings/windows.jai";
} else {
    #import "POSIX";
    #load "bindings/unix.jai";
}
