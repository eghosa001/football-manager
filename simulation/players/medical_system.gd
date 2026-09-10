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

func suffer_injury(player: Dictionary, seed: int, cause: String = "match") -> Dictionary:
	ensure_player(player)
	var key := _stable_key(String(player.get("id", "")) + cause + str(player.medical.history.size()))
	var template: Dictionary = INJURIES[int(SeededRngClass.value_for(seed, key) % INJURIES.size())]
	var days := int(template.min_days) + int(SeededRngClass.value_for(seed, key + 1) % (int(template.max_days) - int(template.min_days) + 1))
	var injury := {"name":String(template.name),"cause":cause,"days_total":days,"days_remaining":days,"recurrence":float(template.recurrence),"body_region":_body_region(String(template.name))}
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
	if float(current.days_remaining) <= 0.0:
		player.medical.current = {}
		player.injured_days = 0
		player.medical.match_fitness = 65.0
		return {"recovered":true,"available":true}
	return {"recovered":false,"available":false,"days_remaining":player.injured_days,"rehab_progress":player.medical.rehab_progress}

func availability(player: Dictionary) -> Dictionary:
	ensure_player(player)
	var current: Dictionary = player.medical.current
	return {"available":current.is_empty(),"injury":String(current.get("name", "")),"days_remaining":int(ceil(float(current.get("days_remaining", 0)))),"match_fitness":float(player.medical.match_fitness)}

func _body_region(name: String) -> String:
	if "hamstring" in name or "calf" in name or "groin" in name: return "lower_limb"
	if "ankle" in name or "knee" in name: return "joint"
	if "concussion" in name: return "head"
	return "other"

func _stable_key(text: String) -> int:
	var value := 53
	for character in text.to_utf8_buffer():
		value = posmod(value * 157 + int(character), 2_147_483_647)
	return value
