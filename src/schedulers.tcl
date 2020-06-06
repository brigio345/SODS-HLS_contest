source ./contest/src/utils.tcl

# alap_sched:
#	* argument(s):
#		- nodes_l: dictionary in which keys correspond to nodes and
#			values correspond to information about the key node.
#			N.B.: fu of each node is required.
#		- lambda: maximum total latency acceptable.
#	* return: 
#		nodes_l labeled with t_alap, which corresponds to the start time
#			of the associated node, according to the ALAP algorithm.
proc alap_sched {nodes_l lambda} {
	# iterate all nodes, in a reverse topological order
	# (so that it is always considered a node with all descendant scheduled)
	dict for {node node_l} [get_reverse_sorted_nodes $nodes_l] {
		set node_delay [get_attribute [dict get $node_l fu] delay]
		set t_alap $lambda
		foreach child [get_attribute $node children] {
			set child_l [dict get $nodes_l $child]
			set t_alap_child [dict get $child_l t_alap]
			set t_alap_new [expr $t_alap_child - $node_delay]
			if {$t_alap_new < $t_alap} {
				set t_alap $t_alap_new
			}
		}
		dict set node_l t_alap $t_alap
		dict set nodes_l $node $node_l
	}

	return $nodes_l
}

