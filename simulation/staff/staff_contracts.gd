class_name StaffContracts
extends RefCounted

func ensure_world(world: Dictionary) -> void:
	world["staff_contracts"] = world.get("staff_contracts", [])
	for member in world.get("staff", []):
		var staff_id := String(member.get("id", ""))
		if staff_id == "" or _contract(world, staff_id).is_empty() == false:
			continue
		world.staff_contracts.append({"id":"staff-contract-"+staff_id,"staff_id":staff_id,"club_id":String(member.get("club_id", "")),"start_year":int(world.get("season_year", 2026)),"end_year":int(world.get("season_year", 2026))+2,"weekly_wage":recommended_wage(member)})

func recommended_wage(member: Dictionary) -> int:
	var ability := int(member.get("ability", 50))
	var role := String(member.get("role", "coach"))
	var multiplier := 3.0 if role == "manager" else (2.0 if role in ["assistant_manager","assistant"] else 1.0)
	return maxi(150, int(float(ability * ability) * multiplier))

func renew(world: Dictionary, staff_id: String, club_id: String, years: int, weekly_wage: int) -> Error:
	ensure_world(world)
	if years < 1 or years > 5: return ERR_INVALID_PARAMETER
	var member := _staff(world, staff_id)
	if member.is_empty() or String(member.get("club_id", "")) != club_id: return ERR_INVALID_PARAMETER
	if weekly_wage < int(recommended_wage(member) * 0.75): return ERR_UNAUTHORIZED
	var contract := _contract(world, staff_id)
	if contract.is_empty(): return ERR_DOES_NOT_EXIST
	contract.club_id = club_id
	contract.start_year = int(world.get("season_year", 2026))
	contract.end_year = int(contract.start_year) + years
	contract.weekly_wage = weekly_wage
	return OK

func process_expiring(world: Dictionary, year: int) -> Dictionary:
	ensure_world(world)
	var renewed: Array = []
	var released: Array = []
	for contract in world.staff_contracts:
		if int(contract.get("end_year", 9999)) > year: continue
		var member := _staff(world, String(contract.staff_id))
		if member.is_empty(): continue
		var club_id := String(member.get("club_id", ""))
		if club_id == "": continue
		var wage := recommended_wage(member)
		if int(member.get("ability", 50)) >= 45:
			contract.start_year = year
			contract.end_year = year + 2
			contract.weekly_wage = wage
			renewed.append(String(member.id))
		else:
			member.club_id = ""
			contract.club_id = ""
			released.append(String(member.id))
	return {"renewed":renewed,"released":released}

func _contract(world: Dictionary, staff_id: String) -> Dictionary:
	for contract in world.get("staff_contracts", []):
		if String(contract.get("staff_id", "")) == staff_id: return contract
	return {}

func _staff(world: Dictionary, staff_id: String) -> Dictionary:
	for member in world.get("staff", []):
		if String(member.get("id", "")) == staff_id: return member
	return {}
