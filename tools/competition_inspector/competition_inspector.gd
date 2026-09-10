class_name CompetitionInspector
extends RefCounted

func inspect(world: Dictionary, competition_id: String) -> Dictionary:
	var competition := _competition(world.get("competitions", []), competition_id)
	if competition.is_empty():
		return {"error":ERR_DOES_NOT_EXIST}
	var fixtures: Array = []
	var played := 0
	var unplayed := 0
	var club_counts := {}
	for fixture in world.get("fixtures", []):
		if String(fixture.get("competition_id", "")) != competition_id: continue
		fixtures.append(fixture)
		if bool(fixture.get("played", false)): played += 1
		else: unplayed += 1
		for club_id in [String(fixture.get("home_club_id", "")), String(fixture.get("away_club_id", ""))]:
			club_counts[club_id] = int(club_counts.get(club_id, 0)) + 1
	var expected_clubs: Array = competition.get("club_ids", [])
	var missing: Array = []
	for club_id in expected_clubs:
		if not club_counts.has(String(club_id)): missing.append(String(club_id))
	return {"competition":competition,"fixture_count":fixtures.size(),"played":played,"unplayed":unplayed,"club_fixture_counts":club_counts,"missing_clubs":missing,"complete":unplayed == 0 and not fixtures.is_empty()}

func duplicate_fixtures(world: Dictionary, competition_id: String) -> Array[String]:
	var seen := {}
	var duplicates: Array[String] = []
	for fixture in world.get("fixtures", []):
		if String(fixture.get("competition_id", "")) != competition_id: continue
		var pair := String(fixture.get("home_club_id", "")) + ">" + String(fixture.get("away_club_id", "")) + "@" + str(fixture.get("round", 0))
		if seen.has(pair): duplicates.append(String(fixture.get("id", "")))
		seen[pair] = true
	return duplicates

func _competition(competitions: Array, id: String) -> Dictionary:
	for competition in competitions:
		if String(competition.get("id", "")) == id: return competition
	return {}
