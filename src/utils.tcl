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

	set unsorted_lst [dict keys $nodes_dict]

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

# get_sorted_nodes_by_t_alap:
#	* argument(s):
#		- nodes_dict: dictionary in which keys correspond to nodes and
#			values correspond to information about the key node.
#			N.B. t_alap of each node is required
#	* return: 
#		nodes_dict sorted by t_alap in descending order.
proc get_sorted_nodes_by_t_alap {nodes_dict} {
	set nodes_t_alap_lst [list]
	dict for {node node_dict} $nodes_dict {
		set t_alap [dict get $node_dict t_alap]
		lappend nodes_t_alap_lst [list $node $t_alap]
	}

	set nodes_t_alap_lst [lsort -index 1 -integer $nodes_t_alap_lst]

	set nodes_sorted_dict [dict create]
	foreach node_t_alap_pair $nodes_t_alap_lst {
		set node [lindex $node_t_alap_pair 0]
		set node_dict [dict get $nodes_dict $node]
		dict set nodes_sorted_dict $node $node_dict
	}

	return $nodes_sorted_dict
}

# update_sorted_nodes_by_t_alap:
#	* argument(s):
#		- node_mod: node whose t_alap has increased
#		- nodes_dict: dictionary in which keys correspond to nodes and
#			values correspond to information about the key node.
#			N.B.1 this dictionary needs to be sorted, except for
#				node_mod.
#			N.B.2 t_alap of each node is required.
#	* return: 
#		nodes_dict sorted by t_alap in descending order.
proc update_sorted_nodes_by_t_alap {mod_node nodes_dict} {
	set mod_node_dict [dict get $nodes_dict $mod_node]
	set t_alap [dict get $mod_node_dict t_alap]

	set inserted 0
	set nodes_sorted_dict [dict create]
	dict for {node node_dict} $nodes_dict {
		if {$inserted == 0 && [dict get $node_dict t_alap] >= $t_alap} {
			dict set nodes_sorted_dict $mod_node $mod_node_dict
			set inserted 1
		}

		dict set nodes_sorted_dict $node $node_dict
	}

	return $nodes_sorted_dict
}

# get_sorted_selected_fus_arr:
#	* argument(s):
#		none.
#	* return: 
#		array in which the key corresponds to operation
#		and the value corresponds to list of dictionaries containing
#		the functional units implementing the key operation, sorted
#		by delay, power and area, in ascending order, and the delta,
#		corresponding to the difference between the delay of the specific
#		functional unit and the minimum possible delay for that operation
#		with the current library of functional units.
#		N.B.1 only "convenient" fus are returned (fastest or which reduce
#			power or area, without increasing power)
#		N.B.2 only operations present in the current design are included.
proc get_sorted_selected_fus_arr {} {
	array set fus_arr {}

	foreach node [get_nodes] {
		set op [get_attribute $node operation]

		# avoid adding duplicates
		if {[array get fus_arr $op] == ""} {
			# label fus with their area, delay and power
			# (needed for sorting)
			set fu_specs_lst [list]
			foreach op_fu [get_lib_fus_from_op $op] {
				set delay [get_attribute $op_fu delay]
				set power [expr {[get_attribute $op_fu power] * $delay}]
				set area [get_attribute $op_fu area]
				lappend fu_specs_lst [list $op_fu $delay $power $area]
			}
			
			# first sort by area and power and then by delay, in order
			# to make sure to include only the most convenient fu for
			# each delay value (e.g. same delay, but bigger area or
			# power)
			set fu_specs_by_area_lst [lsort -integer -index 3 $fu_specs_lst]
			set fu_specs_by_power_lst [lsort -integer -index 2 $fu_specs_by_area_lst]
			set fu_specs_sorted_lst [lsort -integer -index 1 $fu_specs_by_power_lst]

			# always include fastest and most convenient fu
			set fu_specs [lindex $fu_specs_sorted_lst 0]
			set fu [lindex $fu_specs 0]
			set delay [lindex $fu_specs 1]
			set min_delay $delay
			set power [lindex $fu_specs 2]
			set area [lindex $fu_specs 3]
			set op_fu_dict [dict create fu $fu delta 0]
			set sorted_op_fus_lst [list $op_fu_dict]

			# filter out non-convenient fus
			foreach fu_specs $fu_specs_sorted_lst {
				set delay_prev $delay
				set delay [lindex $fu_specs 1]

				# since fus are sorted by delay, power and area
				# the first fu with a certain delay is the best
				# possible: if current fu has same delay as
				# previous one, it is possible to furtherly,
				# since it cannot provide any improvement
				if {$delay == $delay_prev} {
					continue
				}

				set area_prev $area
				set power_prev $power

				set power [lindex $fu_specs 2]
				set area [lindex $fu_specs 3]
				
				# skip current fu if it leads to higher power or
				# it leads to the same power and same or bigger
				# area, with respect to previous fu (which has a
				# lower or equal delay)
				if {$power > $power_prev ||
						($power == $power_prev && $area > $area_prev)} {
					continue
				}

				set fu [lindex $fu_specs 0]
				set delta [expr $delay - $min_delay]

				set op_fu_dict [dict create fu $fu delta $delta]
				lappend sorted_op_fus_lst $op_fu_dict
			}
			
			set fus_arr($op) $sorted_op_fus_lst
		}
	}

	return [array get fus_arr]
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

