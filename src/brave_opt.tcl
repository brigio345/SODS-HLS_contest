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

	# malc + check:
	# foreach v in U
	# 	foreach fu in fus (slowest to fastest)
	#		s_new_map = tALAP - (t_slower - t_fastest) -- add this delta to fus directly instead of having absolute value
	#		if (s_new_map > 0)
	#			skip -- can be scheduled later, with slower res
	#		elsif (0)
	#			map to this slower res and schedule now
	#			update children
	#		else
	#			cannot slow down
	set fus_l [get_sorted_fus_per_op delay]
	set nodes_l [dict create]

	# associate nodes to fastest resources
	foreach node [get_nodes] {
		set op [get_attribute $node operation]
		set fu [lindex [dict get $fus_l $op] 0]
		set node_l [dict create fu_index 0]
		dict set node_l fu $fu
		dict set nodes_l $node $node_l
	}

	# label nodes with last possible start time (with fastest resources)
	set nodes_l [alap_sched $nodes_l $latency_value]

	foreach node [get_sorted_nodes] {
		
	}

	return
}

