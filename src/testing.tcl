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
		set node [lindex $node_pair 0]
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

