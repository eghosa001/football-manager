extends SceneTree

const Builder = preload("res://data/launch_world_builder.gd")
const ModernRules = preload("res://simulation/competitions/modern_rules_catalog.gd")
const RuleEngine = preload("res://simulation/competitions/competition_rule_engine.gd")
const TwoLeg = preload("res://simulation/competitions/knockout_two_leg.gd")
const Knockout = preload("res://simulation/competitions/knockout_competition.gd")
const Continental = preload("res://application/season/continental_competitions.gd")
const ContinentalPhase = preload("res://application/season/continental_league_phase.gd")

var failures := 0
var checks := 0

func _init() -> void:
	var world: Dictionary = Builder.new().build(202627, 0, 25, true)
	_require(not world.is_empty(), "launch world must build")
	var catalog = ModernRules.new()
	catalog.apply_to_world(world)
	var continental = Continental.new()
	continental.prepare(world)
	catalog.apply_to_world(world)
	continental.initialize_formats(world,int(world.get("season_year",2026)),true)
	_require(String(world.get("rules_standard_version", "")) == "2026-27", "world must carry the 2026/27 rules profile")
	_test_universal_rules(world, catalog)
	_test_domestic_structures(world)
	_test_knockout_resolution()
	_test_european_profiles(world)
	var validation: Array = catalog.validate_world(world)
	for error in validation: _fail("catalog validation: " + String(error))
	if failures == 0:
		print("[TEST] MODERN FOOTBALL RULES PASS: functional league phases, five subs, extra time, penalties, no away goals and domestic movement verified")
		quit(0)
	push_error("[TEST] MODERN FOOTBALL RULES FAIL: %d failures across %d checks" % [failures, checks])
	quit(1)

func _test_universal_rules(world: Dictionary, catalog) -> void:
	for competition in world.get("competitions", []):
		var rules: Dictionary = catalog.modern_rules_for(competition)
		_require(int(rules.get("substitutes_allowed", 0)) == 5, "%s must allow five substitutes" % String(competition.get("id", "")))
		_require(int(rules.get("substitution_windows", 0)) == 3, "%s must use three regulation substitution opportunities" % String(competition.get("id", "")))
		_require(int(rules.get("extra_time_substitute", 0)) == 1, "%s must permit the configured extra-time substitution" % String(competition.get("id", "")))
		_require(not bool(rules.get("away_goals", true)), "%s must not use away goals" % String(competition.get("id", "")))
		if String(competition.get("competition_type", "league")) == "knockout":
			_require(int(rules.get("extra_time_minutes", 0)) == 30, "%s knockout must use 30-minute extra time" % String(competition.get("id", "")))
			_require(bool(rules.get("penalties", false)), "%s knockout must support penalties" % String(competition.get("id", "")))
			_require(not bool(rules.get("replays", true)), "%s shipped proper competition must not require replays" % String(competition.get("id", "")))

func _test_domestic_structures(world: Dictionary) -> void:
	_check_league(world, "eng", 1, 20, 0, 0, 0, 3)
	_check_league(world, "eng", 2, 24, 3, 2, 1, 3)
	_check_league(world, "eng", 3, 24, 3, 2, 1, 4)
	_check_league(world, "esp", 1, 20, 0, 0, 0, 3)
	_check_league(world, "esp", 2, 22, 3, 2, 1, 4)
	_check_league(world, "deu", 1, 18, 0, 0, 0, 2)
	_check_league(world, "deu", 2, 18, 2, 2, 0, 2)
	_check_league(world, "fra", 1, 18, 0, 0, 0, 2)
	_check_league(world, "ita", 1, 20, 0, 0, 0, 3)
	_check_league(world, "nld", 1, 18, 0, 0, 0, 2)
	_check_league(world, "bra", 1, 20, 0, 0, 0, 4)
	_check_league(world, "bra", 2, 20, 4, 2, 2, 4)
	var brazil_b := _league(world, "bra", 2)
	_require(brazil_b.get("playoff_places", []) == [3,6], "Brazil tier 2 playoffs must cover positions 3-6")

func _test_knockout_resolution() -> void:
	var engine = RuleEngine.new()
	var rules := {"extra_time":true,"extra_time_minutes":30,"penalties":true,"away_goals":false}
	var et := engine.resolve_knockout(1, 1, rules, 1, 0, 0, 0)
	_require(String(et.get("winner", "")) == "home" and String(et.get("method", "")) == "extra_time", "extra-time goal must decide a level knockout")
	var pens := engine.resolve_knockout(1, 1, rules, 0, 0, 5, 4)
	_require(String(pens.get("winner", "")) == "home" and String(pens.get("method", "")) == "penalties", "penalties must decide a tie still level after extra time")
	var two_leg = TwoLeg.new()
	var level := two_leg.resolve_tie("A", "B", {"home_goals":2,"away_goals":1}, {"home_goals":2,"away_goals":1})
	_require(String(level.get("decided", "")) != "away_goals", "two-legged ties must not default to away goals")
	_require(bool(level.get("needs_extra_time", level.get("needs_shootout", false))), "level aggregate must proceed beyond regulation")
	var bracket := Knockout.new().create_bracket(["A","B"], 7)
	var advanced := Knockout.new().advance_round(bracket, [{"home_goals":1,"away_goals":1,"extra_time_home_goals":1,"extra_time_away_goals":0}])
	_require(bool(advanced.get("complete", false)), "single-leg knockout must accept extra-time resolution")

func _test_european_profiles(world: Dictionary) -> void:
	for tier in [1,2,3]:
		var profile: Dictionary = ModernRules.EUROPEAN_LEAGUE_PHASES[tier]
		_require(int(profile.teams) == 36, "European tier %d league phase must have 36 teams" % tier)
		_require(int(profile.matches_per_club) == (6 if tier == 3 else 8), "European tier %d match count must follow modern format" % tier)
		_require(profile.direct_round_of_16 == [1,8], "European tier %d top eight must reach R16" % tier)
		_require(profile.knockout_playoff == [9,24], "European tier %d positions 9-24 must enter playoff" % tier)
		var competition := _continental_tier(world,tier)
		_require(not competition.is_empty(), "European tier %d competition must exist" % tier)
		if competition.is_empty(): continue
		_require(String(competition.get("competition_type","")) == "continental_league_phase", "European tier %d must use league-phase engine" % tier)
		_require(competition.get("club_ids",[]).size() == 36, "European tier %d must contain 36 clubs" % tier)
		var fixtures: Array = []
		for fixture in world.get("fixtures",[]):
			if String(fixture.get("competition_id","")) == String(competition.id) and String(fixture.get("stage","")) == "league_phase": fixtures.append(fixture)
		var expected_matches := 108 if tier == 3 else 144
		_require(fixtures.size() == expected_matches, "European tier %d league phase fixture count" % tier)
		var home_counts := {}; var away_counts := {}; var opponents := {}
		for fixture in fixtures:
			var home := String(fixture.home_club_id); var away := String(fixture.away_club_id)
			home_counts[home] = int(home_counts.get(home,0))+1; away_counts[away] = int(away_counts.get(away,0))+1
			if not opponents.has(home): opponents[home] = {}
			if not opponents.has(away): opponents[away] = {}
			opponents[home][away] = true; opponents[away][home] = true
		for club_id in competition.club_ids:
			var expected_home := 3 if tier == 3 else 4
			_require(int(home_counts.get(String(club_id),0)) == expected_home, "%s tier %d home-match balance" % [String(club_id),tier])
			_require(int(away_counts.get(String(club_id),0)) == expected_home, "%s tier %d away-match balance" % [String(club_id),tier])
			_require(opponents.get(String(club_id),{}).size() == int(profile.matches_per_club), "%s tier %d must face unique opponents" % [String(club_id),tier])

func _check_league(world: Dictionary, country: String, tier: int, teams: int, promotion: int, automatic: int, playoff: int, relegation: int) -> void:
	var competition := _league(world, country, tier)
	_require(not competition.is_empty(), "%s tier %d must exist" % [country, tier])
	if competition.is_empty(): return
	_require(competition.get("club_ids", []).size() == teams, "%s tier %d club count" % [country, tier])
	_require(int(competition.get("promotion_places", 0)) == promotion, "%s tier %d promotion places" % [country, tier])
	_require(int(competition.get("automatic_promotion_places", 0)) == automatic, "%s tier %d automatic promotion" % [country, tier])
	_require(int(competition.get("playoff_promotion_places", 0)) == playoff, "%s tier %d playoff promotion" % [country, tier])
	_require(int(competition.get("relegation_places", 0)) == relegation, "%s tier %d relegation places" % [country, tier])

func _league(world: Dictionary, country: String, tier: int) -> Dictionary:
	for competition in world.get("competitions", []):
		if String(competition.get("competition_type", "league")) == "league" and String(competition.get("country_id", "")) == country and int(competition.get("tier", 0)) == tier: return competition
	return {}

func _continental_tier(world: Dictionary, tier: int) -> Dictionary:
	for competition in world.get("competitions",[]):
		if String(competition.get("continental_region","")) == "europe" and int(competition.get("continental_tier",0)) == tier and String(competition.get("competition_type","")) == "continental_league_phase": return competition
	return {}

func _require(condition: bool, message: String) -> void:
	checks += 1
	if not condition: _fail(message)

func _fail(message: String) -> void:
	failures += 1
	push_error("[MODERN RULES] " + message)
