extends SceneTree

const WorldGenerator = preload("res://simulation/world/world_generator.gd")
const StadiumService = preload("res://simulation/finance/stadium_service.gd")

var checks := 0
var failures := 0

func _init() -> void:
	var world := WorldGenerator.new().create_world(88301,1,4,20)
	var club: Dictionary = world.clubs[0]
	club["cash"] = 100_000_000
	var service = StadiumService.new()
	service.ensure_club(club)
	var before_cash := int(club.cash)
	var before_capacity := int(club.stadium.capacity)
	club.stadium.expansion_capacity = before_capacity + 10000
	var started := service.start_project(world,String(club.id),"expand",2026)
	_expect(int(started.get("error",FAILED))==OK,"Stadium expansion must start when capacity and cash allow")
	_expect(int(club.cash)<before_cash,"Starting stadium project must post its cost through the finance ledger")
	_expect(not Dictionary(club.get("stadium_project",{})).is_empty(),"Started stadium project must persist on the club")
	var early := service.advance_projects(world,2026)
	_expect(early.is_empty() and int(club.stadium.capacity)==before_capacity,"Stadium project must not finish before completion season")
	var completed := service.advance_projects(world,2027)
	_expect(completed.size()==1 and int(club.stadium.capacity)>before_capacity,"Expansion must increase capacity on completion")
	_expect(Dictionary(club.get("stadium_project",{})).is_empty(),"Completed stadium project must clear pending state")
	club.cash = 0
	var denied := service.start_project(world,String(club.id),"build_new",2027)
	_expect(int(denied.get("error",OK))==ERR_UNAVAILABLE,"Unaffordable new stadium must be rejected")
	if failures==0:
		print("[TEST] STADIUM MANAGEMENT PASS — %d checks"%checks); quit(0)
	else:
		push_error("[TEST] STADIUM MANAGEMENT FAIL — %d failures across %d checks"%[failures,checks]); quit(1)

func _expect(condition:bool,message:String)->void:
	checks+=1
	if not condition:
		failures+=1
		push_error("[TEST] "+message)
