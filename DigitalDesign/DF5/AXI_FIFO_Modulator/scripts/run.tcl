##########################################################################################################
#
# run.tcl: Tcl script for running synthesis, implementation, and bitstream generation
#
# Usage: vivado -mode tcl -source run.tcl -tclargs <synth_flag> <impl_flag> <bit_flag> <xsa_flag>
#
##########################################################################################################

# Sourcing settings from external script
set ::env(REPO_DIR) [file dirname [file dirname [file normalize [info script]]]]
source $env(REPO_DIR)/scripts/settings.tcl

# Set the directory path for the project
set project_dir "[file normalize "$repository_dir/project"]"

# Open existing project
if {[file exists $project_dir/$_xil_proj_name_.xpr]} {
	open_project $project_dir/$_xil_proj_name_.xpr
	puts "Project opened successfully: $_xil_proj_name_"
} else {
	puts "Error: Project not found at $project_dir/$_xil_proj_name_.xpr"
	puts "Please run 'build.bat' first to create the project"
	exit 1
}

# Get command line arguments
set synth_flag [lindex $argv 0]
set impl_flag [lindex $argv 1]
set bit_flag [lindex $argv 2]
set xsa_flag [lindex $argv 3]

# Set default values if not provided
if {$synth_flag eq ""} { set synth_flag 0 }
if {$impl_flag eq ""} { set impl_flag 0 }
if {$bit_flag eq ""} { set bit_flag 0 }
if {$xsa_flag eq ""} { set xsa_flag 0 }

puts "Synthesis flag: $synth_flag"
puts "Implementation flag: $impl_flag"
puts "Bitstream flag: $bit_flag"
puts "XSA flag: $xsa_flag"

# Run synthesis if requested
if {$synth_flag == 1} {
	puts "\n=========================================="
	puts "Starting Synthesis..."
	puts "=========================================="

	if {[get_runs synth_1] ne ""} {
		reset_run synth_1
	} else {
		create_run -name synth_1 -flow {Vivado Synthesis 2023} -strategy "Vivado Synthesis Defaults"
	}

	launch_runs synth_1 -jobs 4
	wait_on_run synth_1

	set synth_status [get_property STATUS [get_runs synth_1]]
	if {[string match "*Complete*" $synth_status] && ![string match "*Error*" $synth_status]} {
		puts "Synthesis completed successfully! Status: $synth_status"
	} else {
		puts "Synthesis failed or incomplete. Status: $synth_status"
		puts "Check results in: $project_dir/synth_1"
		exit 1
	}
}

# Run implementation if requested
if {$impl_flag == 1} {
	puts "\n=========================================="
	puts "Starting Implementation..."
	puts "=========================================="

	if {[get_runs synth_1] eq ""} {
		puts "Error: Synthesis must be run first!"
		exit 1
	}

	if {[get_runs impl_1] ne ""} {
		reset_run impl_1
	} else {
		create_run -name impl_1 -parent_run synth_1 -flow {Vivado Implementation 2023}
	}

	launch_runs impl_1 -jobs 4
	wait_on_run impl_1

	set impl_status [get_property STATUS [get_runs impl_1]]
	if {[string match "*Complete*" $impl_status] && ![string match "*Error*" $impl_status]} {
		puts "Implementation completed successfully! Status: $impl_status"
	} else {
		puts "Implementation failed or incomplete. Status: $impl_status"
		puts "Check results in: $project_dir/impl_1"
		exit 1
	}
}

# Generate bitstream if requested
if {$bit_flag == 1} {
	puts "\n=========================================="
	puts "Starting Bitstream Generation..."
	puts "=========================================="

	if {[get_runs impl_1] eq ""} {
		puts "Error: Implementation must be run first!"
		exit 1
	}

	set impl_status [get_property STATUS [get_runs impl_1]]
	if {![string match "*Complete*" $impl_status] || [string match "*Error*" $impl_status]} {
		puts "Error: Implementation must complete successfully before generating bitstream!"
		puts "Current status: $impl_status"
		exit 1
	}

	launch_runs impl_1 -to_step write_bitstream -jobs 4
	wait_on_run impl_1

	set candidate_paths [list \
		"$project_dir/$_xil_proj_name_.runs/impl_1/${_xil_proj_name_}.bit" \
		"$project_dir/$_xil_proj_name_.runs/impl_1/${_inst_top_name_}.bit" \
		"$project_dir/$_xil_proj_name_.runs/impl_1/microblaze_wrapper.bit" \
		"$project_dir/${_inst_top_name_}.bit" \
		"$project_dir/$_xil_proj_name_.bit" ]
	set found_bit ""
	foreach p $candidate_paths {
		if {[file exists $p]} { set found_bit $p; break }
	}
	if {$found_bit eq ""} {
		set bits [glob -nocomplain -directory "$project_dir/$_xil_proj_name_.runs/impl_1" "*.bit"]
		if {[llength $bits] > 0} { set found_bit [file normalize [lindex $bits 0]] }
	}
	if {$found_bit ne ""} {
		puts "Bitstream generated successfully!"
		puts "Bitstream location: $found_bit"
	} else {
		puts "Bitstream generation failed!"
		exit 1
	}
}

# Export hardware platform (XSA) if requested
if {$xsa_flag == 1} {
	puts "\n=========================================="
	puts "Starting XSA Export..."
	puts "=========================================="

	if {[get_runs impl_1] eq ""} {
		puts "Error: Implementation must be run first!"
		exit 1
	}

	set impl_status [get_property STATUS [get_runs impl_1]]
	if {![string match "*Complete*" $impl_status] || [string match "*Error*" $impl_status]} {
		puts "Error: Implementation must complete successfully before exporting XSA!"
		puts "Current status: $impl_status"
		exit 1
	}

	set candidate_paths [list \
		"$project_dir/$_xil_proj_name_.runs/impl_1/${_xil_proj_name_}.bit" \
		"$project_dir/$_xil_proj_name_.runs/impl_1/${_inst_top_name_}.bit" \
		"$project_dir/$_xil_proj_name_.runs/impl_1/microblaze_wrapper.bit" \
		"$project_dir/${_inst_top_name_}.bit" \
		"$project_dir/$_xil_proj_name_.bit" ]
	set found_bit ""
	foreach p $candidate_paths {
		if {[file exists $p]} { set found_bit $p; break }
	}
	if {$found_bit eq ""} {
		puts "Error: Bitstream not found. Export XSA after a successful -bit run."
		exit 1
	}

	set xsa_dir "[file normalize "$repository_dir/sources"]"
	file mkdir $xsa_dir
	set xsa_name "microblaze_wrapper"
	set xsa_path "[file normalize "$xsa_dir/${xsa_name}.xsa"]"
	puts "Exporting hardware platform: $xsa_path"
	update_compile_order -fileset sources_1
	write_hw_platform -fixed -force -file $xsa_path
	puts "XSA export completed successfully!"
}

puts "\n=========================================="
puts "Build process completed!"
puts "=========================================="

exit
