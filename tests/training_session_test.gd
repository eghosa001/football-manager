extends SceneTree

const WorldGenerator = preload("res://simulation/world/world_generator.gd")
const TrainingSystem = preload("res://simulation/players/training_system.gd")
const TacticsManager = preload("res://simulation/tactics/tactics_manager.gd")

var checks := 0
var failures := 0

func _init() -> void:
	var world := WorldGenerator.new().create_world(88401,1,4,20)
	var club: Dictionary = world.clubs[0]
	club["tactic"] = TacticsManager.new().create_tactic("4-3-3")
	var system = TrainingSystem.new()
	var schedule := ["attacking","defending","possession","tactical","set_piece","match_preparation","recovery"]
	_expect(system.set_schedule(club,schedule,0.75)==OK,"Full v1 training session vocabulary must be accepted")
	var before := float(club.tactic.familiarity)
	var report := system.run_week(world,String(club.id),88402)
	_expect(not report.has("error"),"Complete training schedule must execute")
	_expect(float(club.tactic.familiarity)>before,"Tactical and match-preparation sessions must increase familiarity")
	_expect(int(report.session_mix.counts.attacking)==1 and int(report.session_mix.counts.defending)==1 and int(report.session_mix.counts.possession)==1,"Training report must retain attacking, defending and possession session mix")
	_expect(system.set_schedule(club,["recovery","technical","tactical","physical","set_pieces","match_prep","rest"],0.65)==OK,"Legacy training session names must migrate without breaking old saves")
	system.ensure_club(club)
	_expect("set_piece" in club.training_schedule and "match_preparation" in club.training_schedule,"Legacy set-piece and match-prep names must normalize to canonical names")
	if failures==0:
		print("[TEST] TRAINING SESSIONS PASS — %d checks"%checks); quit(0)
	else:
		push_error("[TEST] TRAINING SESSIONS FAIL — %d failures across %d checks"%[failures,checks]); quit(1)

func _expect(condition:bool,message:String)->void:
	checks+=1
	if not condition:
		failures+=1
		push_error("[TEST] "+message)
