class_name BoardSupporterService
extends RefCounted

func ensure_world(world: Dictionary) -> void:
	world["boards"] = world.get("boards", {})
	world["supporter_groups"] = world.get("supporter_groups", [])
	world["ownership_history"] = world.get("ownership_history", [])

func ensure_club(world: Dictionary, club: Dictionary) -> Dictionary:
	ensure_world(world)
	var club_id := String(club.get("id",""))
	if not world.boards.has(club_id):
		world.boards[club_id] = {
			"club_id":club_id,"owner_id":"owner-%s" % club_id,"vision":{"results":0.65,"youth":0.45,"finance":0.65,"style":0.40},
			"confidence":float(club.get("board_confidence",60)),"objectives":[],"history":[]
		}
	if not _has_supporters(world.supporter_groups,club_id):
		world.supporter_groups.append({"id":"supporters-%s-core" % club_id,"club_id":club_id,"name":"Core Supporters","size":0.55,"patience":55.0,"expectations":50.0,"mood":60.0,"priorities":{"results":0.6,"youth":0.15,"style":0.15,"identity":0.10}})
		world.supporter_groups.append({"id":"supporters-%s-local" % club_id,"club_id":club_id,"name":"Local Supporters","size":0.30,"patience":65.0,"expectations":45.0,"mood":65.0,"priorities":{"results":0.35,"youth":0.20,"style":0.10,"identity":0.35}})
	return world.boards[club_id]

func negotiate_objectives(world: Dictionary, club: Dictionary, manager: Dictionary, proposals: Dictionary) -> Dictionary:
	var board := ensure_club(world,club)
	var vision: Dictionary = board.vision
	var accepted: Array=[]; var rejected:Array=[]
	for key in proposals.keys():
		var requested := float(proposals[key])
		var expected := float(vision.get(String(key),0.5))
		var manager_leverage := clampf(float(manager.get("reputation",50))/100.0+float(board.get("confidence",60))/200.0,0.0,1.5)
		if requested+manager_leverage*0.18>=expected:
			accepted.append({"objective":String(key),"target":requested})
		else:
			rejected.append({"objective":String(key),"requested":requested,"expected":expected})
	board.objectives=accepted
	board.history.append({"type":"objective_negotiation","season_year":int(world.get("season_year",2026)),"accepted":accepted.duplicate(true),"rejected":rejected.duplicate(true)})
	return {"accepted":accepted,"rejected":rejected,"reason_codes":["board_vision","manager_reputation","board_confidence"]}

func evaluate_manager(world: Dictionary, club: Dictionary, manager: Dictionary, season: Dictionary) -> Dictionary:
	var board:=ensure_club(world,club)
	var results:=clampf(float(season.get("results_score",0.5)),0.0,1.0)
	var finance:=clampf(float(season.get("finance_score",0.5)),0.0,1.0)
	var youth:=clampf(float(season.get("youth_score",0.5)),0.0,1.0)
	var style:=clampf(float(season.get("style_score",0.5)),0.0,1.0)
	var vision:Dictionary=board.vision
	var score:=results*float(vision.results)+finance*float(vision.finance)+youth*float(vision.youth)+style*float(vision.style)
	var denominator:=float(vision.results)+float(vision.finance)+float(vision.youth)+float(vision.style)
	score/=maxf(0.01,denominator)
	var supporter_mood:=update_supporters(world,String(club.get("id","")),season)
	score=clampf(score*0.85+supporter_mood/100.0*0.15,0.0,1.0)
	board.confidence=clampf(30.0+score*70.0,0.0,100.0); club.board_confidence=board.confidence
	var status:="secure"
	if score<0.30: status="sack_recommended"
	elif score<0.45: status="under_pressure"
	elif score>0.78: status="excellent"
	return {"score":score,"confidence":board.confidence,"status":status,"reason_codes":["results","finance","youth","style","supporters"]}

func update_supporters(world: Dictionary, club_id: String, season: Dictionary) -> float:
	ensure_world(world)
	var weighted:=0.0; var total_size:=0.0
	for group in world.supporter_groups:
		if String(group.get("club_id",""))!=club_id: continue
		var priorities:Dictionary=group.get("priorities",{})
		var satisfaction:=float(season.get("results_score",0.5))*float(priorities.get("results",0.5))+float(season.get("youth_score",0.5))*float(priorities.get("youth",0.0))+float(season.get("style_score",0.5))*float(priorities.get("style",0.0))+float(season.get("identity_score",0.5))*float(priorities.get("identity",0.0))
		var patience:=float(group.get("patience",50))/100.0
		group.mood=clampf(float(group.get("mood",60))*0.65+satisfaction*100.0*(0.20+patience*0.15),0.0,100.0)
		weighted+=float(group.mood)*float(group.get("size",1.0)); total_size+=float(group.get("size",1.0))
	return weighted/maxf(0.01,total_size)

func change_owner(world: Dictionary, club: Dictionary, new_owner_id: String, vision: Dictionary, investment: int = 0) -> Dictionary:
	var board:=ensure_club(world,club)
	var old_owner:=String(board.get("owner_id",""))
	board.owner_id=new_owner_id
	for key in ["results","youth","finance","style"]:
		if vision.has(key): board.vision[key]=clampf(float(vision[key]),0.0,1.0)
	club.cash=int(club.get("cash",0))+maxi(0,investment)
	var event:={"club_id":String(club.get("id","")),"old_owner_id":old_owner,"new_owner_id":new_owner_id,"investment":maxi(0,investment),"season_year":int(world.get("season_year",2026))}
	world.ownership_history.append(event)
	board.history.append({"type":"ownership_change","event":event.duplicate(true)})
	return event

func _has_supporters(groups:Array,club_id:String)->bool:
	for group in groups:
		if String(group.get("club_id",""))==club_id:return true
	return false
