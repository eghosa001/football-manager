class_name SeasonRunner
extends RefCounted

const MatchEngineClass = preload("res://simulation/match/abstract_match_engine.gd")
const LeagueTableClass = preload("res://simulation/competitions/league_table.gd")

var _match_engine = MatchEngineClass.new()

func play_next_fixture(world: Dictionary, competition_id: String, season_seed: int) -> Dictionary:
	for fixture in world.fixtures:
		if fixture.competition_id != competition_id or fixture.played:
			continue
		var match_seed: int = _fixture_seed(season_seed, fixture)
		var result: Dictionary = _match_engine.simulate_match(
			_find_club(world.clubs, fixture.home_club_id),
			_find_club(world.clubs, fixture.away_club_id),
			world.players,
			match_seed
		)
		_match_engine.apply_to_fixture(fixture, result)
		return {"fixture": fixture, "result": result, "match_seed": match_seed}
	return {}

func complete_competition(world: Dictionary, competition_id: String, season_seed: int) -> Dictionary:
	while true:
		var played: Dictionary = play_next_fixture(world, competition_id, season_seed)
		if played.is_empty():
			break
	return build_season_record(world, competition_id)

func build_season_record(world: Dictionary, competition_id: String) -> Dictionary:
	var competition: Dictionary = _find_competition(world.competitions, competition_id)
	var fixtures: Array = []
	for fixture in world.fixtures:
		if fixture.competition_id == competition_id:
			fixtures.append(fixture)
	var table: Array = LeagueTableClass.build(competition.club_ids, fixtures, competition.points_win, competition.points_draw)
	var complete := true
	for fixture in fixtures:
		if not fixture.played:
			complete = false
			break
	return {
		"competition_id": competition_id,
		"competition_name": competition.name,
		"season_start_year": 2026,
		"complete": complete,
		"fixture_count": fixtures.size(),
		"table": table,
		"champion_club_id": table[0].club_id if complete and not table.is_empty() else "",
	}

func _fixture_seed(season_seed: int, fixture: Dictionary) -> int:
	# Stable across save/reload because it depends only on persisted fixture identity.
	var hash_value: int = season_seed
	for character in String(fixture.id).to_utf8_buffer():
		hash_value = posmod(hash_value * 31 + int(character), 2_147_483_647)
	return hash_value if hash_value != 0 else 1

func _find_club(clubs: Array, club_id: String) -> Dictionary:
	for club in clubs:
		if club.id == club_id:
			return club
	assert(false, "Club not found: %s" % club_id)
	return {}

func _find_competition(competitions: Array, competition_id: String) -> Dictionary:
	for competition in competitions:
		if competition.id == competition_id:
			return competition
	assert(false, "Competition not found: %s" % competition_id)
	return {}
