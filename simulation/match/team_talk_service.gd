class_name TeamTalkService
extends RefCounted

# Half-time/full-time/pre-match team talks plus live touchline shouts.
# Tones interact with player personalities (professionalism, pressure,
# determination, temperament) and match context (scoreline vs expectation)
# to move morale and motivation deterministically. Manual-only: the manager
# delivers talks through career commands; nothing auto-fires in pipelines.

const SeededRngClass = preload("res://core/rng/seeded_rng.gd")
const InboxServiceClass = preload("res://application/career/inbox_service.gd")

const TONES := ["passionate", "assertive", "calm", "demanding"]
const MOMENTS := ["pre_match", "half_time", "full_time"]
const SHOUTS := ["encourage", "demand_more", "calm_down", "praise", "berate", "tactical_refocus"]

func deliver_talk(world: Dictionary, club_id: String, tone: String, moment: String, context: Dictionary = {}, seed: int = 1) -> Dictionary:
	if tone not in TONES or moment not in MOMENTS:
		return {"error": ERR_INVALID_PARAMETER}
	var squad := _squad(world.get("players", []), club_id)
	if squad.is_empty():
		return {"error": ERR_DOES_NOT_EXIST}
	var expectation := _expectation(world, club_id, String(context.get("opponent_id", "")), String(context.get("venue", "home")))
	var goal_diff := int(context.get("goal_difference", 0))
	var reactions: Array = []
	var morale_delta_total := 0.0
	for player in squad:
		var reaction := _player_reaction(player, tone, moment, goal_diff, expectation, seed)
		reactions.append(reaction)
		player["morale"] = clampi(int(player.get("morale", 60)) + int(reaction.get("morale_delta", 0)), 1, 100)
		player["motivation"] = clampi(int(player.get("motivation", 60)) + int(reaction.get("motivation_delta", 0)), 1, 100)
		morale_delta_total += float(reaction.get("morale_delta", 0))
	_inbox(world, club_id, tone, moment, reactions, seed)
	return {
		"club_id": club_id, "tone": tone, "moment": moment,
		"players_addressed": squad.size(),
		"average_morale_delta": snappedf(morale_delta_total / maxf(1.0, float(squad.size())), 0.01),
		"reactions": reactions,
	}

func touchline_shout(world: Dictionary, club_id: String, shout: String, context: Dictionary = {}, seed: int = 1) -> Dictionary:
	if shout not in SHOUTS:
		return {"error": ERR_INVALID_PARAMETER}
	var squad := _squad(world.get("players", []), club_id)
	if squad.is_empty():
		return {"error": ERR_DOES_NOT_EXIST}
	var minute := int(context.get("minute", 60))
	var losing := int(context.get("goal_difference", 0)) < 0
	var effects: Array = []
	for player in squad:
		var hidden: Dictionary = player.get("hidden_attributes", {})
		var professionalism := float(hidden.get("professionalism", 50))
		var pressure := float(hidden.get("pressure", 50))
		var temperament := float(hidden.get("temperament", 50))
		var morale_delta := 0
		var motivation_delta := 0
		match shout:
			"encourage":
				morale_delta = 2 if pressure >= 40.0 else 1
				motivation_delta = 2
			"demand_more":
				motivation_delta = 3 if professionalism >= 55.0 else -1
				morale_delta = -2 if temperament < 35.0 else 0
			"calm_down":
				morale_delta = 1 if losing else 0
				motivation_delta = -1
			"praise":
				morale_delta = 2
				motivation_delta = 1
			"berate":
				motivation_delta = 2 if professionalism >= 70.0 else -2
				morale_delta = -3 if temperament < 50.0 else -1
			"tactical_refocus":
				motivation_delta = 1
				morale_delta = 1 if professionalism >= 60.0 else 0
		if minute >= 75:
			motivation_delta += 1
		player["morale"] = clampi(int(player.get("morale", 60)) + morale_delta, 1, 100)
		player["motivation"] = clampi(int(player.get("motivation", 60)) + motivation_delta, 1, 100)
		effects.append({"player_id": String(player.get("id", "")), "morale_delta": morale_delta, "motivation_delta": motivation_delta})
	return {"club_id": club_id, "shout": shout, "minute": minute, "effects": effects}

func _player_reaction(player: Dictionary, tone: String, moment: String, goal_diff: int, expectation: float, seed: int) -> Dictionary:
	var hidden: Dictionary = player.get("hidden_attributes", {})
	var professionalism := float(hidden.get("professionalism", 50))
	var pressure := float(hidden.get("pressure", 50))
	var determination := float(hidden.get("determination", player.get("current_ability", 50) * 0.7))
	var temperament := float(hidden.get("temperament", 50))
	var jitter := float(SeededRngClass.value_for(seed, _stable_key(String(player.get("id", "")) + tone + moment)) % 5) - 2.0
	var morale_delta := 0.0
	var motivation_delta := 0.0
	var note := ""
	match tone:
		"passionate":
			if moment == "pre_match":
				morale_delta = 3.0 if determination >= 55.0 else 1.0
				motivation_delta = 3.0
				note = "fired up"
			elif moment == "half_time" and goal_diff < 0:
				morale_delta = 2.0 if temperament >= 45.0 else -2.0
				motivation_delta = 3.0
				note = "rallying cry" if temperament >= 45.0 else "lost the room"
			else:
				morale_delta = 2.0
				motivation_delta = 2.0
				note = "emotional"
		"assertive":
			morale_delta = 2.0 if professionalism >= 55.0 else -1.0
			motivation_delta = 2.0
			note = "took it on board" if professionalism >= 55.0 else "switched off"
		"calm":
			morale_delta = 2.0 if pressure < 60.0 else 3.0
			motivation_delta = 1.0
			note = "settled nerves"
		"demanding":
			if expectation >= 0.6 and goal_diff <= 0:
				morale_delta = -1.0 if temperament < 55.0 else 1.0
				motivation_delta = 3.0 if professionalism >= 60.0 else -1.0
				note = "demanded a response"
			else:
				morale_delta = 1.0
				motivation_delta = 2.0
				note = "laid down a marker"
	morale_delta += jitter * 0.4
	return {"player_id": String(player.get("id", "")), "morale_delta": int(round(morale_delta)), "motivation_delta": int(round(motivation_delta)), "note": note}

func _expectation(world: Dictionary, club_id: String, opponent_id: String, venue: String) -> float:
	var club := _club(world.get("clubs", []), club_id)
	var opponent := _club(world.get("clubs", []), opponent_id)
	if club.is_empty() or opponent.is_empty():
		return 0.5
	var edge := float(club.get("reputation", 50)) - float(opponent.get("reputation", 50))
	if venue == "home":
		edge += 5.0
	return clampf(0.5 + edge / 60.0, 0.05, 0.95)

func _inbox(world: Dictionary, club_id: String, tone: String, moment: String, reactions: Array, seed: int) -> void:
	var positive := 0
	for reaction in reactions:
		if int(reaction.get("morale_delta", 0)) > 0:
			positive += 1
	InboxServiceClass.new().add_message(world, "dressing_room", "Team talk delivered (%s)" % tone, "%s %s address: %d of %d players responded positively." % [String(moment).replace("_", " ").capitalize(), tone, positive, reactions.size()])

func _squad(players: Array, club_id: String) -> Array:
	var result: Array = []
	for player in players:
		if String(player.get("club_id", "")) == club_id and not bool(player.get("retired", false)):
			result.append(player)
	return result

func _club(clubs: Array, club_id: String) -> Dictionary:
	for club in clubs:
		if String(club.get("id", "")) == club_id:
			return club
	return {}

func _stable_key(text: String) -> int:
	var value := 149
	for character in text.to_utf8_buffer():
		value = posmod(value * 163 + int(character), 2_147_483_647)
	return value
