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

		puts "Execution time... \t\t\t[expr {$end_time - $start_time}] ms"

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
		set start_lst [list]
		foreach fu_id_i [lsearch -all -index 1 $fu_id_lst $fu] {
			set fu_id_pair [lindex $fu_id_lst $fu_id_i]
			set node [lindex $fu_id_pair 0]
			set start_time_pair [lsearch -inline -index 0 $start_time_lst $node]
			set start [lindex $start_time_pair 1]
			lappend start_lst $start
		}

		set $start_lst [lsort -integer $start_lst]
		set delay [get_attribute $fu delay]
		set end_lst [list]
		foreach start $start_lst {
			lappend end_lst [expr {$start + $delay}]
		}

		set n_alloc_max 0
		for {set i 0} {$i < [llength $start_lst]} {incr i} {
			set start_i [lindex $start_lst $i]
			set end_i [lindex $end_lst $i]
			set n_alloc 1

			for {set j [expr {$i + 1}]} {$j < [llength $start_lst]} {incr j} {
				set start_j [lindex $start_lst $j]
				set end_j [lindex $end_lst $j]

				if {$start_j >= $start_i && $start_j < $end_i} {
					incr n_alloc
				}
			}

			if {$n_alloc > $n_alloc_max} {
				set n_alloc_max $n_alloc
			}
		}

		set fu_alloc_i [lsearch -index 0 $fu_alloc_lst $fu]
		set fu_alloc_pair [lindex $fu_alloc_lst $fu_alloc_i]
		set n_alloc [lindex $fu_alloc_pair 1]

		if {$n_alloc != $n_alloc_max} {
			return 0
		}
	}

	return 1
}

