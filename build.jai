#import "Basic";
#import "Compiler";

#run build();

build :: () {
    build_options := get_build_options();
    build_options.output_type = Build_Output_Type.NO_OUTPUT;
    set_build_options(build_options);

    w := compiler_create_workspace();
    build_options.output_type = Build_Output_Type.EXECUTABLE;
	build_options.output_executable_name = "pgtest";
	build_options.backend = Backend.X64;
	// llvm_args: [..] string;
	// array_add(*llvm_args, "-fasdgasgsanitize=address");
	// build_options.llvm_options.debug_options = llvm_args;
	array_add(*build_options.modules_search_path_array, ".");
    set_build_options(build_options, w);

    add_build_file("pgtest.jai", w);
}

