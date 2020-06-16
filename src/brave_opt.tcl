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

	array set fus_arr [get_sorted_selected_fus_arr]
	set nodes_dict [dict create]

	# associate nodes to fastest resources
	foreach node [get_nodes] {
		set op [get_attribute $node operation]
		set fu_dict [lindex $fus_arr($op) 0]
		set fu [dict get $fu_dict fu]
		set node_dict [dict create fu_index 0]
		dict set node_dict fu $fu
		dict set nodes_dict $node $node_dict
	}

	# label nodes with last possible start time (with fastest resources)
	set nodes_dict [alap_sched $nodes_dict $latency_value]

	# check if scheduling is feasible
	foreach node_dict [dict values $nodes_dict] {
		if {[dict get $node_dict t_alap] <= 0} {
			return -code error "No feasible scheduling with lambda=$latency_value"
		}
	}

	set res_dict [malc_brave $nodes_dict $latency_value]

	set nodes_dict [dict get $res_dict nodes]

	set start_time_lst [list]
	set fu_id_lst [list]
	dict for {node node_dict} $nodes_dict {
		lappend start_time_lst "$node [dict get $node_dict t_sched]"
		lappend fu_id_lst "$node [dict get $node_dict fu]"
	}

	set fus_dict [dict get $res_dict fus]

	set fu_alloc_lst [list]
	dict for {fu alloc} $fus_dict {
		lappend fu_alloc_lst "$fu $alloc"
	}

	return [list $start_time_lst $fu_id_lst $fu_alloc_lst]
}

