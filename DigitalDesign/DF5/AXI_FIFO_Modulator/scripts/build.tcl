##########################################################################################################
#
# build.tcl: Tcl script for creating/re-creating the DF5 project (MicroBlaze + custom AXI interconnect
# + FIFO + simplified modulator).
#
##########################################################################################################

# Sourcing settings from external script
set ::env(REPO_DIR) [file dirname [file dirname [file normalize [info script]]]]

source $env(REPO_DIR)/scripts/settings.tcl

# Suppress warnings for file type setting on managed IP files
set_msg_config -suppress -id {filemgmt 20-1702}

# Set the directory path for the original project from where this script was exported
set project_dir "[file normalize "$repository_dir/project"]"
file mkdir $project_dir

cd $project_dir

# Create project
if {[file exists $_xil_proj_name_.xpr]} {
	open_project $_xil_proj_name_
} else {
	create_project $_xil_proj_name_ $project_dir -part $_part_number_
}

# Set the directory path for the new project
set proj_dir [get_property directory [current_project]]

# Set project properties
set obj [current_project]
set_property -name "default_lib" -value "xil_defaultlib" -objects $obj
set_property -name "source_mgmt_mode" -value "All" -objects $obj
set_property -name "enable_resource_estimation" -value "0" -objects $obj
set_property -name "enable_vhdl_2008" -value "1" -objects $obj
set_property -name "ip_cache_permissions" -value "read write" -objects $obj
set_property -name "ip_output_repo" -value "$proj_dir/.cache/ip" -objects $obj
set_property -name "mem.enable_memory_map_generation" -value "1" -objects $obj
set_property -name "revised_directory_structure" -value "1" -objects $obj
set_property -name "sim.central_dir" -value "$proj_dir/.ip_user_files" -objects $obj
set_property -name "sim.ip.auto_export_scripts" -value "1" -objects $obj
set_property -name "simulator_language" -value "Mixed" -objects $obj
set_property -name "sim_compile_state" -value "1" -objects $obj
set_property -name "webtalk.activehdl_export_sim" -value "2" -objects $obj
set_property -name "webtalk.modelsim_export_sim" -value "2" -objects $obj
set_property -name "webtalk.questa_export_sim" -value "2" -objects $obj
set_property -name "webtalk.riviera_export_sim" -value "2" -objects $obj
set_property -name "webtalk.vcs_export_sim" -value "2" -objects $obj
set_property -name "webtalk.xsim_export_sim" -value "2" -objects $obj
set_property -name "xpm_libraries" -value "XPM_CDC" -objects $obj


## SOURCES
# Set 'sources_1' fileset object
set obj [get_filesets sources_1]

# Add RTL files from rtl directory (recurses into sources/rtl/axi_interconnect etc.)
set rtl_dir "$_src_dir_/rtl"
if {[file exists $rtl_dir]} {
	set files [get_file_list [get_dir_list $rtl_dir] "sv,svh,v,vh,vhd,mif"]
	if {[llength $files]} {
		add_files -norecurse -fileset $obj $files
	}
}

# Add Block Design wrapper and sources, once the MicroBlaze BD has been created in the GUI
set bd_dir "$_src_dir_/bd"
if {[file exists $bd_dir]} {
	set bd_files [glob -type f -nocomplain "$bd_dir/*.{v,vhd,bd}" -directory $bd_dir]
	if {[llength $bd_files]} {
		add_files -norecurse -fileset $obj $bd_files
	}
}

# Set 'sources_1' fileset file properties for local files
catch {
	set file_obj [get_files -of_objects $obj -filter "NAME =~ *.sv"]
	if {[llength $file_obj]} { set_property -name "file_type" -value "SystemVerilog" -objects $file_obj }
}

catch {
	set file_obj [get_files -of_objects $obj -filter "NAME =~ *.v"]
	if {[llength $file_obj]} { set_property -name "file_type" -value "Verilog" -objects $file_obj }
}

# Set top.vhd to default VHDL FIRST
catch {
	set file_obj [get_files -of_objects $obj -filter "NAME == top.vhd"]
	if {[llength $file_obj]} { set_property -name "file_type" -value "VHDL" -objects $file_obj }
}

# Set VHDL 2008 for other .vhd files
catch {
	set file_obj [get_files -of_objects $obj -filter "NAME =~ *.vhd"]
	foreach f $file_obj {
		set fname [file tail [get_property NAME $f]]
		if {$fname ne "top.vhd"} {
			set_property -name "file_type" -value "VHDL 2008" -objects $f
		}
	}
}

catch {
	set file_obj [get_files -of_objects $obj -filter "NAME =~ *.mif"]
	if {[llength $file_obj]} { set_property -name "file_type" -value "Memory Initialization Files" -objects $file_obj }
}

# Set 'sources_1' fileset properties
set_property -name "dataflow_viewer_settings" -value "min_width=16" -objects $obj
update_compile_order -fileset sources_1

# Rebind and regenerate Block Design output products for the active project part,
# once the MicroBlaze BD exists (create it in the Vivado GUI first: IP Integrator ->
# MicroBlaze -> add the custom axi_lite_interconnect_top / axi_fifo_regs as RTL modules).
set microblaze_bd "$_src_dir_/bd/microblaze.bd"
if {[file exists $microblaze_bd]} {
	open_bd_design $microblaze_bd
	validate_bd_design
	save_bd_design
	generate_target all [get_files $microblaze_bd]
	catch { export_ip_user_files -of_objects [get_files $microblaze_bd] -no_script -sync -force -quiet }
	catch { make_wrapper -files [get_files $microblaze_bd] -top -import }
	update_compile_order -fileset sources_1
	set_property -name "top" -value "microblaze_wrapper" -objects $obj
} else {
	set_property -name "top" -value "$_inst_top_name_" -objects $obj
	puts "Note: $microblaze_bd not found yet. Create the MicroBlaze block design in the Vivado GUI, then re-run build.bat."
}


## CONSTRAINTS
# Set 'constrs_1' fileset object
set obj [get_filesets constrs_1]

# Search for constraint files in set folders
set files [get_file_list [get_dir_list $_cnstr_dir_] "xdc,sdc"]

# Add source files to design
add_files -norecurse -fileset $obj $files

# Add/Import constrs file and set constrs file properties
set file_obj [get_files -of_objects $obj [list [lsearch -all -inline $files *.xdc]]]
if {[llength $file_obj]} { set_property -name "file_type" -value "XDC" -objects $file_obj }


## SIMULATION
# Set 'sim_1' fileset object
set obj [get_filesets sim_1]

# Search for simulation files in set location
set files [get_file_list [get_dir_list $_sim_dir_] "v,sv,vhd"]
if {[llength $files]} {
  add_files -norecurse -fileset $obj $files
}

# Set 'sim_1' fileset properties
set_property -name "top" -value "$_inst_top_name_" -objects $obj
set_property -name "top_lib" -value "xil_defaultlib" -objects $obj

exit
