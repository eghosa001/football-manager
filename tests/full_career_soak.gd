extends SceneTree

const GeneratorClass = preload("res://simulation/world/world_generator.gd")
const CareerCycleClass = preload("res://application/career/career_cycle_v2.gd")

func _init() -> void:
	var seasons:=100
	var env:=OS.get_environment("FM_SOAK_SEASONS")
	if env!="": seasons=maxi(2,int(env))
	var world=GeneratorClass.new().create_world(6601,4,20,25)
	var history:Array=[]
	var cycle=CareerCycleClass.new()
	var initial_players:=world.players.size(); var initial_clubs:=world.clubs.size()
	var min_players:=initial_players; var max_players:=initial_players; var negative_cash_seasons:=0
	for year_index in range(seasons):
		var result=cycle.complete_year(world,history,880000+year_index,3)
		if result.has("error"):
			push_error("Career soak failed at season %d"%year_index); quit(1); return
		min_players=mini(min_players,world.players.size()); max_players=maxi(max_players,world.players.size())
		var distressed:=0
		for club in world.clubs:
			if int(club.get("cash",0))<0: distressed+=1
		if distressed>int(world.clubs.size()*0.65): negative_cash_seasons+=1
		if year_index%10==0: print({"season":year_index+1,"season_year":world.get("season_year"),"players":world.players.size(),"clubs":world.clubs.size(),"distressed_clubs":distressed})
	var player_ratio:=float(world.players.size())/maxf(1.0,float(initial_players))
	var ok:=world.clubs.size()==initial_clubs and player_ratio>=0.55 and player_ratio<=2.4 and min_players>=int(initial_players*0.45) and max_players<=int(initial_players*2.8) and negative_cash_seasons<=int(seasons*0.35)
	print({"seasons":seasons,"initial_players":initial_players,"final_players":world.players.size(),"min_players":min_players,"max_players":max_players,"negative_cash_seasons":negative_cash_seasons,"history_entries":history.size()})
	if not ok: push_error("100-season career/economy stability gate failed")
	quit(0 if ok else 1)
