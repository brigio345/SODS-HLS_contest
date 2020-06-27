# High-Level Synthesis Contest
## Synthesis and Optimization of Digital Systems
### Group 4
| Student | ID |
|-|-|
| Brignone Giovanni | s274148 |
| Faggiano Riccardo | s267514 |
| Galasso Luigi | s267302 |
#### Abstract
The developed algorithm is a modified Minimum Area Latency Constrained algorithm:
whenever it is possible functional units are replaced with slower ones, in order
to lower power consumption and lower area occupation.

#### Control flow diagram
```plantuml
start

:Sort fus by delay,
power and area
(filter out non-convenient fus);
:Associate each node
to fastest fu;
note left
	Try to satisfy
	timing constraints
end note
:Label each node with its t_ALAP;
:Do not allocate any fu;
note left
	Actually needed fus
	will be allocated only
end note
:Sort nodes by t_ALAP;
note left
	Ensure to schedule most
	critical nodes first
end note
	
repeat
	if (Not force restarted) then (true)
		:Set all nodes not associated
		with slowest fu as slowable;
	else (false)
	endif
	note left
		Allow slow down only if
		scheduling is actually (re)started
	end note
		:waiting = all nodes
		ready = empty
		running = empty;
		:t = 0;
	while (Not all nodes are scheduled \n and not force restarted) is (true)
		:t++;
		:ready = all waiting nodes with all parents scheduled
		running = running - nodes completed at time t;
		while (Foreach node in ready)
			if (Slack > 0 AND slowable AND \ntiming is satisfied with immediately slower fu) then (true)
				:Slow down to immediately
				slower fu;
				:Update t_ALAP and
				update the sorting by t_ALAP;
				:Set as not slowable;
				note left
					Slow down only
					once per iteration
				end note
			else (false)
			endif
		endwhile
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
