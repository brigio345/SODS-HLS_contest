source ./contest/src/utils.tcl
source ./contest/src/schedulers.tcl

proc brave_opt args {
	array set options {-lambda 0}

	if {[llength $args] != 2} {
		return -code error "Use brave_opt with -lambda \$latency_value\$"
	}

	foreach {opt val} $args {
		if {![info exist options($opt)]} {
			return -code error "unknown option \"$opt\""
		}
		set options($opt) $val
	}

	set latency_value $options(-lambda)

	puts $latency_value

	set fus_dict [get_sorted_fus_per_op delay]
	set nodes_dict [dict create]

	# associate nodes to fastest resources
	foreach node [get_nodes] {
		set op [get_attribute $node operation]
		set fu_dict [lindex [dict get $fus_dict $op] 0]
		set fu [dict get $fu_dict fu]
		set node_dict [dict create fu_index 0]
		dict set node_dict fu $fu
		dict set nodes_dict $node $node_dict
	}

	# label nodes with last possible start time (with fastest resources)
	set nodes_dict [alap_sched $nodes_dict $latency_value]

	# check if scheduling is feasible
	foreach node_dict [dict values $nodes_dict] {
		if {[dict get $node_dict t_alap] < 0} {
			return -code error "No feasible scheduling with lambda=$latency_value"
		}
	}

	set start_time [clock clicks -milliseconds]

	malc_brave $nodes_dict $latency_value

	set end_time [clock clicks -milliseconds]

	puts "Execution took [expr {$end_time - $start_time}] ms"

	return
}

