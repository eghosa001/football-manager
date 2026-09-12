class_name ModernRulesCatalog
extends RefCounted

const STANDARD_VERSION := "2026-27"

const UNIVERSAL_MATCH_RULES := {
	"substitutes_allowed":5,"substitution_windows":3,"extra_time_substitute":1,
	"extra_time_minutes":30,"away_goals":false,"penalties":true,"replays":false,
	"points_win":3,"points_draw":1
}

const DOMESTIC_STRUCTURE := {
	"eng":{1:{"teams":20,"promotion":0,"automatic_promotion":0,"playoff_promotion":0,"relegation":3,"relegation_playoff":0},2:{"teams":24,"promotion":3,"automatic_promotion":2,"playoff_promotion":1,"playoff_places":[3,6],"relegation":3},3:{"teams":24,"promotion":3,"automatic_promotion":2,"playoff_promotion":1,"playoff_places":[3,6],"relegation":4}},
	"esp":{1:{"teams":20,"promotion":0,"relegation":3},2:{"teams":22,"promotion":3,"automatic_promotion":2,"playoff_promotion":1,"playoff_places":[3,6],"relegation":4}},
	"deu":{1:{"teams":18,"promotion":0,"relegation":2,"relegation_playoff":1},2:{"teams":18,"promotion":2,"automatic_promotion":2,"promotion_playoff_vs_upper":1,"relegation":2,"relegation_playoff":1}},
	"fra":{1:{"teams":18,"promotion":0,"relegation":2,"relegation_playoff":1},2:{"teams":18,"promotion":2,"automatic_promotion":2,"promotion_playoff_vs_upper":1,"relegation":3}},
	"ita":{1:{"teams":20,"promotion":0,"relegation":3},2:{"teams":20,"promotion":3,"automatic_promotion":2,"playoff_promotion":1,"playoff_places":[3,8],"relegation":3}},
	"nld":{1:{"teams":18,"promotion":0,"relegation":2,"relegation_playoff":1},2:{"teams":20,"promotion":2,"automatic_promotion":2,"promotion_playoff_vs_upper":1,"relegation":0}},
	"bra":{1:{"teams":20,"promotion":0,"relegation":4},2:{"teams":20,"promotion":4,"automatic_promotion":2,"playoff_promotion":2,"playoff_places":[3,6],"relegation":4}},
	"arg":{1:{"teams":30,"promotion":0,"relegation":2,"season_profiled":true}}
}

const DOMESTIC_RULE_PROFILES := {
	"eng":{"tie_breakers":["points","goal_difference","goals_scored","head_to_head_points","head_to_head_away_goals"],"yellow_thresholds":[5,10,15],"yellow_bans":[1,2,3]},
	"esp":{"tie_breakers":["points","head_to_head_points","head_to_head_goal_difference","goal_difference","goals_scored"],"yellow_thresholds":[5,10,15],"yellow_bans":[1,1,1]},
	"deu":{"tie_breakers":["points","goal_difference","goals_scored","head_to_head_points","head_to_head_goal_difference","head_to_head_away_goals"],"yellow_thresholds":[5,10,15],"yellow_bans":[1,1,1]},
	"fra":{"tie_breakers":["points","goal_difference","goals_scored","head_to_head_points","head_to_head_goal_difference"],"yellow_thresholds":[3,6,9],"yellow_bans":[1,1,1]},
	"ita":{"tie_breakers":["points","head_to_head_points","head_to_head_goal_difference","goal_difference","goals_scored"],"yellow_thresholds":[5,10,15],"yellow_bans":[1,1,1]},
	"nld":{"tie_breakers":["points","goal_difference","goals_scored","head_to_head_points"],"yellow_thresholds":[5,10,15],"yellow_bans":[1,1,1]},
	"bra":{"tie_breakers":["points","wins","goal_difference","goals_scored","head_to_head_points"],"yellow_thresholds":[3,6,9],"yellow_bans":[1,1,1]},
	"arg":{"tie_breakers":["points","goal_difference","goals_scored","head_to_head_points"],"yellow_thresholds":[5,10,15],"yellow_bans":[1,1,1]}
}

const EUROPEAN_LEAGUE_PHASES := {
	1:{"teams":36,"matches_per_club":8,"home_matches":4,"away_matches":4,"direct_round_of_16":[1,8],"knockout_playoff":[9,24],"eliminated":[25,36]},
	2:{"teams":36,"matches_per_club":8,"home_matches":4,"away_matches":4,"direct_round_of_16":[1,8],"knockout_playoff":[9,24],"eliminated":[25,36]},
	3:{"teams":36,"matches_per_club":6,"home_matches":3,"away_matches":3,"direct_round_of_16":[1,8],"knockout_playoff":[9,24],"eliminated":[25,36]}
}

func apply_to_world(world: Dictionary) -> Dictionary:
	world["rules_standard_version"] = STANDARD_VERSION
	var patched: int = 0
	var warnings: Array = []
	for competition in world.get("competitions",[]):
		_apply_universal_rules(competition)
		var country_id: String = String(competition.get("country_id",""))
		if String(competition.get("competition_type","league")) == "league":
			var tier: int = int(competition.get("tier",1))
			var expected: Dictionary = DOMESTIC_STRUCTURE.get(country_id,{}).get(tier,{})
			if not expected.is_empty():
				patched += _apply_domestic_structure(competition,expected)
				if expected.has("teams") and competition.get("club_ids",[]).size() != int(expected.teams): warnings.append("%s has %d clubs; modern profile expects %d" % [String(competition.get("id","")),competition.get("club_ids",[]).size(),int(expected.teams)])
			_apply_domestic_rule_profile(competition,country_id)
		if bool(competition.get("continental",false)) and String(competition.get("continental_region","")) == "europe":
			var continental_tier: int = int(competition.get("continental_tier",1))
			if EUROPEAN_LEAGUE_PHASES.has(continental_tier):
				competition["modern_league_phase"] = EUROPEAN_LEAGUE_PHASES[continental_tier].duplicate(true)
				competition["tie_breakers"] = ["points","goal_difference","goals_scored","wins"]
				competition["yellow_thresholds"] = [3,5,7]
				competition["yellow_bans"] = [1,1,1]
				competition["away_goals"] = false
				competition["rules"] = _merge_rules(competition.get("rules",{}),UNIVERSAL_MATCH_RULES)
		_sync_rule_fields(competition)
	world["rules_audit"] = {"standard":STANDARD_VERSION,"patched":patched,"warnings":warnings}
	return world.rules_audit

func modern_rules_for(competition: Dictionary) -> Dictionary:
	var rules: Dictionary = UNIVERSAL_MATCH_RULES.duplicate(true)
	for key in competition.get("rules",{}).keys(): rules[key] = competition.rules[key]
	for key in ["substitutes_allowed","substitution_windows","extra_time_substitute","extra_time_minutes","away_goals","penalties","replays","points_win","points_draw","tie_breakers","yellow_thresholds","yellow_bans","red_ban_matches","two_yellow_ban_matches"]:
		if competition.has(key): rules[key] = competition[key]
	if not bool(competition.get("legacy_rules",false)): rules["away_goals"] = false
	return rules

func validate_world(world: Dictionary) -> Array:
	var errors: Array = []
	var key_map: Dictionary = {"promotion":"promotion_places","automatic_promotion":"automatic_promotion_places","playoff_promotion":"playoff_promotion_places","relegation":"relegation_places","relegation_playoff":"relegation_playoff_places","promotion_playoff_vs_upper":"promotion_playoff_vs_upper"}
	for competition in world.get("competitions",[]):
		var rules: Dictionary = modern_rules_for(competition)
		if int(rules.get("substitutes_allowed",0)) != 5: errors.append("%s must allow five substitutes" % String(competition.get("id","")))
		if int(rules.get("substitution_windows",0)) != 3: errors.append("%s must use three regulation-time substitution windows" % String(competition.get("id","")))
		if bool(rules.get("away_goals",false)): errors.append("%s uses obsolete away-goals rule" % String(competition.get("id","")))
		if rules.has("yellow_thresholds") and rules.has("yellow_bans") and rules.yellow_thresholds.size() != rules.yellow_bans.size(): errors.append("%s yellow-card threshold profile is inconsistent" % String(competition.get("id","")))
		if String(competition.get("competition_type","league")) == "knockout":
			if int(rules.get("extra_time_minutes",0)) != 30: errors.append("%s must use 30 minutes extra time" % String(competition.get("id","")))
			if not bool(rules.get("penalties",false)): errors.append("%s must resolve level knockout ties with penalties" % String(competition.get("id","")))
			if bool(rules.get("replays",false)) and not bool(competition.get("qualifying_replay_exception",false)): errors.append("%s has an unsupported replay rule" % String(competition.get("id","")))
		var country_id: String = String(competition.get("country_id","")); var tier: int = int(competition.get("tier",1)); var expected: Dictionary = DOMESTIC_STRUCTURE.get(country_id,{}).get(tier,{})
		if String(competition.get("competition_type","league")) == "league" and not expected.is_empty():
			if expected.has("teams") and competition.get("club_ids",[]).size() != int(expected.teams): errors.append("%s club count mismatch" % String(competition.get("id","")))
			for field in key_map.keys():
				if not expected.has(field): continue
				var actual_key: String = String(key_map[field])
				if int(competition.get(actual_key,0)) != int(expected[field]): errors.append("%s %s mismatch" % [String(competition.get("id","")),actual_key])
	return errors

func _apply_universal_rules(competition: Dictionary) -> void:
	for key in UNIVERSAL_MATCH_RULES.keys():
		if key == "away_goals": competition[key] = false
		elif not competition.has(key): competition[key] = UNIVERSAL_MATCH_RULES[key]
	if not competition.has("red_ban_matches"): competition["red_ban_matches"] = 1
	if not competition.has("two_yellow_ban_matches"): competition["two_yellow_ban_matches"] = 1
	competition["rules"] = _merge_rules(competition.get("rules",{}),UNIVERSAL_MATCH_RULES)
	competition.rules["away_goals"] = false
	competition["rules_standard_version"] = STANDARD_VERSION

func _apply_domestic_structure(competition: Dictionary, expected: Dictionary) -> int:
	var changes: int = 0
	var mapping: Dictionary = {"promotion":"promotion_places","automatic_promotion":"automatic_promotion_places","playoff_promotion":"playoff_promotion_places","playoff_places":"playoff_places","promotion_playoff_vs_upper":"promotion_playoff_vs_upper","relegation":"relegation_places","relegation_playoff":"relegation_playoff_places"}
	for source_key in mapping.keys():
		if not expected.has(source_key): continue
		var target_key: String = String(mapping[source_key]); var value: Variant = expected[source_key]
		if competition.get(target_key) != value:
			competition[target_key] = value.duplicate(true) if value is Array or value is Dictionary else value
			changes += 1
	if bool(expected.get("season_profiled",false)): competition["season_profiled_rules"] = true
	return changes

func _apply_domestic_rule_profile(competition: Dictionary,country_id: String) -> void:
	var profile: Dictionary = DOMESTIC_RULE_PROFILES.get(country_id,{})
	for key in profile.keys(): competition[key] = profile[key].duplicate(true) if profile[key] is Array or profile[key] is Dictionary else profile[key]

func _sync_rule_fields(competition: Dictionary) -> void:
	for key in ["tie_breakers","yellow_thresholds","yellow_bans","red_ban_matches","two_yellow_ban_matches"]:
		if competition.has(key): competition.rules[key] = competition[key]

func _merge_rules(existing: Dictionary, defaults: Dictionary) -> Dictionary:
	var merged: Dictionary = defaults.duplicate(true)
	for key in existing.keys(): merged[key] = existing[key]
	merged["away_goals"] = false
	merged["substitutes_allowed"] = 5
	merged["substitution_windows"] = 3
	merged["extra_time_substitute"] = 1
	merged["extra_time_minutes"] = 30
	return merged
