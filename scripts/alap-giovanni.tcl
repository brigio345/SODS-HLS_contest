proc get_reverse_sorted_nodes {} {
	set new_nodes [get_nodes]
	set sorted_nodes [list]

	# loop until there is no new node to be sorted
	while {[llength $new_nodes] > 0} {
		# get first element
		set node [lindex $new_nodes 0]
		# remove first element from list
		set new_nodes [lrange $new_nodes 1 end]
		# initialize flag
		set valid 1
		# loop on all children
		foreach child [get_attribute $node children] {
			# if there is a child not yet sorted,
			# current node cannot be inserted in sorted list
			if {[lsearch $sorted_nodes $child] == -1} {
				# update flag
				set valid 0
				break
			}
		}
		if {$valid == 1} {
			# current node can be added to the sorted
			lappend sorted_nodes $node
		} else {
			# current node must be added back to nodes to be sorted
			lappend new_nodes $node
		}
	}

	return $sorted_nodes
}

proc alap {lambda} {
	set node_start_time [list]

	foreach node [get_reverse_sorted_nodes] {
		set node_op [get_attribute $node operation]
		set fu [get_lib_fu_from_op $node_op]
		set node_delay [get_attribute $fu delay]
		set start_time $lambda
		foreach child [get_attribute $node children] {
			set idx_child_start [lsearch -index 0 $node_start_time $child]
			set child_start_time [lindex [lindex $node_start_time $idx_child_start] 1]
			if { $child_start_time - $node_delay < $start_time } {
				set start_time [expr $child_start_time - $node_delay]
			}
		}
		lappend node_start_time "$node $start_time"
	}

	return $node_start_time
}

