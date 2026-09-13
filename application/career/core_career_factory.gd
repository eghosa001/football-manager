class_name CoreCareerFactory
extends RefCounted

const LaunchWorldBuilder = preload("res://data/launch_world_builder.gd")

func create(session, manager_name: String, club_id: String, selected_country_ids: Array, seed: int = 12345) -> Dictionary:
	var world: Dictionary = LaunchWorldBuilder.new().build(seed, 0, 25, false, selected_country_ids)
	if world.is_empty():
		return {"error": ERR_CANT_CREATE, "message": "Unable to build selected leagues."}
	var club_found := false
	for club in world.get("clubs", []):
		if String(club.get("id", "")) == club_id:
			club_found = true
			break
	if not club_found:
		return {"error": ERR_DOES_NOT_EXIST, "message": "Selected club is not in the active leagues."}
	session.set("save_path", "")
	session.set("seed", seed)
	session.set("world", world)
	session.call("_initialize_world", true)
	session.set("managed_club_id", club_id)
	var manager := {
		"id": "human-manager",
		"name": manager_name.strip_edges() if manager_name.strip_edges() != "" else "Manager",
		"club_id": club_id,
		"reputation": 35,
		"created_year": int(world.get("season_year", 2026)),
		"career_history": [],
	}
	session.set("manager", manager)
	world["human_manager"] = manager.duplicate(true)
	world["day_index"] = int(world.get("day_index", 0))
	world["staff_responsibilities"] = {
		"training": "user",
		"medical": "staff",
		"tactics": "user",
		"recruitment": "user",
	}
	session.set("history", [])
	return session.call("snapshot")
