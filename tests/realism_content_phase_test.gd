extends SceneTree

# Realism + Content + UI Completion phase gate.
# Covers: England default / Spain featured / expanded database; domestic cups,
# three-tier continentals, Club World Cup, international championships + World
# Cup qualification; match-factor causality with seeded determinism; save
# migration; multi-season competition/qualification stability.

func _init() -> void:
	_test_database_defaults()
	_test_competition_formats()
	_test_international_pathways()
	_test_match_factor_sensitivity()
	_test_match_determinism()
	_test_save_migration()
	_test_multi_season_qualification()
	print("[TEST] REALISM CONTENT PHASE PASS")
	quit(0)

func _test_database_defaults() -> void:
	var loader = preload("res://data/database_loader.gd").new()
	var data: Dictionary = loader.load_seed("res://data/seed/launch_database.json", false)
	assert(not data.is_empty())
	assert(loader.validate_seed(data).is_empty())
	assert(loader.default_country_id(data) == "eng")
	var featured: Array = loader.featured_country_ids(data)
	assert("eng" in featured and "esp" in featured)
	assert(String(data.countries[0].id) == "eng")
	assert(String(data.countries[1].id) == "esp")
	assert(data.countries.size() >= 12)
	var catalog: Dictionary = preload("res://data/launch_catalog.gd").new().build(0, false)
	assert(String(catalog.get("default_country_id", "")) == "eng")
	assert(catalog.get("countries", []).size() >= 12)
	assert(catalog.get("clubs", []).size() >= 400)
	var eng_clubs: Array = preload("res://data/launch_catalog.gd").new().clubs_for_country(catalog, "eng")
	var esp_clubs: Array = preload("res://data/launch_catalog.gd").new().clubs_for_country(catalog, "esp")
	assert(eng_clubs.size() >= 40 and esp_clubs.size() >= 30)
	assert(String(preload("res://data/launch_catalog.gd").new().default_club_id(catalog)).begins_with("eng-"))
	var expanded: Dictionary = preload("res://data/launch_catalog.gd").new().build(0, true)
	assert(expanded.get("countries", []).size() == 24)
	assert(expanded.get("clubs", []).size() == 908)

func _test_competition_formats() -> void:
	var world: Dictionary = preload("res://data/launch_world_builder.gd").new().build(4242)
	assert(String(world.get("default_country_id", "")) == "eng")
	# Domestic leagues + cups (England has FA Cup + League Cup).
	var leagues := 0
	var cups := 0
	for competition in world.get("competitions", []):
		if String(competition.get("competition_type", "")) == "league": leagues += 1
		else: cups += 1
	assert(leagues == 25)
	assert(cups >= 13)
	var has_league_cup := false
	for competition in world.get("competitions", []):
		if String(competition.get("id", "")) == "eng-league-cup": has_league_cup = true
	assert(has_league_cup)
	# Three-tier continentals + Club World Cup.
	preload("res://application/season/continental_competitions.gd").new().prepare(world)
	var tiers := {}
	var cwc := 0
	for competition in world.get("competitions", []):
		if bool(competition.get("club_world_cup", false)): cwc += 1
		if bool(competition.get("continental", false)) and not bool(competition.get("club_world_cup", false)):
			tiers[int(competition.get("continental_tier", 0))] = true
	assert(cwc == 1)
	assert(tiers.has(1) and tiers.has(2) and tiers.has(3))
	# Knockout brackets initialize for every cup without date conflicts.
	preload("res://application/season/knockout_season.gd").new().initialize_all(world, 2026)
	var occupied := {}
	for fixture in world.get("fixtures", []):
		for club in [fixture.get("home_club_id", ""), fixture.get("away_club_id", "")]:
			var key := "%s:%s" % [club, String(fixture.get("date", ""))]
			assert(not occupied.has(key))
			occupied[key] = true

func _test_international_pathways() -> void:
	var world: Dictionary = preload("res://data/launch_world_builder.gd").new().build(777)
	var football = preload("res://simulation/competitions/international_football.gd").new()
	football.ensure_world(world)
	assert(football.region_for_country("eng") == "europe")
	assert(football.region_for_country("nga") == "africa")
	assert(football.continental_championship_name("europe") != "")
	var euro: Dictionary = football.create_continental_qualifying(world, "europe", "continental-europe-2026", 8)
	assert(String(euro.get("kind", "")) == "continental_qualifying")
	assert(euro.get("fixtures", []).size() > 0)
	var wc: Dictionary = football.create_world_cup_qualifying(world, "world-cup-2026", 8)
	assert(String(wc.get("kind", "")) == "world_cup_qualifying")
	assert(wc.get("fixtures", []).size() > 0)
	var qualified: Array = football.qualify_from_groups(euro.get("groups", []), euro.get("fixtures", []), 4)
	assert(qualified.size() <= 4)
	# Full international year: continentals + legacy cycle, deterministic.
	var result: Dictionary = preload("res://application/season/international_season.gd").new().run_year(world, 2026, 999)
	assert(result.has("continentals") and result.has("world_cup"))
	assert(not result.get("continentals", []).is_empty())
	assert(String(result.get("champion", "")) != "" or not result.get("qualified", []).is_empty())

func _test_match_factor_sensitivity() -> void:
	var engine = preload("res://simulation/match/abstract_match_engine.gd").new()
	var factors_lib = preload("res://simulation/match/match_factors.gd").new()
	var home := {"id": "home", "name": "Home", "country_id": "eng", "reputation": 60, "stadium_capacity": 50000, "form_points": 7.5, "manager_ability": 60, "tactic": {"formation": "4-3-3", "mentality": "balanced", "tempo": "standard", "pressing": "standard", "familiarity": 70.0}}
	var away := {"id": "away", "name": "Away", "country_id": "esp", "reputation": 60, "stadium_capacity": 20000, "form_points": 7.5, "manager_ability": 60, "tactic": {"formation": "4-3-3", "mentality": "balanced", "tempo": "standard", "pressing": "standard", "familiarity": 70.0}}
	var players := _squad("home", 65, 70) + _squad("away", 65, 70)
	var base := factors_lib.breakdown(home, away, players, {"is_home": true, "importance": 0.5})
	# Deterministic causal proof: each factor moves total_home_edge the right way.
	assert(factors_lib.breakdown(_with(home, {"form_points": 15.0}), away, players, {"is_home": true, "importance": 0.5}).total_home_edge > base.total_home_edge + 0.3, "form should help")
	assert(factors_lib.breakdown(home, _with(away, {"form_points": 15.0}), players, {"is_home": true, "importance": 0.5}).total_home_edge < base.total_home_edge - 0.3, "away form should hurt")
	assert(factors_lib.breakdown(_with(home, {"manager_ability": 90.0}), away, players, {"is_home": true, "importance": 0.5}).total_home_edge > base.total_home_edge + 0.05, "manager ability should help")
	var counter_away := _with(away, {"tactic": {"formation": "5-3-2", "mentality": "balanced", "tempo": "standard", "pressing": "standard", "familiarity": 70.0}})
	assert(factors_lib.breakdown(home, counter_away, players, {"is_home": true, "importance": 0.5}).total_home_edge < base.total_home_edge - 0.05, "tactical counter should hurt")
	var fit_players := _squad("home", 65, 30) + _squad("away", 65, 95)
	assert(factors_lib.breakdown(home, away, fit_players, {"is_home": true, "importance": 0.5}).total_home_edge < base.total_home_edge - 0.2, "low fitness should hurt")
	var strong_players := _squad("home", 85, 90) + _squad("away", 45, 90)
	assert(factors_lib.breakdown(home, away, strong_players, {"is_home": true, "importance": 0.5}).team_quality > base.team_quality + 10.0, "team quality should dominate")
	# Seeded outcomes still respond to the dominant factor over many matches.
	var base_goals := _avg_goals(engine, home, away, players, 50, 40)
	var strong_goals := _avg_goals(engine, home, away, strong_players, 50, 40)
	assert(strong_goals > base_goals + 0.8, "team quality must change outcomes")
	var home_context_goals := _avg_goals(engine, home, away, players, 50, 40)
	assert(home_context_goals > -3.0 and home_context_goals < 3.0, "sanity bounds")
	# Breakdown exposes every required causal weight.
	var factors: Dictionary = factors_lib.breakdown(home, away, players, {"is_home": true, "importance": 0.9})
	for key in ["team_quality", "form", "home_advantage", "morale", "manager_ability", "tactical_matchup", "fitness_availability", "pressure", "total_home_edge"]:
		assert(factors.has(key), "missing factor: " + key)

func _test_match_determinism() -> void:
	var engine = preload("res://simulation/match/abstract_match_engine.gd").new()
	var home := {"id": "home", "name": "Home", "country_id": "eng", "reputation": 60, "form_points": 9.0, "manager_ability": 65, "tactic": {"formation": "4-3-3", "mentality": "positive", "tempo": "high", "pressing": "high", "familiarity": 80.0}}
	var away := {"id": "away", "name": "Away", "country_id": "esp", "reputation": 58, "form_points": 6.0, "manager_ability": 55, "tactic": {"formation": "4-4-2", "mentality": "cautious", "tempo": "low", "pressing": "low", "familiarity": 60.0}}
	var players := _squad("home", 68, 80) + _squad("away", 64, 75)
	var first: Dictionary = engine.simulate_match(home, away, players, 123456, {"is_home": true, "importance": 0.9})
	var second: Dictionary = engine.simulate_match(home, away, players, 123456, {"is_home": true, "importance": 0.9})
	assert(first.home_goals == second.home_goals and first.away_goals == second.away_goals)
	assert(str(first.events) == str(second.events))
	assert(first.factors.total_home_edge == second.factors.total_home_edge)

func _test_save_migration() -> void:
	var store = preload("res://persistence/save_store.gd").new()
	assert(store.CURRENT_SCHEMA_VERSION == 4)
	var world: Dictionary = preload("res://data/launch_world_builder.gd").new().build(31337)
	# Simulate a legacy v3 save missing the new realism fields.
	for club in world.get("clubs", []):
		club.erase("recent_results"); club.erase("form_points"); club.erase("manager_ability")
	world.erase("default_country_id"); world.erase("featured_country_ids")
	var payload := {"schema_version": 3, "world": world, "history": []}
	var migrated: Dictionary = store._migrate(payload)
	assert(int(migrated.get("schema_version", 0)) == 4)
	for club in migrated.world.get("clubs", []):
		assert(club.has("form_points") and club.has("manager_ability") and club.has("recent_results"))
	assert(String(migrated.world.get("default_country_id", "")) == "eng")

func _test_multi_season_qualification() -> void:
	var world: Dictionary = preload("res://data/launch_world_builder.gd").new().build(9001)
	var continental = preload("res://application/season/continental_competitions.gd").new()
	continental.prepare(world)
	var before := {}
	for competition in world.get("competitions", []):
		if bool(competition.get("continental", false)):
			before[String(competition.get("id", ""))] = competition.get("club_ids", []).duplicate()
	# Year two: reversed tables must change qualification (tables, not reputation).
	var records: Array = []
	for competition in world.get("competitions", []):
		if String(competition.get("competition_type", "")) != "league" or int(competition.get("tier", 1)) != 1: continue
		var ids: Array = competition.get("club_ids", []).duplicate()
		ids.reverse()
		var table: Array = []
		for id in ids: table.append({"club_id": id})
		records.append({"competition_id": String(competition.get("id", "")), "table": table})
	continental.prepare(world, records)
	var changed := false
	for competition in world.get("competitions", []):
		if not bool(competition.get("continental", false)): continue
		var key := String(competition.get("id", ""))
		if before.has(key) and str(before[key]) != str(competition.get("club_ids", [])): changed = true
	assert(changed, "qualification must follow league tables across seasons")
	# Club World Cup refreshes from champions-tier winners.
	for competition in world.get("competitions", []):
		if String(competition.get("id", "")).ends_with("-champions") and bool(competition.get("continental", false)):
			var ids: Array = competition.get("club_ids", [])
			if not ids.is_empty(): competition["champion_club_id"] = String(ids[0])
	var cwc: Dictionary = continental.refresh_club_world_cup(world)
	assert(not cwc.get("club_ids", []).is_empty())

func _squad(club_id: String, ability: int, fitness: int) -> Array:
	var result: Array = []
	var positions := ["GK", "DR", "DC", "DC", "DL", "DM", "MC", "MC", "AMR", "AML", "ST", "MC", "ST", "DC", "GK"]
	for i in range(15):
		result.append({"id": "p-%s-%02d" % [club_id, i], "club_id": club_id, "position": positions[i % positions.size()], "current_ability": ability, "fitness": fitness, "morale": 65, "injured_days": 0, "retired": false})
	return result

func _with(club: Dictionary, overrides: Dictionary) -> Dictionary:
	var copy := club.duplicate(true)
	for key in overrides.keys(): copy[key] = overrides[key]
	return copy

func _avg_goals(engine: RefCounted, home: Dictionary, away: Dictionary, players: Array, seed_base: int, count: int) -> float:
	var total := 0.0
	for i in range(count):
		var result: Dictionary = engine.simulate_match(home, away, players, seed_base + i * 7919, {"is_home": true, "importance": 0.5})
		total += float(result.home_goals) - float(result.away_goals)
	return total / float(maxi(1, count))
