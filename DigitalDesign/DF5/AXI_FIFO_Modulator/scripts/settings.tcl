##########################################################################################################
# settings.tcl: Tcl script for configuration user paremeters
##########################################################################################################

# reference project directory configuration
set scripts_dir [file dirname [info script]]
set repository_dir [file dirname $scripts_dir]

# Search for include TCL scripts
foreach scr_file [glob -type f -nocomplain "$scripts_dir/common/*.tcl"] {
	source -notrace $scr_file
}

# project name
set _xil_proj_name_	"DF5_project"

# top instanse name
set _inst_top_name_	"top"

# part number (same board as DF4/AXI_Slave_example)
set _part_number_	"xc7a35tfgg484-2"

# sources folders to scan
set _src_dir_	"$repository_dir/sources"

# constraint folder to scan
set _cnstr_dir_	"$repository_dir/constraints"

# simulation file folder to scan
set _sim_dir_	"$repository_dir/sources/simulation"
