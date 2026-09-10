extends SceneTree

func _init() -> void:
	var world: Dictionary = preload("res://simulation/world/world_generator.gd").new().create_world(701, 1, 2, 25)
	var contracts = preload("res://simulation/staff/staff_contracts.gd").new()
	contracts.ensure_world(world)
	var recruitment = preload("res://simulation/staff/staff_recruitment.gd").new()
	var club: Dictionary = world.clubs[0]
	var candidates: Array = recruitment.candidates(world, String(club.id), "coach")
	assert(not candidates.is_empty())
	var candidate: Dictionary = candidates[0]
	club.cash = 100000000; club.wage_budget = 0
	var before: Dictionary = world.duplicate(true)
	assert(recruitment.hire(world, String(club.id), String(candidate.staff_id), int(candidate.weekly_wage), 2) == ERR_UNAVAILABLE)
	assert(world == before)
	club.wage_budget = 100000000
	var cash_before := int(club.cash)
	assert(recruitment.hire(world, String(club.id), String(candidate.staff_id), int(candidate.weekly_wage), 2) == OK)
	assert(int(club.cash) == cash_before - int(candidate.compensation))
	before = world.duplicate(true)
	assert(recruitment.hire(world, String(club.id), String(candidate.staff_id), int(candidate.weekly_wage), 2) == ERR_ALREADY_EXISTS)
	assert(world == before)
	assert(recruitment.fire(world, String(club.id), String(candidate.staff_id)) == OK)
	assert(recruitment.fire(world, String(club.id), String(candidate.staff_id)) == ERR_INVALID_PARAMETER)
	print("[TEST] STAFF RECRUITMENT SAFETY PASS")
	quit(0)
