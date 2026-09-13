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
		return {"year": year, "callups": [], "qualifying": {}, "qualified": [], "champion": "", "continentals": [], "world_cup": {}}
	var callups: Array = []
	for country in countries:
		callups.append(_international.register_callups(world, String(country.get("id", "")), "international-%d" % year, 23))
	var continentals: Array = []
	# Continental championships in even years; World Cup qualifying + finals on a 4-year rhythm.
	if year % 2 == 0:
		for region in ["europe", "africa", "south_america", "asia", "north_america"]:
			var members := _region_members(world, String(region))
			if members.size() < 2:
				continue
			var slots := mini(8, members.size())
			var cycle: Dictionary = _international.create_continental_qualifying(world, String(region), _international.continental_championship_id(String(region), year), slots)
			continentals.append(_play_international_cycle(world, cycle, seed + _stable(String(region)) % 10000, year))
	var world_cup := {}
	if year % 4 == 2:
		var wc_cycle: Dictionary = _international.create_world_cup_qualifying(world, _international.world_cup_id(year), 8)
		world_cup = _play_international_cycle(world, wc_cycle, seed + 40000, year)
		_international.complete_tournament(world, _international.world_cup_id(year), String(world_cup.get("champion", "")), String(world_cup.get("runner_up", "")))
	# Legacy generic yearly cycle preserved for save compatibility and regression.
	var country_ids: Array = []
	for country in countries: country_ids.append(String(country.get("id", "")))
	var group_count := maxi(1, int(ceil(float(country_ids.size()) / 4.0)))
	var legacy: Dictionary = _international.create_qualifying_cycle(world, "international-%d" % year, group_count)
	var legacy_result := _play_international_cycle(world, legacy, seed, year)
	return {"year": year, "callups": callups, "qualifying": legacy, "qualified": legacy_result.get("qualified", []), "champion": legacy_result.get("champion", ""), "continentals": continentals, "world_cup": world_cup}

func _region_members(world: Dictionary, region: String) -> Array:
	var members: Array = []
	for country in world.get("countries", []):
		if _international.region_for_country(String(country.get("id", ""))) == region:
			members.append(String(country.get("id", "")))
	return members

func _play_international_cycle(world: Dictionary, cycle: Dictionary, seed: int, year: int) -> Dictionary:
	for i in range(cycle.fixtures.size()):
		var fixture: Dictionary = cycle.fixtures[i]
		var home_key := String(fixture.get("home_club_id", fixture.get("home", "")))
		var away_key := String(fixture.get("away_club_id", fixture.get("away", "")))
		if home_key == "" or away_key == "":
			continue
		var result := _simulate_national_match(world, home_key, away_key, seed + i * 997)
		fixture.played = true
		fixture.home_goals = int(result.home_goals)
		fixture.away_goals = int(result.away_goals)
		fixture["result"] = result
	var slots := int(cycle.get("slots", 8))
	var qualified: Array = _international.qualify_from_groups(cycle.get("groups", []), cycle.get("fixtures", []), slots)
	if qualified.is_empty():
		# Fallback: top-two per group when slot math yields nothing.
		qualified = GroupStageClass.new().qualifiers(cycle.get("groups", []), cycle.get("fixtures", []), 2)
	cycle.qualified = qualified.duplicate()
	_international.complete_qualifying(world, String(cycle.get("id", "")), qualified)
	cycle.stage = "knockout"
	if qualified.size() < 2:
		cycle.stage = "complete"
		cycle.winner = String(qualified[0]) if qualified.size() == 1 else ""
		cycle["knockout_results"] = []
		return {"qualified": qualified, "champion": String(cycle.get("winner", "")), "runner_up": "", "cycle": cycle}
	var bracket: Dictionary = KnockoutClass.new().create_bracket(qualified, seed + 50_000)
	var knockout_results: Array = []
	var round_counter := 0
	var runner_up := ""
	while not bool(bracket.get("complete", false)) and round_counter < 8:
		var results: Array = []
		for i in range(bracket.matches.size()):
			var pairing: Dictionary = bracket.matches[i]
			var home := String(pairing.home); var away := String(pairing.away)
			if home == "" or away == "":
				results.append({})
				continue
			var result := _simulate_national_match(world, home, away, seed + 70_000 + round_counter * 1000 + i * 31)
			var row := {"home_goals": int(result.home_goals), "away_goals": int(result.away_goals)}
			if int(row.home_goals) == int(row.away_goals): row["shootout_winner"] = home if _stable(home + away + str(year) + str(round_counter)) % 2 == 0 else away
			results.append(row)
			knockout_results.append({"round": int(bracket.round), "home": home, "away": away, "result": result, "shootout_winner": row.get("shootout_winner", "")})
		var previous_finalists := _finalists(bracket)
		bracket = KnockoutClass.new().advance_round(bracket, results)
		if bracket.is_empty(): break
		if bool(bracket.get("complete", false)) and previous_finalists.size() == 2:
			var winner := String(bracket.get("winner", ""))
			runner_up = String(previous_finalists[1]) if String(previous_finalists[0]) == winner else String(previous_finalists[0])
		round_counter += 1
	var champion := String(bracket.get("winner", ""))
	cycle.stage = "complete" if champion != "" else "knockout"
	cycle.winner = champion
	cycle["knockout_results"] = knockout_results
	if champion != "":
		_international.complete_tournament(world, String(cycle.get("id", "")), champion, runner_up)
	return {"qualified": qualified, "champion": champion, "runner_up": runner_up, "cycle": cycle}

func _finalists(bracket: Dictionary) -> Array:
	var result: Array = []
	for pairing in bracket.get("matches", []):
		if String(pairing.get("home", "")) != "": result.append(String(pairing.get("home", "")))
		if String(pairing.get("away", "")) != "": result.append(String(pairing.get("away", "")))
		if result.size() >= 2: break
	return result

func _simulate_national_match(world: Dictionary, home_country: String, away_country: String, seed: int) -> Dictionary:
	var home_ids := _international.select_squad(world, home_country, 23)
	var away_ids := _international.select_squad(world, away_country, 23)
	var pool: Array = []
	for player_id in home_ids:
		var player := _player(world, String(player_id)).duplicate(true)
		if not player.is_empty():
			player.club_id = home_country
			pool.append(player)
	for player_id in away_ids:
		var player := _player(world, String(player_id)).duplicate(true)
		if not player.is_empty():
			player.club_id = away_country
			pool.append(player)
	# Small/newly-added countries and heavily depleted long saves can have fewer
	# than eleven eligible persistent players. Do not turn every such fixture
	# into an artificial 0-0. Temporary emergency call-ups exist only for this
	# match and are derived deterministically from the nation's football strength.
	_add_emergency_callups(world, pool, home_country, home_ids.size(), seed + 101)
	_add_emergency_callups(world, pool, away_country, away_ids.size(), seed + 202)
	var home := {"id":home_country,"name":_country_name(world,home_country),"reputation":_country_strength(world, home_country)}
	var away := {"id":away_country,"name":_country_name(world,away_country),"reputation":_country_strength(world, away_country)}
	var result: Dictionary = _engine.simulate_match(home, away, pool, seed)
	result["emergency_callups"] = {"home": maxi(0, 11 - home_ids.size()), "away": maxi(0, 11 - away_ids.size())}
	return result

func _add_emergency_callups(world: Dictionary, pool: Array, country_id: String, existing_count: int, seed: int) -> void:
	if existing_count >= 11:
		return
	var positions := ["GK", "DR", "DC", "DC", "DL", "DM", "MC", "MC", "AMR", "AML", "ST"]
	var existing_positions: Dictionary = {}
	for player in pool:
		if String(player.get("club_id", "")) == country_id:
			var position := String(player.get("position", "MC"))
			existing_positions[position] = int(existing_positions.get(position, 0)) + 1
	var needed := 11 - existing_count
	var strength := _country_strength(world, country_id)
	for i in range(needed):
		var position := _next_emergency_position(positions, existing_positions)
		existing_positions[position] = int(existing_positions.get(position, 0)) + 1
		var jitter := posmod(_stable("%s:%d:%d" % [country_id, seed, i]), 13) - 6
		var ability := clampi(strength + jitter, 25, 80)
		pool.append({
			"id":"emergency-%s-%d-%d" % [country_id, seed, i],
			"club_id":country_id,
			"country_id":country_id,
			"first_name":"Emergency",
			"last_name":"Call-up %d" % (i + 1),
			"name":"Emergency Call-up %d" % (i + 1),
			"age":24,
			"position":position,
			"current_ability":ability,
			"potential":ability,
			"fitness":100.0,
			"fatigue":10.0,
			"morale":60.0,
			"injured_days":0,
			"retired":false,
			"attributes":{"pace":ability,"stamina":ability,"passing":ability,"finishing":ability,"tackling":ability,"positioning":ability,"decisions":ability,"technique":ability,"handling":ability if position == "GK" else maxi(20, ability - 20)}
		})

func _next_emergency_position(positions: Array, existing_positions: Dictionary) -> String:
	var target_counts := {"GK":1,"DR":1,"DC":2,"DL":1,"DM":1,"MC":2,"AMR":1,"AML":1,"ST":1}
	for position_value in positions:
		var position := String(position_value)
		if int(existing_positions.get(position, 0)) < int(target_counts.get(position, 1)):
			return position
	return "MC"

func _country_strength(world: Dictionary, id: String) -> int:
	for country in world.get("countries", []):
		if String(country.get("id", "")) == id:
			return clampi(int(country.get("youth_rating", country.get("reputation", 50))), 25, 80)
	return 50

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