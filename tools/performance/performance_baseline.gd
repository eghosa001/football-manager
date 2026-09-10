class_name PerformanceBaseline
extends RefCounted

func measure_world(world: Dictionary) -> Dictionary:
	var bytes := var_to_bytes(world).size()
	return {"serialized_bytes":bytes,"players":world.get("players", []).size(),"clubs":world.get("clubs", []).size(),"fixtures":world.get("fixtures", []).size(),"bytes_per_player":float(bytes)/maxf(1.0,float(world.get("players", []).size()))}

func benchmark(callable: Callable, iterations: int = 1) -> Dictionary:
	var count := maxi(1, iterations)
	var start := Time.get_ticks_usec()
	var last = null
	for _i in range(count):
		last = callable.call()
	var elapsed := Time.get_ticks_usec() - start
	return {"iterations":count,"total_usec":elapsed,"avg_usec":float(elapsed)/float(count),"last":last}

func compare(current: Dictionary, baseline: Dictionary, tolerance: float = 0.25) -> Dictionary:
	var current_avg := float(current.get("avg_usec", 0.0))
	var baseline_avg := maxf(float(baseline.get("avg_usec", current_avg)), 1.0)
	var ratio := current_avg / baseline_avg
	return {"ratio":ratio,"regression":ratio > 1.0 + maxf(0.0,tolerance)}
