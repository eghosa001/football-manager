class_name StadiumService
extends RefCounted

const LedgerClass = preload("res://simulation/finance/ledger.gd")
const EconomyClass = preload("res://simulation/finance/club_economy.gd")

var _ledger = LedgerClass.new()

func ensure_club(club: Dictionary) -> void:
	EconomyClass.new().ensure_club(club)
	var stadium: Dictionary = club.stadium
	stadium["seated_capacity"] = clampi(int(stadium.get("seated_capacity", stadium.capacity)),0,int(stadium.capacity))
	stadium["corporate_capacity"] = clampi(int(stadium.get("corporate_capacity", maxi(100,int(stadium.capacity*0.03)))),0,int(stadium.capacity))
	stadium["pitch_quality"] = clampi(int(stadium.get("pitch_quality",75)),1,100)
	stadium["roof"] = bool(stadium.get("roof",false))
	stadium["location"] = String(stadium.get("location", club.get("city",club.get("country_id",""))))
	stadium["expansion_capacity"] = maxi(int(stadium.capacity),int(stadium.get("expansion_capacity",int(stadium.capacity*(1.0+float(stadium.get("expansion_potential",50))/100.0)))))
	club["stadium"] = stadium
	club["stadium_project"] = club.get("stadium_project", {})

func start_project(world: Dictionary, club_id: String, action: String, season_year: int) -> Dictionary:
	_ledger.ensure(world)
	var club := _club(world,club_id)
	if club.is_empty(): return {"error":ERR_DOES_NOT_EXIST}
	ensure_club(club)
	if not Dictionary(club.get("stadium_project",{})).is_empty(): return {"error":ERR_BUSY,"reason":"project_already_active"}
	var stadium: Dictionary = club.stadium
	var project: Dictionary = {}
	match action:
		"expand":
			var room := int(stadium.expansion_capacity)-int(stadium.capacity)
			if room < 1000: return {"error":ERR_ALREADY_EXISTS,"reason":"no_expansion_room"}
			var increase := mini(room,maxi(1500,int(stadium.capacity*0.15)))
			project={"type":"expand","cost":increase*220,"completion_year":season_year+1,"capacity_increase":increase}
		"renovate":
			if int(stadium.condition)>=95 and int(stadium.pitch_quality)>=95: return {"error":ERR_ALREADY_EXISTS,"reason":"stadium_already_modern"}
			project={"type":"renovate","cost":maxi(600000,int(stadium.capacity)*55),"completion_year":season_year+1}
		"relocate":
			project={"type":"relocate","cost":maxi(1500000,int(stadium.capacity)*95),"completion_year":season_year+2,"new_location":String(club.get("city",club.get("country_id","New district")))+" District"}
		"build_new":
			var target := maxi(int(stadium.capacity)+5000,int(round(float(stadium.capacity)*1.45)))
			project={"type":"build_new","cost":target*420,"completion_year":season_year+3,"target_capacity":target}
		_:
			return {"error":ERR_INVALID_PARAMETER}
	var cost := int(project.cost)
	if int(club.get("cash",0)) < cost: return {"error":ERR_UNAVAILABLE,"reason":"insufficient_cash","cost":cost}
	_ledger.post(world,club_id,-cost,"stadium_project","stadium-%s-%s-%d"%[club_id,action,season_year],season_year)
	project["started_year"] = season_year
	club["stadium_project"] = project
	return {"error":OK,"project":project.duplicate(true)}

func advance_projects(world: Dictionary, season_year: int) -> Array:
	var completed: Array = []
	for club in world.get("clubs",[]):
		ensure_club(club)
		var project: Dictionary = club.get("stadium_project",{})
		if project.is_empty() or int(project.get("completion_year",9999))>season_year: continue
		match String(project.get("type","")):
			"expand":
				club.stadium.capacity = mini(int(club.stadium.expansion_capacity),int(club.stadium.capacity)+int(project.get("capacity_increase",0)))
				club.stadium.seated_capacity = int(club.stadium.capacity)
			"renovate":
				club.stadium.condition = mini(100,int(club.stadium.condition)+30)
				club.stadium.pitch_quality = mini(100,int(club.stadium.pitch_quality)+20)
				club.stadium.corporate_capacity = mini(int(club.stadium.capacity),int(club.stadium.corporate_capacity)+maxi(100,int(club.stadium.capacity*0.01)))
			"relocate":
				club.stadium.location = String(project.get("new_location",club.stadium.location))
				club.stadium.condition = 95
			"build_new":
				var target := int(project.get("target_capacity",club.stadium.capacity))
				club.stadium.capacity = target; club.stadium.seated_capacity = target; club.stadium.corporate_capacity = maxi(250,int(target*0.05)); club.stadium.pitch_quality=95; club.stadium.condition=100; club.stadium.ownership="owned"; club.stadium.annual_rent=0; club.stadium.expansion_capacity=int(target*1.35)
		completed.append({"club_id":String(club.id),"type":String(project.get("type","")),"season_year":season_year})
		club["stadium_project"] = {}
	return completed

func _club(world: Dictionary, club_id: String) -> Dictionary:
	for club in world.get("clubs",[]):
		if String(club.get("id",""))==club_id: return club
	return {}
