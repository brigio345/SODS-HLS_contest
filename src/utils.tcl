# get_reverse_sorted_nodes:
#	* argument(s):
#		- nodes_l: dictionary in which keys correspond to nodes and
#			values correspond to information about the key node.
#	* return: 
#		nodes_l in topological reverse order.
proc get_reverse_sorted_nodes {nodes_l} {
	set sorted_l [dict create]

	# label all nodes with "sorted" key
	foreach node [dict keys $nodes_l] {
		set node_l [dict get $nodes_l $node]
		dict set node_l sorted 0
		dict set nodes_l $node $node_l
	}

	set fully_sorted 0
	while {$fully_sorted == 0} {
		set fully_sorted 1
		foreach node [dict keys $nodes_l] {
			set node_l [dict get $nodes_l $node]
			if {[dict get $node_l sorted] == 0} {
				set all_child_sorted 1
				foreach child [get_attribute $node children] {
					# if current node has a child not sorted yet,
					# it cannot be added to sorted list
					if {[dict exists $sorted_l $child] == 0} {
						set all_child_sorted 0
						break
					}
				}

				if {$all_child_sorted} {
					# remove no more needed label
					set node_l [dict remove $node_l sorted]
					dict set sorted_l $node $node_l
				} else {
					# there exists a node not sorted that
					# cannot be sorted yet
					set fully_sorted 0
				}
			}
		}
	}

	return $sorted_l
}

# get_sorted_fus_per_op:
#	* argument(s):
#		- attr: attribute of functional unit, by which lists of
#			functional units are sorted in ascending order.
#	* return: 
#		dictionary in which the key corresponds to operation
#		and the value corresponds to list of functional units
#		implementing the key operation, sorted by attr,
#		in ascending order.
#		N.B. only operations present in the current design are included.
proc get_sorted_fus_per_op {attr} {
	set fus [dict create]

	foreach node [get_nodes] {
		set op [get_attribute $node operation]
		# avoid adding duplicates to the dictionary
		if {[dict exists $fus $op] == 0} {
			set op_fus [get_lib_fus_from_op $op]
			set op_fus_lab [list]
			# label functional units with their attribute
			foreach op_fu $op_fus {
				lappend op_fus_lab "$op_fu [get_attribute $op_fu $attr]"
			}
			# sort functional units according to the attribute
			set op_fus_lab [lsort -real -index end $op_fus_lab]
			set op_fus [list]
			# remove labels
			foreach op_fu $op_fus_lab {
				lappend op_fus [lindex $op_fu 0]
			}

			# add the value to the dictionary
			dict set fus $op $op_fus
		}
	}

	return $fus
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

# update_children_t_alap:
#	* argument(s):
#		- parent: node whose t_alap has been updated.
#		- nodes_l: dictionary in which keys correspond to nodes and
#			values correspond to information about the key node.
#		- delta: value to be summed to t_alap of every child node
#			of parent (can be negative).
#	* return: 
#		nodes_l with t_alap values updated.
proc update_children_t_alap {parent nodes_l delta} {
	foreach child [get_attribute $parent children] {
		# update children t_alap
		set child_l [dict get $nodes_l $child]
		set child_l t_alap [eval [dict get $child_l t_alap] + $delta]
		dict set nodes_l $child $child_l

		# recur on nephews
		set nodes_l [update_children_t_alap $child $nodes_l $delta]
	}

	return $nodes_l
}

