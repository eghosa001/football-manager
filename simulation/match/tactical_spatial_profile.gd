class_name TacticalSpatialProfile
extends RefCounted

# Maps manager instructions to continuous movement parameters.
# Behaviour changes first; statistics change only as a consequence.
# No direct stat multipliers live here.

static func for_tactic(tactic: Dictionary) -> Dictionary:
	var instructions: Dictionary = tactic.get("instructions", {})
	var oop: Dictionary = instructions.get("out_of_possession", {})
	var ip: Dictionary = instructions.get("in_possession", {})
	var tr: Dictionary = instructions.get("transition", {})
	var mentality := String(tactic.get("mentality", "balanced"))
	var tempo := String(tactic.get("tempo", "standard"))
	var pressing := String(tactic.get("pressing", "standard"))
	var familiarity := clampf(float(tactic.get("familiarity", 50.0)), 0.0, 100.0)
	var execution := 0.82 + familiarity / 550.0

	var line_height := 0.5
	match String(oop.get("defensive_line", "standard")):
		"higher": line_height = 0.62
		"much_higher": line_height = 0.68
		"lower": line_height = 0.40
		"much_lower": line_height = 0.34
		_: line_height = 0.5
	if mentality in ["positive", "attacking"]:
		line_height += 0.04
	elif mentality in ["cautious", "very_cautious"]:
		line_height -= 0.04

	var width := 0.5
	match String(ip.get("width", "standard")):
		"wide": width = 0.72
		"narrow": width = 0.32
		_: width = 0.5
	match String(oop.get("defensive_width", "standard")):
		"wide": width = maxf(width, 0.62)
		"narrow": width = minf(width, 0.38)
		_: pass

	var trigger := 8.0
	var closing := 4.2
	match pressing:
		"low":
			trigger = 5.5
			closing = 3.4
		"standard":
			trigger = 8.0
			closing = 4.2
		"high":
			trigger = 11.5
			closing = 5.2
		"very_high":
			trigger = 14.0
			closing = 5.9
		_: pass
	match String(oop.get("pressing_triggers", pressing)):
		"low": trigger = minf(trigger, 6.0)
		"high": trigger = maxf(trigger, 10.5)
		"very_high": trigger = maxf(trigger, 13.0)
		_: pass
	if bool(tr.get("counter_press", false)):
		trigger += 1.5
		closing += 0.4
	if bool(tr.get("regroup", false)):
		trigger -= 2.0
		closing -= 0.5

	var decision_interval := 1.0
	match tempo:
		"very_low": decision_interval = 1.45
		"low": decision_interval = 1.2
		"standard": decision_interval = 1.0
		"high": decision_interval = 0.8
		"very_high": decision_interval = 0.65
		_: pass

	var directness := 0.5
	match String(ip.get("passing_directness", "standard")):
		"shorter": directness = 0.25
		"more_direct": directness = 0.78
		_: directness = 0.5

	return {
		"line_height": clampf(line_height, 0.3, 0.72),
		"width": clampf(width, 0.28, 0.78),
		"press_trigger": trigger,
		"closing_speed": maxf(2.5, closing),
		"decision_interval": decision_interval,
		"directness": directness,
		"overlap_left": bool(ip.get("overlap_left", false)),
		"overlap_right": bool(ip.get("overlap_right", false)),
		"counter": bool(tr.get("counter", false)),
		"counter_press": bool(tr.get("counter_press", false)),
		"offside_trap": bool(oop.get("offside_trap", false)),
		"marking": String(oop.get("marking", "zonal")),
		"execution": execution,
	}
