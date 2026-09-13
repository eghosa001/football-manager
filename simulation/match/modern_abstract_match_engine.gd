class_name ModernAbstractMatchEngine
extends "res://simulation/match/abstract_match_engine.gd"

# Modern senior competition baseline: up to five substitutions, but only three
# regulation-time substitution opportunities. Half-time is not modelled as a
# stoppage here, so AI changes are grouped into three in-play windows.
func _add_sub_plan(result: Array, side: String, squad: Array, lineup: Array, seed: int, key_base: int) -> void:
	var bench: Array = _bench(squad, lineup)
	var count: int = mini(5, mini(bench.size(), lineup.size()))
	if count <= 0: return
	var windows: Array = [60, 72, 82]
	var distribution: Array = _distribution(count)
	var used := 0
	for window_index in range(distribution.size()):
		var in_window := int(distribution[window_index])
		if in_window <= 0: continue
		var minute := int(windows[window_index]) + _rand_int(seed,key_base+window_index,-2,2)
		for slot in range(in_window):
			var index := used + slot
			if index >= count: break
			result.append({
				"minute":minute,
				"window":window_index+1,
				"side":side,
				"player_out":String(lineup[lineup.size()-1-index].id),
				"player_in":String(bench[index].id),
				"player":bench[index],
				"applied":false
			})
		used += in_window

func _distribution(count: int) -> Array:
	match count:
		1: return [1,0,0]
		2: return [1,1,0]
		3: return [1,1,1]
		4: return [2,1,1]
		_: return [2,2,1]
