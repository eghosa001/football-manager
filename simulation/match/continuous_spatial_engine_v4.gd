class_name ContinuousSpatialEngineV4
extends "res://simulation/match/continuous_spatial_engine_v3.gd"

const MotionClass = preload("res://simulation/match/player_motion.gd")
const SpatialHashClass = preload("res://simulation/match/spatial_hash.gd")

const MIN_PLAYER_SEPARATION := 1.65
const SPACING_PUSH := 0.34
const PERCEPTION_REFRESH_TICKS := 2
const STATE_REFRESH_TICKS := 3
const PERCEPTION_RANGE := 32.0

var _motion_states: Dictionary = {}
var _perception_cache: Dictionary = {}
var _context_states: Dictionary = {}
var _grid = SpatialHashClass.new(6.0)

func _move_side(lineup: Array, own: Dictionary, opp: Dictionary, ball: Dictionary, profile: Dictionary, loads: Dictionary, marking: Dictionary, in_possession: bool, dt: float, tick: int) -> void:
	var before: Dictionary = {}
	for player in lineup:
		var pid := String(player.get("id", ""))
		if pid != "" and own.has(pid):
			before[pid] = (own[pid] as Dictionary).duplicate(true)

	# v3 computes the tactical target and physical load. We then reinterpret the
	# proposed point as steering intent so acceleration, braking and turning are
	# continuous instead of marker-like point stepping.
	super._move_side(lineup, own, opp, ball, profile, loads, marking, in_possession, dt, tick)
	_grid.clear()
	for own_id in own.keys(): _grid.insert(String(own_id), own[own_id], "own")
	for opp_id in opp.keys(): _grid.insert(String(opp_id), opp[opp_id], "opp")
	var ball_v := Vector2(float(ball.get("x",0.0)),float(ball.get("y",0.0)))

	for i in range(1,lineup.size()):
		var player: Dictionary = lineup[i]
		var id := String(player.get("id", ""))
		if id == "" or not before.has(id) or not own.has(id):
			continue
		var previous: Dictionary = before[id]
		var proposed: Dictionary = own[id]
		var state: Dictionary = _motion_states.get(id, {})
		if state.is_empty():
			var facing := Vector2.RIGHT if float(proposed.get("x",0.0)) >= float(previous.get("x",0.0)) else Vector2.LEFT
			state = MotionClass.make_state(previous,facing)
		else:
			state["position"] = Vector2(float(previous.get("x",0.0)),float(previous.get("y",0.0)))

		if tick % PERCEPTION_REFRESH_TICKS == 0 or not _perception_cache.has(id):
			var fov := lerpf(105.0,155.0,_quality(player,["vision","anticipation","concentration"]))
			_perception_cache[id] = MotionClass.can_perceive(state,ball_v,PERCEPTION_RANGE,fov)
		var target := Vector2(float(proposed.get("x",0.0)),float(proposed.get("y",0.0)))
		var previous_v := Vector2(float(previous.get("x",0.0)),float(previous.get("y",0.0)))
		if not in_possession and not bool(_perception_cache.get(id,true)) and previous_v.distance_to(ball_v) > 12.0:
			var anchor: Dictionary = _role_anchor(player,i,profile)
			target = target.lerp(Vector2(float(anchor.x),float(anchor.y)),0.48)

		var athleticism := _quality(player,["pace","acceleration","agility"])
		var max_speed := lerpf(5.8,9.1,athleticism)
		var accel := lerpf(3.8,7.2,_quality(player,["acceleration","agility","balance"]))
		var decel := lerpf(5.0,8.6,_quality(player,["agility","balance","strength"]))
		var turn_rate := lerpf(3.1,6.4,_quality(player,["agility","balance","technique"]))
		MotionClass.step(state,target,dt,max_speed,accel,decel,turn_rate)
		var p: Vector2 = state.position
		own[id] = SpatialStateClass.clamp_position({"x":p.x,"y":p.y})
		_motion_states[id] = state

		if tick % STATE_REFRESH_TICKS == 0 or not _context_states.has(id):
			var nearby := _grid.query_radius(own[id],12.0,id,"opp")
			var opponent_distance := 99.0 if nearby.is_empty() else float(nearby[0].distance)
			_context_states[id] = MotionClass.contextual_state(in_possession,false,p.distance_to(ball_v),opponent_distance,float(p.x)/PITCH_LENGTH)

	_resolve_team_spacing(lineup,own)
	_keep_outfield_inside_playable_lane(lineup,own)

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

func runtime_player_state(player_id: String) -> Dictionary:
	var state: Dictionary = _motion_states.get(player_id, {}).duplicate(true)
	if not state.is_empty():
		state["context"] = String(_context_states.get(player_id,"shape"))
		state["perceives_ball"] = bool(_perception_cache.get(player_id,true))
	return state

func _trait_key(text: String) -> int:
	var value := 97
	for character in text.to_utf8_buffer():
		value = posmod(value * 199 + int(character), 2_147_483_647)
	return value
