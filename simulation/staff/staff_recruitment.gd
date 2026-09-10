class_name StaffRecruitment
extends RefCounted

const StaffContractsClass = preload("res://simulation/staff/staff_contracts.gd")
const LedgerClass = preload("res://simulation/finance/ledger.gd")

func candidates(world: Dictionary, hiring_club_id: String, role: String, limit: int = 20) -> Array:
	var rows: Array = []
	for member in world.get("staff", []):
		if String(member.get("role", "")) != role or String(member.get("club_id", "")) == hiring_club_id: continue
		var ability := int(member.get("ability",50)); var current_club := String(member.get("club_id", ""))
		var compensation := 0 if current_club == "" else _remaining_compensation(world, String(member.id))
		rows.append({"staff_id":String(member.id),"name":String(member.get("name","")),"ability":ability,"current_club_id":current_club,"weekly_wage":StaffContractsClass.new().recommended_wage(member),"compensation":compensation,"score":ability*1.0-(compensation/100000.0)})
	rows.sort_custom(func(a: Dictionary,b: Dictionary):
		if is_equal_approx(float(a.score),float(b.score)): return String(a.staff_id)<String(b.staff_id)
		return float(a.score)>float(b.score)
	)
	if rows.size()>limit: rows.resize(limit)
	return rows

func hire(world: Dictionary, hiring_club_id: String, staff_id: String, weekly_wage: int, years: int) -> Error:
	var member := _staff(world,staff_id); var buyer := _club(world,hiring_club_id)
	if member.is_empty() or buyer.is_empty() or years<1 or years>5: return ERR_INVALID_PARAMETER
	var contracts = StaffContractsClass.new(); contracts.ensure_world(world)
	var minimum := int(contracts.recommended_wage(member)*0.8)
	if weekly_wage < minimum: return ERR_UNAUTHORIZED
	var previous := String(member.get("club_id", "")); var compensation := 0 if previous=="" else _remaining_compensation(world,staff_id)
	if int(buyer.get("cash",0)) < compensation: return ERR_UNAVAILABLE
	if compensation>0:
		var ledger=LedgerClass.new(); ledger.ensure(world); ledger.post(world,hiring_club_id,-compensation,"staff_compensation","staff-hire-"+staff_id,int(world.get("season_year",2026)))
		if previous!="": ledger.post(world,previous,compensation,"staff_compensation","staff-hire-"+staff_id,int(world.get("season_year",2026)))
	member.club_id=hiring_club_id
	var contract := _contract(world,staff_id)
	contract.club_id=hiring_club_id; contract.start_year=int(world.get("season_year",2026)); contract.end_year=int(contract.start_year)+years; contract.weekly_wage=weekly_wage
	return OK

func fire(world: Dictionary, club_id: String, staff_id: String) -> Error:
	var member := _staff(world,staff_id)
	if member.is_empty() or String(member.get("club_id", ""))!=club_id: return ERR_INVALID_PARAMETER
	var contract := _contract(world,staff_id); var severance := int(contract.get("weekly_wage",0))*12 if not contract.is_empty() else 0
	var club := _club(world,club_id)
	if severance>0 and int(club.get("cash",0))<severance: return ERR_UNAVAILABLE
	if severance>0:
		var ledger=LedgerClass.new(); ledger.ensure(world); ledger.post(world,club_id,-severance,"staff_severance","staff-fire-"+staff_id,int(world.get("season_year",2026)))
	member.club_id=""
	if not contract.is_empty(): contract.club_id=""
	return OK

func _remaining_compensation(world: Dictionary, staff_id: String) -> int:
	var contract := _contract(world,staff_id)
	if contract.is_empty(): return 0
	var years := maxi(0,int(contract.get("end_year",0))-int(world.get("season_year",2026)))
	return int(contract.get("weekly_wage",0))*52*years

func _contract(world: Dictionary,staff_id: String)->Dictionary:
	for contract in world.get("staff_contracts",[]):
		if String(contract.get("staff_id",""))==staff_id:return contract
	return {}

func _staff(world: Dictionary,staff_id: String)->Dictionary:
	for member in world.get("staff",[]):
		if String(member.get("id",""))==staff_id:return member
	return {}

func _club(world: Dictionary,club_id: String)->Dictionary:
	for club in world.get("clubs",[]):
		if String(club.get("id",""))==club_id:return club
	return {}
