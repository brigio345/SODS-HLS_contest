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

	# label all nodes with "sorted" key
	dict for {node node_dict} $nodes_dict {
		dict set node_dict sorted 0
		dict set nodes_dict $node $node_dict
	}

	set fully_sorted 0
	while {$fully_sorted == 0} {
		set fully_sorted 1
		dict for {node node_dict} $nodes_dict {
			if {[dict get $node_dict sorted] == 0} {
				set all_child_sorted 1
				foreach child [get_attribute $node children] {
					# if current node has a child not sorted yet,
					# it cannot be added to sorted list
					if {[dict exists $sorted_dict $child] == 0} {
						set all_child_sorted 0
						break
					}
				}

				if {$all_child_sorted} {
					# remove no more needed label
					set node_dict [dict remove $node_dict sorted]
					dict set sorted_dict $node $node_dict
				} else {
					# there exists a node not sorted that
					# cannot be sorted yet
					set fully_sorted 0
				}
			}
		}
	}

	return $sorted_dict
}

# get_sorted_fus_per_op:
#	* argument(s):
#		- attr: attribute of functional unit, by which lists of
#			functional units are sorted in ascending order.
#	* return: 
#		dictionary in which the key corresponds to operation
#		and the value corresponds to list of a dictionary containing
#		the functional units implementing the key operation, sorted
#		by attr, in ascending order, and the delta, corresponding to
#		the difference between the value of attibute of the specific
#		functional unit and the minimum value possible for that operation
#		with the current library of functional units.
#		N.B. only operations present in the current design are included.
proc get_sorted_fus_per_op {attr} {
	set fus_dict [dict create]

	foreach node [get_nodes] {
		set op [get_attribute $node operation]
		# avoid adding duplicates to the dictionary
		if {[dict exists $fus_dict $op] == 0} {
			set op_fus [get_lib_fus_from_op $op]
			set op_fus_dict [list]
			# label functional units with their attribute
			foreach op_fu $op_fus {
				lappend op_fus_dict "$op_fu [get_attribute $op_fu $attr]"
			}
			# sort functional units according to the attribute
			set op_fus_dict [lsort -real -index end $op_fus_dict]
			set op_fus [list]

			set min [lindex [lindex $op_fus_dict 0] 1]
			# remove labels
			foreach op_fu $op_fus_dict {
				set fu [lindex $op_fu 0]
				set delta [expr {[lindex $op_fu 1] - $min}]
				set op_fu_dict [dict create fu $fu delta $delta]
				lappend op_fus $op_fu_dict
			}

			# add the value to the dictionary
			dict set fus_dict $op $op_fus
		}
	}

	return $fus_dict
}

# get_nodes_per_op:
#	* argument(s):
#		None.
#	* return: 
#		dictionary in which the key corresponds to operation
#		and the value corresponds to list nodes associated to
#		the key operation.
#		N.B. only operations present in the current design are included.
proc get_nodes_per_op {} {
	set nodes [dict create]

	foreach node [get_nodes] {
		set op [get_attribute $node operation]
		if {[dict exists $nodes $op]} {
			# if the operation already exists in the dictionary,
			# we have to add current node to the list
			dict set nodes $op [concat [dict get $nodes $op] $node]
		} else {
			# if the operation do not exists in the dictionary,
			# we have create a new list, containing current node
			dict set nodes $op [list $node]
		}
	}

	return $nodes
}

