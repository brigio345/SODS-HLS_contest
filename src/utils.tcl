# lremove:
#	* argument(s):
#		- list_variable: variable name of a list.
#		- value: value to be removed from the list.
#	* return: 
#		none.
#	* behavior:
#		remove the value from the list
proc lremove {list_variable value} {
	upvar 1 $list_variable var
	set idx [lsearch -exact $var $value]
	set var [lreplace $var $idx $idx]
}

# get_reverse_sorted_nodes:
#	* argument(s):
#		- nodes_dict: dictionary in which keys correspond to nodes and
#			values correspond to information about the key node.
#	* return: 
#		nodes_dict in topological reverse order.
proc get_reverse_sorted_nodes {nodes_dict} {
	set sorted_dict [dict create]

	set unsorted_lst [list]
	foreach node [dict keys $nodes_dict] {
		lappend unsorted_lst $node
	}

	while {[llength $unsorted_lst] > 0} {
		foreach node $unsorted_lst {
			set all_child_sorted 1
			foreach child [get_attribute $node children] {
				# if current node has a child not sorted yet,
				# it cannot be added to sorted list
				if {[lsearch $unsorted_lst $child] != -1} {
					set all_child_sorted 0
					break
				}
			}
			if {$all_child_sorted == 1} {
				lremove unsorted_lst $node
				dict set sorted_dict $node [dict get $nodes_dict $node]
			}
		}
	}

	return $sorted_dict
}

# get_sorted_selected_fus_dict:
#	* argument(s):
#		none.
#	* return: 
#		dictionary in which the key corresponds to operation
#		and the value corresponds to list of a dictionary containing
#		the functional units implementing the key operation, sorted
#		by attr, in ascending order, and the delta, corresponding to
#		the difference between the value of attibute of the specific
#		functional unit and the minimum value possible for that operation
#		with the current library of functional units.
#		N.B.1 only "convenient" fus are returned (fastest or which reduce
#			area or power or both)
#		N.B.2 only operations present in the current design are included.
proc get_sorted_selected_fus_dict {} {
	set fus_dict [dict create]

	foreach node [get_nodes] {
		set op [get_attribute $node operation]

		# avoid adding duplicates
		if {[dict exists $fus_dict $op] == 0} {
			# label fus with their delays (needed for sorting fus by delay)
			set fu_delay_lst [list]
			foreach op_fu [get_lib_fus_from_op $op] {
				lappend fu_delay_lst "$op_fu [get_attribute $op_fu delay]"
			}

			set fu_delay_sorted_lst [lsort -integer -index 1 $fu_delay_lst]

			# always include fastest fu
			set fu [lindex [lindex $fu_delay_sorted_lst 0] 0]
			set area [get_attribute $fu area]
			set min_delay [get_attribute $fu delay]
			set power [expr {[get_attribute $fu power] * $min_delay}]

			set op_fu_dict [dict create fu $fu delta 0]
			set sorted_op_fus_lst [list $op_fu_dict]

			# filter out non-convenient fus
			foreach fu_delay $fu_delay_sorted_lst {
				set fu [lindex $fu_delay 0]
				
				set area_prev $area
				set power_prev $power
				set area [get_attribute $fu area]
				set delay [get_attribute $fu delay]
				set power [expr {[get_attribute $fu power] * $delay}]
				
				# skip current fu if it doesn't provide area or
				# power improvements with respect to previous fu
				# (which has a lower or equal delay)
				if {$area >= $area_prev && $power >= $power_prev} {
					continue
				}

				set delta [expr $delay - $min_delay]

				set op_fu_dict [dict create fu $fu delta $delta]
				lappend sorted_op_fus_lst $op_fu_dict
			}
			
			dict set fus_dict $op $sorted_op_fus_lst
		}
	}

	return $fus_dict
}

