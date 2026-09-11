class_name ModIntegration
extends RefCounted

const Models = preload("res://simulation/world/domain_models.gd")

func finalize(world: Dictionary) -> Dictionary:
	var added_fixtures := 0
	var season_year := int(world.get("season_year", 2026))
	world["fixtures"] = world.get("fixtures", [])
	var existing_competitions := {}
	for fixture in world.fixtures: existing_competitions[String(fixture.get("competition_id", ""))] = true
	for competition in world.get("competitions", []):
		if String(competition.get("competition_type", "league")) != "league": continue
		var id := String(competition.get("id", ""))
		if id == "" or existing_competitions.has(id): continue
		var clubs: Array = competition.get("club_ids", [])
		if clubs.size() < 2: continue
		if clubs.size() % 2 != 0:
			# Round-robin scheduling uses an explicit bye marker for odd-sized mod leagues.
			clubs = clubs.duplicate(); clubs.append("")
		var generated := _round_robin(id, clubs, season_year)
		world.fixtures.append_array(generated)
		added_fixtures += generated.size()
	return {"fixtures_added": added_fixtures}

func _round_robin(competition_id: String, input_club_ids: Array, season_year: int) -> Array:
	var teams := input_club_ids.duplicate()
	var fixtures: Array = []
	var count := teams.size()
	if count < 2 or count % 2 != 0: return fixtures
	for leg in range(2):
		var rotation := teams.duplicate()
		for round_index in range(count - 1):
			for pair_index in range(int(count / 2)):
				var a := String(rotation[pair_index]); var b := String(rotation[count - 1 - pair_index])
				if a == "" or b == "": continue
				var home := a if (round_index + pair_index + leg) % 2 == 0 else b
				var away := b if home == a else a
				var fixture_id := "fixture-mod-%s-%d-%d-%d-%d" % [competition_id, season_year, leg, round_index, pair_index]
				var fixture: Dictionary = Models.fixture(fixture_id, competition_id, leg * (count - 1) + round_index + 1, home, away)
				fixture["season_year"] = season_year
				fixtures.append(fixture)
			var fixed = rotation[0]
			var rotating: Array = rotation.slice(1)
			rotating.push_front(rotating.pop_back())
			rotation = [fixed]; rotation.append_array(rotating)
	return fixtures
