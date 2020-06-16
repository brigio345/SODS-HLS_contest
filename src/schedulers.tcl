source ./contest/src/utils.tcl

# alap_sched:
#	* argument(s):
#		- nodes_dict: dictionary in which keys correspond to nodes and
#			values correspond to information about the key node.
#			N.B.: fu of each node is required.
#		- lambda: maximum total latency acceptable.
#	* return: 
#		nodes_dict labeled with t_alap, which corresponds to the start time
#			of the associated node, according to the ALAP algorithm.
proc alap_sched {nodes_dict lambda} {
	# iterate all nodes, in a reverse topological order
	# (so that it is always considered a node with all descendant scheduled)
	dict for {node node_dict} [get_reverse_sorted_nodes $nodes_dict] {
		set node_delay [get_attribute [dict get $node_dict fu] delay]
		set t_alap [expr {$lambda - $node_delay}]
		foreach child [get_attribute $node children] {
			set child_dict [dict get $nodes_dict $child]
			set t_alap_child [dict get $child_dict t_alap]
			set t_alap_new [expr {$t_alap_child - $node_delay}]
			if {$t_alap_new < $t_alap} {
				set t_alap $t_alap_new
			}
		}

		dict set node_dict t_alap $t_alap
		dict set nodes_dict $node $node_dict
	}

	return $nodes_dict
}

# malc_brave:
#	* argument(s):
#		- nodes_dict: dictionary in which keys correspond to nodes and
#			values correspond to information about the key node.
#			N.B.: fu of each node is required.
#		- lambda: maximum total latency acceptable.
#	* return: 
#		nodes_dict with each node labeled with:
#			1. t_sched: start time.
#			2. fu: functional unit (chosen trying to minimize area
#				and power consumption)
proc malc_brave {nodes_dict lambda} {
	array set fus_arr [get_sorted_selected_fus_arr]

	# do not allocate any fu at the beginnning
	set fus_alloc_dict [dict create]
	foreach fu [get_lib_fus] {
		dict set fus_alloc_dict $fu 0
	}

	# sorting nodes by t_alap forces to schedule first most critical nodes,
	# not only when their slack is 0, but also on "free" resources:
	# this may reduce the number of allocated resources, thus reducing area
	set nodes_dict [get_sorted_nodes_by_t_alap $nodes_dict]

	set has_slowed 1
	set restarted 0
	# repeat until a node has slowed or a fu has allocated
	while {$has_slowed == 1 || $restarted == 1} {
		set has_slowed 0

		# initialization

		# at the beginning a node is slowable if it is not associated
		# to the latest fu of fus_list (which is the slowest)
		# N.B. nodes are made slowable only when previous
		# scheduling iteration has been completely performed
		# (i.e. it wasn't restarted due to a new fu allocation)
		# or when the first iteration is being executed:
		# this is to avoid slowing down only first nodes in
		# topological order
		if {$restarted == 0} {
			dict for {node node_dict} $nodes_dict {
				set op [get_attribute $node operation]
				# get fus implementing the operation of
				# current node
				set fu_index [dict get $node_dict fu_index]

				if {$fu_index < [llength $fus_arr($op)] - 1} {
					dict set node_dict slowable 1
				} else {
					dict set node_dict slowable 0
				}

				dict set nodes_dict $node $node_dict
			}
		}

		# set all nodes as "waiting"
		set waiting_lst [dict keys $nodes_dict]
		# set no node as "ready" or "running"
		set ready_lst [list]
		set running_lst [list]

		# set all fus as not "running"
		set fus_running_dict [dict create]
		set fus_max_running_dict [dict create]
		foreach fu [get_lib_fus] {
			dict set fus_running_dict $fu 0
			dict set fus_max_running_dict $fu 0
		}

		set restarted 0
		set t 0
		# iterate until all nodes are scheduled
		while {[llength $waiting_lst] + [llength $ready_lst] > 0 && $restarted == 0} {
			# update current time
			incr t

			# update ready list
			foreach node $waiting_lst {
				set ready 1

				# check if all parents are scheduled
				# (not present in ready or waiting lists)
				foreach parent [get_attribute $node parents] {
					if {[lsearch $waiting_lst $parent] != -1 ||
							[lsearch $ready_lst $parent] != -1} {
						set ready 0
						break
					}
				}

				if {$ready == 1} {
					lappend ready_lst $node
					lremove waiting_lst $node
				}
			}

			# check what nodes has completed at time t
			# and update fus_running_dict accordingly
			foreach node $running_lst {
				set node_dict [dict get $nodes_dict $node]

				set t_sched [dict get $node_dict t_sched]
				set fu [dict get $node_dict fu]
				set delay [get_attribute $fu delay]

				if {$t >= $t_sched + $delay} {
					lremove running_lst $node
					set running [dict get $fus_running_dict $fu]
					incr running -1
					dict set fus_running_dict $fu $running
				}
			}

			foreach node $ready_lst {
				set node_dict [dict get $nodes_dict $node]

				set t_alap [dict get $node_dict t_alap]
				set slack [expr {$t_alap - $t}]

				# When slack is positive and node is slowable
				# there is room for slowing down to improve
				# area/power while still satisfying latency
				# constraint.
				# Proceed only if node hasn't already been
				# slowed down in this iteration.
				if {$slack > 0 && [dict get $node_dict slowable] == 1} {
					# get current fu index
					set fu_index [dict get $node_dict fu_index]
					# move to the next slower fu
					incr fu_index
					# get functional units implementing
					# current node operation
					set op [get_attribute $node operation]
					set fus_lst $fus_arr($op)
					# get dictionary of the new fu
					set fu_dict [lindex $fus_lst $fu_index]
					# check if the latency constraint would
					# be still satisfied with the new fu
					set delta [dict get $fu_dict delta]
					set t_alap_slowed [expr {$t_alap - $delta}]

					# if current node, after slowing it down
					# can be still scheduled at time t or
					# later, it can be slowed down
					if {$t_alap_slowed >= $t} {
						# update the flag
						set has_slowed 1
						# update t_alap with new resource
						dict set node_dict t_alap $t_alap_slowed

						dict set node_dict fu_index $fu_index
						dict set node_dict fu [dict get $fu_dict fu]

						# after substituting a fu, t_alap
						# are modified: need of sorting again
						set nodes_dict [update_sorted_nodes_by_t_alap $node $nodes_dict]

						# update new slack
						set slack [expr {$t_alap_slowed - $t}]
					}

					# avoid trying to replace this node in
					# next iterations:
					#	- if it has been replaced, it is
					#		forbidden to replace it
					#		again, in order to avoid
					#		to slow down only first
					#		nodes in topological
					#		order
					#	- if it hasn't been replaced,
					#		it is impossible that
					#		it can be replaced in
					#		next iterations, since
					#		the slack will decrease
					dict set node_dict slowable 0

					dict set nodes_dict $node $node_dict
				}

				set fu [dict get $node_dict fu]

				set running [dict get $fus_running_dict $fu]
				set alloc [dict get $fus_alloc_dict $fu]
				# schedule node with no more positive slack or
				# which do not require additional fu
				if {$slack == 0 || $running < $alloc} {
					# annotate scheduled node with t_sched
					dict set node_dict t_sched $t
					dict set nodes_dict $node $node_dict
					# remove scheduled node from ready_lst
					lremove ready_lst $node
					lappend running_lst $node

					# update fus count
					incr running
					dict set fus_running_dict $fu $running
					
					# store the maximum number of contemporary
					# running fus of each type (to know what
					# are actually  used in this scheduling
					# iteration)
					set max_running [dict get $fus_max_running_dict $fu]
					if {$running > $max_running} {
						dict set fus_max_running_dict $fu $running

						# when running > alloc it is
						# necessary to allocate a new fu
						if {$running > $alloc} {
							# restart the scheduling
							# every time a fu is added
							# N.B. all data structures
							# are re-initialized,
							# except for fus_alloc_dict,
							# so that previous scheduling
							# steps will be aware of
							# fus which are allocated
							# later and can make use
							# of them
							set restarted 1
							break
						}
					}

				}
			}
		}

		# Update fus_alloc_dict with actually used fus:
		# - it is necessary to allocate a number of fus equal to the
		# maximum number of contemporary running fus of each type
		# - it is possible that some fus allocated in previous scheduling
		# iteration are no more needed
		set fus_alloc_dict $fus_max_running_dict
	}

	# remove malc labels
	dict for {node node_dict} $nodes_dict {
		set node_dict [dict remove $node_dict slowable]
		dict set nodes_dict $node $node_dict
	}

	return [dict create nodes $nodes_dict fus $fus_alloc_dict]
}

