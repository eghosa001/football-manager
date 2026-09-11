class_name DomainValidator
extends RefCounted

const PLAYER_REQUIRED := {"id":TYPE_STRING,"club_id":TYPE_STRING,"age":TYPE_INT,"position":TYPE_STRING,"current_ability":TYPE_INT,"potential":TYPE_INT}
const CLUB_REQUIRED := {"id":TYPE_STRING,"name":TYPE_STRING}
const FIXTURE_REQUIRED := {"id":TYPE_STRING}
const CONTRACT_REQUIRED := {"id":TYPE_STRING,"player_id":TYPE_STRING,"club_id":TYPE_STRING}

func validate_world(world: Dictionary) -> Dictionary:
	var errors: Array = []
	var warnings: Array = []
	_validate_collection(world.get("players",[]),"player",PLAYER_REQUIRED,errors,warnings)
	_validate_collection(world.get("clubs",[]),"club",CLUB_REQUIRED,errors,warnings)
	_validate_collection(world.get("fixtures",[]),"fixture",FIXTURE_REQUIRED,errors,warnings)
	_validate_collection(world.get("contracts",[]),"contract",CONTRACT_REQUIRED,errors,warnings)
	_validate_references(world,errors)
	return {"ok":errors.is_empty(),"errors":errors,"warnings":warnings}

func validate_player(player: Dictionary) -> Dictionary:
	var errors: Array = []; var warnings: Array = []
	_validate_entity(player,"player",PLAYER_REQUIRED,errors,warnings)
	if int(player.get("age",0)) < 14 or int(player.get("age",0)) > 60: errors.append(_issue("player_age_out_of_range",player))
	if int(player.get("current_ability",0)) < 0 or int(player.get("current_ability",0)) > 200: errors.append(_issue("player_ca_out_of_range",player))
	if int(player.get("potential",0)) < int(player.get("current_ability",0)): warnings.append(_issue("potential_below_current_ability",player))
	return {"ok":errors.is_empty(),"errors":errors,"warnings":warnings}

func normalize_player(player: Dictionary) -> Dictionary:
	var value := player.duplicate(true)
	value["id"] = String(value.get("id",""))
	value["club_id"] = String(value.get("club_id",""))
	value["age"] = clampi(int(value.get("age",18)),14,60)
	value["position"] = String(value.get("position","MC"))
	value["current_ability"] = clampi(int(value.get("current_ability",50)),0,200)
	value["potential"] = clampi(int(value.get("potential",value.current_ability)),int(value.current_ability),200)
	value["retired"] = bool(value.get("retired",false))
	value["injured_days"] = maxi(0,int(value.get("injured_days",0)))
	return value

func _validate_collection(values, kind: String, required: Dictionary, errors: Array, warnings: Array) -> void:
	if typeof(values) != TYPE_ARRAY:
		errors.append({"code":"collection_not_array","collection":kind})
		return
	var ids := {}
	for value in values:
		if typeof(value) != TYPE_DICTIONARY:
			errors.append({"code":"entity_not_dictionary","collection":kind})
			continue
		_validate_entity(value,kind,required,errors,warnings)
		var id := String(value.get("id",""))
		if id != "":
			if ids.has(id): errors.append({"code":"duplicate_id","kind":kind,"id":id})
			ids[id]=true

func _validate_entity(value: Dictionary, kind: String, required: Dictionary, errors: Array, warnings: Array) -> void:
	for key in required.keys():
		if not value.has(key):
			errors.append({"code":"missing_required_field","kind":kind,"field":String(key),"id":String(value.get("id",""))})
			continue
		if typeof(value[key]) != int(required[key]):
			errors.append({"code":"wrong_field_type","kind":kind,"field":String(key),"id":String(value.get("id","")),"expected_type":int(required[key]),"actual_type":typeof(value[key])})
	if String(value.get("id","")) == "": errors.append({"code":"empty_id","kind":kind})

func _validate_references(world: Dictionary, errors: Array) -> void:
	var clubs := _ids(world.get("clubs",[])); var players := _ids(world.get("players",[]))
	for player in world.get("players",[]):
		var club_id := String(player.get("club_id",""))
		if club_id != "" and not clubs.has(club_id): errors.append({"code":"missing_club_reference","player_id":String(player.get("id","")),"club_id":club_id})
	for contract in world.get("contracts",[]):
		if not players.has(String(contract.get("player_id",""))): errors.append({"code":"missing_player_reference","contract_id":String(contract.get("id",""))})
		if not clubs.has(String(contract.get("club_id",""))): errors.append({"code":"missing_contract_club_reference","contract_id":String(contract.get("id",""))})
	for fixture in world.get("fixtures",[]):
		var home := String(fixture.get("home_club_id",fixture.get("home_id",""))); var away := String(fixture.get("away_club_id",fixture.get("away_id","")))
		if home != "" and not clubs.has(home): errors.append({"code":"missing_home_club_reference","fixture_id":String(fixture.get("id",""))})
		if away != "" and not clubs.has(away): errors.append({"code":"missing_away_club_reference","fixture_id":String(fixture.get("id",""))})
		if home != "" and home == away: errors.append({"code":"fixture_same_club","fixture_id":String(fixture.get("id",""))})

func _ids(values: Array) -> Dictionary:
	var result := {}
	for value in values:
		if typeof(value)==TYPE_DICTIONARY and String(value.get("id",""))!="": result[String(value.id)]=true
	return result

func _issue(code: String, value: Dictionary) -> Dictionary:
	return {"code":code,"id":String(value.get("id",""))}
