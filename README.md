# High-Level Synthesis Contest
## Synthesis and Optimization of Digital Systems
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
![flow-diagram](http://www.plantuml.com/plantuml/proxy?cache=no&src=https://raw.githubusercontent.com/brigio345/SODS-HLS_contest/master/flow_chart.iuml&fmt=svg)

