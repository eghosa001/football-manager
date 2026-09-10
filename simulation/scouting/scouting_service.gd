class_name ScoutingService
extends RefCounted

const SeededRngClass = preload("res://core/rng/seeded_rng.gd")

func ensure_world(world: Dictionary) -> void:
	world["scouting_knowledge"] = world.get("scouting_knowledge", {})
	world["scout_assignments"] = world.get("scout_assignments", [])

func assign_scout(world: Dictionary, scout_id: String, target_type: String, target_id: String, start_day: int = 0) -> Dictionary:
	ensure_world(world)
	var assignment := {"id":"assignment-%s-%s" % [scout_id, target_id], "scout_id":scout_id, "target_type":target_type, "target_id":target_id, "start_day":start_day, "progress":0.0, "complete":false}
	world.scout_assignments.append(assignment)
	return assignment

func advance_assignment(world: Dictionary, assignment: Dictionary, days: int, scout_ability: int, seed: int) -> Dictionary:
	ensure_world(world)
	assignment.progress = clampf(float(assignment.get("progress", 0.0)) + days * (0.6 + scout_ability / 100.0), 0.0, 100.0)
	assignment.complete = float(assignment.progress) >= 100.0
	if assignment.complete and String(assignment.target_type) == "player":
		world.scouting_knowledge[String(assignment.target_id)] = maxf(float(world.scouting_knowledge.get(String(assignment.target_id), 0.0)), clampf(scout_ability / 100.0, 0.15, 1.0))
	return assignment

func player_report(world: Dictionary, player: Dictionary, observer_quality: int, seed: int) -> Dictionary:
	ensure_world(world)
	var knowledge: float = clampf(maxf(float(world.scouting_knowledge.get(String(player.id), 0.0)), observer_quality / 100.0 * 0.5), 0.0, 1.0)
	var attrs: Dictionary = player.get("attributes", {})
	var visible := {}
	for name in attrs.keys():
		var actual: int = int(attrs[name])
		var uncertainty: int = int(round((1.0 - knowledge) * 12.0))
		var noise: int = int(SeededRngClass.value_for(seed, _stable_key(String(player.id) + String(name))) % (uncertainty * 2 + 1)) - uncertainty if uncertainty > 0 else 0
		var center := clampi(actual + noise, 1, 100)
		visible[name] = {"min":clampi(center - uncertainty, 1, 100), "max":clampi(center + uncertainty, 1, 100), "exact":actual if knowledge >= 0.95 else null}
	return {"player_id":String(player.id), "knowledge":knowledge, "attributes":visible, "ability_estimate":_range(int(player.get("current_ability",50)), knowledge), "potential_estimate":_range(int(player.get("potential",50)), knowledge)}

func _range(value: int, knowledge: float) -> Dictionary:
	var spread := int(round((1.0 - knowledge) * 20.0))
	return {"min":clampi(value-spread,1,100), "max":clampi(value+spread,1,100)}

func _stable_key(text: String) -> int:
	var value := 29
	for character in text.to_utf8_buffer():
		value = posmod(value * 139 + int(character), 2_147_483_647)
	return value
