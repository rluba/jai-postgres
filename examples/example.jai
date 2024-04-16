main :: () {
    args := get_command_line_arguments();
    if args.count != 2 {
        log_error("Usage: % <postgres_connection_url>", args[0]);
        exit(1);
    }

    db_url := args[1];

    conn, success := connect(db_url);
    defer disconnect(conn);
    if !success        exit(1);

    // Let’s just test deserializing all the supported column types:
    QUERY :: #string END
        SELECT
            1::int2, 2::int4, 3::int8,
            2.5::float8, 3.5::float8 as float8_to_4, 4.5::float4, 5.5::float4 as float4_to_8, 6.5::numeric(8, 2),
            true "boolean_true",
            false "boolean_false",
            'a'::char(3) "char", 'b'::bpchar "bpchar", 'c'::varchar, 'd'::name, 'e'::text,
            '2023-05-15'::timestamp, '2023-05-14 UTC'::timestamptz,
            '2023-05-15T14:30:00'::timestamp time_wo_tz, '2023-05-15T14:30:00 Europe/Vienna'::timestamptz time_with_tz, '2023-05-15T14:30:00 UTC'::timestamptz time_utc,
            '2023-05-15T14:30:00'::timestamp timestamp_apollo, -- Test writing timestamp into Apollo_Time
            '2023-10-24'::date real_date,
            -- '2023-10-24'::date real_date_apollo,          -- Test writing date into Apollo_Time
            'Hello, Sailor!'::bytea sailor_bytes,         -- Test [] case
            'Hello, Sailor!'::bytea sailor_bytes_dynamic, -- Test [..] case
            'Hello, Sailor!'::bytea sailor_bytes_fixed    -- Test [n] case
    END

    results: [] Test;
    results, success = execute(conn, Test, QUERY);
    assert(success);
    log("Results: %", results);
    assert(results.count == 1);

    result := results[0];
    assert(result.int2          == 1);
    assert(result.int4          == 2);
    assert(result.int8          == 3);
    assert(result.float8        == 2.5);
    assert(result.float8_to_4   == 3.5);
    assert(result.float4        == 4.5);
    assert(result.float4_to_8   == 5.5);
    assert(result.numeric       == "6.50");
    assert(result.boolean_true  == true);
    assert(result.boolean_false == false);
    assert(result.char          == "a  ");
    assert(result.bpchar        == "b");
    assert(result.varchar       == "c");
    assert(result.name          == "d");
    assert(result.text          == "e");
    assert(result.timestamp     == "2023-05-15T00:00:00.000Z");
    assert(result.timestamptz   == 1684022400000000);
    assert(calendar_to_iso_string(to_calendar(result.timestamp_apollo)) == "2023-05-15T14:30:00.000Z");
    assert(result.real_date   == 8697); // Days since 2000-01-01
    // assert(calendar_to_iso_string(to_calendar(result.real_date_apollo)) == "2023-10-24T00:00:00.000Z");
    assert(cast(string) result.sailor_bytes         == "Hello, Sailor!");
    assert(cast(string) result.sailor_bytes_dynamic == "Hello, Sailor!");
    assert(cast(string) result.sailor_bytes_fixed   == "Hello, Sailor!");
    log("% vs % vs %", result.time_wo_tz, result.time_with_tz, result.time_utc);
    log("ALL OK");
}

Test :: struct {
    int2:                 int;
    int4:                 int;
    int8:                 s64;
    float8:               float64;
    float8_to_4:          float32;
    float4:               float32;
    float4_to_8:          float64;
    numeric:              string;
    boolean_true:         bool;
    boolean_false:        bool;
    char:                 string;
    bpchar:               string;
    varchar:              string;
    name:                 string;
    text:                 string;
    timestamp:            string;
    timestamptz:          s64;
    timestamp_apollo:     Apollo_Time;
    time_wo_tz:           s64;
    time_with_tz:         s64;
    time_utc:             s64;
    real_date:            s64;
    // real_date_apollo:     Apollo_Time; // Only works with SUPPORT_DATE_AS_STRINGS
    sailor_bytes:         [] u8;
    sailor_bytes_dynamic: [..] u8;
    sailor_bytes_fixed:   [14] u8;
}

#import,file "../module.jai";
#import "Basic";
