class_name FootballLawsEngine
extends RefCounted

const SeededRngClass = preload("res://core/rng/seeded_rng.gd")

func weather_profile(seed: int) -> Dictionary:
	var roll := SeededRngClass.unit_for(seed, 91001)
	if roll < 0.12:
		return {"kind":"heavy_rain","pass_factor":0.90,"touch_factor":0.86,"stamina_factor":0.92,"shot_factor":0.94,"attendance_factor":0.88}
	if roll < 0.30:
		return {"kind":"rain","pass_factor":0.95,"touch_factor":0.93,"stamina_factor":0.96,"shot_factor":0.97,"attendance_factor":0.94}
	if roll > 0.92:
		return {"kind":"hot","pass_factor":0.99,"touch_factor":0.98,"stamina_factor":0.88,"shot_factor":0.98,"attendance_factor":0.96}
	return {"kind":"clear","pass_factor":1.0,"touch_factor":1.0,"stamina_factor":1.0,"shot_factor":1.0,"attendance_factor":1.0}

func process_event(event: Dictionary, home: Array, away: Array, home_tactic: Dictionary, away_tactic: Dictionary, weather: Dictionary, seed: int) -> Array:
	var output: Array = []
	var e := event.duplicate(true)
	var side := String(e.get("side", "home"))
	var attack := home if side == "home" else away
	var defend := away if side == "home" else home
	var tactic := home_tactic if side == "home" else away_tactic
	var event_type := String(e.get("type", ""))

	if event_type == "pass":
		var passer := _player(attack, String(e.get("player_id", "")))
		var receiver := _player(attack, String(e.get("receiver_id", e.get("target_id", ""))))
		var pass_quality := _quality(passer, ["passing", "technique", "vision"])
		var control := _quality(receiver, ["first_touch", "technique", "composure"])
		var weak_foot := clampf(float(passer.get("weak_foot", 10)) / 20.0, 0.2, 1.0)
		var pressure := _pressure(defend, passer)
		var execution := clampf((0.56 + pass_quality * 0.38) * float(weather.get("pass_factor", 1.0)) * lerpf(0.90, 1.02, weak_foot) * (1.0 - pressure * 0.08), 0.30, 0.96)
		if SeededRngClass.unit_for(seed, 92000 + int(e.get("tick", 0))) > execution:
			e["success"] = false
			e["outcome"] = "misplaced"
		elif not receiver.is_empty():
			var first_touch := clampf((0.66 + control * 0.30) * float(weather.get("touch_factor", 1.0)) * (1.0 - pressure * 0.05), 0.45, 0.98)
			if SeededRngClass.unit_for(seed, 93000 + int(e.get("tick", 0))) > first_touch:
				e["success"] = false
				e["outcome"] = "poor_first_touch"
				output.append({"type":"turnover","side":side,"player_id":String(receiver.get("id", "")),"minute":int(e.get("minute", 0)),"reason":"first_touch","success":false})
		if bool(e.get("success", false)) and _offside(receiver, defend, side, tactic):
			e["success"] = false
			e["outcome"] = "offside"
			output.append(e)
			output.append({"type":"offside","side":side,"player_id":String(receiver.get("id", "")),"minute":int(e.get("minute", 0)),"restart":"indirect_free_kick","success":false})
			return output
		_classify_pass(e, passer, receiver)

	if event_type in ["dribble", "interception", "tackle"]:
		var foul_events := _maybe_foul(e, attack, defend, seed)
		if not foul_events.is_empty():
			for f in foul_events:
				output.append(f)
			if String(foul_events[0].get("type", "")) == "foul" and not bool(foul_events[0].get("advantage", false)):
				return output

	if event_type == "shot":
		e["xg"] = clampf(float(e.get("xg", 0.05)) * float(weather.get("shot_factor", 1.0)), 0.005, 0.95)
		if String(e.get("outcome", "")) == "missed":
			var corner_roll := SeededRngClass.unit_for(seed, 94000 + int(e.get("tick", 0)))
			if corner_roll < 0.16:
				output.append(e)
				output.append({"type":"corner","side":side,"minute":int(e.get("minute", 0)),"restart":"corner","success":true})
				return output

	output.append(e)
	return output

func injury_from_event(event: Dictionary, lineup: Array, weather: Dictionary, seed: int) -> Dictionary:
	if String(event.get("type", "")) not in ["foul", "tackle", "dribble", "sprint", "interception"]:
		return {}
	var victim_id := String(event.get("victim_id", event.get("player_id", "")))
	var player := _player(lineup, victim_id)
	if player.is_empty():
		return {}
	var fitness := _quality(player, ["natural_fitness", "stamina", "strength"])
	var base := 0.00012 + (1.0 - fitness) * 0.00045
	if String(event.get("type", "")) == "foul":
		base *= 3.0
	if String(weather.get("kind", "clear")) == "heavy_rain":
		base *= 1.35
	if SeededRngClass.unit_for(seed, 97000 + int(event.get("tick", event.get("minute", 0)))) >= base:
		return {}
	var days := 3 + int(SeededRngClass.value_for(seed, 97100 + int(event.get("minute", 0))) % 35)
	return {"type":"injury","side":String(event.get("side", "home")),"player_id":victim_id,"minute":int(event.get("minute", 0)),"days":days,"severity":"major" if days >= 21 else ("moderate" if days >= 8 else "minor"),"success":false}

func suspension_state(events: Array, rules: Dictionary = {}) -> Dictionary:
	var yellow_limit := int(rules.get("yellow_limit", 5))
	var red_games := int(rules.get("red_games", 1))
	var yellows := {}
	var bans := {}
	for event in events:
		if String(event.get("type", "")) != "card":
			continue
		var id := String(event.get("player_id", ""))
		if String(event.get("card", "")) == "red":
			bans[id] = maxi(int(bans.get(id, 0)), red_games)
		else:
			yellows[id] = int(yellows.get(id, 0)) + 1
			if int(yellows[id]) >= yellow_limit:
				bans[id] = maxi(int(bans.get(id, 0)), 1)
	return {"yellows":yellows,"bans":bans}

func _maybe_foul(event: Dictionary, attack: Array, defend: Array, seed: int) -> Array:
	var minute := int(event.get("minute", 0))
	var side := String(event.get("side", "home"))
	var ball_player := _player(attack, String(event.get("player_id", "")))
	var defender := _nearest_defender(defend, ball_player, seed + minute)
	if defender.is_empty():
		return []
	var tackling := _quality(defender, ["tackling", "decisions", "anticipation"])
	var aggression := _quality(defender, ["aggression", "bravery"])
	var dribbling := _quality(ball_player, ["dribbling", "agility", "balance"])
	var foul_chance := clampf(0.0035 + aggression * 0.012 + dribbling * 0.007 - tackling * 0.009, 0.0015, 0.025)
	if SeededRngClass.unit_for(seed, 95000 + int(event.get("tick", minute))) >= foul_chance:
		return []
	var dangerous := aggression > 0.72 and SeededRngClass.unit_for(seed, 95100 + minute) < 0.22
	var denial := bool(event.get("clear_chance", false))
	var penalty := bool(event.get("in_penalty_area", false))
	var advantage := not penalty and bool(event.get("success", false)) and SeededRngClass.unit_for(seed, 95200 + minute) < 0.28
	var card := ""
	if dangerous or denial:
		card = "red" if dangerous and SeededRngClass.unit_for(seed, 95300 + minute) < 0.16 else "yellow"
	elif SeededRngClass.unit_for(seed, 95400 + minute) < 0.22:
		card = "yellow"
	var result: Array = [{"type":"foul","side":"away" if side == "home" else "home","player_id":String(defender.get("id", "")),"victim_id":String(ball_player.get("id", "")),"minute":minute,"advantage":advantage,"restart":"penalty" if penalty else "direct_free_kick","success":false}]
	if penalty:
		result.append({"type":"penalty_awarded","side":side,"minute":minute,"success":true})
	if card != "":
		result.append({"type":"card","side":"away" if side == "home" else "home","player_id":String(defender.get("id", "")),"minute":minute,"card":card})
	return result

func _offside(receiver: Dictionary, defenders: Array, side: String, tactic: Dictionary) -> bool:
	if receiver.is_empty() or defenders.size() < 2:
		return false
	var rx := float(receiver.get("x", receiver.get("position_x", 52.5)))
	var line: Array = []
	for defender in defenders:
		line.append(float(defender.get("x", defender.get("position_x", 52.5))))
	line.sort()
	var threshold := float(line[line.size() - 2]) if side == "home" else float(line[1])
	var trap_bonus := 1.5 if bool(tactic.get("offside_trap", false)) else 0.0
	return rx > threshold + trap_bonus if side == "home" else rx < threshold - trap_bonus

func _classify_pass(event: Dictionary, passer: Dictionary, receiver: Dictionary) -> void:
	var risk := float(event.get("risk", 0.5))
	if bool(event.get("one_two_intent", false)):
		event["action"] = "one_two"
	elif risk > 0.78:
		event["action"] = "through_ball"
	elif bool(event.get("cross", false)):
		event["action"] = "cross"
	elif String(event.get("outcome", "")) == "recycle":
		event["action"] = "recycle"
	else:
		event["action"] = "pass"
	if receiver.is_empty() and not passer.is_empty():
		event["action"] = "clear" if risk < 0.2 else event["action"]

func _pressure(defenders: Array, player: Dictionary) -> float:
	if player.is_empty() or defenders.is_empty():
		return 0.35
	var work := 0.0
	for defender in defenders:
		work += _quality(defender, ["work_rate", "aggression", "anticipation"])
	return clampf(work / float(defenders.size()), 0.0, 1.0)

func _nearest_defender(defenders: Array, attacker: Dictionary, seed: int) -> Dictionary:
	if defenders.is_empty():
		return {}
	var index := int(SeededRngClass.value_for(seed, 96001) % defenders.size())
	return defenders[index]

func _player(team: Array, player_id: String) -> Dictionary:
	for player in team:
		if String(player.get("id", "")) == player_id:
			return player
	return {}

func _quality(player: Dictionary, keys: Array) -> float:
	if player.is_empty():
		return 0.5
	var attrs: Dictionary = player.get("attributes", player)
	var total := 0.0
	var count := 0
	for key in keys:
		if attrs.has(key):
			var raw := float(attrs.get(key, 10))
			total += clampf(raw / (20.0 if raw <= 20.0 else 100.0), 0.0, 1.0)
			count += 1
	return total / float(count) if count > 0 else clampf(float(player.get("current_ability", 50)) / 100.0, 0.0, 1.0)
