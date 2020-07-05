# High-Level Synthesis Contest
## Synthesis and Optimization of Digital Systems
### Group 4
| Student | ID |
|-|-|
| Brignone Giovanni | s274148 |
| Faggiano Riccardo | s267514 |
| Galasso Luigi | s267302 |
#### Abstract
`brave_opt` is a Tcl script compatible with Shy_HLS, aimed at minimizing power
and area under latency constraints.

The basic idea behind `brave_opt` is:
* filter out non-convenient functional units
* bind all nodes to fastest functional units (in order to check if the
scheduling is feasible)
* slow down every node as far as timing constraints are satisfied
* schedule nodes using a Minimum Area Latency Constrained algorithm

&nbsp;

N.B. "non-convenient functional units" are:
* slower and more power consuming
* slower, equally power consuming and more or equal area requiring

This filtering is hence prioritizing power saving: this choice has been taken
considering that in modern designs power consumption is usually more critical
than area occupation.

#### Control flow diagram
```plantuml
start

:Sort fus by delay,
power and area
(filter out non-convenient fus);
:Associate each node
to fastest fu;
note left
	This ensures that
	timing constraints
	are satisfied
end note
:Label each node with its t_ALAP;
:Do not allocate any fu;
note left
	Actually needed fus
	will be allocated only
end note
	
repeat
	if (Not force restarted) then (true)
		:Allow every node to be
		slowed down, if possible;
	else (false)
	endif
	note left
		Allow at max one slow down per scheduling
		iteration: this is to avoid slowing down
		first nodes in topological order too much,
		which may force later nodes to be associated
		with fastest resources in order to satisfy
		timing constraints
	end note
		:ready = nodes without parents
		waiting = all nodes - ready
		running = empty
		complete = empty;
		:t = 0;
	while (Not all nodes are scheduled \n and not force restarted) is (true)
		:t++;
		while (Foreach node in running) is (true)
			if (node t_end == t) then (true)
				:running = running - node
				complete = complete + node;
				while (Foreach child of node) is (true)
					if (all parents of child in complete) then (true)
						:waiting = waiting - child
						ready = ready + child;
						if (child allowed to be slowed AND\nnot associated with slowest fu) then (true)
							:slowable = slowable + child;
						else (false)
						endif
					else (false)
					endif
				endwhile
			else (false)
			endif
		endwhile
		while (Foreach node in slowable)
			if (\t\t\tSlack > 0 AND \ntiming is satisfied with immediately slower fu) then (true)
				:Slow down to immediately
				slower fu;
				:Update t_ALAP of current node and
				of all its ancestors recursively;
			else (false)
			endif
		endwhile
		:slowable = empty;
		note left
			Slow down only once
			per iteration at max
		end note
		:Sort ready nodes by t_ALAP;
		note left
			Ensure to schedule most
			critical nodes first
		end note
		while (Foreach node in ready)
			if (Slack == 0 OR do not require additional fu) then (true)
				:Schedule node at time t and add it to running;
				:Update # max contemporary running fus;
				if (Additional fu is required) then (true)
					:Force restart;
					note left
						Make use of newly added fu
						in previuos times too
					end note
					:break;
				else (false)
				endif
			else (false)
			endif
		endwhile
		: # allocated fus = # max contemporary running fus;
		note left
			Allocate actually used fus only
			(it is possible that in previous
			iterations more fus were allocated)
		end note
	endwhile (false)
repeat while (Some node has been slowed down \n or force restarted) is (true)

stop
```

