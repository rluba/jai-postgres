#run {
    set_build_options_dc(.{do_output = false});

    w := compiler_create_workspace();
    options := get_build_options();
    options.output_type = .EXECUTABLE;
    options.output_executable_name = "example";
	if OS == .MACOS {
        HOMEBREW_LIB_PATH :: "/usr/local/homebrew/lib"; // This is where my x64 libraries live. Adjust to fit your needs.
        options.additional_linker_arguments = .["-L", HOMEBREW_LIB_PATH];
		compiler_add_library_search_directory(HOMEBREW_LIB_PATH);
    }

    set_build_options(options, w);

    add_build_file("example.jai", w);
}

#import "Compiler";

