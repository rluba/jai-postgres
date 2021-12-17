#import "Compiler";

#run build();

// Just try to compile the module source without producing an executable to check for obvious errors.
build :: () {
	set_build_options_dc(.{do_output = false});

    w := compiler_create_workspace();
    build_options := get_build_options(w);
    build_options.output_type = .NO_OUTPUT;
    set_build_options(build_options, w);

    add_build_file("module.jai", w);
}

