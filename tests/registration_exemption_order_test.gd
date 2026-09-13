extends SceneTree

const RegistrationServiceClass = preload("res://simulation/competitions/registration_service.gd")

func _init() -> void:
	var service = RegistrationServiceClass.new()
	var players := [
		{"id":"u21","club_id":"club","country_id":"eng","age":19,"position":"MC","current_ability":80,"retired":false,"injured_days":0},
		{"id":"senior","club_id":"club","country_id":"eng","age":26,"position":"GK","current_ability":70,"retired":false,"injured_days":0},
	]
	var world := {"players":players,"registrations":{}}
	var competition := {"id":"comp","country_id":"eng","registration_rules":{"max_squad":1,"u21_exempt":true}}
	var result: Dictionary = service.register_squad(world,"club",competition,["u21","senior"],2026)
	assert(result.registered.size() == 2)
	assert("u21" in result.registered)
	assert("senior" in result.registered)
	assert(int(result.get("counted_squad_size",0)) == 1)
	assert(result.rejected.is_empty())
	print("[TEST] REGISTRATION EXEMPTION ORDER PASS")
	quit(0)
