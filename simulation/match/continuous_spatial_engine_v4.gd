class_name ContinuousSpatialEngineV4
extends "res://simulation/match/continuous_spatial_engine_v3.gd"

const MIN_PLAYER_SEPARATION := 1.65
const SPACING_PUSH := 0.34

func _move_side(lineup: Array, own: Dictionary, opp: Dictionary, ball: Dictionary, profile: Dictionary, loads: Dictionary, marking: Dictionary, in_possession: bool, dt: float, tick: int) -> void:
	# Keep the v3 tactical/physical movement model as the source of truth, then
	# resolve unrealistic same-point convergence. This preserves deterministic
	# decisions and fitness load while making press/support movement read like
	# football rather than markers collapsing into one coordinate.
	super._move_side(lineup, own, opp, ball, profile, loads, marking, in_possession, dt, tick)
	_resolve_team_spacing(lineup, own)
	_keep_outfield_inside_playable_lane(lineup, own)

func _resolve_team_spacing(lineup: Array, positions: Dictionary) -> void:
	for i in range(1, lineup.size()):
		var a_id := String(lineup[i].get("id", ""))
		if a_id == "" or not positions.has(a_id):
			continue
		for j in range(i + 1, lineup.size()):
			var b_id := String(lineup[j].get("id", ""))
			if b_id == "" or not positions.has(b_id):
				continue
			var a: Dictionary = positions[a_id]
			var b: Dictionary = positions[b_id]
			var dx := float(b.get("x", 0.0)) - float(a.get("x", 0.0))
			var dy := float(b.get("y", 0.0)) - float(a.get("y", 0.0))
			var distance := sqrt(dx * dx + dy * dy)
			if distance >= MIN_PLAYER_SEPARATION:
				continue
			var nx: float
			var ny: float
			if distance < 0.001:
				# Stable tie-breaker instead of random jitter.
				var sign := -1.0 if String(a_id) < String(b_id) else 1.0
				nx = 0.35 * sign
				ny = 0.94
				distance = 1.0
			else:
				nx = dx / distance
				ny = dy / distance
			var overlap := (MIN_PLAYER_SEPARATION - distance) * 0.5 * SPACING_PUSH
			a = SpatialStateClass.clamp_position({"x": float(a.x) - nx * overlap, "y": float(a.y) - ny * overlap})
			b = SpatialStateClass.clamp_position({"x": float(b.x) + nx * overlap, "y": float(b.y) + ny * overlap})
			positions[a_id] = a
			positions[b_id] = b

func _keep_outfield_inside_playable_lane(lineup: Array, positions: Dictionary) -> void:
	for i in range(1, lineup.size()):
		var id := String(lineup[i].get("id", ""))
		if id == "" or not positions.has(id):
			continue
		var pos: Dictionary = positions[id]
		# Small safety gutter keeps labels/markers readable and prevents tactical
		# targets from pinning outfield players exactly onto the touchline.
		pos.x = clampf(float(pos.get("x", 0.0)), 0.75, PITCH_LENGTH - 0.75)
		pos.y = clampf(float(pos.get("y", 0.0)), 0.75, PITCH_WIDTH - 0.75)
		positions[id] = pos

func _decide_action(ball: Dictionary, owner: Dictionary, possession: String, home_lineup: Array, away_lineup: Array, home_pos: Dictionary, away_pos: Dictionary, home_profile: Dictionary, away_profile: Dictionary, loads: Dictionary, seed: int, tick: int) -> Dictionary:
	var outcome: Dictionary = super._decide_action(ball, owner, possession, home_lineup, away_lineup, home_pos, away_pos, home_profile, away_profile, loads, seed, tick)
	var team: Array = home_lineup if possession == "home" else away_lineup
	var player: Dictionary = _player_by_id(team, String(owner.get("id", "")))
	var traits: Array = player.get("traits", [])
	if traits.is_empty():
		return outcome
	var direction := 1.0 if possession == "home" else -1.0
	var event_type := String(outcome.get("event", ""))
	var roll := SeededRngClass.unit_for(seed, 32000 + tick + _trait_key(String(player.get("id", ""))))

	# Traits modify action-selection weights rather than granting attribute bonuses.
	if "tries_long_shots" in traits and event_type not in ["shot", "goal"]:
		var goal_x := PITCH_LENGTH if possession == "home" else 0.0
		var distance := absf(goal_x - float(ball.x))
		if distance < 42.0 and roll < 0.18:
			var finishing := _quality(player, ["long_shots", "finishing", "composure"])
			var xg := clampf((0.23 - distance / 240.0) * lerpf(0.72, 1.25, finishing), 0.01, 0.22)
			outcome = {"possession":possession,"owner_id":String(owner.get("id", "")),"target":{"x":goal_x,"y":PITCH_WIDTH*0.5},"event":"shot","xg":xg,"outcome":"missed","success":false,"trait":"tries_long_shots"}
	elif "runs_with_ball" in traits and event_type == "pass" and roll < 0.24:
		outcome["event"] = "dribble"
		outcome["owner_id"] = String(owner.get("id", ""))
		outcome["target"] = SpatialStateClass.clamp_position({"x":float(ball.x)+direction*7.0,"y":float(ball.y)})
		outcome["success"] = true
		outcome["trait"] = "runs_with_ball"
		outcome.erase("receiver_id")
		outcome.erase("target_id")
	elif "plays_one_twos" in traits and event_type == "pass" and roll < 0.30:
		outcome["trait"] = "plays_one_twos"
		outcome["one_two_intent"] = true
	elif "switches_ball" in traits and event_type == "pass" and roll < 0.26:
		var target: Dictionary = outcome.get("target", ball).duplicate(true)
		target.y = clampf(PITCH_WIDTH - float(target.get("y", ball.y)), 2.0, PITCH_WIDTH - 2.0)
		outcome["target"] = target
		outcome["trait"] = "switches_ball"

	if String(outcome.get("event", "")) == "dribble":
		var target: Dictionary = outcome.get("target", ball).duplicate(true)
		if "cuts_inside" in traits:
			target.y = lerpf(float(target.get("y", ball.y)), PITCH_WIDTH * 0.5, 0.55)
			outcome["trait"] = "cuts_inside"
		elif "stays_wide" in traits:
			var current_y := float(ball.get("y", PITCH_WIDTH * 0.5))
			target.y = 4.0 if current_y < PITCH_WIDTH * 0.5 else PITCH_WIDTH - 4.0
			outcome["trait"] = "stays_wide"
		if "beats_offside_trap" in traits:
			target.x = clampf(float(target.get("x", ball.x)) + direction * 4.0, 0.0, PITCH_LENGTH)
			outcome["trait_run_in_behind"] = true
		if "drops_deep" in traits and roll < 0.22:
			target.x = clampf(float(target.get("x", ball.x)) - direction * 4.5, 0.0, PITCH_LENGTH)
			outcome["trait_drops_deep"] = true
		outcome["target"] = SpatialStateClass.clamp_position(target)

	if "avoids_weak_foot" in traits:
		outcome["preferred_foot_bias"] = true
	return outcome

func _trait_key(text: String) -> int:
	var value := 97
	for character in text.to_utf8_buffer():
		value = posmod(value * 199 + int(character), 2_147_483_647)
	return value
