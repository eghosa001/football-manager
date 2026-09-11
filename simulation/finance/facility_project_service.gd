class_name FacilityProjectService
extends RefCounted

const FACILITIES := ["training","youth","recruitment","medical","sports_science","academy"]

func ensure_world(world: Dictionary) -> void:
	world["facility_projects"] = world.get("facility_projects", [])

func propose(world: Dictionary, club: Dictionary, facility: String, target_level: int, seed: int = 0) -> Dictionary:
	ensure_world(world)
	if facility not in FACILITIES: return {"status":"invalid","reason_codes":["unknown_facility"]}
	var current := int(club.get(facility+"_facilities",club.get(facility+"_level",50)))
	var target := clampi(target_level,current+1,100)
	var delta := target-current
	var base_cost := delta*250_000
	var reputation := float(club.get("reputation",50))/100.0
	var board_confidence := float(club.get("board_confidence",50))/100.0
	var cash := int(club.get("cash",0))
	var approval_score := clampf(0.25+reputation*0.20+board_confidence*0.35+(0.20 if cash>=base_cost else -0.25),0.0,1.0)
	var approved := approval_score>=0.50
	var project := {
		"id":"facility-%s-%s-%d" % [String(club.get("id","")),facility,world.facility_projects.size()+1],"club_id":String(club.get("id","")),
		"facility":facility,"from_level":current,"target_level":target,"cost":base_cost,"paid":0,"remaining_days":maxi(30,delta*30),
		"status":"approved" if approved else "rejected","approval_score":approval_score,"reason_codes":["board_confidence","club_reputation","available_cash"]
	}
	world.facility_projects.append(project)
	return project

func start(world: Dictionary, club: Dictionary, project: Dictionary) -> Dictionary:
	if String(project.get("status",""))!="approved": return {"status":"invalid","reason_codes":["project_not_approved"]}
	var cost := int(project.get("cost",0))
	if int(club.get("cash",0))<cost: return {"status":"blocked","reason_codes":["insufficient_cash"]}
	club.cash=int(club.get("cash",0))-cost
	project.paid=cost; project.status="construction"
	return {"status":"construction","reason_codes":["funded"]}

func advance(world: Dictionary, days: int, cost_variance: float = 0.0, delay_days: int = 0) -> Array:
	ensure_world(world)
	var completed: Array=[]
	for project in world.facility_projects:
		if String(project.get("status",""))!="construction": continue
		if delay_days>0 and not bool(project.get("delay_applied",false)):
			project.remaining_days=int(project.remaining_days)+delay_days; project.delay_applied=true; project.reason_codes.append("construction_delay")
		if cost_variance>0.0 and not bool(project.get("variance_applied",false)):
			project.cost=int(round(float(project.cost)*(1.0+clampf(cost_variance,0.0,0.5)))); project.variance_applied=true; project.reason_codes.append("cost_overrun")
		project.remaining_days=maxi(0,int(project.remaining_days)-maxi(0,days))
		if int(project.remaining_days)==0:
			var club:=_club(world.get("clubs",[]),String(project.club_id))
			if not club.is_empty(): club[String(project.facility)+"_facilities"]=int(project.target_level)
			project.status="complete"; completed.append(String(project.id))
	return completed

func _club(clubs:Array,id:String)->Dictionary:
	for club in clubs:
		if String(club.get("id",""))==id:return club
	return {}
