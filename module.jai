#module_parameters ()(SUPPORT_DATE_AS_STRINGS := false); // SUPPORT_DATE requires https://github.com/rluba/jai-date, at least for now.

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
execute :: (conn: *PGconn, command: string, args: .. Any) -> success: bool, update_rows: int {
    success := send_query(conn, command, ..args);
    if !success false;

    query_res := get_last_query_result(conn);
    defer PQclear(query_res);

    has_results: bool;
    update_rows: int;
    has_results, success, update_rows = check_query_result(query_res);

    return success, update_rows;
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
            case .INTEGER;
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

            case .FLOAT;
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
                param_values[index]  = be_value;
                param_lengths[index] = cast(s32) arg.type.runtime_size;
                param_formats[index] = 1;

            case .STRING;
                str := cast(*string) arg.value_pointer;
                param_types[index]   = cast(Oid) Pq_Type.TEXT;
                param_values[index]  = ifx str.data else ""; // This handles empty strings. Sending no data means null string
                param_lengths[index] = cast(s32) str.count;
                param_formats[index] = 1;

            case .BOOL;
                val := cast(*bool) arg.value_pointer;
                param_types[index]   = cast(Oid) Pq_Type.BOOL;
                param_values[index]  = ifx val.* then *BOOL_TRUE_VALUE else *BOOL_FALSE_VALUE;
                param_lengths[index] = 1;
                param_formats[index] = 1;

            // case .ARRAY;
                // @ToDo: Implement binary format according to array_recv format.
                // See https://doxygen.postgresql.org/arrayfuncs_8c.html#a315b67e6e01e8f283326b5a6b27e07c9
                //
                // Format seems to be:
                //   4 byte number of dimensions
                //   4 byte flags (seems unused, but must be 0 or 1)
                //   4 byte element type (sizeof OID, actually…)
                // Then for each dimension:
                //   4 byte number of elements
                //   4 byte lower bound
                // Then for each element:
                //   4 byte length
                //   n byte encoded element
                //
                // But given the overhead, maybe it would be smarter to just serialize arrays as strings?
                // Eg. an array of two ints would be 28 bytes + 2 * int size.
                // The string equivalent would be 3 bytes + string-size of the integers

            // ToDo: Struct as Jsonb?

            case;
                // @ToDo: Implement
                log_error("Unsupported param type: %", arg.type.type);
                return false;
        }
    }

    c_command := to_c_string(command);

    result: int;
    result = PQsendQueryParams(conn, c_command, cast(s32) args.count, param_types.data, param_values.data, param_lengths.data, param_formats.data, 1);
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

check_query_result :: (query_res: *PGresult) -> has_results: bool, success: bool, updated_rows: int {
    res_status := PQresultStatus(query_res);
    if res_status == {
        case ExecStatusType.PGRES_EMPTY_QUERY;
            return false, true, 0;
        case ExecStatusType.PGRES_COMMAND_OK;
            rows_affected := to_string(PQcmdTuples(query_res));
            rows_affected_count := string_to_int(rows_affected);

            return false, true, rows_affected_count;
        case ExecStatusType.PGRES_TUPLES_OK;
            return true, true, 0;
        case ExecStatusType.PGRES_FATAL_ERROR;
            error_message := to_string(PQresultErrorMessage(query_res));
            log_error("Fatal error: %", error_message);
            return false, false, 0;
        case ExecStatusType.PGRES_NONFATAL_ERROR;
            error_message := to_string(PQresultErrorMessage(query_res));
            log_error("Non-fatal error: %", error_message);
            return false, false, 0;
        case;
            log_error("Query result status: %", res_status);
            return false, false, 0;
    }
}

get_results :: (query_res: *PGresult, $T: Type, $ignore_unknown := false) -> [] T, success: bool {
    raw_result, success := get_results(query_res, type_info(T), ignore_unknown);

    results: []T;
    results.data = xx raw_result.data;
    results.count = raw_result.count;
    return results, success;
}

Member_Offset :: struct {
    member: *Type_Info_Struct_Member;
    offset_in_bytes: s64;
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
    column_members := NewArray(num_columns, Member_Offset, initialized = false);
    defer array_free(column_members);

    for col: 0..num_columns - 1 {
        name: string;
        name.data = PQfname(query_res, col);
        name.count = c_style_strlen(name.data);
        member, offset_in_bytes := get_field(info_struct, name);
        if !ignore_unknown && !member {
            log_error("Column \"%\" has no corresponding member in struct type \"%\"", name, <<info_struct);
            return results, false;
        }
        column_members[col] = .{member, offset_in_bytes};
    }

    for row: 0..num_tuples - 1 {
        row_data := results.data + (info.runtime_size * row);
        if initializer initializer(row_data);

        for col: 0..num_columns - 1 {
            member_offset := column_members[col];
            if !member_offset.member    continue;

            if PQgetisnull(query_res, row, col) {
                // @ToDo: Handle pointer member types and null them
                // We keep the value as default instead, atm.
            } else {
                type := PQftype(query_res, col);
                len := PQgetlength(query_res, row, col);
                data := PQgetvalue(query_res, row, col);
                slot := row_data + member_offset.offset_in_bytes;
                success := assign_member(member_offset.member.name, member_offset.member.type, slot, cast(Pq_Type) type, len, data, row, col);
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
            assert(len == 2);
            // Explicitly throwing away 48 bits.
            val := ntoh(<< cast(*s16) data);
            return write_integer(col, name, info, slot, col_type, val);

        case .OID; #through;
        case .INT4;
            assert(len == 4);
            // Explicitly throwing away 32 bits.
            val := ntoh(<< cast(*s32) data);
            return write_integer(col, name, info, slot, col_type, val);

        case .INT8;
            assert(len == 8);
            val := ntoh(<< cast(*s64) data);
            return write_integer(col, name, info, slot, col_type, val);

        case .FLOAT4;
            if info.type != Type_Info_Tag.FLOAT {
                log_error("Error: Trying to write float4 column % into member field \"%\" of type %", col, name, info.type);
                return false;
            }

            if info.runtime_size == 4 {
                << (cast(*float32) slot) = ntoh(<<(cast(*float32) data));
            } else {
                assert(info.runtime_size == 8);
                << (cast(*float64) slot) = cast(float64) ntoh(<<(cast(*float32) data));
            }
            return true;

        case .FLOAT8;
            if info.type != Type_Info_Tag.FLOAT {
                log_error("Error: Trying to write float8 column % into member field \"%\" of type %", col, name, info.type);
                return false;
            }

            if info.runtime_size == 4 {
                << (cast(*float32) slot) = cast(float32) ntoh(<<(cast(*float64) data));
            } else {
                assert(info.runtime_size == 8);
                << (cast(*float64) slot) = ntoh(<<(cast(*float64) data));
            }
            return true;

        case .NUMERIC;
            if info.type != Type_Info_Tag.STRING {
                log_error("Error: Trying to write numeric column % into member field \"%\" of type %, but we only support writing to string fields at the moment.", col, name, info.type);
                return false;
            }
            success: bool;
            << (cast(*string) slot), success = str_from_numeric(data, len, row, col);
            return success;

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
        case .NAME; #through;
        case .TEXT;
            val: string;
            val.data = data;
            val.count = len;
            write_string_value(col, name, info, slot, col_type, val, is_custom = false);
            return true;

        case .DATE;
            assert(len == 4);
            days_since_2000_01_01 := ntoh(<< cast(*s32) data);
            if info.type == Type_Info_Tag.INTEGER {
                return write_integer(col, name, info, slot, col_type, days_since_2000_01_01);
            } else {
                #if SUPPORT_DATE_AS_STRINGS {
                    #import "date"; // https://github.com/rluba/jai-date
                    date := Date.{2000, 1, 1};
                    add(*date, days_since_2000_01_01, .DAY);
                    if info == type_info(Date) {
                        target := cast(*Date) slot;
                        <<target = date;
                        return true;
                    } else if info == type_info(Apollo_Time) {
                        target := cast(*Apollo_Time) slot;
                        <<target = to_apollo_time(date);
                        return true;
                    } else {
                        date_string := string_from_date(date, .ISO);
                        return write_string_value(col, name, info, slot, col_type, date_string, is_custom = false);
                    }
                } else {
                    log_error("Error: Trying to write column % of type % into member field \"%\" of type %", col, col_type, name, info.type);
                    return false;
                }
            }
        case .TIMESTAMP;   #through;
        case .TIMESTAMPTZ;
            val := ntoh(<< cast(*s64) data);
            // shift from 2000 to 1970
            val += 946_684_800_000000;
            if info.type == .STRING || info == type_info(Apollo_Time) {
                a_seconds     :=     seconds_to_apollo(val / 1_000_000);
                a_nanoseconds := nanoseconds_to_apollo((val % 1_000_000) * 1000);

                apollo := a_seconds + a_nanoseconds + APOLLO_TIME_FOR_JAN_1_1970;

                if info == type_info(Apollo_Time) {
                    target := cast(*Apollo_Time) slot;
                    <<target = apollo;
                    return true;
                } else {
                    calendar := to_calendar(apollo);
                    iso := calendar_to_iso_string(calendar);
                    return write_string_value(col, name, info, slot, col_type, iso, is_custom = false);
                }
            } else {
                return write_integer(col, name, info, slot, col_type, val);
            }

        case .UUID; #through;
        case .BYTEA;
            if info.type == .ARRAY {
                array_info := cast(*Type_Info_Array) info;
                element_size := array_info.element_type.runtime_size;
                assert(element_size != -1);
                if element_size != 1 {
                    log_error("Error: Trying to write column % of type % with array count % into member field \"%\" with array element size of % instead of 1!", col, col_type, len, name, element_size);
                    return false;
                }

                dest_data_pointer: *void;
                if array_info.array_type == .VIEW {
                    view := (cast(*Array_View_64) slot);
                    view.count = len;
                    view.data = alloc(len * element_size);
                    dest_data_pointer = view.data;
                } else if array_info.array_count == -1 {
                    resizable_array := cast(*Resizable_Array) slot;
                    array_reserve(resizable_array, len, element_size);
                    resizable_array.count = len;
                    dest_data_pointer = resizable_array.data;
                } else {
                    if array_info.array_count != len {
                        log_error("Error: Trying to write column % of type % with array count % into member field \"%\", which is a fixed-size array with count %. For fixed-size arrays, the size must match!", col, col_type, len, name, array_info.array_count);
                        return false;
                    }
                    dest_data_pointer = slot;
                }

                memcpy(dest_data_pointer, data, element_size * len);
                return true;
            } else {
                log_error("Error: Trying to write column % of type % into member field \"%\" of type %", col, col_type, name, info.type);
                return false;
            }

        case;

            // See if we have a handler that knows how to deal with this type
            for pg_custom_type_handlers {
                if it.oid != col_type.(Oid) continue;
                return it.handler(name, info, slot, col_type, len, data, row, col);
            }

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
        valid, low, high := Reflection.range_check_and_store(value, int_info, pointer);

        if !valid {
            log_error("Value % of column % is out of range for \"%\". (The value must be between % and %.)", value, col, name, low, high);
            return false;
        }
    } else {
        valid, low, high := Reflection.range_check_and_store(cast(u64) value, int_info, pointer);  // Different overload from the above!

        if !valid {
            log_error("Value % of column % is out of range for \"%\". (The value must be between % and %.)", value, col, name, low, high);
            return false;
        }
    }

    return true;
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

BOOL_TRUE_VALUE:  u8 = 1;
BOOL_FALSE_VALUE: u8 = 0;

#import "Basic";
#import "Pool";
Reflection :: #import "Reflection";

#load "byte_order.jai";
#load "pq_types.jai";
#load "custom_type_handling.jai";

#if OS == .WINDOWS {
    Windows :: #import "Windows";
    #load "bindings/windows.jai";
    size_t :: Windows.size_t;
    FILE :: *void;
} else {
    #import "POSIX";
    #load "bindings/unix.jai";
}
