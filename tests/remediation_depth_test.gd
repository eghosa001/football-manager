extends SceneTree

const RelationshipClass = preload("res://simulation/world/relationship_service.gd")
const SquadPlanningClass = preload("res://simulation/transfers/squad_planning_service.gd")
const StaffOperationsClass = preload("res://simulation/staff/staff_operations_service.gd")
const FacilityProjectsClass = preload("res://simulation/finance/facility_project_service.gd")
const BoardSupporterClass = preload("res://simulation/finance/board_supporter_service.gd")
const AwardsClass = preload("res://simulation/world/award_service.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_relationships()
	_test_squad_planning()
	_test_staff_and_facilities()
	_test_board_and_awards()
	print("[TEST] REMEDIATION DEPTH PASS")
	quit(0)

func _test_relationships() -> void:
	var world := {"season_year":2026,"relationships":[]}
	var service = RelationshipClass.new()
	var row := service.change(world,"p1","p2","friendship",12.0,"shared_success",2026)
	assert(float(row.strength) == 12.0)
	service.process_event(world,{"type":"TRAINING_DISPUTE","season_year":2026,"payload":{"person_a":"p1","person_b":"p3"}})
	assert(not service.relationship(world,"p1","p3","dislike").is_empty())
	service.decay(world,1)
	assert(float(service.relationship(world,"p1","p2","friendship").strength) < 12.0)

func _test_squad_planning() -> void:
	var world := {
		"season_year":2026,
		"players":[
			{"id":"gk1","club_id":"c1","position":"GK","age":32,"current_ability":70,"potential":70,"attributes":{}},
			{"id":"st1","club_id":"c1","position":"ST","age":20,"current_ability":55,"potential":80,"homegrown":true,"attributes":{"pace":70,"off_the_ball":65}}
		],
		"contracts":[{"id":"ct1","player_id":"gk1","club_id":"c1","end_year":2027}]
	}
	var club := {"id":"c1","tactic":{"directness":"direct"},"homegrown_min":2}
	var service = SquadPlanningClass.new()
	var plan := service.build_plan(world,club,3)
	assert(not (plan.needs as Array).is_empty())
	assert(not (plan.succession as Array).is_empty())
	var target := {"id":"target","position":"ST","age":21,"current_ability":72,"potential":86,"homegrown":true,"attributes":{"pace":80,"off_the_ball":78}}
	assert(float(service.evaluate_target(world,club,target,plan).score) > 0.0)

func _test_staff_and_facilities() -> void:
	var world := {
		"season_year":2026,
		"clubs":[{"id":"c1","cash":100000000,"reputation":70,"board_confidence":75,"training_facilities":50}],
		"staff":[{"id":"s1","club_id":"c1","role":"coach","ability":75,"license":"continental_a","specialisms":{"attacking":82}}]
	}
	var staff = StaffOperationsClass.new()
	var load := staff.assign(world,"c1","s1",["attacking","possession"])
	assert(not bool(load.overloaded))
	assert(staff.coaching_quality(world,"c1","attacking") > 50.0)
	var course := staff.enroll_course(world,world.staff[0],"continental_pro",10000,30)
	staff.advance_courses(world,30)
	assert(String(course.status) == "complete")
	assert(String(world.staff[0].license) == "continental_pro")
	var facilities = FacilityProjectsClass.new()
	var project := facilities.propose(world,world.clubs[0],"training",55)
	assert(String(project.status) == "approved")
	assert(String(facilities.start(world,world.clubs[0],project).status) == "construction")
	facilities.advance(world,365)
	assert(String(project.status) == "complete")
	assert(int(world.clubs[0].training_facilities) == 55)

func _test_board_and_awards() -> void:
	var world := {
		"season_year":2026,
		"clubs":[{"id":"c1","name":"Club","cash":10000000,"board_confidence":60}],
		"players":[{"id":"p1","club_id":"c1","age":20,"position":"ST"},{"id":"p2","club_id":"c1","age":28,"position":"MC"}],
		"competitions":[{"id":"league","reputation":80}],
		"player_match_stats":[
			{"season_year":2026,"competition_id":"league","player_id":"p1","minutes":90,"goals":2,"assists":1,"rating":8.5,"xg":1.2},
			{"season_year":2026,"competition_id":"league","player_id":"p1","minutes":90,"goals":1,"assists":0,"rating":8.0,"xg":0.8},
			{"season_year":2026,"competition_id":"league","player_id":"p1","minutes":90,"goals":1,"assists":1,"rating":8.2,"xg":0.9},
			{"season_year":2026,"competition_id":"league","player_id":"p2","minutes":90,"goals":0,"assists":1,"rating":7.1},
			{"season_year":2026,"competition_id":"league","player_id":"p2","minutes":90,"goals":0,"assists":0,"rating":7.0},
			{"season_year":2026,"competition_id":"league","player_id":"p2","minutes":90,"goals":0,"assists":1,"rating":7.2}
		]
	}
	var board = BoardSupporterClass.new()
	var manager := {"id":"m1","reputation":70}
	board.ensure_club(world,world.clubs[0])
	var eval := board.evaluate_manager(world,world.clubs[0],manager,{"results_score":0.8,"finance_score":0.7,"youth_score":0.7,"style_score":0.6,"identity_score":0.6})
	assert(float(eval.score) > 0.5)
	var awards = AwardsClass.new()
	var rows := awards.calculate_season_awards(world,2026,"league")
	assert(not rows.is_empty())
	var found_player := false
	for award in rows:
		if String(award.get("type","")) == "player_of_the_year":
			found_player = true
			assert(String(award.player_id) == "p1")
	assert(found_player)
