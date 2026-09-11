class_name ManagerCareerService
extends RefCounted

const SeededRngClass = preload("res://core/rng/seeded_rng.gd")

func ensure_world(world: Dictionary) -> void:
	world["manager_careers"] = world.get("manager_careers", [])
	world["manager_job_market"] = world.get("manager_job_market", [])

func create_manager(world: Dictionary, manager_id: String, name: String, human: bool = false, club_id: String = "") -> Dictionary:
	ensure_world(world)
	var manager := {
		"id":manager_id,"name":name,"human":human,"club_id":club_id,"national_team_id":"",
		"employment":"employed" if club_id != "" else "unemployed","reputation":50.0,"ambition":50.0,
		"tactical_identity":{},"preferred_staff":[],"relationships":{},"history":[],"applications":[],"approaches":[],
		"contract":{"wage":0,"years":0,"start_year":int(world.get("season_year",2026))},"reason_codes":[]
	}
	world.manager_careers.append(manager)
	return manager

func advertise_job(world: Dictionary, club_id: String, kind: String = "club", reputation: float = 50.0) -> Dictionary:
	ensure_world(world)
	var job := {"id":"job-%s-%d" % [club_id, world.manager_job_market.size()+1],"club_id":club_id,"kind":kind,"reputation":reputation,"status":"open","candidates":[]}
	world.manager_job_market.append(job)
	return job

func apply_for_job(world: Dictionary, manager: Dictionary, job: Dictionary) -> Dictionary:
	ensure_world(world)
	if String(job.get("status","")) != "open": return {"status":"invalid","reason_codes":["job_closed"]}
	if String(manager.get("employment","")) == "employed" and bool(manager.get("human",false)):
		manager.reason_codes = ["currently_employed_application"]
	manager.applications.append(String(job.id))
	job.candidates.append(String(manager.id))
	return {"status":"applied","reason_codes":["job_open","candidate_registered"]}

func interview(manager: Dictionary, job: Dictionary, answers: Dictionary, seed: int) -> Dictionary:
	var reputation_fit := 1.0 - minf(1.0, absf(float(manager.get("reputation",50.0)) - float(job.get("reputation",50.0))) / 100.0)
	var philosophy := clampf(float(answers.get("philosophy_fit",0.5)),0.0,1.0)
	var wage_fit := clampf(float(answers.get("wage_fit",0.5)),0.0,1.0)
	var confidence := clampf(float(answers.get("confidence",0.5)),0.0,1.0)
	var score := reputation_fit*0.35 + philosophy*0.30 + wage_fit*0.15 + confidence*0.20
	score += (SeededRngClass.unit_for(seed, 121001)-0.5)*0.08
	return {"score":score,"passed":score>=0.56,"reason_codes":["reputation_fit","philosophy_fit","wage_expectation","interview_confidence"]}

func offer_contract(world: Dictionary, manager: Dictionary, job: Dictionary, wage: int, years: int) -> Dictionary:
	var contract := {"wage":maxi(0,wage),"years":clampi(years,1,5),"start_year":int(world.get("season_year",2026)),"club_id":String(job.get("club_id",""))}
	manager.approaches.append({"job_id":String(job.id),"contract":contract.duplicate(true)})
	return contract

func accept_job(manager: Dictionary, job: Dictionary, contract: Dictionary) -> Dictionary:
	var previous := String(manager.get("club_id",""))
	manager.club_id = String(job.get("club_id","")) if String(job.get("kind","club")) == "club" else String(manager.get("club_id",""))
	if String(job.get("kind","club")) == "national": manager.national_team_id = String(job.get("club_id",""))
	manager.employment = "employed"
	manager.contract = contract.duplicate(true)
	manager.history.append({"type":"appointed","club_id":String(job.get("club_id","")),"previous_club_id":previous})
	job.status = "filled"
	job["appointed_manager_id"] = String(manager.id)
	return {"status":"accepted","reason_codes":["contract_accepted","job_filled"]}

func sack(manager: Dictionary, club_id: String, reasons: Array) -> Dictionary:
	if String(manager.get("club_id","")) != club_id: return {"status":"invalid"}
	manager.history.append({"type":"sacked","club_id":club_id,"reason_codes":reasons.duplicate()})
	manager.club_id = ""
	manager.employment = "unemployed"
	manager.contract = {"wage":0,"years":0}
	manager.reason_codes = reasons.duplicate()
	return {"status":"sacked","reason_codes":reasons.duplicate()}

func resign(manager: Dictionary, reason: String) -> Dictionary:
	var old_club := String(manager.get("club_id",""))
	manager.history.append({"type":"resigned","club_id":old_club,"reason":reason})
	manager.club_id = ""
	manager.employment = "unemployed"
	manager.contract = {"wage":0,"years":0}
	return {"status":"resigned","reason_codes":[reason]}

func approach_manager(manager: Dictionary, job: Dictionary, seed: int) -> Dictionary:
	var ambition := float(manager.get("ambition",50.0))/100.0
	var job_rep := float(job.get("reputation",50.0))/100.0
	var current_rep := float(manager.get("reputation",50.0))/100.0
	var interest := clampf(0.30 + job_rep*0.55 + ambition*0.25 - current_rep*0.20,0.0,1.0)
	var interested := SeededRngClass.unit_for(seed, 122001 + abs(hash(String(manager.id)))%10000) < interest
	return {"interested":interested,"interest":interest,"reason_codes":["career_ambition","job_reputation","current_status"]}

func evolve_ai_manager(manager: Dictionary, season_result: Dictionary) -> void:
	var trophies := int(season_result.get("trophies",0))
	var performance := clampf(float(season_result.get("performance",0.5)),0.0,1.0)
	manager.reputation = clampf(float(manager.get("reputation",50.0)) + trophies*4.0 + (performance-0.5)*6.0,1.0,100.0)
	var identity: Dictionary = manager.get("tactical_identity", {})
	identity["risk"] = clampf(float(identity.get("risk",0.5)) + (performance-0.5)*0.08,0.1,0.9)
	identity["pressing"] = clampf(float(identity.get("pressing",0.5)) + (performance-0.5)*0.05,0.1,0.9)
	manager.tactical_identity = identity
	manager.history.append({"type":"season_review","performance":performance,"trophies":trophies})
