class_name InternationalSeason
extends RefCounted

const InternationalClass = preload("res://simulation/competitions/international_football.gd")
const GroupStageClass = preload("res://simulation/competitions/group_stage.gd")
const KnockoutClass = preload("res://simulation/competitions/knockout_competition.gd")
const AbstractEngineClass = preload("res://simulation/match/abstract_match_engine.gd")

var _international = InternationalClass.new()
var _engine = AbstractEngineClass.new()

func run_year(world: Dictionary, year: int, seed: int) -> Dictionary:
	_international.ensure_world(world)
	var countries: Array = world.get("countries", [])
	if countries.size() < 2:
		return {"year":year,"callups":[],"qualifying":{},"qualified":[],"champion":""}
	var callups: Array = []
	for country in countries:
		callups.append(_international.register_callups(world, String(country.get("id", "")), "international-%d" % year, 23))
	var country_ids: Array = []
	for country in countries: country_ids.append(String(country.get("id", "")))
	var group_count := maxi(1, int(ceil(float(country_ids.size()) / 4.0)))
	var cycle: Dictionary = _international.create_qualifying_cycle(world, "international-%d" % year, group_count)
	for i in range(cycle.fixtures.size()):
		var fixture: Dictionary = cycle.fixtures[i]
		var result := _simulate_national_match(world, String(fixture.home_club_id), String(fixture.away_club_id), seed + i * 997)
		fixture.played = true
		fixture.home_goals = int(result.home_goals)
		fixture.away_goals = int(result.away_goals)
		fixture["result"] = result
	var qualified: Array = GroupStageClass.new().qualifiers(cycle.groups, cycle.fixtures, 2)
	cycle.qualified = qualified.duplicate()
	cycle.stage = "knockout"
	var bracket: Dictionary = KnockoutClass.new().create_bracket(qualified, seed + 50_000)
	var knockout_results: Array = []
	var round_counter := 0
	while not bool(bracket.get("complete", false)) and round_counter < 8:
		var results: Array = []
		for i in range(bracket.matches.size()):
			var pairing: Dictionary = bracket.matches[i]
			var home := String(pairing.home); var away := String(pairing.away)
			if home == "" or away == "":
				results.append({})
				continue
			var result := _simulate_national_match(world, home, away, seed + 70_000 + round_counter * 1000 + i * 31)
			var row := {"home_goals":int(result.home_goals),"away_goals":int(result.away_goals)}
			if int(row.home_goals) == int(row.away_goals): row["shootout_winner"] = home if _stable(home+away+str(year)+str(round_counter)) % 2 == 0 else away
			results.append(row)
			knockout_results.append({"round":int(bracket.round),"home":home,"away":away,"result":result,"shootout_winner":row.get("shootout_winner","")})
		bracket = KnockoutClass.new().advance_round(bracket, results)
		if bracket.is_empty(): break
		round_counter += 1
	var champion := String(bracket.get("winner", ""))
	cycle.stage = "complete" if champion != "" else "knockout"
	cycle.winner = champion
	cycle["knockout_results"] = knockout_results
	return {"year":year,"callups":callups,"qualifying":cycle,"qualified":qualified,"champion":champion}

func _simulate_national_match(world: Dictionary, home_country: String, away_country: String, seed: int) -> Dictionary:
	var home_ids := _international.select_squad(world, home_country, 23)
	var away_ids := _international.select_squad(world, away_country, 23)
	var pool: Array = []
	for player_id in home_ids:
		var player := _player(world, String(player_id)).duplicate(true)
		if not player.is_empty(): player.club_id = home_country; pool.append(player)
	for player_id in away_ids:
		var player := _player(world, String(player_id)).duplicate(true)
		if not player.is_empty(): player.club_id = away_country; pool.append(player)
	if home_ids.size() < 11 or away_ids.size() < 11:
		return {"home_goals":0,"away_goals":0,"events":[],"stats":{"home":{},"away":{}},"lineups":{"home":home_ids,"away":away_ids}}
	var home := {"id":home_country,"name":_country_name(world,home_country),"reputation":50}
	var away := {"id":away_country,"name":_country_name(world,away_country),"reputation":50}
	return _engine.simulate_match(home, away, pool, seed)

func _player(world: Dictionary, id: String) -> Dictionary:
	for player in world.get("players", []):
		if String(player.get("id", "")) == id: return player
	return {}

func _country_name(world: Dictionary, id: String) -> String:
	for country in world.get("countries", []):
		if String(country.get("id", "")) == id: return String(country.get("name", id))
	return id

func _stable(text: String) -> int:
	var value := 109
	for c in text.to_utf8_buffer(): value = posmod(value * 199 + int(c), 2_147_483_647)
	return value
