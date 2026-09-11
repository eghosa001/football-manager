class_name MatchViewModes
extends RefCounted

const MODES := ["Full", "Comprehensive", "Extended", "Key", "Goals", "Instant"]

func filtered(result: Dictionary, mode: String) -> Dictionary:
	var copy := result.duplicate(true)
	var spatial: Dictionary = copy.get("spatial", {})
	var frames: Array = spatial.get("frames", [])
	if frames.is_empty() or mode == "Full": return copy
	var selected: Array = []
	match mode:
		"Comprehensive":
			selected = _stride(frames, 2)
		"Extended":
			selected = _event_windows(frames, copy.get("events", []), ["shot","goal","card","corner","free_kick","substitution"], 3, 5)
			if selected.size() < 12: selected = _stride(frames, 4)
		"Key":
			selected = _event_windows(frames, copy.get("events", []), ["shot","goal","card","substitution"], 2, 3)
		"Goals":
			selected = _event_windows(frames, copy.get("events", []), ["goal"], 2, 4)
			if selected.is_empty(): selected = [frames.back()]
		"Instant":
			selected = [frames.back()]
		_:
			selected = frames.duplicate(true)
	spatial["frames"] = selected
	spatial["view_mode"] = mode
	copy["spatial"] = spatial
	return copy

func _stride(frames: Array, step: int) -> Array:
	var out: Array = []
	for i in range(0, frames.size(), maxi(1, step)): out.append(frames[i])
	if not frames.is_empty() and (out.is_empty() or out.back() != frames.back()): out.append(frames.back())
	return out

func _event_windows(frames: Array, events: Array, types: Array, before: int, after: int) -> Array:
	var keep := {}
	for event in events:
		if String(event.get("type", "")) not in types: continue
		var minute := float(event.get("minute", 0.0))
		var closest := _closest_frame(frames, minute)
		for i in range(maxi(0, closest-before), mini(frames.size(), closest+after+1)): keep[i] = true
	var indices: Array = keep.keys(); indices.sort()
	var out: Array = []
	for i in indices: out.append(frames[int(i)])
	return out

func _closest_frame(frames: Array, minute: float) -> int:
	var best := 0
	var distance := INF
	for i in range(frames.size()):
		var d := absf(float(frames[i].get("minute", 0.0)) - minute)
		if d < distance: distance = d; best = i
	return best
