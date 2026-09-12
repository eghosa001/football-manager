class_name PhysicalModel
extends RefCounted

# Continuous physical model: distance, sprint load, pressing load,
# recovery during stoppages, role differences, injury-risk coupling.
# All deterministic; no wall-clock dependence.

const MIN_ENERGY := 0.35
const SPRINT_SPEED := 7.0
const HIGH_INTENSITY := 5.2

static func initial_load() -> Dictionary:
	return {"distance": 0.0, "sprint_distance": 0.0, "high_intensity_actions": 0, "pressing_load": 0.0, "energy": 1.0}

static func update(load: Dictionary, distance: float, speed: float, pressing: bool, player: Dictionary, stoppage: bool) -> Dictionary:
	var stamina := float(player.get("attributes", {}).get("stamina", 50))
	var work_rate := float(player.get("attributes", {}).get("work_rate", 50))
	var resilience := 0.65 + stamina / 180.0
	var effort := 0.00045 + work_rate / 500000.0
	load["distance"] = float(load.get("distance", 0.0)) + distance
	if speed >= SPRINT_SPEED:
		load["sprint_distance"] = float(load.get("sprint_distance", 0.0)) + distance
	if speed >= HIGH_INTENSITY:
		load["high_intensity_actions"] = int(load.get("high_intensity_actions", 0)) + 1
	if pressing:
		load["pressing_load"] = float(load.get("pressing_load", 0.0)) + distance * 1.4
	var drain := distance * effort / resilience
	if pressing:
		drain *= 1.35
	if stoppage:
		# Recovery during stoppages: small rebound, bounded.
		load["energy"] = clampf(float(load.get("energy", 1.0)) - drain + 0.004, MIN_ENERGY, 1.0)
	else:
		load["energy"] = clampf(float(load.get("energy", 1.0)) - drain, MIN_ENERGY, 1.0)
	return load

static func energy_factor(load: Dictionary) -> float:
	return clampf(float(load.get("energy", 1.0)), MIN_ENERGY, 1.0)

static func injury_risk(load: Dictionary, player: Dictionary, congestion: float = 1.0, context: Dictionary = {}) -> float:
	var proneness := float(player.get("hidden_attributes", {}).get("injury_proneness", 50))
	var base := 0.002 + proneness / 22000.0
	var fatigue := 1.0 - energy_factor(load)
	var sprint := float(load.get("sprint_distance", 0.0)) / 900.0
	var age := int(player.get("age", 25))
	var age_factor := 1.0 + maxf(0.0, float(age - 28)) * 0.045
	var surface_factor := 1.0
	match String(context.get("surface", "good")):
		"poor":
			surface_factor = 1.28
		"wet":
			surface_factor = 1.12
		"hard":
			surface_factor = 1.16
	var recurrence := 1.0
	var history: Array = player.get("injury_history", player.get("medical", {}).get("history", []))
	var region := String(context.get("body_region", ""))
	for prior in history.slice(maxi(0, history.size() - 4)):
		if region != "" and String(prior.get("body_region", "")) != region:
			continue
		recurrence += float(prior.get("recurrence", 0.08)) * 0.30
	var training_factor := 1.0 + clampf(float(context.get("training_load", 0.0)), 0.0, 1.0) * 0.25
	return clampf(base * age_factor * surface_factor * recurrence * training_factor + fatigue * 0.012 + sprint * 0.006 * congestion, 0.001, 0.06)

static func post_match_recovery(load: Dictionary, player: Dictionary, rest_days: int) -> Dictionary:
	var recovery := clampi(rest_days, 0, 7) * 0.09
	player["fitness"] = clampi(int(player.get("fitness", 90)) + int(round(recovery * 40.0)), 0, 100)
	player["match_load"] = {"distance": load.get("distance", 0.0), "sprint_distance": load.get("sprint_distance", 0.0)}
	return player

static func apply_substitution_effect(lineup: Array, outgoing_id: String, incoming: Dictionary) -> Array:
	var result: Array = []
	for player in lineup:
		if String(player.get("id", "")) == outgoing_id:
			result.append(incoming)
		else:
			result.append(player)
	return result
