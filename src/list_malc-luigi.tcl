proc list_malc_scheduler { latency } {

source ./tcl_scripts/scheduling/alap.tcl

set resources { {ADD 0} {MUL 0} {LOD 0} {STR 0} }
set min_resources $resources
set alap_schedule [ alap $latency ]
set step 1
set still_running [list]
set L_prime [list]
set slack [list]
set start_time [list] 
set ready_operators [list]

foreach node [get_sorted_nodes] {
	puts "$node"
	set n_parents [get_attribute $node n_parents]
	puts "$n_parents"
	lappend L_prime "$node $n_parents"
}

puts "L_prime  $L_prime\n"		

while {[llength $L_prime] != [llength $start_time] } {
	set min_resources { {ADD 0} {MUL 0} {LOD 0} {STR 0} }	
	
	foreach node $L_prime {
		set n_parents [lindex $node 1]
		set node_id [lindex $node 0]
		if { $n_parents == 0 && ( [llength $ready_operators] == 0 || ( [ lsearch -index 0 $ready_operators $node_id ] == -1  )) } {
			lappend ready_operators "$node_id"
		}
	}
	puts "STEP $step\n"
	puts "Ready operators are $ready_operators\n "
	###ALAP
	puts "ALAP $alap_schedule"
	foreach node $alap_schedule {
		set node_id [lindex $node 0]
		set node_start [lindex $node 1]
		#set pos [lsearch $alap_schedule $node ]
		set node_slack [expr { $node_start - $step } ]
		if { [ llength $slack ] == 0  } {
			lappend slack "$node_id $node_slack "
		} else {
			set s_pos [lsearch -index 0 $slack $node_id ]
			set slack [lreplace $slack $s_pos $s_pos "$node_id $node_slack" ]
		}
		
	}
	puts "Slack $slack\n"
	###still running check
	foreach node $still_running {
                set node_op [ get_attribute $node operation ]
		set res_pos [lsearch -index 0 $min_resources $node_op]
		set res_value [lindex [ lindex $min_resources $res_pos] 1 ]
                set new_n [expr {$res_value + 1 } ]
                set min_resources [ lreplace $min_resources $res_pos $res_pos "$node_op $new_n" ]

	}
	puts "Still running $still_running\n"
	###schedule
	foreach node $ready_operators {
		#set node_id [lindex $node 0]
                #set node_start [lindex $node 1]
		set node_op [get_attribute $node operation]
		set node_pos [lsearch -index 0 $slack $node ]
		set node_slack [lindex [lindex $slack $node_pos ] 1 ]
		if {$node_slack == 0 && ( [ lsearch -index 0 $start_time $node ] == -1  ) } {
			lappend start_time "$node $step"
			set res_pos [ lsearch -index 0  $min_resources $node_op ]
			set res_value [lindex [ lindex $min_resources $res_pos] 1 ]
			set new_n [expr {$res_value + 1 } ]
			set min_resources [ lreplace $min_resources $res_pos $res_pos "$node_op $new_n" ]
					
		}
		
	}
puts "Min resources $min_resources\n"	
	foreach resource $min_resources {
		set res_pos [ lsearch $min_resources $resource ]
		set res_type [lindex [lindex $min_resources $res_pos ] 0]
                set min_res_value [lindex [ lindex $min_resources $res_pos] 1 ]
                set res_value [lindex [ lindex $resources $res_pos] 1 ]
		if { $min_res_value > $res_value } {
                	set resources [ lreplace $resources $res_pos $res_pos "$res_type $min_res_value" ]
		}
	}
puts "Resources required $resources"
set step [ expr { $step +1 } ]

	foreach scheduled $start_time {
		set node_id [lindex $scheduled 0]
		set node_start_time  [lindex $scheduled 1 ]
		set node_op [ get_attribute $node_id operation ]
		set fu [get_lib_fu_from_op $node_op]
		set node_delay [get_attribute $fu delay]
		set node_end_time [ expr { $node_start_time + $node_delay } ]
		if { $node_end_time  == $step } {
			foreach child [get_attribute $scheduled children ] {
				set pos [ lsearch -index 0 $L_prime $child]
				set new_parents [ expr { [lindex [lindex $L_prime $pos] 1] -1 } ]
				set el [lreplace [lindex $L_prime [lsearch -index 0 $L_prime $child ]] 1 1 $new_parents ]
				set L_prime [lreplace $L_prime $pos $pos $el]
			}	
		}
		if { $node_end_time > $step && ( [lsearch -index 0  $still_running $node_id] == -1 ) } {
	#      		puts "STEP $step\nThere is NODE $node NODE START TIME IS $node_start_time , END TIME is $node_end_time \n"
			lappend still_running $node_id
        	} elseif {$node_end_time <= $step && ( [lsearch -index 0 $still_running $node_id] > -1 ) } {
        		set pos [lsearch -index 0 $still_running $node_id]
        	        if {$pos > -1 } {
        			set still_running [lreplace $still_running $pos $pos ]
	#			puts "changed still_r $still_running"
 	       		 }
        	}
		
	}
puts "L_prime $L_prime\n"

}
puts "Start time $start_time\n"
set ret [list]
lappend ret "$start_time"
lappend ret " $resources"
return $ret 
}	
