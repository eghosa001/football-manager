class_name WorldIntegrityAudit
extends RefCounted

const ModernRulesClass = preload("res://simulation/competitions/modern_rules_catalog.gd")

func audit(world: Dictionary) -> Dictionary:
	var errors: Array = []
	var warnings: Array = []
	var stats := {}
	var indexes := _indexes(world,errors)
	_validate_players(world,indexes,errors,warnings)
	_validate_staff(world,indexes,errors,warnings)
	_validate_contracts(world,indexes,errors,warnings)
	_validate_competitions(world,indexes,errors,warnings)
	_validate_fixtures(world,indexes,errors,warnings)
	_validate_registrations(world,indexes,errors,warnings)
	_validate_finances(world,indexes,errors,warnings)
	_validate_transfers(world,indexes,errors,warnings)
	_validate_manager(world,indexes,errors,warnings)
	stats["clubs"] = world.get("clubs",[]).size()
	stats["players"] = world.get("players",[]).size()
	stats["competitions"] = world.get("competitions",[]).size()
	stats["fixtures"] = world.get("fixtures",[]).size()
	stats["contracts"] = world.get("contracts",[]).size()
	return {"ok":errors.is_empty(),"errors":errors,"warnings":warnings,"stats":stats}

func _indexes(world: Dictionary, errors: Array) -> Dictionary:
	var result := {}
	for kind in ["clubs","players","staff","competitions","contracts","fixtures"]:
		var values = world.get(kind,[])
		if not values is Array:
			errors.append({"code":"collection_not_array","collection":kind}); result[kind] = {}; continue
		var ids := {}
		for value in values:
			if not value is Dictionary:
				errors.append({"code":"entity_not_dictionary","collection":kind}); continue
			var id := String(value.get("id",""))
			if id == "": errors.append({"code":"empty_id","collection":kind}); continue
			if ids.has(id): errors.append({"code":"duplicate_id","collection":kind,"id":id})
			ids[id] = value
		result[kind] = ids
	return result

func _validate_players(world: Dictionary, indexes: Dictionary, errors: Array, warnings: Array) -> void:
	var clubs: Dictionary = indexes.clubs
	for player in world.get("players",[]):
		var id := String(player.get("id","")); var club_id := String(player.get("club_id",""))
		if club_id != "" and not clubs.has(club_id): errors.append({"code":"player_missing_club","player_id":id,"club_id":club_id})
		var age := int(player.get("age",0)); var ca := int(player.get("current_ability",-1)); var pa := int(player.get("potential",-1))
		if age < 14 or age > 60: errors.append({"code":"player_age_out_of_range","player_id":id,"age":age})
		if ca < 0 or ca > 100: errors.append({"code":"player_ca_out_of_range","player_id":id,"ca":ca})
		if pa < 0 or pa > 100: errors.append({"code":"player_pa_out_of_range","player_id":id,"pa":pa})
		if pa >= 0 and ca > pa: errors.append({"code":"player_ca_above_pa","player_id":id,"ca":ca,"pa":pa})
		for field in ["fitness","morale"]:
			if player.has(field) and (float(player[field]) < 0.0 or float(player[field]) > 100.0): errors.append({"code":"player_state_out_of_range","player_id":id,"field":field,"value":player[field]})
		if int(player.get("injured_days",0)) < 0: errors.append({"code":"negative_injury_days","player_id":id})
		if bool(player.get("retired",false)) and club_id != "": warnings.append({"code":"retired_player_still_assigned","player_id":id,"club_id":club_id})

func _validate_staff(world: Dictionary, indexes: Dictionary, errors: Array, warnings: Array) -> void:
	var clubs: Dictionary = indexes.clubs
	for member in world.get("staff",[]):
		var club_id := String(member.get("club_id",""))
		if club_id != "" and not clubs.has(club_id): errors.append({"code":"staff_missing_club","staff_id":String(member.get("id","")),"club_id":club_id})
		if member.has("ability") and (int(member.ability) < 0 or int(member.ability) > 100): errors.append({"code":"staff_ability_out_of_range","staff_id":String(member.get("id",""))})

func _validate_contracts(world: Dictionary, indexes: Dictionary, errors: Array, warnings: Array) -> void:
	var players: Dictionary = indexes.players; var clubs: Dictionary = indexes.clubs
	var active_by_player := {}
	for contract in world.get("contracts",[]):
		var id := String(contract.get("id","")); var player_id := String(contract.get("player_id","")); var club_id := String(contract.get("club_id",""))
		if not players.has(player_id): errors.append({"code":"contract_missing_player","contract_id":id,"player_id":player_id})
		if club_id != "" and not clubs.has(club_id): errors.append({"code":"contract_missing_club","contract_id":id,"club_id":club_id})
		if int(contract.get("weekly_wage",0)) < 0: errors.append({"code":"negative_contract_wage","contract_id":id})
		var start_year := int(contract.get("start_year",contract.get("start",0))); var end_year := int(contract.get("end_year",contract.get("end",start_year)))
		if end_year < start_year: errors.append({"code":"contract_end_before_start","contract_id":id})
		if not bool(contract.get("expired",false)) and player_id != "":
			if active_by_player.has(player_id) and String(players.get(player_id,{}).get("loan_parent_club_id","")) == "": warnings.append({"code":"multiple_active_contracts","player_id":player_id})
			active_by_player[player_id] = id

func _validate_competitions(world: Dictionary, indexes: Dictionary, errors: Array, warnings: Array) -> void:
	var clubs: Dictionary = indexes.clubs
	var modern_errors := ModernRulesClass.new().validate_world(world)
	for issue in modern_errors: errors.append({"code":"modern_rule_violation","detail":String(issue)})
	for competition in world.get("competitions",[]):
		var id := String(competition.get("id","")); var seen := {}
		for club_id_value in competition.get("club_ids",[]):
			var club_id := String(club_id_value)
			if not clubs.has(club_id): errors.append({"code":"competition_missing_club","competition_id":id,"club_id":club_id})
			if seen.has(club_id): errors.append({"code":"competition_duplicate_club","competition_id":id,"club_id":club_id})
			seen[club_id] = true
		var promotion := int(competition.get("promotion_places",0)); var relegation := int(competition.get("relegation_places",0)); var count := competition.get("club_ids",[]).size()
		if promotion < 0 or relegation < 0 or promotion > count or relegation > count: errors.append({"code":"competition_movement_out_of_range","competition_id":id})
		if int(competition.get("automatic_promotion_places",0)) + int(competition.get("playoff_promotion_places",0)) > promotion and promotion > 0: errors.append({"code":"promotion_breakdown_exceeds_total","competition_id":id})

func _validate_fixtures(world: Dictionary, indexes: Dictionary, errors: Array, warnings: Array) -> void:
	var clubs: Dictionary = indexes.clubs; var competitions: Dictionary = indexes.competitions
	var club_date := {}
	for fixture in world.get("fixtures",[]):
		var id := String(fixture.get("id","")); var home := String(fixture.get("home_club_id","")); var away := String(fixture.get("away_club_id","")); var competition_id := String(fixture.get("competition_id",""))
		if home == away and home != "": errors.append({"code":"fixture_same_club","fixture_id":id})
		if home != "" and not clubs.has(home): errors.append({"code":"fixture_missing_home","fixture_id":id,"club_id":home})
		if away != "" and not clubs.has(away): errors.append({"code":"fixture_missing_away","fixture_id":id,"club_id":away})
		if competition_id != "" and not competitions.has(competition_id): errors.append({"code":"fixture_missing_competition","fixture_id":id,"competition_id":competition_id})
		if bool(fixture.get("played",false)) and (int(fixture.get("home_goals",0)) < 0 or int(fixture.get("away_goals",0)) < 0): errors.append({"code":"negative_score","fixture_id":id})
		var date := String(fixture.get("date",""))
		if date != "":
			for club_id in [home,away]:
				if club_id == "": continue
				var key := "%s|%s" % [club_id,date]
				if club_date.has(key): errors.append({"code":"club_double_booked","club_id":club_id,"date":date,"fixtures":[club_date[key],id]})
				else: club_date[key] = id

func _validate_registrations(world: Dictionary, indexes: Dictionary, errors: Array, warnings: Array) -> void:
	var registrations = world.get("registrations",{})
	if not registrations is Dictionary: errors.append({"code":"registrations_not_dictionary"}); return
	var players: Dictionary = indexes.players; var clubs: Dictionary = indexes.clubs; var competitions: Dictionary = indexes.competitions
	for key in registrations.keys():
		var row: Dictionary = registrations[key]
		var club_id := String(row.get("club_id","")); var competition_id := String(row.get("competition_id","")); var seen := {}
		if not clubs.has(club_id): errors.append({"code":"registration_missing_club","key":key})
		if not competitions.has(competition_id): errors.append({"code":"registration_missing_competition","key":key})
		for player_id_value in row.get("player_ids",[]):
			var player_id := String(player_id_value)
			if seen.has(player_id): errors.append({"code":"registration_duplicate_player","key":key,"player_id":player_id})
			seen[player_id] = true
			if not players.has(player_id): errors.append({"code":"registration_missing_player","key":key,"player_id":player_id})
			elif String(players[player_id].get("club_id","")) != club_id: errors.append({"code":"registration_wrong_club","key":key,"player_id":player_id})
		if row.has("valid") and not bool(row.valid): warnings.append({"code":"registration_marked_invalid","key":key})

func _validate_finances(world: Dictionary, indexes: Dictionary, errors: Array, warnings: Array) -> void:
	for club in world.get("clubs",[]):
		var id := String(club.get("id",""))
		for field in ["transfer_budget","wage_budget"]:
			if club.has(field) and float(club[field]) < 0.0: errors.append({"code":"negative_budget","club_id":id,"field":field,"value":club[field]})
		if club.has("cash") and float(club.cash) < -2_000_000_000.0: warnings.append({"code":"extreme_negative_cash","club_id":id,"value":club.cash})
	for entry in world.get("ledger",[]):
		if entry.has("amount") and float(entry.amount) < 0.0: warnings.append({"code":"negative_ledger_amount","entry_id":String(entry.get("id",""))})

func _validate_transfers(world: Dictionary, indexes: Dictionary, errors: Array, warnings: Array) -> void:
	var players: Dictionary = indexes.players; var clubs: Dictionary = indexes.clubs
	for collection in ["transfer_cases","transfer_history","pending_transfers"]:
		for row in world.get(collection,[]):
			var player_id := String(row.get("player_id","")); var buyer := String(row.get("buyer_id",row.get("to_club_id",""))); var seller := String(row.get("seller_id",row.get("from_club_id","")))
			if player_id != "" and not players.has(player_id): errors.append({"code":"transfer_missing_player","collection":collection,"player_id":player_id})
			if buyer != "" and not clubs.has(buyer): errors.append({"code":"transfer_missing_buyer","collection":collection,"club_id":buyer})
			if seller != "" and not clubs.has(seller): errors.append({"code":"transfer_missing_seller","collection":collection,"club_id":seller})
			if buyer != "" and buyer == seller: errors.append({"code":"transfer_same_club","collection":collection,"player_id":player_id})
			if float(row.get("fee",0)) < 0.0 or float(row.get("wage",row.get("weekly_wage",0))) < 0.0: errors.append({"code":"negative_transfer_value","collection":collection,"player_id":player_id})

func _validate_manager(world: Dictionary, indexes: Dictionary, errors: Array, warnings: Array) -> void:
	var manager = world.get("human_manager",{})
	if manager is Dictionary and not manager.is_empty():
		var club_id := String(manager.get("club_id",""))
		if club_id != "" and not indexes.clubs.has(club_id): errors.append({"code":"human_manager_missing_club","club_id":club_id})
