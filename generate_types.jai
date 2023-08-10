// Adapted from node-pg-types (https://github.com/brianc/node-pg-types/blob/master/lib/binaryParsers.js)
// From their doc:
 // Following query was used to generate this file:
 // SELECT json_object_agg(UPPER(PT.typname), PT.oid::int4 ORDER BY pt.oid)
 // FROM pg_type PT
 // WHERE typnamespace = (SELECT pgn.oid FROM pg_namespace pgn WHERE nspname = 'pg_catalog') -- Take only builting Postgres types with stable OID (extension types are not guaranted to be stable)
 // AND typtype = 'b' -- Only basic types
 // AND typelem = 0 -- Ignore aliases
 // AND typisdefined -- Ignore undefined types

#run {
    #import "Compiler";
    set_build_options_dc(.{do_output = false});
    args := get_build_options().compile_time_command_line;
    if args.count != 1 {
        log_error("Usage: jai % - <db_url>", #file);
        exit(1);
    }

    db_url := args[0];
    success := generate_types(db_url);
    if !success compiler_report("Error while generating types");
}

generate_types :: (db_url: string) -> bool {
	conn, success := connect(db_url);
	defer disconnect(conn);
	if !success	{
        log_error("Could not connect to \"%\"", db_url);
        return false;
    }

	TYPE_QUERY :: #string END
        SELECT UPPER(pt.typname) typname, pt.oid, pt.typarray
        FROM pg_type pt
        WHERE typnamespace = (SELECT pgn.oid FROM pg_namespace pgn WHERE nspname = 'pg_catalog') -- Take only builting Postgres types with stable OID (extension types are not guaranted to be stable)
        AND typtype = 'b' -- Only basic types
        AND typname NOT LIKE '\_%' -- ignore names starting with "_", which seem to be 1:1 aliases for the ones without "_"
        AND typisdefined -- Ignore undefined types
        ORDER BY pt.oid
	END

    type_list:, success = execute(conn, Sql_Type, TYPE_QUERY);
    if !success {
        log_error("Could not fetch types");
        return false;
    }

    max_len := 0;
    for type_list {
        if it.typname.count > max_len  max_len = it.typname.count;
    }

    builder: String_Builder;
    print_to_builder(*builder, "// Generated via \"%\"\n\n", path_filename(#file));
    append(*builder, "Pq_Type :: enum Oid {\n");
    for type_list {
        print_to_builder(*builder, "    %", it.typname);
        for it.typname.count..max_len {
            append(*builder, " ");
        }
        print_to_builder(*builder, ":: %;\n", it.oid);
    }
    append(*builder, "}\n\n");
    append(*builder, "Pq_Array_Type :: enum Oid {\n");
    for type_list {
        if it.typarray == 0 continue;
        print_to_builder(*builder, "    %", it.typname);
        for it.typname.count..max_len {
            append(*builder, " ");
        }
        print_to_builder(*builder, ":: %;\n", it.typarray);
    }
    append(*builder, "}\n");

    FILENAME :: "pq_types.jai";
    success = write_entire_file(FILENAME, *builder);
    if !success {
        log_error("Could not write to file \"%\".", FILENAME);
        return false;
    }

    return true;
}

Sql_Type :: struct {
    typname: string;
    oid: int;
    typarray: int;
}

#import "Basic";
#import "File";
#import "String";
#import,file "module.jai";
