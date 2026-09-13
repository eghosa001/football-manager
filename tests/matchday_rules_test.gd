extends SceneTree

const Builder = preload("res://data/launch_world_builder.gd")
const ModernRules = preload("res://simulation/competitions/modern_rules_catalog.gd")
const Registration = preload("res://simulation/competitions/registration_service.gd")
const ModernMatch = preload("res://simulation/match/modern_abstract_match_engine.gd")
const SeasonRunner = preload("res://application/season/season_runner.gd")

var failures := 0
var checks := 0

func _init() -> void:
	_test_five_subs_three_windows()
	_test_registration_enforced_on_matchday()
	if failures == 0:
		print("[TEST] MATCHDAY RULES PASS: five substitutions use at most three windows and registered squads are enforced")
		quit(0)
		return
	push_error("[TEST] MATCHDAY RULES FAIL: %d failures across %d checks" % [failures,checks])
	quit(1)

func _test_five_subs_three_windows() -> void:
	var world: Dictionary = Builder.new().build(771991,1,25,false)
	var competition: Dictionary = {}
	for row in world.get("competitions",[]):
		if String(row.get("competition_type","")) == "league": competition = row; break
	_require(not competition.is_empty(),"league must exist for substitution test")
	if competition.is_empty(): return
	var home_id := String(competition.club_ids[0]); var away_id := String(competition.club_ids[1])
	var home := _club(world,home_id); var away := _club(world,away_id)
	var players: Array = []
	for player in world.players:
		if String(player.get("club_id","")) in [home_id,away_id]: players.append(player)
	var result: Dictionary = ModernMatch.new().simulate_match(home,away,players,99182,{})
	for side in ["home","away"]:
		var rows: Array = []
		var minutes := {}
		for substitution in result.get("substitutions",[]):
			if String(substitution.get("side","")) != side: continue
			rows.append(substitution)
			minutes[int(substitution.get("minute",0))] = true
		_require(rows.size() <= 5,"%s must not use more than five substitutions" % side)
		_require(rows.size() == 5,"%s AI plan should use five substitutions when a full bench is available" % side)
		_require(minutes.size() <= 3,"%s substitutions must use at most three in-play opportunities" % side)

func _test_registration_enforced_on_matchday() -> void:
	var world: Dictionary = Builder.new().build(881992,1,25,false)
	ModernRules.new().apply_to_world(world)
	var competition: Dictionary = {}
	for row in world.get("competitions",[]):
		if String(row.get("competition_type","")) == "league": competition=row; break
	_require(not competition.is_empty(),"league must exist for registration test")
	if competition.is_empty(): return
	var season_year := int(world.get("season_year",2026))
	Registration.new().auto_register_world(world,season_year)
	var home_id := String(competition.club_ids[0]); var away_id := String(competition.club_ids[1])
	var key := "%s:%s:%d" % [home_id,String(competition.id),season_year]
	var registration: Dictionary = world.get("registrations",{}).get(key,{})
	_require(not registration.is_empty(),"home registration must exist")
	if registration.is_empty() or registration.get("player_ids",[]).is_empty(): return
	var removed_id := String(registration.player_ids[0])
	registration.player_ids.erase(removed_id)
	world.registrations[key] = registration
	var eligible: Array = SeasonRunner.new()._eligible_match_players(world,competition,home_id,away_id,{})
	var eligible_ids := {}
	for player in eligible: eligible_ids[String(player.get("id",""))] = true
	_require(not eligible_ids.has(removed_id),"unregistered player must be excluded from match selection")
	var registered_id := String(registration.player_ids[0]) if not registration.player_ids.is_empty() else ""
	if registered_id != "": _require(eligible_ids.has(registered_id),"registered eligible player must remain selectable")

func _club(world: Dictionary,club_id: String) -> Dictionary:
	for club in world.get("clubs",[]):
		if String(club.get("id","")) == club_id: return club
	return {}

func _require(condition: bool,message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[MATCHDAY RULES] "+message)
