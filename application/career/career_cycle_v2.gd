class_name CareerCycleV2
extends "res://application/career/career_cycle.gd"

const EventBusClass = preload("res://core/events/domain_event_bus.gd")
const RelationshipClass = preload("res://simulation/world/relationship_service.gd")
const AwardClass = preload("res://simulation/world/award_service.gd")
const SquadPlanClass = preload("res://simulation/transfers/squad_planning_service.gd")
const StaffOpsClass = preload("res://simulation/staff/staff_operations_service.gd")
const FacilitiesClass = preload("res://simulation/finance/facility_project_service.gd")
const BoardSupportClass = preload("res://simulation/finance/board_supporter_service.gd")

var _events_v2 = EventBusClass.new()
var _relationships_v2 = RelationshipClass.new()
var _awards_v2 = AwardClass.new()
var _plans_v2 = SquadPlanClass.new()
var _staff_ops_v2 = StaffOpsClass.new()
var _facilities_v2 = FacilitiesClass.new()
var _boards_v2 = BoardSupportClass.new()

func complete_year(world: Dictionary, history: Array, season_seed: int, promotion_places: int = 3) -> Dictionary:
	var result: Dictionary = super.complete_year(world,history,season_seed,promotion_places)
	if result.has("error"): return result
	var completed_year := int(result.get("season_year",int(world.get("season_year",2026))))-1
	_events_v2.ensure_world(world)
	_relationships_v2.ensure_world(world)
	_staff_ops_v2.ensure_world(world)
	_facilities_v2.ensure_world(world)
	_boards_v2.ensure_world(world)

	# Migrate legacy annual reason records into domain events. NewsEventConsumer
	# remains the only component allowed to manufacture user-facing news articles.
	var living: Dictionary = result.get("living_world",{})
	for reason in living.get("reasons",[]):
		_events_v2.emit(world,"WORLD_UPDATE",{"completed_year":completed_year,"reason":reason.duplicate(true)},"career_cycle_v2")
	world["news"] = world.get("news",[]).filter(func(article): return article.has("event_id"))

	# Canonical relationship evolution consumes domain events and regenerates
	# club social groups each year before applying decay.
	for event in world.get("domain_events",[]):
		if int(event.get("season_year",completed_year))>=completed_year-1: _relationships_v2.process_event(world,event)
	for club in world.get("clubs",[]):
		_relationships_v2.build_social_groups(world,String(club.get("id","")),world.get("players",[]))
	_relationships_v2.decay(world,1)

	# Remove legacy reputation-selected player awards for this year, preserving
	# champions, then create performance/statistics-driven positional awards.
	world["awards"] = world.get("awards",[]).filter(func(a): return int(a.get("year",a.get("season_year",-1)))!=completed_year or String(a.get("type",""))=="champion")
	var canonical_awards: Array = []
	for competition in world.get("competitions",[]):
		var competition_id:=String(competition.get("id",""))
		var created:=_awards_v2.calculate_season_awards(world,completed_year,competition_id)
		canonical_awards.append_array(created)
		for award in created: _events_v2.emit(world,"AWARD_WON",award.duplicate(true),"award_service")

	# Persistent multi-year squad plans become part of AI club state.
	world["squad_plans"] = {}
	for club in world.get("clubs",[]):
		world.squad_plans[String(club.get("id",""))] = _plans_v2.build_plan(world,club,3)
		_boards_v2.ensure_club(world,club)

	# Staff courses/workload and facility construction are advanced from the same
	# annual clock rather than existing as disconnected helper systems.
	var completed_courses:=_staff_ops_v2.advance_courses(world,365)
	var completed_facilities:=_facilities_v2.advance(world,365)
	result["canonical_awards"] = canonical_awards
	result["relationship_count"] = world.get("relationships",[]).size()
	result["social_group_count"] = world.get("social_groups",[]).size()
	result["squad_plans"] = world.get("squad_plans",{}).size()
	result["staff_courses_completed"] = completed_courses
	result["facility_projects_completed"] = completed_facilities
	return result
