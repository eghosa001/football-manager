class_name EconomyStabilityService
extends RefCounted

func ensure_world(world: Dictionary) -> void:
	world["economic_indices"] = world.get("economic_indices", {"wage":1.0,"transfer":1.0,"broadcast":1.0,"commercial":1.0})
	world["economic_history"] = world.get("economic_history", [])
	world["insolvency_cases"] = world.get("insolvency_cases", [])

func advance_season(world: Dictionary) -> Dictionary:
	ensure_world(world)
	var indices: Dictionary = world.economic_indices
	var clubs: Array = world.get("clubs",[])
	var median_cash := _median_cash(clubs)
	var aggregate_pressure := clampf(float(median_cash)/100_000_000.0,-0.5,1.5)
	indices.wage = clampf(float(indices.get("wage",1.0))*(1.012+aggregate_pressure*0.006),0.70,4.0)
	indices.transfer = clampf(float(indices.get("transfer",1.0))*(1.010+aggregate_pressure*0.008),0.65,5.0)
	indices.broadcast = clampf(float(indices.get("broadcast",1.0))*1.008,0.75,3.0)
	indices.commercial = clampf(float(indices.get("commercial",1.0))*1.009,0.75,3.5)
	var interventions: Array = []
	for club in clubs:
		var result := assess_club(world,club)
		if not result.is_empty(): interventions.append(result)
	var record := {"season_year":int(world.get("season_year",2026)),"indices":indices.duplicate(true),"median_cash":median_cash,"interventions":interventions.size()}
	world.economic_history.append(record)
	return record

func assess_club(world: Dictionary, club: Dictionary) -> Dictionary:
	ensure_world(world)
	var cash := int(club.get("cash",0))
	var debt := maxi(0,int(club.get("debt",0)))
	var annual_wages := maxi(0,int(club.get("annual_wages",club.get("weekly_wages",0)*52)))
	var revenue := maxi(1,int(club.get("annual_revenue",club.get("revenue",1))))
	var wage_ratio := float(annual_wages)/float(revenue)
	var debt_ratio := float(debt)/float(revenue)
	var reasons: Array = []
	if cash < 0: reasons.append("negative_cash")
	if wage_ratio > 0.85: reasons.append("wage_ratio_high")
	if debt_ratio > 2.0: reasons.append("debt_ratio_high")
	if reasons.is_empty(): return {}
	club["financial_controls"] = {"transfer_budget_multiplier":0.35 if debt_ratio>2.0 else 0.65,"wage_budget_multiplier":0.80 if wage_ratio>0.85 else 0.95,"board_sale_bias":0.75 if cash<0 else 0.55}
	if cash < -maxi(5_000_000,int(float(revenue)*0.35)):
		var case := {"club_id":String(club.get("id","")),"season_year":int(world.get("season_year",2026)),"status":"administration_watch","reason_codes":reasons.duplicate()}
		world.insolvency_cases.append(case)
		club["insolvency_status"] = "administration_watch"
		return case
	return {"club_id":String(club.get("id","")),"status":"controls_applied","reason_codes":reasons}

func broadcast_payment(world: Dictionary, club: Dictionary, base_amount: int, merit_factor: float = 1.0) -> int:
	ensure_world(world)
	var amount := int(round(float(base_amount)*float(world.economic_indices.get("broadcast",1.0))*clampf(merit_factor,0.5,2.0)))
	club["cash"] = int(club.get("cash",0))+amount
	return amount

func sponsor_value(world: Dictionary, club: Dictionary, years: int = 3) -> Dictionary:
	ensure_world(world)
	var reputation := clampf(float(club.get("reputation",50))/100.0,0.05,1.0)
	var fanbase := clampf(float(club.get("supporters",club.get("fanbase",100000)))/1_000_000.0,0.05,2.0)
	var annual := int(round(750_000.0*reputation*(0.7+fanbase*0.3)*float(world.economic_indices.get("commercial",1.0))))
	return {"annual_value":annual,"years":clampi(years,1,7),"total_value":annual*clampi(years,1,7)}

func financing_cost(club: Dictionary, annual_rate: float = 0.06) -> int:
	var debt := maxi(0,int(club.get("debt",0)))
	var cost := int(round(float(debt)*clampf(annual_rate,0.0,0.30)))
	club["cash"] = int(club.get("cash",0))-cost
	return cost

func _median_cash(clubs: Array) -> int:
	if clubs.is_empty(): return 0
	var values: Array = []
	for club in clubs: values.append(int(club.get("cash",0)))
	values.sort()
	return int(values[values.size()/2])
