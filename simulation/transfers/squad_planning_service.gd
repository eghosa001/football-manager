class_name SquadPlanningService
extends RefCounted

func build_plan(world: Dictionary, club: Dictionary, horizon_years: int = 3) -> Dictionary:
	var club_id := String(club.get("id",""))
	var players: Array = []
	for player in world.get("players",[]):
		if String(player.get("club_id",""))==club_id and not bool(player.get("retired",false)): players.append(player)
	var needs: Array = []
	var succession: Array = []
	var sell_candidates: Array = []
	var loan_candidates: Array = []
	var registration := _registration_state(players, club)
	for position in ["GK","DL","DC","DR","DMC","MC","AMC","AML","AMR","ST"]:
		var options := players.filter(func(p): return _position_group(String(p.get("position",""))) == _position_group(position))
		if options.size() < _minimum_for(position): needs.append({"position":position,"priority":"high","reason_codes":["depth_shortage"]})
		for player in options:
			var age := int(player.get("age",25)); var years_left := _contract_years_left(world,String(player.get("id","")),int(world.get("season_year",2026)))
			if age >= 29 or years_left <= 1:
				succession.append({"player_id":String(player.id),"position":String(player.get("position","")),"timeline_years":1 if age>=31 or years_left<=1 else 2,"reason_codes":["age_curve" if age>=29 else "contract_expiry"]})
			if age >= 30 and int(player.get("current_ability",50)) < _squad_average(players)-8: sell_candidates.append({"player_id":String(player.id),"reason_codes":["decline_risk","below_squad_level"]})
			elif age <= 22 and int(player.get("current_ability",50)) < _squad_average(players)-12: loan_candidates.append({"player_id":String(player.id),"reason_codes":["development_minutes"]})
	var priorities := _rank_needs(needs,succession,club,registration)
	return {"club_id":club_id,"horizon_years":clampi(horizon_years,1,5),"needs":priorities,"succession":succession,"sell_candidates":sell_candidates,"loan_candidates":loan_candidates,"registration":registration,"reason_codes":["depth","age_curve","contracts","registration","resale","tactical_fit"]}

func evaluate_target(world: Dictionary, club: Dictionary, target: Dictionary, plan: Dictionary) -> Dictionary:
	var age := int(target.get("age",25)); var ability := int(target.get("current_ability",50)); var potential := int(target.get("development_ceiling",target.get("potential",ability)))
	var fit := _tactical_fit(club,target)
	var registration_bonus := 0.12 if bool(target.get("homegrown",false)) else 0.0
	var resale := clampf(float(28-age)/12.0,0.0,1.0)*0.18 + clampf(float(potential-ability)/25.0,0.0,1.0)*0.12
	var need_bonus := 0.0
	for need in plan.get("needs",[]):
		if _position_group(String(need.get("position",""))) == _position_group(String(target.get("position",""))): need_bonus = 0.20 if String(need.get("priority",""))=="high" else 0.10
	var injury_penalty := clampf(float(target.get("injury_history",[]).size())/20.0,0.0,0.20)
	var score := clampf(ability/100.0*0.45+fit*0.25+need_bonus+registration_bonus+resale-injury_penalty,0.0,1.5)
	return {"score":score,"tactical_fit":fit,"need_bonus":need_bonus,"registration_bonus":registration_bonus,"resale_value":resale,"injury_penalty":injury_penalty,"reason_codes":["ability","tactical_fit","squad_need","registration","resale","injury_risk"]}

func opportunity_cost(target_eval: Dictionary, alternatives: Array, budget: int, target_cost: int) -> Dictionary:
	var best_alt := 0.0
	for alt in alternatives: best_alt=maxf(best_alt,float(alt.get("score",0.0)))
	var budget_share := float(maxi(0,target_cost))/maxf(1.0,float(maxi(1,budget)))
	var score := float(target_eval.get("score",0.0))-best_alt-budget_share*0.18
	return {"net_score":score,"approve":score>=-0.05 and budget_share<=1.0,"reason_codes":["alternative_quality","budget_share","target_quality"]}

func _registration_state(players: Array, club: Dictionary) -> Dictionary:
	var homegrown := 0; var foreign := 0
	for player in players:
		if bool(player.get("homegrown",false)): homegrown += 1
		if bool(player.get("foreign",false)): foreign += 1
	return {"squad_size":players.size(),"homegrown":homegrown,"foreign":foreign,"homegrown_target":int(club.get("homegrown_min",8)),"foreign_limit":int(club.get("foreign_max",99))}

func _rank_needs(needs: Array, succession: Array, club: Dictionary, registration: Dictionary) -> Array:
	var result := needs.duplicate(true)
	for row in succession:
		var exists := false
		for need in result:
			if _position_group(String(need.get("position",""))) == _position_group(String(row.get("position",""))): exists=true; break
		if not exists: result.append({"position":String(row.get("position","")),"priority":"medium","reason_codes":["succession"]})
	if int(registration.homegrown)<int(registration.homegrown_target): result.append({"position":"ANY","priority":"high","filters":{"homegrown":true},"reason_codes":["homegrown_quota"]})
	return result

func _minimum_for(position: String) -> int:
	return 2 if position in ["GK","DL","DR","DMC","AMC","AML","AMR","ST"] else 4

func _position_group(position: String) -> String:
	if position in ["GK"]: return "GK"
	if position in ["DL","DR","DC","LB","RB","CB","LWB","RWB"]: return "DEF"
	if position in ["DMC","MC","AMC","ML","MR","AML","AMR","DM","CM","AM","LM","RM"]: return "MID"
	return "FWD"

func _contract_years_left(world: Dictionary, player_id: String, year: int) -> int:
	for contract in world.get("contracts",[]):
		if String(contract.get("player_id",""))==player_id: return int(contract.get("end_year",contract.get("expiry_year",year)))-year
	return 0

func _squad_average(players: Array) -> int:
	if players.is_empty(): return 50
	var total := 0
	for player in players: total += int(player.get("current_ability",50))
	return int(round(float(total)/float(players.size())))

func _tactical_fit(club: Dictionary, player: Dictionary) -> float:
	var tactic: Dictionary = club.get("tactic",{})
	var attrs: Dictionary = player.get("attributes",{})
	var pressing := float(attrs.get("work_rate",50)+attrs.get("stamina",50))/200.0
	var technical := float(attrs.get("passing",50)+attrs.get("technique",50))/200.0
	var direct := float(attrs.get("pace",50)+attrs.get("off_the_ball",50))/200.0
	var score := 0.5
	if String(tactic.get("pressing","")) in ["high","more_urgent"]: score=pressing
	elif String(tactic.get("passing_style","")) in ["short","possession"]: score=technical
	elif String(tactic.get("directness","")) in ["direct","more_direct"]: score=direct
	return clampf(score,0.0,1.0)
