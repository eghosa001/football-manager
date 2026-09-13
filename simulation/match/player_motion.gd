class_name FootballPlayerMotion
extends RefCounted

const DEFAULT_MAX_ACCEL := 5.8
const DEFAULT_MAX_DECEL := 7.2
const DEFAULT_TURN_RATE := 4.8
const DEFAULT_MAX_SPEED := 8.4

static func make_state(position: Dictionary, facing: Vector2 = Vector2.RIGHT) -> Dictionary:
	var p := Vector2(float(position.get("x",0.0)),float(position.get("y",0.0)))
	return {"position":p,"velocity":Vector2.ZERO,"facing":facing.normalized() if facing.length_squared()>0.001 else Vector2.RIGHT,"state":"shape","intent":"hold"}

static func step(state: Dictionary, target: Vector2, dt: float, max_speed: float = DEFAULT_MAX_SPEED, max_accel: float = DEFAULT_MAX_ACCEL, max_decel: float = DEFAULT_MAX_DECEL, turn_rate: float = DEFAULT_TURN_RATE) -> void:
	var pos: Vector2 = state.get("position",Vector2.ZERO)
	var velocity: Vector2 = state.get("velocity",Vector2.ZERO)
	var facing: Vector2 = state.get("facing",Vector2.RIGHT)
	var offset := target-pos
	var distance := offset.length()
	var desired := Vector2.ZERO
	if distance > 0.02:
		var braking_distance := maxf(0.5,velocity.length()*velocity.length()/(2.0*maxf(max_decel,0.1)))
		var desired_speed := max_speed*clampf(distance/braking_distance,0.18,1.0) if distance < braking_distance else max_speed
		desired = offset.normalized()*desired_speed
	var dv := desired-velocity
	var accelerating := desired.length() >= velocity.length()
	var limit := (max_accel if accelerating else max_decel)*dt
	if dv.length() > limit:
		dv = dv.normalized()*limit
	velocity += dv
	if velocity.length() > max_speed:
		velocity = velocity.normalized()*max_speed
	if velocity.length_squared() > 0.03:
		var desired_facing := velocity.normalized()
		var angle := facing.angle_to(desired_facing)
		var max_turn := turn_rate*dt
		facing = facing.rotated(clampf(angle,-max_turn,max_turn)).normalized()
		var corner_factor := clampf(1.0-absf(angle)/PI*0.42,0.58,1.0)
		velocity *= corner_factor
	pos += velocity*dt
	state["position"] = pos
	state["velocity"] = velocity
	state["facing"] = facing

static func can_perceive(observer: Dictionary, target: Vector2, max_distance: float, fov_degrees: float = 130.0) -> bool:
	var pos: Vector2 = observer.get("position",Vector2.ZERO)
	var facing: Vector2 = observer.get("facing",Vector2.RIGHT)
	var delta := target-pos
	if delta.length() > max_distance:
		return false
	if delta.length_squared() < 0.001:
		return true
	var half_angle := deg_to_rad(clampf(fov_degrees,20.0,360.0)*0.5)
	return absf(facing.angle_to(delta.normalized())) <= half_angle

static func contextual_state(in_possession: bool, owns_ball: bool, ball_distance: float, opponent_distance: float, goal_side: float) -> String:
	if owns_ball:
		return "dribbling"
	if in_possession:
		return "receiving" if ball_distance < 8.0 else "supporting"
	if ball_distance < 6.0:
		return "pressing"
	if opponent_distance < 4.0:
		return "tracking"
	return "covering" if goal_side < 0.5 else "recovering"
