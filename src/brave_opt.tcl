source ./contest/src/utils.tcl
source ./contest/src/schedulers.tcl

proc brave_opt args {
	array set options {-lambda 0}

	if {[llength $args] != 2} {
		return -code error "Use brave_opt with -lambda \$latency_value\$"
	}

	foreach {opt val} $args {
		if {![info exist options($opt)]} {
			return -code error "unknown option \"$opt\""
		}
		set options($opt) $val
	}

	set latency_value $options(-lambda)

	puts $latency_value

	return [malc_brave $latency_value]
}

