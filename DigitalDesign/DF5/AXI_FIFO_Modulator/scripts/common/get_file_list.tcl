proc get_file_list { dir_list type_list } {
	while {[llength $dir_list]} {
		lappend file_list [glob -type f -nocomplain -directory [lindex $dir_list 0] *.{$type_list}]
		set dir_list [lrange $dir_list 1 end]
	}
	return [lflat $file_list]
}
