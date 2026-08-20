proc lflat { list } {
	while { $list != [set list [join $list]] } { }
	return $list
}
