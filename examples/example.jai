#run {
    #import "Compiler";
    if OS == .MACOS {
        compiler_add_library_search_directory("/usr/local/homebrew/opt/libpq/lib");
    }
}

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
            2.5::float8, 3.5::numeric(8, 2),
            true "boolean",
            'a'::char(3) "char", 'b'::bpchar "bpchar", 'c'::varchar, 'd'::name, 'e'::text,
            '2023-05-15'::timestamp, '2023-05-14'::timestamptz
    END

    results: [] Test;
    results, success = execute(conn, Test, QUERY);
    assert(success);
    log("Results: %", results);
    assert(results.count == 1);

    result := results[0];
    assert(result.int2 == 1);
    assert(result.int4 == 2);
    assert(result.int8 == 3);
    assert(result.float8 == 2.5);
    assert(result.numeric == "3.50");
    assert(result.boolean == true);
    assert(result.char == "a  ");
    assert(result.bpchar == "b");
    assert(result.varchar == "c");
    assert(result.name == "d");
    assert(result.text == "e");
    assert(result.timestamp == "2023-05-15T00:00:00.000Z");
    assert(result.timestamptz == 1684022400000000);
    log("ALL OK");
}

Test :: struct {
    int2:   int;
    int4:   int;
    int8:   s64;
    float8: float64;
    numeric: string;
    boolean: bool;
    char: string;
    bpchar: string;
    varchar: string;
    name: string;
    text: string;
    timestamp: string;
    timestamptz: s64;
}

#import,file "../module.jai";
#import "Basic";