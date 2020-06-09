# test_latency:
#	* argument(s):
#		- start_time_lst: list of pairs <node_id, start_time>
#		- fu_id_lst: list of pairs <node_id, fu_id>
#		- lambda: latency constraint.
#	* return: 
#		1 if latency constraint is satisfied, 0 otherwise.
proc test_latency {start_time_lst fu_id_lst lambda} {
	foreach node [get_nodes] {
		# check end time of leaves only
		if {[get_attribute $node n_children] == 0} {
			set start_time_i [lsearch -index 0 $start_time_lst $node]
			set start_time_pair [lindex $start_time_lst $start_time_i]
			set start_time [lindex $start_time_pair 1]
			set fu_id_i [lsearch -index 0 $fu_id_lst $node]
			set fu [lindex [lindex $fu_id_lst $fu_id_i] 1]

			set delay [get_attribute $fu delay]
			set end_time [expr {$start_time + $delay}]
			
			if {$end_time > $lambda} {
				return 0
			}
		}
	}

	return 1
}

# test_dependencies:
#	* argument(s):
#		- start_time_lst: list of pairs <node_id, start_time>
#		- fu_id_lst: list of pairs <node_id, fu_id>
#	* return: 
#		1 if DFG dependencies are satisfied by inputs, 0 otherwise.
proc test_dependencies {start_time_lst fu_id_lst} {
	foreach node [get_nodes] {
		set node_i [lsearch -index 0 $start_time_lst $node]
		set node_pair [lindex $start_time_lst $node_i]
		set node_start [lindex $node_pair 1]
		set fu_i [lsearch -index 0 $fu_id_lst $node]
		set node_fu [lindex [lindex $fu_id_lst $fu_i] 1]
		set node_delay [get_attribute $node_fu delay]
		set node_end [expr {$node_start + $node_delay}]
		foreach child [get_attribute $node children] {
			set child_i [lsearch -index 0 $start_time_lst $child]
			set child_start [lindex $start_time_lst $child_i]

			if {$child_start < $node_end} {
				puts "Node $node completing at $node_end"
				puts "Child $child scheduled at $child_start"
				return 0
			}
		}
	}

	return 1
}

# test_fu_conflicts:
#	* argument(s):
#		- start_time_lst: list of pairs <node_id, start_time>
#		- fu_id_lst: list of pairs <node_id, fu_id>
#		- fu_alloc_lst: list of pairs <fu_id, n_allocated>
#	* return: 
#		1 if the number of maximum contemporaneously running fus of each
#		type is equal to n_allocated, 0 otherwise.
proc test_fu_conflicts {start_time_lst fu_id_lst fu_alloc_lst} {
	foreach fu [get_lib_fus] {
		puts -nonewline "Checking conflicts for functional unit $fu..."
		set delay [get_attribute $fu delay]
		set start_lst [list]
		set end_lst [list]
		foreach fu_id_i [lsearch -all -index 1 $fu_id_lst $fu] {
			set fu_id_pair [lindex $fu_id_lst $fu_id_i]
			set node [lindex $fu_id_pair 0]
			set start_time_i [lsearch -index 0 $start_time_lst $node]
			set start_time_pair [lindex $start_time_lst $start_time_i]
			set start [lindex $start_time_pair 1]
			lappend start_lst $start
			lappend end_lst [expr {$start + $delay}]
		}

		set n_allocated_max 0
		for {set i 0} {$i < [llength $start_lst]} {incr i} {
			set start_i [lindex $start_lst $i]
			set end_i [lindex $end_lst $i]
			set n_allocated 1

			for {set j [expr {$i + 1}]} {$j < [llength $start_lst]} {incr j} {
				set start_j [lindex $start_lst $j]
				set end_j [lindex $end_lst $j]

				if {$start_j >= $start_i && $start_j < $end_i ||
					$start_i >= $start_j && $start_i < $end_j} {
					incr n_allocated
				}
			}

			if {$n_allocated > $n_allocated_max} {
				set n_allocated_max $n_allocated
			}
		}

		set fu_alloc_i [lsearch -index 0 $fu_alloc_lst $fu]
		set fu_alloc_pair [lindex $fu_alloc_lst $fu_alloc_i]
		set n_alloc [lindex $fu_alloc_pair 1]

		if {$n_alloc != $n_allocated_max} {
			puts "\tFAIL"
			return 0
		}
		puts "\tOK"
	}

	return 1
}

