class_name ContinuousSpatialEngineV5
extends "res://simulation/match/continuous_spatial_engine_v4.gd"

const MotionClass = preload("res://simulation/match/player_motion.gd")
const SpatialHashClass = preload("res://simulation/match/spatial_hash.gd")

# Physics remains bounded for mobile. The engine advances authoritative motion at
# 20 Hz; expensive perception/tactical work is decimated below that frequency.
const AUTHORITATIVE_HZ := 20.0
const PERCEPTION_REFRESH_TICKS := 4 # 5 Hz
const STATE_REFRESH_TICKS := 5 # 4 Hz
const PERCEPTION_RANGE := 32.0

var _motion_states: Dictionary = {}
var _perception_cache: Dictionary = {}
var _context_states: Dictionary = {}
var _grid = SpatialHashClass.new(6.0)

func reset_runtime_state() -> void:
	_motion_states.clear()
	_perception_cache.clear()
	_context_states.clear()
	_grid.clear()

func _move_side(lineup: Array, own: Dictionary, opp: Dictionary, ball: Dictionary, profile: Dictionary, loads: Dictionary, marking: Dictionary, in_possession: bool, dt: float, tick: int) -> void:
	# Let v4 compute tactical intent/spacing, but treat that result as a steering
	# target rather than teleporting directly to it. This gives acceleration,
	# braking and turn-rate limits without rewriting tactical decisions.
	var before: Dictionary = {}
	for player in lineup:
		var id := String(player.get("id", ""))
		if id != "" and own.has(id):
			before[id] = (own[id] as Dictionary).duplicate(true)

	super._move_side(lineup, own, opp, ball, profile, loads, marking, in_possession, dt, tick)
	_grid.clear()
	for id in own.keys(): _grid.insert(String(id), own[id], "own")
	for id in opp.keys(): _grid.insert(String(id), opp[id], "opp")
	var ball_v := Vector2(float(ball.get("x", 0.0)), float(ball.get("y", 0.0)))

	for i in range(1, lineup.size()):
		var player: Dictionary = lineup[i]
		var id := String(player.get("id", ""))
		if id == "" or not own.has(id) or not before.has(id):
			continue
		var previous: Dictionary = before[id]
		var proposed: Dictionary = own[id]
		var state: Dictionary = _motion_states.get(id, {})
		if state.is_empty():
			var facing := Vector2.RIGHT if float(proposed.get("x",0.0)) >= float(previous.get("x",0.0)) else Vector2.LEFT
			state = MotionClass.make_state(previous, facing)
		else:
			state["position"] = Vector2(float(previous.get("x",0.0)),float(previous.get("y",0.0)))

		if tick % PERCEPTION_REFRESH_TICKS == 0 or not _perception_cache.has(id):
			_perception_cache[id] = MotionClass.can_perceive(state, ball_v, PERCEPTION_RANGE, lerpf(105.0,155.0,_quality(player,["vision","anticipation","concentration"])))
		var sees_ball := bool(_perception_cache.get(id, true))
		var target := Vector2(float(proposed.get("x",0.0)),float(proposed.get("y",0.0)))
		if not in_possession and not sees_ball and Vector2(float(previous.x),float(previous.y)).distance_to(ball_v) > 12.0:
			# A player who cannot currently perceive the ball keeps tactical shape
			# instead of reacting omnisciently to every movement behind them.
			var anchor: Dictionary = _role_anchor(player, i, profile)
			target = target.lerp(Vector2(float(anchor.x),float(anchor.y)),0.48)

		var athleticism := _quality(player,["pace","acceleration","agility"])
		var max_speed := lerpf(5.8,9.1,athleticism)
		var accel := lerpf(3.8,7.2,_quality(player,["acceleration","agility","balance"]-[]))
		var decel := lerpf(5.0,8.6,_quality(player,["agility","balance","strength"]-[]))
		var turn_rate := lerpf(3.1,6.4,_quality(player,["agility","balance","technique"]-[]))
		MotionClass.step(state,target,dt,max_speed,accel,decel,turn_rate)
		var p: Vector2 = state.position
		own[id] = SpatialStateClass.clamp_position({"x":p.x,"y":p.y})
		_motion_states[id] = state

		if tick % STATE_REFRESH_TICKS == 0 or not _context_states.has(id):
			var nearest := _grid.query_radius(own[id],12.0,id,"opp")
			var opponent_distance := 99.0 if nearest.is_empty() else float(nearest[0].distance)
			var ball_distance := p.distance_to(ball_v)
			_context_states[id] = MotionClass.contextual_state(in_possession,false,ball_distance,opponent_distance,float(p.x)/PITCH_LENGTH)

	_resolve_team_spacing(lineup,own)
	_keep_outfield_inside_playable_lane(lineup,own)

func runtime_player_state(player_id: String) -> Dictionary:
	var state: Dictionary = _motion_states.get(player_id, {}).duplicate(true)
	if not state.is_empty():
		state["context"] = String(_context_states.get(player_id,"shape"))
		state["perceives_ball"] = bool(_perception_cache.get(player_id,true))
	return state
