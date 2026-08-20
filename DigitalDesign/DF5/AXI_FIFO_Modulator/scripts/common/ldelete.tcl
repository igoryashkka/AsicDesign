proc ldelete { list value } {
	set x [lsearch -exact $list $value]
	if {$x >= 0} {
		return [lreplace $list $x $x]
	} else {
		return $list
	}
}
