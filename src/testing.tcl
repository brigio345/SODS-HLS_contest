source ./contest/src/brave_opt.tcl

# test_suite:
#	* argument(s):
#		none.
#	* return: 
#		1 if all tests are passed, 0 otherwise.
proc test_suite {} {
	set libs_root "./data/RTL_libraries/"
	set DFGs_root "./data/DFGs/"

	# TODO: find a better way to set lambda
	set lambda 80

	set success 1
	foreach lib [glob $libs_root/*.txt] {
		read_library $lib
		foreach dfg [glob $DFGs_root/*.dot] {
			puts "Testing DFG $dfg with library $lib"
			read_design $dfg

			puts "Executing algorithm..."

			set start_time [clock clicks -milliseconds]

			set res [brave_opt -lambda $lambda]

			set end_time [clock clicks -milliseconds]


			set node_start_lst [lindex $res 0]
			set node_fu_lst [lindex $res 1]
			set fu_alloc_lst [lindex $res 2]

			puts -nonewline "Testing occurrencies..."
			if {[test_occurrencies $node_start_lst $node_fu_lst $fu_alloc_lst] == 1} {
				puts "\t\t\tOK"
			} else {
				puts "\t\t\tFAIL"
				set success 0
			}

			puts -nonewline "Testing latency violations..."
			if {[test_latency $node_start_lst $node_fu_lst $lambda] == 1} {
				puts "\t\tOK"
			} else {
				puts "\t\tFAIL"
				set success 0
			}

			puts -nonewline "Testing dependecies violations..."
			if {[test_dependencies $node_start_lst $node_fu_lst] == 1} {
				puts "\tOK"
			} else {
				puts "\tFAIL"
				set success 0
			}

			puts -nonewline "Testing fus conflicts..."
			if {[test_fu_conflicts $node_start_lst $node_fu_lst $fu_alloc_lst] == 1} {
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

		remove_library
	}

	return $success
}

# test_occurrencies:
#	* argument(s):
#		- node_start_lst: list of pairs <node_id, start_time>
#		- node_fu_lst: list of pairs <node_id, fu_id>
#		- fu_alloc_lst: list of pairs <fu_id, n_allocated>
#	* return: 
#		1 if each node appears exactly once in node_start_lst and
#		node_fu_lst and each fu appears exactly once in fu_alloc_lst,
#		0 otherwise.
proc test_occurrencies {node_start_lst node_fu_lst fu_alloc_lst} {
	foreach node [get_nodes] {
		set node_start_pair_lst [lsearch -all -inline -index 0 $node_start_lst $node]
		
		if {[llength $node_start_pair_lst] != 1} {
			return 0
		}

		set node_fu_pair_lst [lsearch -all -inline -index 0 $node_fu_lst $node]
		
		if {[llength $node_fu_pair_lst] != 1} {
			return 0
		}
	}

	foreach fu [get_lib_fus] {
		set node_fu_pair_lst [lsearch -all -inline -index 0 $fu_alloc_lst $fu]

		if {[llength $node_fu_pair_lst] != 1} {
			return 0
		}
	}

	return 1
}

# test_latency:
#	* argument(s):
#		- node_start_lst: list of pairs <node_id, start_time>
#		- node_fu_lst: list of pairs <node_id, fu_id>
#		- lambda: latency constraint.
#	* return: 
#		1 if latency constraint is satisfied, 0 otherwise.
proc test_latency {node_start_lst node_fu_lst lambda} {
	foreach node [get_nodes] {
		# check end time of leaves only
		if {[get_attribute $node n_children] == 0} {
			set node_start_pair [lsearch -inline -index 0 $node_start_lst $node]
			set start [lindex $node_start_pair 1]

			set node_fu_pair [lsearch -inline -index 0 $node_fu_lst $node]
			set fu [lindex $node_fu_pair 1]
			set delay [get_attribute $fu delay]

			set end [expr {$start + $delay}]
			
			if {$end > $lambda} {
				return 0
			}
		}
	}

	return 1
}

# test_dependencies:
#	* argument(s):
#		- node_start_lst: list of pairs <node_id, start_time>
#		- node_fu_lst: list of pairs <node_id, fu_id>
#	* return: 
#		1 if DFG dependencies are satisfied, 0 otherwise.
proc test_dependencies {node_start_lst node_fu_lst} {
	foreach node [get_nodes] {
		set node_start_pair [lsearch -inline -index 0 $node_start_lst $node]
		set start [lindex $node_start_pair 1]

		set node_fu_pair [lsearch -inline -index 0 $node_fu_lst $node]
		set fu [lindex $node_fu_pair 1]
		set delay [get_attribute $fu delay]
		set end [expr {$start + $delay}]

		foreach child [get_attribute $node children] {
			set child_start_pair [lsearch -inline -index 0 $node_start_lst $child]
			set child_start [lindex $child_start_pair 1]

			if {$child_start < $end} {
				return 0
			}
		}
	}

	return 1
}

# test_fu_conflicts:
#	* argument(s):
#		- node_start_lst: list of pairs <node_id, start_time>
#		- node_fu_lst: list of pairs <node_id, fu_id>
#		- fu_alloc_lst: list of pairs <fu_id, n_allocated>
#	* return: 
#		1 if the number of maximum contemporaneously running fus of each
#		type is equal to n_allocated, 0 otherwise.
proc test_fu_conflicts {node_start_lst node_fu_lst fu_alloc_lst} {
	foreach fu [get_lib_fus] {
		set start_lst [list]

		foreach node_fu_pair [lsearch -all -inline -index 1 $node_fu_lst $fu] {
			set node [lindex $node_fu_pair 0]
			set node_start_pair [lsearch -inline -index 0 $node_start_lst $node]
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

		set fu_alloc_pair [lsearch -inline -index 0 $fu_alloc_lst $fu]
		set alloc [lindex $fu_alloc_pair 1]

		if {$running_max != $alloc} {
			return 0
		}
	}

	return 1
}

proc print_info {node_start_lst node_fu_lst} {
	set end_max 0
	foreach node_start_pair $node_start_lst {
		set node [lindex $node_start_pair 0]
		set start [lindex $node_start_pair 1]
		set node_fu_pair [lsearch -inline -index 0 $node_fu_lst $node]
		set fu [lindex $node_fu_pair 1]

		set delay [get_attribute $fu delay]

		set end [expr {$start + $delay}]
		
		if {$end > $end_max} {
			set end_max $end
		}

		puts "node=$node; fu=$fu; start=$start; end=$end"
	}

	puts "Latency=$end_max"
}

