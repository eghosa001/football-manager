extends SceneTree

const YouthClass = preload("res://simulation/players/youth_academy.gd")
const RelationshipClass = preload("res://simulation/world/relationship_service.gd")
const AwardClass = preload("res://simulation/world/award_service.gd")
const SquadPlanClass = preload("res://simulation/transfers/squad_planning_service.gd")
const StaffOpsClass = preload("res://simulation/staff/staff_operations_service.gd")
const MatchDepthClass = preload("res://simulation/match/match_depth_service.gd")
const AnalyticsClass = preload("res://game/analysis/advanced_match_analytics.gd")
const FuzzerClass = preload("res://tools/save_debugger/destructive_fuzzer.gd")

var failures: Array = []

func _init() -> void:
	_test_youth_identity()
	_test_relationships()
	_test_awards()
	_test_match_depth()
	_test_analytics()
	_test_destructive_fuzzer()
	if failures.is_empty():
		print("REMEDIATION COMPLETION: PASS")
		quit(0)
	else:
		for failure in failures: push_error(String(failure))
		quit(1)

func _test_youth_identity() -> void:
	var world={"season_year":2027,"countries":[{"id":"nga","name":"Nigeria"},{"id":"gha","name":"Ghana"}],"cities":[{"id":"benin","country_id":"nga","region_id":"edo","name":"Benin City"}],"clubs":[{"id":"club","name":"Club","country_id":"nga","city_id":"benin","region_id":"edo","reputation":60}],"players":[],"name_pools":[{"country_id":"nga","first_names":["Efe","Osaze"],"last_names":["Aigbe","Okunbo"]}]}
	var rows=YouthClass.new().intake_preview(world,"club",44,7)
	_assert(rows.size()==7,"youth intake count")
	_assert(String(rows[0].get("first_name",""))!="","youth first name")
	_assert(int(rows[0].get("height_cm",0))>=160,"youth physical identity")
	_assert(rows[0].has("preferred_foot"),"youth preferred foot")
	_assert(rows[0].has("development_ceiling"),"youth dynamic ceiling")

func _test_relationships() -> void:
	var world={"relationships":[],"social_groups":[],"season_year":2027}
	var service=RelationshipClass.new()
	var row=service.change(world,"p1","p2","friendship",12.0,"shared_success",2027)
	_assert(float(row.get("strength",0.0))==12.0,"relationship change")
	service.change(world,"p1","p2","dislike",5.0,"argument",2027)
	_assert(world.relationships.size()==2,"relationship dimensions")

func _test_awards() -> void:
	var world={"players":[{"id":"p1","club_id":"c","age":20,"position":"ST"},{"id":"p2","club_id":"c","age":28,"position":"ST"}],"competitions":[{"id":"l","reputation":80}],"player_match_stats":[],"awards":[]}
	for i in range(5):
		world.player_match_stats.append({"season_year":2027,"competition_id":"l","player_id":"p1","goals":2,"assists":1,"key_passes":2,"xg":1.3,"xa":0.5,"rating":8.0})
		world.player_match_stats.append({"season_year":2027,"competition_id":"l","player_id":"p2","goals":0,"assists":0,"key_passes":0,"xg":0.1,"xa":0.0,"rating":6.0})
	var awards=AwardClass.new().calculate_season_awards(world,2027,"l")
	_assert(not awards.is_empty(),"stat driven awards")
	_assert(String(awards[0].get("player_id",""))=="p1","award winner based on performance")

func _test_match_depth() -> void:
	var service=MatchDepthClass.new()
	var home=[{"id":"h1","position":"MC","role":"regista","current_ability":75,"attributes":{"free_kicks":16,"passing":17,"technique":16}},{"id":"h2","position":"ST","current_ability":70,"attributes":{"heading":15,"jumping_reach":15,"strength":14}}]
	var away=[{"id":"gk","position":"GK","current_ability":70,"attributes":{"reflexes":15,"handling":14,"goalkeeper_positioning":15}},{"id":"a2","position":"DC","current_ability":70,"attributes":{"heading":16,"jumping_reach":15,"strength":15}}]
	var enriched=service.enrich_event({"type":"foul","side":"home","minute":30,"player_id":"h1","advantage":false},home,away,{"tempo":"higher","pressing":"more_urgent"},{},99)
	_assert(enriched.size()>=2,"set piece enrichment")
	_assert(String(enriched[1].get("type",""))=="set_piece","canonical set piece")
	var keeper=service.enrich_event({"type":"shot","side":"home","minute":40,"player_id":"h2","xg":0.4,"outcome":"saved"},home,away,{}, {},101)
	_assert(keeper.filter(func(e): return String(e.get("type",""))=="goalkeeper_action").size()==1,"goalkeeper behaviour")

func _test_analytics() -> void:
	var events=[{"type":"pass","side":"home","start_x":30.0,"target_x":50.0,"success":true,"minute":10},{"type":"dribble","side":"home","start_x":70.0,"target_x":88.0,"success":true,"minute":11},{"type":"shot","side":"home","xg":0.3,"minute":11}]
	var result=AnalyticsClass.new().analyze(events)
	_assert(int(result.home.progressive_passes)>=1,"progressive pass metric")
	_assert(int(result.home.progressive_carries)>=1,"progressive carry metric")
	_assert(float(result.home.xt)>0.0,"expected threat metric")

func _test_destructive_fuzzer() -> void:
	var result=FuzzerClass.new().run(7,8)
	_assert(result.has("failures"),"fuzzer executes")
	_assert(FuzzerClass.new().malformed_save_cases().size()>=5,"malformed save corpus")

func _assert(condition: bool, label: String) -> void:
	if not condition: failures.append(label)
