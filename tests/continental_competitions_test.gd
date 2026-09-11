extends SceneTree

func _init() -> void:
	var world: Dictionary = preload("res://data/launch_world_builder.gd").new().build(8181)
	var continental = preload("res://application/season/continental_competitions.gd").new()
	continental.prepare(world)
	var cups: Array = []
	for competition in world.competitions:
		if bool(competition.get("continental", false)): cups.append(competition)
	# Base world: 5 regions covered (europe/africa/south_america) x3 tiers + Club World Cup.
	assert(cups.size() == 10)
	var cwc := 0
	var tiered := 0
	for cup in cups:
		if bool(cup.get("club_world_cup", false)): cwc += 1
		elif int(cup.get("continental_tier", 0)) >= 1: tiered += 1
	assert(cwc == 1)
	assert(tiered == 9)
	continental.prepare(world)
	assert(world.competitions.size() == 48)
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
	# Tiered qualification: champions-tier cups must include a table-top club
	# from their region; lower tiers must not duplicate the champions entrants.
	for cup in cups:
		if bool(cup.get("club_world_cup", false)):
			continue
		if int(cup.get("continental_tier", 1)) == 1:
			var region := String(cup.get("continental_region", ""))
			var tops: Array = []
			for record in records:
				var comp := _competition(world, String(record.get("competition_id", "")))
				if String(comp.get("country_id", "")) in preload("res://application/season/continental_competitions.gd").REGIONS.get(region, []):
					if not record.get("table", []).is_empty():
						tops.append(String(record.table[0].club_id))
			var hit := false
			for top in tops:
				if top in cup.get("club_ids", []): hit = true
			assert(hit, "Champions tier missing table-top qualifier for " + region)
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

func _competition(world: Dictionary, competition_id: String) -> Dictionary:
	for competition in world.get("competitions", []):
		if String(competition.get("id", "")) == competition_id: return competition
	return {}
