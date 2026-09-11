class_name BoardEvaluation
extends RefCounted

const CATEGORIES := ["results","finances","objectives","playing_style","youth_usage","transfers","fan_sentiment"]

func evaluate_world(world: Dictionary, season_records: Array) -> Dictionary:
	var reviewed := 0
	var critical := 0
	for club in world.get("clubs", []):
		var result := evaluate_club(world, club, season_records)
		reviewed += 1
		if float(result.get("overall", 50.0)) < 30.0:
			critical += 1
	return {"clubs_reviewed":reviewed,"critical":critical}

func evaluate_club(world: Dictionary, club: Dictionary, season_records: Array) -> Dictionary:
	if not club.has("board"):
		club["board"] = {"patience":65,"ambition":55,"confidence":65,"financial_prudence":55,"youth_priority":50,"style_priority":"balanced"}
	var scores := {
		"results": _results_score(club, season_records),
		"finances": _finance_score(club),
		"objectives": _objective_score(club, season_records),
		"playing_style": _style_score(club),
		"youth_usage": _youth_score(world, club),
		"transfers": _transfer_score(world, club),
		"fan_sentiment": float(club.get("supporters", {}).get("mood", 60)),
	}
	var weights := {
		"results":0.30,
		"finances":0.18,
		"objectives":0.18,
		"playing_style":0.08,
		"youth_usage":0.09,
		"transfers":0.07,
		"fan_sentiment":0.10,
	}
	var overall := 0.0
	for category in CATEGORIES:
		overall += float(scores[category]) * float(weights[category])
	var patience := float(club.board.get("patience",65))/100.0
	var previous := float(club.board.get("confidence",65))
	# Patient boards move more slowly; impatient boards react more strongly.
	var max_step := lerpf(8.0,3.0,patience)
	var confidence := clampf(previous + clampf(overall-previous,-max_step,max_step),0.0,100.0)
	club.board["confidence"] = int(round(confidence))
	club.board["evaluation"] = {"overall":snappedf(overall,0.1),"categories":scores,"weights":weights,"status":_status(overall)}
	return club.board.evaluation

func _results_score(club: Dictionary, records: Array) -> float:
	for record in records:
		var table: Array = record.get("table", [])
		for i in range(table.size()):
			if String(table[i].get("club_id", "")) != String(club.get("id", "")):
				continue
			var percentile := 1.0 - float(i) / maxf(1.0,float(table.size()-1))
			var expectation := float(club.get("reputation",50))/100.0
			return clampf(55.0 + (percentile-expectation)*70.0,10.0,95.0)
	return 50.0

func _finance_score(club: Dictionary) -> float:
	var cash := float(club.get("cash",0))
	var debt := float(club.get("debt",0))
	var ratio := debt/maxf(1.0,cash+debt)
	var score := 80.0-ratio*75.0
	if String(club.get("financial_status","secure"))=="insecure": score-=15.0
	return clampf(score,5.0,95.0)

func _objective_score(club: Dictionary, records: Array) -> float:
	var objectives: Array = club.get("board",{}).get("objectives",[])
	if objectives.is_empty(): return _results_score(club,records)
	var total := 0.0
	var weight_total := 0.0
	for objective in objectives:
		var weight := float(objective.get("weight",1.0)); var score := 50.0
		match String(objective.get("type","")):
			"league_position":
				var actual := _league_position(String(club.get("id","")),records)
				var target := maxi(1,int(objective.get("target",10)))
				if actual>0: score=clampf(70.0+float(target-actual)*5.0,10.0,95.0)
			"financial_security": score=_finance_score(club)
			"youth": score=55.0+float(club.get("facilities",{}).get("youth_training",50)-50)*0.5
		total += score*weight; weight_total += weight
	return total/maxf(1.0,weight_total)

func _style_score(club: Dictionary) -> float:
	var preferred := String(club.get("board",{}).get("style_priority","balanced"))
	var tactic: Dictionary = club.get("tactic",{})
	if preferred=="balanced" or tactic.is_empty(): return 70.0
	var mentality := String(tactic.get("mentality","balanced"))
	var pressing := String(tactic.get("pressing","standard"))
	match preferred:
		"attacking": return 85.0 if mentality in ["positive","attacking"] else 45.0
		"defensive": return 85.0 if mentality in ["cautious","very_cautious"] else 45.0
		"pressing": return 85.0 if pressing in ["high","very_high"] else 45.0
		_: return 65.0

func _youth_score(world: Dictionary, club: Dictionary) -> float:
	var appearances := 0
	var youth_count := 0
	for player in world.get("players",[]):
		if String(player.get("club_id",""))!=String(club.get("id","")) or bool(player.get("retired",false)): continue
		if int(player.get("age",99))<=21:
			youth_count+=1; appearances+=int(player.get("season_appearances",0))
	var usage := float(appearances)/maxf(1.0,float(youth_count*12))
	var priority := float(club.get("board",{}).get("youth_priority",50))/100.0
	return clampf(65.0+(usage-priority)*45.0,20.0,95.0)

func _transfer_score(world: Dictionary, club: Dictionary) -> float:
	var club_id := String(club.get("id","")); var completed:=0; var failed:=0
	for offer in world.get("transfer_offers",[]):
		if String(offer.get("buyer_id",""))!=club_id and String(offer.get("seller_id",""))!=club_id: continue
		if String(offer.get("status",""))=="completed": completed+=1
		elif String(offer.get("status","")) in ["rejected","failed"]: failed+=1
	return clampf(60.0+completed*5.0-failed*2.0,20.0,90.0)

func _league_position(club_id:String,records:Array)->int:
	for record in records:
		var table:Array=record.get("table",[])
		for i in range(table.size()):
			if String(table[i].get("club_id",""))==club_id: return i+1
	return 0

func _status(value:float)->String:
	if value>=75.0: return "delighted"
	if value>=60.0: return "pleased"
	if value>=45.0: return "satisfied"
	if value>=30.0: return "concerned"
	return "critical"
