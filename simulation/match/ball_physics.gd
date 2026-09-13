class_name FootballBallPhysics
extends RefCounted

const GRAVITY := 9.81
const AIR_DENSITY := 1.225
const BALL_MASS := 0.43
const BALL_RADIUS := 0.11
const DRAG_COEFFICIENT := 0.25
const MAGNUS_COEFFICIENT := 0.00042
const GROUND_RESTITUTION := 0.52
const GROUND_FRICTION := 0.82
const ROLLING_FRICTION := 0.36
const SPIN_DECAY_AIR := 0.994
const SPIN_DECAY_GROUND := 0.965

static func initial_state(position_2d: Dictionary = {}, z: float = BALL_RADIUS) -> Dictionary:
	return {
		"position":Vector3(float(position_2d.get("x",52.5)), float(position_2d.get("y",34.0)), maxf(BALL_RADIUS,z)),
		"velocity":Vector3.ZERO,
		"spin":Vector3.ZERO,
		"grounded":true,
	}

static func kick(state: Dictionary, target: Vector3, speed: float, lift: float = 0.0, side_spin: float = 0.0, top_spin: float = 0.0) -> void:
	var pos: Vector3 = state.get("position", Vector3(52.5,34.0,BALL_RADIUS))
	var delta := target-pos
	if delta.length_squared() < 0.0001:
		return
	var dir := delta.normalized()
	dir.z = maxf(dir.z,lift)
	dir = dir.normalized()
	state["velocity"] = dir*maxf(0.0,speed)
	state["spin"] = Vector3(top_spin,0.0,side_spin)
	state["grounded"] = false if lift > 0.01 or dir.z > 0.03 else true

static func step(state: Dictionary, dt: float, pitch_length: float = 105.0, pitch_width: float = 68.0) -> void:
	var pos: Vector3 = state.get("position", Vector3(52.5,34.0,BALL_RADIUS))
	var vel: Vector3 = state.get("velocity", Vector3.ZERO)
	var spin: Vector3 = state.get("spin", Vector3.ZERO)
	var grounded := bool(state.get("grounded", pos.z <= BALL_RADIUS+0.001))
	var safe_dt := clampf(dt,0.0001,0.05)

	if not grounded:
		var speed := vel.length()
		if speed > 0.001:
			var area := PI*BALL_RADIUS*BALL_RADIUS
			var drag_force := 0.5*AIR_DENSITY*DRAG_COEFFICIENT*area*speed*speed
			vel += (-vel.normalized()*(drag_force/BALL_MASS))*safe_dt
			var magnus := spin.cross(vel)*MAGNUS_COEFFICIENT
			vel += magnus*safe_dt
		vel.z -= GRAVITY*safe_dt
		spin *= pow(SPIN_DECAY_AIR,safe_dt*40.0)
	else:
		vel.z = 0.0
		var horizontal := Vector2(vel.x,vel.y)
		var hs := horizontal.length()
		if hs > 0.001:
			var decel := ROLLING_FRICTION*GRAVITY*safe_dt
			var next_speed := maxf(0.0,hs-decel)
			horizontal = horizontal.normalized()*next_speed
			vel.x = horizontal.x
			vel.y = horizontal.y
			vel *= pow(GROUND_FRICTION,safe_dt)
		spin *= pow(SPIN_DECAY_GROUND,safe_dt*40.0)

	pos += vel*safe_dt
	if pos.z <= BALL_RADIUS:
		pos.z = BALL_RADIUS
		if vel.z < -0.75:
			vel.z = -vel.z*GROUND_RESTITUTION
			state["grounded"] = false
		else:
			vel.z = 0.0
			state["grounded"] = true
	else:
		state["grounded"] = false

	# Touchline/goal-line bounds are deterministic hard barriers for the physics
	# state. Laws/throw-ins can consume boundary crossings at the event layer.
	if pos.x < 0.0 or pos.x > pitch_length:
		pos.x = clampf(pos.x,0.0,pitch_length)
		vel.x = -vel.x*0.42
	if pos.y < 0.0 or pos.y > pitch_width:
		pos.y = clampf(pos.y,0.0,pitch_width)
		vel.y = -vel.y*0.42

	# Preserve the physical invariant even after long floating-point integration.
	pos.z = maxf(BALL_RADIUS, pos.z)
	state["position"] = pos
	state["velocity"] = vel
	state["spin"] = spin

static func to_2d(state: Dictionary) -> Dictionary:
	var p: Vector3 = state.get("position", Vector3(52.5,34.0,BALL_RADIUS))
	return {"x":p.x,"y":p.y,"z":p.z}
