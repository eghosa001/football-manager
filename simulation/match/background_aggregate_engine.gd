class_name BackgroundAggregateEngine
extends RefCounted

const SeededRng = preload("res://core/rng/seeded_rng.gd")

func simulate_match(home_club: Dictionary, away_club: Dictionary, _players: Array, seed: int) -> Dictionary:
	var home_strength := float(home_club.get("reputation", 50))
	var away_strength := float(away_club.get("reputation", 50))
	var home_expectation := clampf(1.20 + (home_strength - away_strength) / 70.0 + 0.22, 0.25, 3.10)
	var away_expectation := clampf(1.05 + (away_strength - home_strength) / 75.0, 0.20, 2.90)
	var home_goals := _sample_goals(seed, 101, home_expectation)
	var away_goals := _sample_goals(seed, 211, away_expectation)
	var home_shots := maxi(home_goals, int(round(home_expectation * 6.2 + SeededRng.unit_for(seed, 301) * 5.0)))
	var away_shots := maxi(away_goals, int(round(away_expectation * 6.0 + SeededRng.unit_for(seed, 302) * 5.0)))
	var home_possession := clampf(50.0 + (home_strength - away_strength) * 0.22 + (SeededRng.unit_for(seed, 401) - 0.5) * 7.0, 34.0, 66.0)
	var stats := {
		"home": {"goals":home_goals,"shots":home_shots,"shots_on_target":maxi(home_goals,int(round(home_shots*0.34))),"xg":snappedf(home_expectation,0.01),"passes":0,"passes_completed":0,"dribbles":0,"dribbles_completed":0,"interceptions":0,"corners":0,"free_kicks":0,"cards":0,"red_cards":0,"saves":maxi(0,int(round(away_shots*0.34))-away_goals),"possession":snappedf(home_possession,0.1)},
		"away": {"goals":away_goals,"shots":away_shots,"shots_on_target":maxi(away_goals,int(round(away_shots*0.34))),"xg":snappedf(away_expectation,0.01),"passes":0,"passes_completed":0,"dribbles":0,"dribbles_completed":0,"interceptions":0,"corners":0,"free_kicks":0,"cards":0,"red_cards":0,"saves":maxi(0,int(round(home_shots*0.34))-home_goals),"possession":snappedf(100.0-home_possession,0.1)}
	}
	return {"home_goals":home_goals,"away_goals":away_goals,"events":[],"stats":stats,"lineups":{"home":[],"away":[]},"participants":{"home":[],"away":[]},"model":"inactive_aggregate","seed":seed}

func apply_to_fixture(fixture: Dictionary, result: Dictionary) -> void:
	if result.has("error"):
		return
	fixture.played = true
	fixture.home_goals = int(result.get("home_goals",0))
	fixture.away_goals = int(result.get("away_goals",0))

func _sample_goals(seed: int, key: int, expectation: float) -> int:
	# Deterministic inverse-Poisson sampling, capped to keep aggregate results sane.
	var threshold := exp(-expectation)
	var product := 1.0
	var count := 0
	while count < 8:
		product *= maxf(0.000001, SeededRng.unit_for(seed, key + count * 17))
		if product <= threshold:
			break
		count += 1
	return count
