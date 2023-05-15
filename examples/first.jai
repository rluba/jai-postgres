#run {
    set_build_options_dc(.{do_output = false});

    if OS == .MACOS {
        compiler_add_library_search_directory("/usr/local/homebrew/opt/libpq/lib");
    }

    w := compiler_create_workspace();
    build_options := get_build_options();
    build_options.output_type = .EXECUTABLE;
    build_options.output_executable_name = "example";
    set_build_options(build_options, w);

    add_build_file("example.jai", w);
}

#import "Compiler";

