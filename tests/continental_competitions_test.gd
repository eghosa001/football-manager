extends SceneTree

func _init() -> void:
	var world: Dictionary = preload("res://data/launch_world_builder.gd").new().build(8181)
	var continental = preload("res://application/season/continental_competitions.gd").new()
	continental.prepare(world)
	var cups: Array = []
	for competition in world.competitions:
		if bool(competition.get("continental", false)): cups.append(competition)
	assert(cups.size() == 2)
	continental.prepare(world)
	assert(world.competitions.size() == 27)
	var knockout = preload("res://application/season/knockout_season.gd").new()
	knockout.initialize_all(world, 2026)
	_check_dates(world)
	for cup in cups:
		var count: int = cup.club_ids.size()
		while not bool(cup.knockout_bracket.complete):
			var last_date := ""
			for fixture in world.fixtures:
				if String(fixture.competition_id) != String(cup.id) or bool(fixture.played): continue
				fixture.played = true; fixture.home_goals = 1; fixture.away_goals = 0
				last_date = maxi_date(last_date, String(fixture.date))
			knockout.advance_ready(world, String(cup.id), last_date)
			_check_dates(world)
		assert(String(cup.champion_club_id) in cup.club_ids)
		assert(int(knockout.record(world, cup).fixture_count) == count - 1)
	# Qualification follows completed league tables, not reputation, after year one.
	var records: Array = []
	for competition in world.competitions:
		if String(competition.get("competition_type", "")) != "league" or int(competition.tier) != 1: continue
		var table: Array = []
		var ids: Array = competition.club_ids.duplicate(); ids.reverse()
		for id in ids: table.append({"club_id":id})
		records.append({"competition_id":competition.id,"table":table})
	continental.prepare(world, records)
	for cup in cups:
		for record in records:
			if String(record.table[0].club_id) in cup.club_ids:
				for row in record.table.slice(0, 4): assert(String(row.club_id) in cup.club_ids)
	print("[TEST] CONTINENTAL COMPETITIONS PASS")
	quit(0)

func maxi_date(a: String, b: String) -> String:
	return a if a > b else b

func _check_dates(world: Dictionary) -> void:
	var occupied := {}
	for fixture in world.fixtures:
		for club in [fixture.home_club_id, fixture.away_club_id]:
			var key := "%s:%s" % [club, fixture.date]
			assert(not occupied.has(key), "Club has overlapping fixtures: " + key)
			occupied[key] = true
