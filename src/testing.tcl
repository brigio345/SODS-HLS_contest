source ./contest/src/brave_opt.tcl

# test_suite:
#	* argument(s):
#		none.
#	* return: 
#		1 if all tests are passed, 0 otherwise.
proc test_suite {} {
	set DFGs_root "./data/DFGs/"

	# TODO: find a better way to set lambda
	set lambda 80

	set success 1
	foreach dfg [glob $DFGs_root/*.dot] {
		puts "Testing DFG $dfg"
		read_design $dfg

		puts "Executing algorithm..."

		set start_time [clock clicks -milliseconds]

		set res [brave_opt -lambda $lambda]

		set end_time [clock clicks -milliseconds]


		set start_time_lst [lindex $res 0]
		set fu_id_lst [lindex $res 1]
		set fu_alloc_lst [lindex $res 2]

		puts -nonewline "Testing latency violations..."
		if {[test_latency $start_time_lst $fu_id_lst $lambda] == 1} {
			puts "\t\tOK"
		} else {
			puts "\t\tFAIL"
			set success 0
		}

		puts -nonewline "Testing dependecies violations..."
		if {[test_dependencies $start_time_lst $fu_id_lst] == 1} {
			puts "\tOK"
		} else {
			puts "\tFAIL"
			set success 0
		}

		puts -nonewline "Testing fus conflicts..."
		if {[test_fu_conflicts $start_time_lst $fu_id_lst $fu_alloc_lst] == 1} {
			puts "\t\tOK"
		} else {
			puts "\t\tFAIL"
			set success 0
		}

		puts "INFO:"

		puts "CPU execution time: \t\t\t[expr {$end_time - $start_time}] ms"
		puts "Total power: \t\t\t\t[get_total_power [lindex $res 1]]"
		puts "Total area: \t\t\t\t[get_total_area [lindex $res 2]]"

		puts ""

		remove_design
	}

	return $success
}

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
		set node_pair [lsearch -inline -index 0 $start_time_lst $node]
		set node_start [lindex $node_pair 1]
		set node_fu_pair [lsearch -inline -index 0 $fu_id_lst $node]
		set fu [lindex $node_fu_pair 1]
		set node_delay [get_attribute $fu delay]
		set node_end [expr {$node_start + $node_delay}]
		foreach child [get_attribute $node children] {
			set child_start_pair [lsearch -inline -index 0 $start_time_lst $child]
			set child_start [lindex $child_start_pair 1]

			if {$child_start < $node_end} {
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
		set start_lst [list]

		foreach fu_id_pair [lsearch -all -inline -index 1 $fu_id_lst $fu] {
			set node [lindex $fu_id_pair 0]
			set node_start_pair_lst [lsearch -all -inline -index 0 $start_time_lst $node]

			# check if a node has been scheduled more than once
			# or is hasn't been scheduled
			if {[llength $node_start_pair_lst] != 1} {
				return 0
			}

			set node_start_pair [lindex $node_start_pair_lst 0]
			lappend start_lst [lindex $node_start_pair 1]
		}

		set delay [get_attribute $fu delay]
		set sorted_start_lst [lsort -integer $start_lst]

		set running 0
		set running_max 0
		set running_end_lst [list]
		foreach start $sorted_start_lst {
			incr running
			lappend running_end_lst [expr {$start + $delay}]

			set oldest_end [lindex $running_end_lst 0]
			if {$oldest_end <= $start} {
				while {[lindex $running_end_lst 0] == $oldest_end} {
					incr running -1
					set running_end_lst [lrange $running_end_lst 1 end]
				}
			}

			if {$running > $running_max} {
				set running_max $running
			}
		}

		set fu_alloc_pair_lst [lsearch -all -inline -index 0 $fu_alloc_lst $fu]

		# check if the fu has appears more than once or it does not appear
		if {[llength $fu_alloc_pair_lst] != 1} {
			return 0
		}

		set fu_alloc_pair [lindex $fu_alloc_pair_lst 0]

		set alloc [lindex $fu_alloc_pair 1]

		if {$running_max != $alloc} {
			return 0
		}
	}

	return 1
}

