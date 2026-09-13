class_name WorldIntegrityAudit
extends RefCounted

const ModernRulesClass = preload("res://simulation/competitions/modern_rules_catalog.gd")

func audit(world: Dictionary) -> Dictionary:
	var errors: Array = []
	var warnings: Array = []
	var stats: Dictionary = {}
	var indexes: Dictionary = _indexes(world,errors)
	_validate_players(world,indexes,errors,warnings)
	_validate_staff(world,indexes,errors,warnings)
	_validate_contracts(world,indexes,errors,warnings)
	_validate_competitions(world,indexes,errors,warnings)
	_validate_fixtures(world,indexes,errors,warnings)
	_validate_registrations(world,indexes,errors,warnings)
	_validate_discipline(world,indexes,errors,warnings)
	_validate_transfer_windows(world,errors,warnings)
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
	var result: Dictionary = {}
	for kind_value in ["clubs","players","staff","competitions","contracts","fixtures"]:
		var kind: String = String(kind_value)
		var values: Variant = world.get(kind,[])
		if not values is Array:
			errors.append({"code":"collection_not_array","collection":kind}); result[kind] = {}; continue
		var ids: Dictionary = {}
		for value in values:
			if not value is Dictionary:
				errors.append({"code":"entity_not_dictionary","collection":kind}); continue
			var id: String = String(value.get("id",""))
			if id == "": errors.append({"code":"empty_id","collection":kind}); continue
			if ids.has(id): errors.append({"code":"duplicate_id","collection":kind,"id":id})
			ids[id] = value
		result[kind] = ids
	return result

func _validate_players(world: Dictionary, indexes: Dictionary, errors: Array, warnings: Array) -> void:
	var clubs: Dictionary = indexes.clubs
	for player in world.get("players",[]):
		var id: String = String(player.get("id","")); var club_id: String = String(player.get("club_id",""))
		if club_id != "" and not clubs.has(club_id): errors.append({"code":"player_missing_club","player_id":id,"club_id":club_id})
		var age: int = int(player.get("age",0)); var ca: int = int(player.get("current_ability",-1)); var pa: int = int(player.get("potential",-1))
		if age < 14 or age > 60: errors.append({"code":"player_age_out_of_range","player_id":id,"age":age})
		if ca < 0 or ca > 100: errors.append({"code":"player_ca_out_of_range","player_id":id,"ca":ca})
		if pa < 0 or pa > 100: errors.append({"code":"player_pa_out_of_range","player_id":id,"pa":pa})
		if pa >= 0 and ca > pa: errors.append({"code":"player_ca_above_pa","player_id":id,"ca":ca,"pa":pa})
		for field_value in ["fitness","morale"]:
			var field: String = String(field_value)
			if player.has(field) and (float(player[field]) < 0.0 or float(player[field]) > 100.0): errors.append({"code":"player_state_out_of_range","player_id":id,"field":field,"value":player[field]})
		if int(player.get("injured_days",0)) < 0: errors.append({"code":"negative_injury_days","player_id":id})
		if bool(player.get("retired",false)) and club_id != "": warnings.append({"code":"retired_player_still_assigned","player_id":id,"club_id":club_id})

func _validate_staff(world: Dictionary, indexes: Dictionary, errors: Array, _warnings: Array) -> void:
	var clubs: Dictionary = indexes.clubs
	for member in world.get("staff",[]):
		var club_id: String = String(member.get("club_id",""))
		if club_id != "" and not clubs.has(club_id): errors.append({"code":"staff_missing_club","staff_id":String(member.get("id","")),"club_id":club_id})
		if member.has("ability") and (int(member.ability) < 0 or int(member.ability) > 100): errors.append({"code":"staff_ability_out_of_range","staff_id":String(member.get("id",""))})

func _validate_contracts(world: Dictionary, indexes: Dictionary, errors: Array, warnings: Array) -> void:
	var players: Dictionary = indexes.players; var clubs: Dictionary = indexes.clubs; var active_by_player: Dictionary = {}
	for contract in world.get("contracts",[]):
		var id: String = String(contract.get("id","")); var player_id: String = String(contract.get("player_id","")); var club_id: String = String(contract.get("club_id",""))
		if not players.has(player_id): errors.append({"code":"contract_missing_player","contract_id":id,"player_id":player_id})
		if club_id != "" and not clubs.has(club_id): errors.append({"code":"contract_missing_club","contract_id":id,"club_id":club_id})
		if int(contract.get("weekly_wage",0)) < 0: errors.append({"code":"negative_contract_wage","contract_id":id})
		var start_year: int = int(contract.get("start_year",contract.get("start",0))); var end_year: int = int(contract.get("end_year",contract.get("end",start_year)))
		if end_year < start_year: errors.append({"code":"contract_end_before_start","contract_id":id})
		if not bool(contract.get("expired",false)) and player_id != "":
			if active_by_player.has(player_id) and String(players.get(player_id,{}).get("loan_parent_club_id","")) == "": warnings.append({"code":"multiple_active_contracts","player_id":player_id})
			active_by_player[player_id] = id

func _validate_competitions(world: Dictionary, indexes: Dictionary, errors: Array, _warnings: Array) -> void:
	var clubs: Dictionary = indexes.clubs
	var modern_errors: Array = ModernRulesClass.new().validate_world(world)
	for issue in modern_errors: errors.append({"code":"modern_rule_violation","detail":String(issue)})
	for competition in world.get("competitions",[]):
		var id: String = String(competition.get("id","")); var seen: Dictionary = {}
		for club_id_value in competition.get("club_ids",[]):
			var club_id: String = String(club_id_value)
			if not clubs.has(club_id): errors.append({"code":"competition_missing_club","competition_id":id,"club_id":club_id})
			if seen.has(club_id): errors.append({"code":"competition_duplicate_club","competition_id":id,"club_id":club_id})
			seen[club_id] = true
		var promotion: int = int(competition.get("promotion_places",0)); var relegation: int = int(competition.get("relegation_places",0)); var count: int = int(competition.get("club_ids",[]).size())
		if promotion < 0 or relegation < 0 or promotion > count or relegation > count: errors.append({"code":"competition_movement_out_of_range","competition_id":id})
		if int(competition.get("automatic_promotion_places",0)) + int(competition.get("playoff_promotion_places",0)) > promotion and promotion > 0: errors.append({"code":"promotion_breakdown_exceeds_total","competition_id":id})
		if String(competition.get("competition_type","")) == "club_world_cup": _validate_cwc_competition(competition,errors)

func _validate_cwc_competition(competition: Dictionary, errors: Array) -> void:
	var id := String(competition.get("id","")); var clubs: Array = competition.get("club_ids",[]); var format: Dictionary = competition.get("format",{})
	if clubs.size() != 32: errors.append({"code":"cwc_club_count","competition_id":id,"count":clubs.size()})
	if int(format.get("groups",0)) != 8 or int(format.get("group_size",0)) != 4: errors.append({"code":"cwc_group_format","competition_id":id})
	if int(format.get("group_matches_per_club",0)) != 3: errors.append({"code":"cwc_group_match_count","competition_id":id})
	if int(format.get("qualifiers_per_group",0)) != 2: errors.append({"code":"cwc_qualification_format","competition_id":id})
	if bool(format.get("third_place_match",true)): errors.append({"code":"cwc_third_place_not_modern","competition_id":id})
	var groups: Array = competition.get("groups",[])
	if not groups.is_empty():
		if groups.size() != 8: errors.append({"code":"cwc_group_count","competition_id":id})
		var seen := {}
		for group in groups:
			if not group is Array or group.size() != 4: errors.append({"code":"cwc_group_size","competition_id":id}); continue
			for club_id in group:
				if seen.has(String(club_id)): errors.append({"code":"cwc_duplicate_group_club","competition_id":id,"club_id":String(club_id)})
				seen[String(club_id)] = true

func _validate_fixtures(world: Dictionary, indexes: Dictionary, errors: Array, _warnings: Array) -> void:
	var clubs: Dictionary = indexes.clubs; var competitions: Dictionary = indexes.competitions; var club_date: Dictionary = {}
	var cwc_group_fixture_count := 0
	for fixture in world.get("fixtures",[]):
		var id: String = String(fixture.get("id","")); var home: String = String(fixture.get("home_club_id","")); var away: String = String(fixture.get("away_club_id","")); var competition_id: String = String(fixture.get("competition_id",""))
		if home == away and home != "": errors.append({"code":"fixture_same_club","fixture_id":id})
		if home != "" and not clubs.has(home): errors.append({"code":"fixture_missing_home","fixture_id":id,"club_id":home})
		if away != "" and not clubs.has(away): errors.append({"code":"fixture_missing_away","fixture_id":id,"club_id":away})
		if competition_id != "" and not competitions.has(competition_id): errors.append({"code":"fixture_missing_competition","fixture_id":id,"competition_id":competition_id})
		if bool(fixture.get("played",false)) and (int(fixture.get("home_goals",0)) < 0 or int(fixture.get("away_goals",0)) < 0): errors.append({"code":"negative_score","fixture_id":id})
		if competition_id == "global-club-world-cup" and String(fixture.get("stage","")) == "group_stage": cwc_group_fixture_count += 1
		var date: String = String(fixture.get("date",""))
		if date != "":
			for club_id_value in [home,away]:
				var club_id: String = String(club_id_value)
				if club_id == "": continue
				var key: String = "%s|%s" % [club_id,date]
				if club_date.has(key): errors.append({"code":"club_double_booked","club_id":club_id,"date":date,"fixtures":[club_date[key],id]})
				else: club_date[key] = id
	if cwc_group_fixture_count > 0 and cwc_group_fixture_count != 48: errors.append({"code":"cwc_group_fixture_count","count":cwc_group_fixture_count})

func _validate_registrations(world: Dictionary, indexes: Dictionary, errors: Array, warnings: Array) -> void:
	var registrations: Variant = world.get("registrations",{})
	if not registrations is Dictionary: errors.append({"code":"registrations_not_dictionary"}); return
	var players: Dictionary = indexes.players; var clubs: Dictionary = indexes.clubs; var competitions: Dictionary = indexes.competitions
	for key in registrations.keys():
		var row: Dictionary = registrations[key]; var club_id: String = String(row.get("club_id","")); var competition_id: String = String(row.get("competition_id","")); var seen: Dictionary = {}
		if not clubs.has(club_id): errors.append({"code":"registration_missing_club","key":key})
		if not competitions.has(competition_id): errors.append({"code":"registration_missing_competition","key":key})
		var competition: Dictionary = competitions.get(competition_id,{})
		var max_squad: int = int(competition.get("registration_rules",{}).get("max_squad",999))
		if row.get("player_ids",[]).size() > max_squad: errors.append({"code":"registration_squad_limit","key":key,"count":row.get("player_ids",[]).size(),"max":max_squad})
		for player_id_value in row.get("player_ids",[]):
			var player_id: String = String(player_id_value)
			if seen.has(player_id): errors.append({"code":"registration_duplicate_player","key":key,"player_id":player_id})
			seen[player_id] = true
			if not players.has(player_id): errors.append({"code":"registration_missing_player","key":key,"player_id":player_id})
			elif String(players[player_id].get("club_id","")) != club_id: errors.append({"code":"registration_wrong_club","key":key,"player_id":player_id})
		if row.has("valid") and not bool(row.valid): warnings.append({"code":"registration_marked_invalid","key":key})

func _validate_discipline(world: Dictionary, indexes: Dictionary, errors: Array, _warnings: Array) -> void:
	var discipline: Variant = world.get("discipline",{})
	if not discipline is Dictionary: errors.append({"code":"discipline_not_dictionary"}); return
	for competition_id_value in discipline.keys():
		var competition_id := String(competition_id_value)
		if not indexes.competitions.has(competition_id): errors.append({"code":"discipline_missing_competition","competition_id":competition_id})
		var state: Dictionary = discipline[competition_id]
		for player_id_value in state.get("players",{}).keys():
			var player_id := String(player_id_value); var record: Dictionary = state.players[player_id]
			if not indexes.players.has(player_id): errors.append({"code":"discipline_missing_player","competition_id":competition_id,"player_id":player_id})
			if int(record.get("yellows",0)) < 0 or int(record.get("reds",0)) < 0 or int(record.get("ban_remaining",0)) < 0: errors.append({"code":"discipline_negative_value","competition_id":competition_id,"player_id":player_id})

func _validate_transfer_windows(world: Dictionary, errors: Array, warnings: Array) -> void:
	var windows: Variant = world.get("transfer_windows_by_country",{})
	if windows == null: return
	if not windows is Dictionary: errors.append({"code":"transfer_windows_not_dictionary"}); return
	for country_id in windows.keys():
		var values: Variant = windows[country_id]
		if not values is Array: errors.append({"code":"transfer_windows_country_not_array","country_id":String(country_id)}); continue
		if values.is_empty(): warnings.append({"code":"transfer_windows_empty","country_id":String(country_id)})
		for window in values:
			if not window is Dictionary: errors.append({"code":"transfer_window_not_dictionary","country_id":String(country_id)}); continue
			for field in ["start_month","start_day","end_month","end_day"]:
				if not window.has(field): errors.append({"code":"transfer_window_missing_field","country_id":String(country_id),"field":field})
			var sm := int(window.get("start_month",0)); var em := int(window.get("end_month",0)); var sd := int(window.get("start_day",0)); var ed := int(window.get("end_day",0))
			if sm < 1 or sm > 12 or em < 1 or em > 12 or sd < 1 or sd > 31 or ed < 1 or ed > 31: errors.append({"code":"transfer_window_invalid_date","country_id":String(country_id),"window":window})

func _validate_finances(world: Dictionary, _indexes: Dictionary, errors: Array, warnings: Array) -> void:
	for club in world.get("clubs",[]):
		var id: String = String(club.get("id",""))
		for field_value in ["transfer_budget","wage_budget"]:
			var field: String = String(field_value)
			if club.has(field) and float(club[field]) < 0.0: errors.append({"code":"negative_budget","club_id":id,"field":field,"value":club[field]})
		if club.has("cash") and float(club.cash) < -2_000_000_000.0: warnings.append({"code":"extreme_negative_cash","club_id":id,"value":club.cash})
	for entry in world.get("ledger",[]):
		if entry.has("amount") and float(entry.amount) < 0.0: warnings.append({"code":"negative_ledger_amount","entry_id":String(entry.get("id",""))})

func _validate_transfers(world: Dictionary, indexes: Dictionary, errors: Array, _warnings: Array) -> void:
	var players: Dictionary = indexes.players; var clubs: Dictionary = indexes.clubs
	for collection_value in ["transfer_cases","transfer_history","pending_transfers"]:
		var collection: String = String(collection_value)
		for row in world.get(collection,[]):
			var player_id: String = String(row.get("player_id","")); var buyer: String = String(row.get("buyer_id",row.get("to_club_id",""))); var seller: String = String(row.get("seller_id",row.get("from_club_id","")))
			if player_id != "" and not players.has(player_id): errors.append({"code":"transfer_missing_player","collection":collection,"player_id":player_id})
			if buyer != "" and not clubs.has(buyer): errors.append({"code":"transfer_missing_buyer","collection":collection,"club_id":buyer})
			if seller != "" and not clubs.has(seller): errors.append({"code":"transfer_missing_seller","collection":collection,"club_id":seller})
			if buyer != "" and buyer == seller: errors.append({"code":"transfer_same_club","collection":collection,"player_id":player_id})
			if float(row.get("fee",0)) < 0.0 or float(row.get("wage",row.get("weekly_wage",0))) < 0.0: errors.append({"code":"negative_transfer_value","collection":collection,"player_id":player_id})

func _validate_manager(world: Dictionary, indexes: Dictionary, errors: Array, _warnings: Array) -> void:
	var manager: Variant = world.get("human_manager",{})
	if manager is Dictionary and not manager.is_empty():
		var club_id: String = String(manager.get("club_id",""))
		if club_id != "" and not indexes.clubs.has(club_id): errors.append({"code":"human_manager_missing_club","club_id":club_id})
