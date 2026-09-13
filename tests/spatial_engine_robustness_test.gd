extends SceneTree

const HashClass = preload("res://simulation/match/spatial_hash.gd")
const BallClass = preload("res://simulation/match/ball_physics.gd")
const MotionClass = preload("res://simulation/match/player_motion.gd")
const SessionClass = preload("res://application/career/career_session.gd")
const DayRunnerClass = preload("res://application/career/day_runner.gd")

func _init() -> void:
	_test_spatial_hash()
	_test_ball_determinism()
	_test_motion_and_perception()
	_test_managed_match_continue()
	print("[TEST] SPATIAL ENGINE ROBUSTNESS PASS")
	quit(0)

func _test_spatial_hash() -> void:
	var grid = HashClass.new(5.0)
	grid.rebuild({"h1":{"x":10.0,"y":10.0},"h2":{"x":40.0,"y":40.0}}, {"a1":{"x":12.0,"y":10.0}})
	var near := grid.query_radius({"x":10.0,"y":10.0},5.0,"h1","away")
	assert(near.size() == 1)
	assert(String(near[0].id) == "a1")

func _test_ball_determinism() -> void:
	var a := BallClass.initial_state({"x":30.0,"y":20.0})
	var b := BallClass.initial_state({"x":30.0,"y":20.0})
	BallClass.kick(a,Vector3(65.0,35.0,1.4),24.0,0.18,14.0,-3.0)
	BallClass.kick(b,Vector3(65.0,35.0,1.4),24.0,0.18,14.0,-3.0)
	for _i in range(160):
		BallClass.step(a,1.0/40.0)
		BallClass.step(b,1.0/40.0)
	assert((a.position as Vector3).distance_to(b.position as Vector3) < 0.00001)
	assert((a.velocity as Vector3).distance_to(b.velocity as Vector3) < 0.00001)
	assert(float((a.position as Vector3).z) >= BallClass.BALL_RADIUS)

func _test_motion_and_perception() -> void:
	var state := MotionClass.make_state({"x":20.0,"y":30.0},Vector2.RIGHT)
	for _i in range(20):
		MotionClass.step(state,Vector2(35.0,30.0),0.1,8.0,5.5,7.0,4.0)
	assert((state.position as Vector2).x > 20.0)
	assert((state.velocity as Vector2).length() <= 8.001)
	assert(MotionClass.can_perceive(state,Vector2(40.0,30.0),30.0,120.0))
	assert(not MotionClass.can_perceive(state,Vector2(0.0,30.0),30.0,90.0))

func _test_managed_match_continue() -> void:
	var session = SessionClass.new()
	var created: Dictionary = session.new_career("SpatialCI","eng-t1-c01",77119)
	assert(not created.has("error"))
	session.world["detailed_match_model"] = "continuous"
	# Opening league fixtures are scheduled for 1 August in the launch world.
	session.world["date"] = "2026-07-31"
	var started := Time.get_ticks_msec()
	var result: Dictionary = DayRunnerClass.new().advance_day(session.world,session.history,77120)
	var elapsed := Time.get_ticks_msec()-started
	assert(not result.has("error"))
	assert(int(result.get("fixtures_played",0)) > 0)
	assert(session.world.has("last_managed_match"))
	var last: Dictionary = session.world.last_managed_match
	assert(String(last.get("model","")) == "continuous")
	var frames: Array = last.get("result",{}).get("spatial",{}).get("frames",[])
	assert(not frames.is_empty())
	# Guard against accidental unbounded replay capture on phones/laptops.
	assert(frames.size() <= 4000)
	print("[SPATIAL] managed match %d ms; %d replay frames" % [elapsed,frames.size()])
