class_name MedicalSystem
extends RefCounted

const INJURIES := [
	{"name":"hamstring strain","min_days":7,"max_days":28,"recurrence":0.18},
	{"name":"ankle sprain","min_days":10,"max_days":35,"recurrence":0.12},
	{"name":"groin strain","min_days":6,"max_days":24,"recurrence":0.16},
	{"name":"knee ligament injury","min_days":60,"max_days":240,"recurrence":0.09},
	{"name":"calf strain","min_days":7,"max_days":30,"recurrence":0.15},
	{"name":"concussion","min_days":7,"max_days":21,"recurrence":0.04}
]

const SeededRngClass = preload("res://core/rng/seeded_rng.gd")

func ensure_player(player: Dictionary) -> void:
	player["medical"] = player.get("medical", {"current":{},"history":[],"rehab_progress":0.0,"match_fitness":100.0})

func injury_risk(player: Dictionary, context: Dictionary = {}) -> Dictionary:
	ensure_player(player)
	var hidden: Dictionary = player.get("hidden_attributes", {})
	var proneness := clampf(float(hidden.get("injury_proneness", 50)) / 50.0, 0.35, 2.0)
	var fatigue := clampf(float(context.get("fatigue", player.get("fatigue", 20))) / 100.0, 0.0, 1.0)
	var match_intensity := clampf(float(context.get("match_intensity", 0.6)), 0.0, 1.5)
	var training_load := clampf(float(context.get("training_load", 0.5)), 0.0, 1.5)
	var age := int(player.get("age", 25))
	var age_factor := 1.0 + maxf(0.0, float(age - 28)) * 0.035
	var surface := String(context.get("surface", "good"))
	var surface_factor := 1.0
	match surface:
		"poor": surface_factor = 1.28
		"wet": surface_factor = 1.12
		"hard": surface_factor = 1.16
		_: surface_factor = 1.0
	var recurrence_factor := 1.0
	var region := String(context.get("body_region", ""))
	for prior in player.medical.get("history", []):
		if region != "" and String(prior.get("body_region", "")) != region:
			continue
		recurrence_factor += float(prior.get("recurrence", 0.08)) * 0.25
	var base := float(context.get("base_risk", 0.004))
	var exposure := 0.55 + fatigue * 0.65 + match_intensity * 0.45 + training_load * 0.35
	var probability := clampf(base * proneness * age_factor * surface_factor * recurrence_factor * exposure, 0.001, 0.12)
	return {"probability":probability,"proneness_factor":proneness,"fatigue_factor":fatigue,"intensity_factor":match_intensity,"training_factor":training_load,"age_factor":age_factor,"surface_factor":surface_factor,"recurrence_factor":recurrence_factor}

func maybe_suffer_injury(player: Dictionary, seed: int, cause: String = "match", context: Dictionary = {}) -> Dictionary:
	var risk := injury_risk(player, context)
	var key := _stable_key(String(player.get("id", "")) + cause + str(player.medical.get("history", []).size()) + "risk")
	if SeededRngClass.unit_for(seed, key) >= float(risk.probability):
		return {"injured":false,"risk":risk}
	var injury := suffer_injury(player, seed, cause)
	injury["injured"] = true
	injury["risk"] = risk
	return injury

func suffer_injury(player: Dictionary, seed: int, cause: String = "match") -> Dictionary:
	ensure_player(player)
	var key := _stable_key(String(player.get("id", "")) + cause + str(player.medical.history.size()))
	var template: Dictionary = INJURIES[int(SeededRngClass.value_for(seed, key) % INJURIES.size())]
	var days := int(template.min_days) + int(SeededRngClass.value_for(seed, key + 1) % (int(template.max_days) - int(template.min_days) + 1))
	var injury := {
		"name":String(template.name),"cause":cause,"days_total":days,"days_remaining":days,"recurrence":float(template.recurrence),
		"body_region":_body_region(String(template.name)),"severity":_severity(days),"rehab_stage":"acute"
	}
	player.medical.current = injury
	player.medical.history.append(injury.duplicate(true))
	player.injured_days = days
	player.medical.rehab_progress = 0.0
	player.medical.match_fitness = minf(float(player.medical.match_fitness), 70.0)
	return injury

func advance_day(player: Dictionary, physio_quality: int = 50, rehab_intensity: float = 0.6) -> Dictionary:
	ensure_player(player)
	var current: Dictionary = player.medical.current
	if current.is_empty():
		player.medical.match_fitness = minf(100.0, float(player.medical.match_fitness) + 1.5)
		return {"recovered":false,"available":true}
	var recovery_rate := 1.0 + clampf(float(physio_quality) / 200.0, 0.0, 0.5)
	var recovered_days := maxf(0.5, recovery_rate * clampf(rehab_intensity, 0.25, 1.0))
	current.days_remaining = maxf(0.0, float(current.days_remaining) - recovered_days)
	player.injured_days = int(ceil(float(current.days_remaining)))
	player.medical.rehab_progress = clampf(1.0 - float(current.days_remaining) / maxf(float(current.days_total), 1.0), 0.0, 1.0)
	current.rehab_stage = _rehab_stage(float(player.medical.rehab_progress))
	if float(current.days_remaining) <= 0.0:
		player.medical.current = {}
		player.injured_days = 0
		player.medical.match_fitness = 65.0
		return {"recovered":true,"available":true,"rehab_stage":"return_to_play"}
	return {"recovered":false,"available":false,"days_remaining":player.injured_days,"rehab_progress":player.medical.rehab_progress,"rehab_stage":String(current.rehab_stage)}

func availability(player: Dictionary, physio_quality: int = 50) -> Dictionary:
	ensure_player(player)
	var current: Dictionary = player.medical.current
	if current.is_empty():
		return {"available":true,"injury":"","days_remaining":0,"estimated_min_days":0,"estimated_max_days":0,"estimated_range":"","match_fitness":float(player.medical.match_fitness),"rehab_stage":"available"}
	var remaining := int(ceil(float(current.get("days_remaining", 0))))
	# Medical staff never expose the exact internal recovery timer. Better staff
	# narrow the estimate around the hidden canonical remaining duration.
	var uncertainty := clampf(0.42 - float(clampi(physio_quality, 0, 100)) / 330.0, 0.08, 0.42)
	var min_days := maxi(1, int(floor(float(remaining) * (1.0 - uncertainty))))
	var max_days := maxi(min_days + 1, int(ceil(float(remaining) * (1.0 + uncertainty))))
	return {
		"available":false,"injury":String(current.get("name", "")),"days_remaining":int(round((min_days + max_days) / 2.0)),
		"estimated_min_days":min_days,"estimated_max_days":max_days,"estimated_range":"%d–%d days" % [min_days,max_days],
		"match_fitness":float(player.medical.match_fitness),"rehab_stage":String(current.get("rehab_stage", _rehab_stage(float(player.medical.rehab_progress)))),
		"severity":String(current.get("severity", "moderate")),"recurrence":float(current.get("recurrence",0.0))
	}

func _severity(days: int) -> String:
	if days <= 10:
		return "minor"
	if days <= 35:
		return "moderate"
	if days <= 90:
		return "serious"
	return "major"

func _rehab_stage(progress: float) -> String:
	if progress < 0.20:
		return "acute"
	if progress < 0.55:
		return "rehabilitation"
	if progress < 0.82:
		return "conditioning"
	return "return_to_play"

func _body_region(name: String) -> String:
	if "hamstring" in name or "calf" in name or "groin" in name:
		return "lower_limb"
	if "ankle" in name or "knee" in name:
		return "joint"
	if "concussion" in name:
		return "head"
	return "other"

func _stable_key(text: String) -> int:
	var value := 53
	for character in text.to_utf8_buffer():
		value = posmod(value * 157 + int(character), 2_147_483_647)
	return value
