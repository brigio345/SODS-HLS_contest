source ./alap-giovanni.tcl

proc get_sorted_U {V S} {
	set U [list]

	foreach node $V {
		set valid 1
		set node_id [lindex $node 0]
		foreach parent [get_attribute $node_id parents] {
			if {[lsearch -index 0 $S $parent] == -1} {
				set valid 0
				break
			}
		}
		if {$valid == 1} {
			lappend U $node
		}
	}

	set U [lsort -index 1 -integer -decreasing $U]
	
	set sorted_U [list]

	# remove no more needed labels, since the list is sorted
	foreach u $U {
		lappend sorted_U [lindex $u 0]
	}

	return $sorted_U
}

proc list_malc {lambda} {
	set alap_sched [alap $lambda]

	if {[lindex [lindex $alap_sched end] 1] < 1} {
		puts "No feasible scheduling with lambda=$lambda"
		return
	}

	set res [list]
	foreach node $alap_sched {
		set op [get_attribute [lindex $node 0] operation]
		if {[lsearch -index 0 $res $op] == -1} {
			lappend res "$op 1"
		}
	}

	set start_time 1
	set sched [list]
	while {[llength $alap_sched] > 0} {
		set ready [get_sorted_U $alap_sched $sched]
		set free_res $res

		foreach node $ready {
			# get the index of the number of resources related to operation of current node
			set i_r [lsearch -index 0 $free_res [get_attribute $node operation]]
			# get the number of resources related to operation of current node
			set r [lindex [lindex $free_res $i_r] 1]

			if {[lsearch $alap_sched $node] - $start_time < 1} {
				lappend sched "$node $start_time"
				incr r -1
				if {$r < 0} {
					set curr_res [lindex $res $i_r]
					set curr_res "[lindex $curr_res 0] [expr {[lindex $curr_res 1] + 1}]"
					lset res $i_r $curr_res
				}
				# remove current node from set alap_sched
				set alap_sched [lsearch -index 0 -inline -not -all -exact $alap_sched $node]
			} elseif {$free_res > 0} {
				lappend sched "$node $start_time"
				incr r -1
				# remove current node from set alap_sched
				set alap_sched [lsearch -index 0 -inline -not -all -exact $alap_sched $node]
			}

			lset free_res $i_r "[lindex [lindex $free_res $i_r] 0] $r"
		}

		incr start_time
	}

	set last_start [expr $start_time - 1]
	set last_delay [get_attribute [get_lib_fu_from_op [get_attribute [lindex [lindex $sched end] 0] operation]] delay]
	set latency [expr $last_start + $last_delay - 1]

	return [list $sched $latency]
}

