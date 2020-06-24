source ./contest/src/utils.tcl

# alap_sched:
#	* argument(s):
#		- nodes_fu_arr: array in which keys correspond to nodes and
#			values correspond to its fu.
#		- lambda: maximum total latency acceptable.
#	* return: 
#		nodes_dict labeled with t_alap, which corresponds to the start time
#			of the associated node, according to the ALAP algorithm.
proc alap_sched {node_fu_arr_arg lambda} {
	array set node_fu_arr $node_fu_arr_arg
	array set t_alap_arr {}

	# iterate all nodes, in a reverse topological order
	# (so that it is always considered a node with all descendant scheduled)
	foreach node [get_reverse_sorted_nodes] {
		set node_delay [get_attribute $node_fu_arr($node) delay]
		set t_alap [expr {$lambda - $node_delay}]
		foreach child [get_attribute $node children] {
			set t_alap_new [expr {$t_alap_arr($child) - $node_delay}]
			if {$t_alap_new < $t_alap} {
				set t_alap $t_alap_new
			}
		}

		set t_alap_arr($node) $t_alap
	}

	return [array get t_alap_arr]
}

# malc_brave:
#	* argument(s):
#		- lambda: maximum total latency acceptable.
#	* return: 
#		- start_time_lst: list of pairs <node_id, start_time>
#		- fu_id_lst: list of pairs <node_id, fu_id>
#		- fu_alloc_lst: list of pairs <fu_id, n_allocated>
proc malc_brave {lambda} {
	array set fus_arr [get_sorted_selected_fus_arr]
	array set node_fu_arr {}
	array set node_fu_index_arr {}
	array set fus_running_arr {}
	array set fus_max_running_arr {}
	array set slowable_arr {}
	array set t_sched_arr {}

	# associate nodes to fastest resources
	foreach node [get_nodes] {
		set op [get_attribute $node operation]
		set fu_dict [lindex $fus_arr($op) 0]
		set node_fu_arr($node) [dict get $fu_dict fu]
		set node_fu_index_arr($node) 0
	}

	# label nodes with last possible start time (with fastest resources)
	array set t_alap_arr [alap_sched [array get node_fu_arr] $lambda]

	# check if scheduling is feasible
	foreach {node t_alap} [array get t_alap_arr] {
		if {$t_alap <= 0} {
			return -code error "No feasible scheduling with lambda=$lambda"
		}
	}

	# do not allocate any fu at the beginnning
	array set fus_alloc_arr {}
	foreach fu [get_lib_fus] {
		set fus_alloc_arr($fu) 0
	}

	# sorting nodes by t_alap forces to schedule first most critical nodes,
	# not only when their slack is 0, but also on "free" resources:
	# this may reduce the number of allocated resources, thus reducing area
	set sorted_nodes_lst [get_sorted_nodes_by_t_alap [array get t_alap_arr]]

	set sched_complete 1
	set improvement 1
	set has_slowed 0
	# repeat until a node has slowed or a fu has allocated
	while {$sched_complete == 0 || $improvement == 1} {
		# keep track if there has been improvement in this
		# scheduling iteration (in which each node is slowed down
		# at max once)
		if {$sched_complete == 1} {
			# initialize improvement flag when starting a
			# new scheduling iteration
			set improvement 0
		} elseif {$has_slowed == 1} {
			# if a node has been slowed down
			# there had been an improvement
			set improvement 1
		}

		# initialization

		# at the beginning a node is slowable if it is not associated
		# to the latest fu of fus_list (which is the slowest)
		# N.B. nodes are made slowable only when previous
		# scheduling iteration has been completely performed
		# (i.e. it wasn't restarted due to a new fu allocation)
		# or when the first iteration is being executed:
		# this is to avoid slowing down only first nodes in
		# topological order
		if {$sched_complete == 1} {
			foreach {node fu_index} [array get node_fu_index_arr] {
				set op [get_attribute $node operation]
				set slowable_arr($node) [expr {$fu_index < [llength $fus_arr($op)] - 1}]
			}
		}

		# set all nodes as "waiting"
		# set no node as "ready" or "running"
		array set waiting_arr {}
		array set ready_arr {}
		array set running_arr {}
		foreach node $sorted_nodes_lst {
			set waiting_arr($node) 1
			set ready_arr($node) 0
			set running_arr($node) 0
		}

		# set all fus as not "running"
		foreach fu [get_lib_fus] {
			set fus_running_arr($fu) 0
			set fus_max_running_arr($fu) 0
		}

		# setup variables to force entering the while loop
		set waiting_cnt 1
		set ready_cnt 0
		set sched_complete 1
		# initialize time
		set t 0

		set has_slowed 0
		# iterate until all nodes are scheduled
		while {$waiting_cnt + $ready_cnt > 0 && $sched_complete == 1} {
			# update current time
			incr t

			# initialize counters (needed for controlling the main loop)
			set waiting_cnt 0
			set ready_cnt 0
			# update ready list
			foreach {node waiting} [array get waiting_arr] {
				if {$waiting == 0} {
					continue
				}
				set ready 1

				# check if all parents are scheduled
				# (not present in ready or waiting lists)
				foreach parent [get_attribute $node parents] {
					if {$waiting_arr($parent) == 1 ||
							$ready_arr($parent) == 1} {
						set ready 0
						break
					}
				}

				if {$ready == 1} {
					set ready_arr($node) 1
					set waiting_arr($node) 0
				} else {
					# update waiting count (ready nodes
					# will be counted later)
					incr waiting_cnt
				}
			}

			# check what nodes has completed at time t
			# and update fus_running_arr accordingly
			foreach {node running} [array get running_arr] {
				if {$running == 0} {
					continue
				}

				set fu $node_fu_arr($node)
				set delay [get_attribute $fu delay]

				if {$t >= $t_sched_arr($node) + $delay} {
					set running_arr($node) 0
					incr fus_running_arr($fu) -1
				}
			}

			foreach node $sorted_nodes_lst {
				if {$ready_arr($node) == 0} {
					continue
				}
				# count how many nodes are ready
				incr ready_cnt

				set t_alap $t_alap_arr($node)
				set slack [expr {$t_alap - $t}]

				# When slack is positive and node is slowable
				# there is room for slowing down to improve
				# area/power while still satisfying latency
				# constraint.
				# Proceed only if node hasn't already been
				# slowed down in this iteration.
				if {$slack > 0 && $slowable_arr($node) == 1} {
					set fu_index $node_fu_index_arr($node)
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
						set t_alap_arr($node) $t_alap_slowed

						set node_fu_arr($node) [dict get $fu_dict fu]
						set node_fu_index_arr($node) $fu_index

						# after substituting a fu, t_alap
						# are modified: need of sorting again
						set sorted_nodes_lst [update_sorted_nodes_by_t_alap $node $sorted_nodes_lst [array get t_alap_arr]]

						# update new slack
						set slack [expr {$t_alap_slowed - $t}]

						set slowable_arr($node) 0
						set sched_complete 0

						break
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
					set slowable_arr($node) 0
				}

				set fu $node_fu_arr($node)

				set running $fus_running_arr($fu)
				set alloc $fus_alloc_arr($fu)
				# schedule node with no more positive slack or
				# which do not require additional fu
				if {$slack == 0 || $running < $alloc} {
					# decrease ready counter: a scheduled
					# node is no more ready
					incr ready_cnt -1
					# annotate scheduled node with t_sched
					set t_sched_arr($node) $t

					# remove scheduled node from ready_arr
					set ready_arr($node) 0
					set running_arr($node) 1

					# update fus count
					incr running
					set fus_running_arr($fu) $running
					
					# store the maximum number of contemporary
					# running fus of each type (to know what
					# are actually  used in this scheduling
					# iteration)
					if {$running > $fus_max_running_arr($fu)} {
						set fus_max_running_arr($fu) $running

						# when running > alloc it is
						# necessary to allocate a new fu
						if {$running > $alloc} {
							# restart the scheduling
							# every time a fu is added
							# N.B. all data structures
							# are re-initialized,
							# except for fus_alloc_arr,
							# so that previous scheduling
							# steps will be aware of
							# fus which are allocated
							# later and can make use
							# of them
							set sched_complete 0
							break
						}
					}

				}
			}
		}

		# Update fus_alloc_arr with actually used fus:
		# - it is necessary to allocate a number of fus equal to the
		# maximum number of contemporary running fus of each type
		# - it is possible that some fus allocated in previous scheduling
		# iteration are no more needed
		array set fus_alloc_arr [array get fus_max_running_arr]
	}

	set start_time_lst [list]
	foreach {node t_sched} [array get t_sched_arr] {
		lappend start_time_lst "$node $t_sched"
	}
	set fu_id_lst [list]
	foreach {node fu} [array get node_fu_arr] {
		lappend fu_id_lst "$node $fu"
	}
	set fu_alloc_lst [list]
	foreach {fu alloc} [array get fus_alloc_arr] {
		lappend fu_alloc_lst "$fu $alloc"
	}

	return [list $start_time_lst $fu_id_lst $fu_alloc_lst]
}

