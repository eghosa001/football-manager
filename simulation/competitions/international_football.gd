class_name InternationalFootball
extends RefCounted

const GroupStageClass = preload("res://simulation/competitions/group_stage.gd")
const KnockoutClass = preload("res://simulation/competitions/knockout_competition.gd")

func ensure_world(world: Dictionary) -> void:
	world["national_teams"] = world.get("national_teams", _build_national_teams(world.get("countries", [])))
	world["international_callups"] = world.get("international_callups", [])
	world["international_competitions"] = world.get("international_competitions", [])

func select_squad(world: Dictionary, country_id: String, size: int = 23) -> Array:
	ensure_world(world)
	var eligible: Array = []
	for player in world.get("players", []):
		if bool(player.get("retired", false)): continue
		var nationality := String(player.get("country_id", player.get("nationality_id", "")))
		if nationality == "":
			var club := _club(world.get("clubs", []), String(player.get("club_id", "")))
			nationality = String(club.get("country_id", ""))
		if nationality == country_id: eligible.append(player)
	eligible.sort_custom(func(a: Dictionary, b: Dictionary):
		var aa := int(a.get("current_ability",0)); var bb := int(b.get("current_ability",0))
		if aa == bb: return String(a.id) < String(b.id)
		return aa > bb
	)
	var selected: Array = []; var goalkeeper_count := 0
	for player in eligible:
		if String(player.get("position","")) == "GK" and goalkeeper_count < 3:
			selected.append(String(player.id)); goalkeeper_count += 1
	for player in eligible:
		if selected.size() >= size: break
		if String(player.id) not in selected: selected.append(String(player.id))
	return selected

func register_callups(world: Dictionary, country_id: String, competition_id: String, size: int = 23) -> Dictionary:
	ensure_world(world)
	var record := {"country_id":country_id,"competition_id":competition_id,"player_ids":select_squad(world,country_id,size),"season_year":int(world.get("season_year",2026))}
	world.international_callups.append(record)
	return record

func create_qualifying_cycle(world: Dictionary, competition_id: String, group_count: int = 4) -> Dictionary:
	ensure_world(world)
	var country_ids: Array = []
	for country in world.get("countries", []): country_ids.append(String(country.get("id", "")))
	var groups := GroupStageClass.new().seed_groups(country_ids, mini(group_count, maxi(1,country_ids.size())))
	var cycle := {"id":competition_id,"season_year":int(world.get("season_year",2026)),"stage":"qualifying","groups":groups,"fixtures":GroupStageClass.new().fixtures_for_groups(groups,competition_id),"qualified":[],"winner":""}
	world.international_competitions.append(cycle)
	return cycle

func knockout_stage(qualified_country_ids: Array, seed: int) -> Dictionary:
	return KnockoutClass.new().create_bracket(qualified_country_ids, seed)

func _build_national_teams(countries: Array) -> Array:
	var teams: Array = []
	for country in countries:
		teams.append({"id":"national-%s" % String(country.get("id","")),"country_id":String(country.get("id","")),"name":String(country.get("name","Nation")),"reputation":int(country.get("youth_rating",50))})
	return teams

func _club(clubs: Array, id: String) -> Dictionary:
	for club in clubs:
		if String(club.get("id", "")) == id: return club
	return {}
