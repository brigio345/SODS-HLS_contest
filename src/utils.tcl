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

# get_sorted_nodes_by_sink_dist:
#	* argument(s):
#		- nodes_dict: dictionary in which keys correspond to nodes and
#			values correspond to information about the key node.
#			N.B. fu of each node is required
#	* return: 
#		nodes_dict sorted by sink distance (weighted on the delay
#		of nodes), in descending order.
proc get_sorted_nodes_by_sink_dist {nodes_dict} {
	set nodes_dict [get_reverse_sorted_nodes $nodes_dict]

	set node_dist_lst [list]
	dict for {node node_dict} $nodes_dict {
		set max_child_dist 0
		foreach child [get_attribute $node children] {
			set child_dist_pair [lsearch -index 0 -inline $node_dist_lst $child]
			set child_dist [lindex $child_dist_pair 1]
			if {$child_dist > $max_child_dist} {
				set max_child_dist $child_dist
			}
		}

		set fu [dict get $node_dict fu]
		set delay [get_attribute $fu delay]
		set dist [expr {$max_child_dist + $delay}]

		lappend node_dist_lst [list $node $dist]
	}

	set node_dist_sorted_lst [lsort -index 1 -integer -decreasing $node_dist_lst]

	set nodes_sorted_dict [dict create]
	foreach node_dist_pair $node_dist_sorted_lst {
		set node [lindex $node_dist_pair 0]
		set node_dict [dict get $nodes_dict $node]
		dict set nodes_sorted_dict $node $node_dict
	}

	return $nodes_sorted_dict
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

# get_total_area:
#	* argument(s):
#		- fus_alloc_lst: list of pairs <fu_id, n_allocated>
#	* return: 
#		total allocated area
proc get_total_area {fus_alloc_lst} {
	set total_area 0
	foreach fu_alloc_lst $fus_alloc_lst {
		set fu [lindex $fu_alloc_lst 0]
		set alloc [lindex $fu_alloc_lst 1]
		set area [get_attribute $fu area]

		set total_area [expr {$total_area + $area * $alloc}]
	}

	return $total_area
}

# get_total_power:
#	* argument(s):
#		- nodes_fu_lst: list of pairs <node_id, fu_id>
#	* return: 
#		total consumed power
proc get_total_power {nodes_fu_lst} {
	# TODO: check what lambda means in the provided formula
	set total_power 0
	foreach node_fu_lst $nodes_fu_lst {
		set node [lindex $node_fu_lst 0]
		set fu [lindex $node_fu_lst 1]
		set power [get_attribute $fu power]
		set delay [get_attribute $fu delay]

		set total_power [expr {$total_power + $power * $delay}]
	}

	return $total_power
}

