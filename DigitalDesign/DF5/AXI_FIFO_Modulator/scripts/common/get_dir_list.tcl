proc get_dir_list { { input_dir_list {} } } {
	while {[llength $input_dir_list]} {
		lappend output_dir_list [lindex $input_dir_list 0]
		set input_dir_list [concat [glob -nocomplain -directory [lindex $input_dir_list 0] -type { d r } *] [lrange $input_dir_list 1 end]]
	}
	return $output_dir_list
}
