extends SceneTree

const Registration = preload("res://simulation/competitions/registration_service.gd")

func _init() -> void:
	var service = Registration.new()
	var player := {"id":"p1","club_id":"a","country_id":"nga","age":25,"position":"GK"}
	var competition := {"id":"league","country_id":"nga","club_ids":["a"],"registration_rules":{}}
	var world := {"players":[player],"competitions":[competition]}
	var result: Dictionary = service.register_squad(world, "a", competition, ["p1","p1"], 2026)
	assert(result.registered == ["p1"])
	assert(result.goalkeepers == 1)
	assert(result.rejected[0].reason == "duplicate")
	var expected: Dictionary = world.registrations.duplicate(true)
	service.auto_register_world(world, 2026)
	assert(world.registrations == expected)
	player.club_id = "b"
	assert(service.registered_players(world, "a", "league", 2026).is_empty())
	player.club_id = "a"
	player.retired = true
	assert(service.registered_players(world, "a", "league", 2026).is_empty())
	print("[TEST] REGISTRATION SAFETY PASS")
	quit(0)
