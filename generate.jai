AT_COMPILE_TIME :: true;

IMGUI_PATH :: "src/imgui-1.85";

DECLARATIONS_TO_OMIT :: string.[
];

#if AT_COMPILE_TIME {
    #run {
        set_build_options_dc(.{do_output=false});
        if !generate_bindings() {
            compiler_set_workspace_status(.FAILED);
        }
    }
} else {
    #import "System";

    main :: () {
        set_working_directory(path_strip_filename(get_path_of_running_executable()));
        if !generate_bindings() {
            exit(1);
        }
    }
}

generate_bindings :: () -> bool {
    output_filename: string;
    opts: Generate_Bindings_Options;
    {
        using opts;

		make_directory_if_it_does_not_exist("bindings");

        #if OS == .WINDOWS {
            output_filename          = "bindings/windows.jai";
        } else #if OS == .LINUX {
            output_filename          = "bindings/unix.jai";
			generate_library_declarations = false;
			footer = FOOTER_UNIX;
        } else #if OS == .MACOS {
            // @ToDo: Determine dynamically? Customize?
            array_add(*system_include_paths, "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include");
			array_add(*include_paths, "/usr/local/homebrew/opt/libpq/include");
			array_add(*libpaths, "/usr/local/homebrew/opt/libpq/lib");
            output_filename          = "bindings/unix.jai";
			generate_library_declarations = false;
			footer = FOOTER_UNIX;
        } else {
            assert(false);
        }

        array_add(*libnames,      "libpq");
        array_add(*system_include_paths, GENERATOR_DEFAULT_SYSTEM_INCLUDE_PATH);
        array_add(*source_files,  "libpq-fe.h");
        array_add(*extra_clang_arguments, "-x", "c");
        auto_detect_enum_prefixes = false;
        generate_compile_time_struct_checks = false;
        strip_flags |= .INLINED_FUNCTIONS; // "inline" functions are not present in the static library.

        // visitor   = imgui_visitor;
    }

    return generate_bindings(opts, output_filename);
}

//imgui_visitor :: (decl: *Declaration, parent_decl: *Declaration) -> Declaration_Visit_Result {
//    // ImGui has "typedef ints" for each enum. but we want to just use the enums directly,
//    // so we get nice type safety, and .unary dots, etc.
//    //
//    // Look for declarations inside functions (i.e., arguments) or structs (i.e., fields)
//    get_associated_enum_name :: (name: string) -> string {
//        if name.count > 1 && name[name.count - 1] != #char "_" {
//            return tprint("%_", name);
//        }
//        return name;
//    }

//    if !parent_decl {
//        if array_find(DECLARATIONS_TO_OMIT, decl.name) {
//            decl.decl_flags |= .OMIT_FROM_OUTPUT;
//            return .STOP;
//        }
//    }

//    // Look for function arguments with "typedef" types.
//    if parent_decl &&
//        (parent_decl.kind == .FUNCTION || parent_decl.kind == .STRUCT) &&
//        decl.kind == .DECLARATION && decl.type.type_of_typedef != null
//    {
//        old_name := decl.type.type_of_typedef.name;
//        if !old_name return .RECURSE;
//        new_name := get_associated_enum_name(old_name);

//        //print("% -> %\n", old_name, new_name);

//        for context.generator.global_scope.members {
//            if it.kind != .ENUM  || it.name != new_name     continue;

//            en := cast(*Enum)it;

//            // Don't output the integer typedef
//            decl.type.type_of_typedef.decl_flags |= .OMIT_FROM_OUTPUT;

//            // Make sure the enums like "FocusFlags_" get outputted as "FocusFlags"
//            if en.output_name.count > 2 && en.output_name[en.output_name.count - 1] == #char "_" {
//                en.output_name.count -= 1;
//            }

//            // swap in the enum for the typedef
//            decl.type.type_of_typedef = null;
//            decl.type.type_of_enum = en;

//            // we'll also need to output a cast, like "cast(EnumType)5" for the default argument
//            decl.decl_flags |= .NEEDS_DEFAULT_ARGUMENT_CAST;

//            break;
//        }
//    }

//    if decl.kind == .ENUM {
//        // ImGui has lots of enums that should be enum flags. Luckily, they all end in "…Flags_".
//        if ends_with(decl.name, "Flags_") {
//            en := cast(*Enum)decl;
//            en.flags |= .IS_ENUM_FLAGS;
//            en.flags |= .VALUES_IN_HEX;
//        }
//    }

//    if decl.kind == .FUNCTION {
//        func := cast(*Function)decl;
//        type := func.type.type_of_function;
//        // ImGui also has functions with pairs of arguments like "text_begin" and "text_end"
//        // for the pointers to the beginning and end of a string. We'll generate wrappers for
//        // those function which take a jai string.
//        //
//        // Here we collect pointers to "_begin" arguments, and use them in
//        // get_func_args_for_printing below.
//        for type.arguments {
//            if it_index == 0 || !ends_with(it.name, "_end")     continue;

//            name_part := slice(it.name, 0, it.name.count - "_end".count);
//            if !name_part   continue;

//            // the first arg may appear as "text_begin" or just "text"
//            name_part_with_begin := tprint("%_begin", name_part);
//            prev_arg := type.arguments[it_index - 1];
//            if prev_arg.name == name_part || prev_arg.name == name_part_with_begin {
//                array_add(*begin_end_string_args, prev_arg);
//                func.decl_flags |= .NEEDS_ARGUMENT_WRAPPER;
//            }
//        }
//    }

//    return .RECURSE;
//}

#import "Basic";
#import "Bindings_Generator";
#import "Compiler";
#import "File";
#import "String";

FOOTER_UNIX :: #string END

libpq :: #system_library "libpq";

END
