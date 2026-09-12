class_name KnockoutResolutionService
extends RefCounted

const SeededRngClass = preload("res://core/rng/seeded_rng.gd")
const SpecialAbilityServiceClass = preload("res://simulation/players/special_ability_service.gd")

var _abilities = SpecialAbilityServiceClass.new()

func resolve_level_match(world: Dictionary, fixture: Dictionary, competition: Dictionary, seed: int) -> Dictionary:
	var home_id: String = String(fixture.get("home_club_id", ""))
	var away_id: String = String(fixture.get("away_club_id", ""))
	var home_squad: Array = _squad(world, home_id)
	var away_squad: Array = _squad(world, away_id)
	var extra_time: Dictionary = _simulate_extra_time(home_squad, away_squad, seed, competition)
	var result: Dictionary = {"extra_time_home_goals":int(extra_time.home_goals),"extra_time_away_goals":int(extra_time.away_goals),"extra_time_events":extra_time.events,"extra_time_substitutions":extra_time.substitutions,"after_extra_time":true,"shootout_winner":"","penalties_home":0,"penalties_away":0,"penalty_kicks":[]}
	if int(extra_time.home_goals) != int(extra_time.away_goals):
		result["winner"] = home_id if int(extra_time.home_goals) > int(extra_time.away_goals) else away_id
		result["decided"] = "extra_time"
		return result
	var shootout: Dictionary = _simulate_shootout(home_squad, away_squad, seed + 79_913, competition)
	result["penalties_home"] = int(shootout.home); result["penalties_away"] = int(shootout.away); result["penalty_kicks"] = shootout.kicks
	result["shootout_winner"] = home_id if int(shootout.home) > int(shootout.away) else away_id
	result["winner"] = result.shootout_winner; result["decided"] = "penalties"
	return result

func resolve_level_aggregate(world: Dictionary, second_leg: Dictionary, competition: Dictionary, seed: int) -> Dictionary:
	return resolve_level_match(world, second_leg, competition, seed)

func _simulate_extra_time(home_squad: Array, away_squad: Array, seed: int, competition: Dictionary) -> Dictionary:
	var home_lineup: Array = _best_lineup(home_squad); var away_lineup: Array = _best_lineup(away_squad)
	var home_quality: float = _late_match_quality(home_lineup, competition); var away_quality: float = _late_match_quality(away_lineup, competition)
	var substitutions: Array = []
	var home_sub: Dictionary = _extra_time_sub(home_squad, home_lineup); var away_sub: Dictionary = _extra_time_sub(away_squad, away_lineup)
	if not home_sub.is_empty():
		home_quality += float(home_sub.get("impact", 0.0)); substitutions.append({"side":"home","minute":105,"player_in":String(home_sub.get("player_in","")),"player_out":String(home_sub.get("player_out","")),"extra_time":true})
	if not away_sub.is_empty():
		away_quality += float(away_sub.get("impact", 0.0)); substitutions.append({"side":"away","minute":105,"player_in":String(away_sub.get("player_in","")),"player_out":String(away_sub.get("player_out","")),"extra_time":true})
	var home_goals: int = 0; var away_goals: int = 0; var events: Array = []
	for attack in range(24):
		var minute: int = 91 + int(float(attack) / 23.0 * 29.0)
		var home_share: float = clampf(0.50 + (home_quality - away_quality) / 280.0, 0.34, 0.66)
		var side: String = "home" if SeededRngClass.unit_for(seed, 30_000 + attack * 17) < home_share else "away"
		var attackers: Array = home_lineup if side == "home" else away_lineup; var defenders: Array = away_lineup if side == "home" else home_lineup
		if attackers.is_empty() or defenders.is_empty(): continue
		var shooter: Dictionary = _pick_attacker(attackers, seed, 30_003 + attack * 17); var keeper: Dictionary = _goalkeeper(defenders)
		var shooter_quality: float = _player_attack_quality(shooter, minute, competition); var keeper_quality: float = _keeper_quality(keeper, minute, competition)
		var chance_probability: float = clampf(0.19 + (shooter_quality - keeper_quality) / 430.0, 0.10, 0.33)
		if SeededRngClass.unit_for(seed, 30_007 + attack * 17) >= chance_probability: continue
		var xg: float = 0.045 + SeededRngClass.unit_for(seed, 30_009 + attack * 17) * 0.21
		xg *= _abilities.shot_multiplier(shooter,{"minute":minute,"score_diff":0,"importance":1.0,"one_on_one":xg>0.18,"long_shot":xg<0.08})
		var goal_probability: float = clampf(xg * (0.78 + shooter_quality / 330.0) * (1.0 - _abilities.goalkeeper_goal_reduction(keeper,{"importance":1.0,"minute":minute,"one_on_one":xg>0.18})),0.01,0.58)
		var goal: bool = SeededRngClass.unit_for(seed, 30_011 + attack * 17) < goal_probability
		events.append({"minute":minute,"type":"extra_time_shot","side":side,"player_id":String(shooter.get("id","")),"goalkeeper_id":String(keeper.get("id","")),"xg":snappedf(xg,0.001),"outcome":"goal" if goal else "no_goal"})
		if goal:
			if side == "home": home_goals += 1
			else: away_goals += 1
	return {"home_goals":home_goals,"away_goals":away_goals,"events":events,"substitutions":substitutions}

func _simulate_shootout(home_squad: Array, away_squad: Array, seed: int, competition: Dictionary) -> Dictionary:
	var home_takers: Array = _penalty_takers(home_squad); var away_takers: Array = _penalty_takers(away_squad)
	if home_takers.is_empty() or away_takers.is_empty(): return {"home":1,"away":0,"kicks":[]}
	var home_keeper: Dictionary = _goalkeeper(_best_lineup(home_squad)); var away_keeper: Dictionary = _goalkeeper(_best_lineup(away_squad))
	var home_score: int = 0; var away_score: int = 0; var kicks: Array = []; var kick_index: int = 0
	for round_index in range(5):
		var h: bool = _penalty_kick(home_takers[round_index % home_takers.size()], away_keeper, seed, kick_index, competition); kick_index += 1
		if h: home_score += 1
		kicks.append({"side":"home","round":round_index+1,"player_id":String(home_takers[round_index % home_takers.size()].get("id","")),"scored":h})
		if home_score > away_score + (5 - round_index): break
		var a: bool = _penalty_kick(away_takers[round_index % away_takers.size()], home_keeper, seed, kick_index, competition); kick_index += 1
		if a: away_score += 1
		kicks.append({"side":"away","round":round_index+1,"player_id":String(away_takers[round_index % away_takers.size()].get("id","")),"scored":a})
		if away_score > home_score + (4 - round_index): break
	var sudden: int = 0
	while home_score == away_score and sudden < 20:
		var h_index: int = (5+sudden)%home_takers.size(); var a_index: int = (5+sudden)%away_takers.size()
		var h: bool = _penalty_kick(home_takers[h_index],away_keeper,seed,kick_index,competition); kick_index += 1
		var a: bool = _penalty_kick(away_takers[a_index],home_keeper,seed,kick_index,competition); kick_index += 1
		if h: home_score += 1
		if a: away_score += 1
		kicks.append({"side":"home","round":6+sudden,"player_id":String(home_takers[h_index].get("id","")),"scored":h,"sudden_death":true}); kicks.append({"side":"away","round":6+sudden,"player_id":String(away_takers[a_index].get("id","")),"scored":a,"sudden_death":true})
		sudden += 1
	if home_score == away_score:
		if SeededRngClass.unit_for(seed,99_999) < 0.5: home_score += 1
		else: away_score += 1
	return {"home":home_score,"away":away_score,"kicks":kicks}

func _penalty_kick(taker: Dictionary, keeper: Dictionary, seed: int, key: int, _competition: Dictionary) -> bool:
	var attrs: Dictionary = taker.get("attributes",{}); var finishing: float = float(attrs.get("finishing",taker.get("current_ability",50))); var composure: float = float(attrs.get("composure",taker.get("current_ability",50))); var technique: float = float(attrs.get("technique",taker.get("current_ability",50)))
	var taker_quality: float = finishing*0.35+composure*0.40+technique*0.25+_abilities.situational_bonus(taker,{"phase":"penalty","minute":120,"importance":1.0})
	var keeper_attrs: Dictionary = keeper.get("attributes",{}); var keeper_quality: float = float(keeper_attrs.get("reflexes",keeper.get("current_ability",50)))*0.45+float(keeper_attrs.get("one_on_ones",keeper.get("current_ability",50)))*0.35+float(keeper_attrs.get("handling",keeper.get("current_ability",50)))*0.20
	keeper_quality += _abilities.situational_bonus(keeper,{"phase":"goalkeeping","minute":120,"importance":1.0})
	var probability: float = clampf(0.73+(taker_quality-keeper_quality)/420.0,0.56,0.91)
	return SeededRngClass.unit_for(seed,70_000+key*31) < probability

func _best_lineup(squad: Array) -> Array:
	var available: Array = []
	for player in squad:
		if bool(player.get("retired",false)) or int(player.get("injured_days",0)) > 0: continue
		available.append(player)
	available.sort_custom(func(a: Dictionary,b: Dictionary):
		var av: float = float(a.get("current_ability",50))*(0.75+float(a.get("fitness",100))/400.0); var bv: float = float(b.get("current_ability",50))*(0.75+float(b.get("fitness",100))/400.0)
		return av > bv
	)
	return available.slice(0,mini(11,available.size()))

func _extra_time_sub(squad: Array, lineup: Array) -> Dictionary:
	if lineup.is_empty(): return {}
	var ids: Dictionary = {}
	for player in lineup: ids[String(player.get("id",""))] = true
	var bench: Array = []
	for player in squad:
		if String(player.get("id","")) not in ids and not bool(player.get("retired",false)) and int(player.get("injured_days",0)) <= 0: bench.append(player)
	if bench.is_empty(): return {}
	bench.sort_custom(func(a: Dictionary,b: Dictionary):
		var av: float = float(a.get("current_ability",50))+(5.0 if _abilities.has(a,SpecialAbilityServiceClass.SUPER_SUB) else 0.0); var bv: float = float(b.get("current_ability",50))+(5.0 if _abilities.has(b,SpecialAbilityServiceClass.SUPER_SUB) else 0.0)
		return av > bv
	)
	var outgoing: Dictionary = lineup[0]
	for player in lineup:
		if float(player.get("fitness",100)) < float(outgoing.get("fitness",100)): outgoing = player
	var incoming: Dictionary = bench[0]
	var impact: float = clampf((float(incoming.get("current_ability",50))-float(outgoing.get("current_ability",50)))/22.0,-2.0,4.0)
	if _abilities.has(incoming,SpecialAbilityServiceClass.SUPER_SUB): impact += 2.5
	if _abilities.has(incoming,SpecialAbilityServiceClass.GAMECHANGER): impact += 1.5
	return {"player_in":String(incoming.get("id","")),"player_out":String(outgoing.get("id","")),"impact":impact}

func _late_match_quality(lineup: Array, _competition: Dictionary) -> float:
	if lineup.is_empty(): return 45.0
	var total: float = 0.0
	for player in lineup:
		var fitness: float = clampf(float(player.get("fitness",100))/100.0,0.4,1.0); var morale: float = clampf(float(player.get("morale",70))/100.0,0.4,1.0); var retention: float = _abilities.stamina_retention(player); var fatigue: float = clampf(0.80+retention,0.70,1.02)
		total += float(player.get("current_ability",50))*fitness*(0.92+morale*0.08)*fatigue+_abilities.situational_bonus(player,{"minute":105,"importance":1.0,"phase":"general"})
	return total/float(lineup.size())

func _player_attack_quality(player: Dictionary, minute: int, _competition: Dictionary) -> float:
	var attrs: Dictionary = player.get("attributes",{}); var q: float = float(player.get("current_ability",50))*0.45+float(attrs.get("finishing",50))*0.20+float(attrs.get("composure",50))*0.15+float(attrs.get("off_the_ball",50))*0.10+float(attrs.get("technique",50))*0.10
	q += _abilities.situational_bonus(player,{"minute":minute,"importance":1.0,"phase":"shot","score_diff":0}); return q

func _keeper_quality(player: Dictionary, minute: int, _competition: Dictionary) -> float:
	if player.is_empty(): return 45.0
	var attrs: Dictionary = player.get("attributes",{})
	return float(player.get("current_ability",50))*0.45+float(attrs.get("reflexes",50))*0.20+float(attrs.get("handling",50))*0.15+float(attrs.get("one_on_ones",50))*0.20+_abilities.situational_bonus(player,{"minute":minute,"importance":1.0,"phase":"goalkeeping"})

func _pick_attacker(lineup: Array, seed: int, key: int) -> Dictionary:
	var candidates: Array = []
	for player in lineup:
		if String(player.get("position","")) in ["ST","AML","AMR","AMC","MC"]: candidates.append(player)
	if candidates.is_empty(): candidates = lineup
	return candidates[int(SeededRngClass.value_for(seed,key)%candidates.size())]

func _penalty_takers(squad: Array) -> Array:
	var candidates: Array = _best_lineup(squad)
	candidates.sort_custom(func(a: Dictionary,b: Dictionary): return _penalty_quality(a) > _penalty_quality(b))
	return candidates if not candidates.is_empty() else squad.slice(0,mini(5,squad.size()))

func _penalty_quality(player: Dictionary) -> float:
	var attrs: Dictionary = player.get("attributes",{})
	return float(attrs.get("finishing",50))*0.30+float(attrs.get("composure",50))*0.40+float(attrs.get("technique",50))*0.20+(10.0 if _abilities.has(player,SpecialAbilityServiceClass.PENALTY_EXPERT) else 0.0)

func _goalkeeper(lineup: Array) -> Dictionary:
	for player in lineup:
		if String(player.get("position","")) == "GK": return player
	return lineup[0] if not lineup.is_empty() else {}

func _squad(world: Dictionary, club_id: String) -> Array:
	var result: Array = []
	for player in world.get("players",[]):
		if String(player.get("club_id","")) == club_id: result.append(player)
	return result
