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
		set t_alap_child_min $lambda
		foreach child [get_attribute $node children] {
			set t_alap_child [dict get [dict get $nodes_dict $child] t_alap]
			if {$t_alap_child < $t_alap_child_min} {
				set t_alap_child_min $t_alap_child
			}
		}

		set t_alap [expr {$t_alap_child_min - [get_attribute [dict get $node_dict fu] delay]}]
		dict set node_dict t_alap $t_alap

		dict set nodes_dict $node $node_dict
	}

	return $nodes_dict
}

# malc_brave:
#	* argument(s):
#		- lambda: maximum total latency acceptable.
#	* return: 
#		- start_time_lst: list of pairs <node_id, start_time>
#		- fu_id_lst: list of pairs <node_id, fu_id>
#		- fu_alloc_lst: list of pairs <fu_id, n_allocated>
proc malc_brave {lambda} {
	set nodes_dict [dict create]

	array set fus_arr [get_sorted_selected_fus_arr]
	# associate nodes to fastest resources
	foreach node [get_nodes] {
		set fu_dict [lindex $fus_arr([get_attribute $node operation]) 0]
		dict set nodes_dict $node [dict create fu_index 0 fu [dict get $fu_dict fu]]
	}

	# label nodes with last possible start time (with fastest resources)
	set nodes_dict [alap_sched $nodes_dict $lambda]

	# check if scheduling is feasible
	foreach node_dict [dict values $nodes_dict] {
		if {[dict get $node_dict t_alap] <= 0} {
			return -code error "No feasible scheduling with lambda=$lambda"
		}
	}

	# do not allocate any fu at the beginnning
	foreach fu [get_lib_fus] {
		set fus_alloc_arr($fu) 0
	}

	# initialize flags
	set sched_complete 1
	set improvement 1
	set has_slowed 0
	# repeat until at least a node has slowed down (improvement == 1) or
	# a fu has been allocated (sched_complete == 0)
	while {$sched_complete == 0 || $improvement == 1} {
		# keep track if there has been improvement in this
		# scheduling iteration (in which each node is slowed down
		# at max once)
		if {$sched_complete == 1} {
			# initialize improvement flag when starting a
			# new scheduling iteration
			set improvement 0

			foreach node [dict keys $nodes_dict] {
				set slow_allowed_arr($node) 1
			}
		} elseif {$has_slowed == 1} {
			# if a node has been slowed down
			# there had been an improvement
			set improvement 1
		}

		# set all nodes as "waiting"
		# set no node as "running" or "ready"
		set ready_lst [list]
		# set nodes with no parent as "ready" and "slowable" (if possible)
		# set no node as "complete"
		dict for {node node_dict} $nodes_dict {
			set complete_arr($node) 0
			if {[get_attribute $node n_parents] == 0} {
				lappend ready_lst $node

				if {$slow_allowed_arr($node) == 1} {
					set slow_allowed_arr($node) 0
					set op [get_attribute $node operation]
					# get fus implementing the operation of
					# current node
					set fu_index [dict get $node_dict fu_index]

					if {$fu_index < [llength $fus_arr($op)] - 1} {
						set slowable_arr($node) 1
					}
				}
			} else {
				set waiting_arr($node) 1
			}
		}

		# set all fus as not "running"
		foreach fu [get_lib_fus] {
			set fus_running_arr($fu) 0
			set fus_max_running_arr($fu) 0
		}

		# initialize flags
		set sched_complete 1
		set has_slowed 0

		# initialize time
		set t 0

		# iterate until all nodes are scheduled or restart is forces (sched_complete == 0)
		while {[array size waiting_arr] + [llength $ready_lst] > 0 && $sched_complete == 1} {
			# update current time
			incr t

			# check what nodes have completed at time t and update
			# fus_running_arr and nodes status accordingly
			foreach node [array names running_arr] {
				set node_dict [dict get $nodes_dict $node]

				if {$t >= [dict get $node_dict t_end]} {
					unset running_arr($node)

					set complete_arr($node) 1
					incr fus_running_arr([dict get $node_dict fu]) -1

					# update ready list checking children of completed node
					foreach child [get_attribute $node children] {
						set ready 1
						# check if also all other parents have completed
						foreach parent [get_attribute $child parents] {
							if {$complete_arr($parent) == 0} {
								set ready 0
								break
							}
						}

						if {$ready == 1} {
							lappend ready_lst $child
							unset waiting_arr($child)

							if {$slow_allowed_arr($child) == 1} {
								set slow_allowed_arr($child) 0
								set op [get_attribute $child operation]
								# get fus implementing the operation of
								# current node
								set child_dict [dict get $nodes_dict $child]
								set fu_index [dict get $child_dict fu_index]

								if {$fu_index < [llength $fus_arr($op)] - 1} {
									set slowable_arr($child) 1
								}
							}
						}
					}
				}
			}

			# slow down loop
			foreach node [array names slowable_arr] {
				set node_dict [dict get $nodes_dict $node]
				set t_alap [dict get $node_dict t_alap]
				set slack [expr {$t_alap - $t}]

				# When slack is positive and node is slowable
				# there is room for slowing down to improve
				# area/power while still satisfying latency
				# constraint.
				# Proceed only if node hasn't already been
				# slowed down in this iteration.
				if {$slack > 0} {
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
						dict set nodes_dict $node $node_dict

						foreach parent [get_attribute $node parents] {
							set nodes_dict [update_t_alap $parent $node $nodes_dict]
						}
					}
				}
			}
			# avoid trying to replace these nodes in next iterations:
			#	- if a node has been replaced, it is forbidden
			#		to replace it again, until scheduling is
			#		restarted, in order to avoid to slow down
			#		first nodes in topological order only
			#	- if a node hasn't been replaced, it is impossible
			#		that it can be replaced in next iterations,
			#		since the slack will decrease
			array unset slowable_arr

			# sorting nodes by t_alap forces to schedule first most
			# critical nodes, not only when their slack is 0, but
			# also on "free" resources: this may reduce the number
			# of allocated resources, thus reducing area
			set ready_t_alap_lst [list]
			foreach node $ready_lst {
				lappend ready_t_alap_lst "$node [dict get [dict get $nodes_dict $node] t_alap]"
			}

			set ready_t_alap_lst [lsort -integer -index 1 $ready_t_alap_lst]
			set ready_lst [list]
			foreach ready_t_alap_pair $ready_t_alap_lst {
				lappend ready_lst [lindex $ready_t_alap_pair 0]
			}

			# scheduling loop
			foreach node $ready_lst {
				set node_dict [dict get $nodes_dict $node]

				set slack [expr {[dict get $node_dict t_alap] - $t}]
				set fu [dict get $node_dict fu]

				set running $fus_running_arr($fu)
				set alloc $fus_alloc_arr($fu)

				# schedule node with no more positive slack or
				# which do not require additional fu
				if {$slack == 0 || $running < $alloc} {
					set running_arr($node) 1
					lremove ready_lst $node

					# annotate scheduled node with t_sched
					# and t_end
					dict set node_dict t_sched $t
					dict set node_dict t_end [expr {$t + [get_attribute $fu delay]}]

					dict set nodes_dict $node $node_dict

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

	set node_start_lst [list]
	set node_fu_lst [list]
	dict for {node node_dict} $nodes_dict {
		lappend node_start_lst "$node [dict get $node_dict t_sched]"
		lappend node_fu_lst "$node [dict get $node_dict fu]"
	}

	set fu_alloc_lst [list]
	foreach {fu alloc} [array get fus_alloc_arr] {
		lappend fu_alloc_lst "$fu $alloc"
	}

	return [list $node_start_lst $node_fu_lst $fu_alloc_lst]
}

