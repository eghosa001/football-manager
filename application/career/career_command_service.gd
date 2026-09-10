class_name CareerCommandService
extends RefCounted

const TrainingSystemClass = preload("res://simulation/players/training_system.gd")
const ScoutingServiceClass = preload("res://simulation/scouting/scouting_service.gd")
const TransferNegotiationClass = preload("res://simulation/transfers/transfer_negotiation.gd")
const TransferMarketClass = preload("res://simulation/transfers/transfer_market.gd")
const AgentServiceClass = preload("res://simulation/transfers/agent_service.gd")
const LedgerClass = preload("res://simulation/finance/ledger.gd")
const TacticsManagerClass = preload("res://simulation/tactics/tactics_manager.gd")
const InboxServiceClass = preload("res://application/career/inbox_service.gd")
const PlayerPromisesClass = preload("res://simulation/players/player_promises.gd")

func set_training(world: Dictionary, club_id: String, sessions: Array, intensity: float) -> Error:
	var club := _club(world, club_id)
	if club.is_empty(): return ERR_DOES_NOT_EXIST
	var err := TrainingSystemClass.new().set_schedule(club, sessions, intensity)
	if err == OK: InboxServiceClass.new().add_message(world, "training", "Training schedule updated", "The first-team training schedule has been updated.")
	return err

func set_tactic(world: Dictionary, club_id: String, formation: String, mentality: String, tempo: String, pressing: String) -> Error:
	var club := _club(world, club_id)
	if club.is_empty(): return ERR_DOES_NOT_EXIST
	club["tactic"] = TacticsManagerClass.new().create_tactic(formation, mentality, tempo, pressing)
	InboxServiceClass.new().add_message(world, "tactics", "Tactical plan changed", "%s will now use %s with a %s mentality." % [String(club.get("name", "Club")), formation, mentality])
	return OK

func set_tactical_instruction(world: Dictionary, club_id: String, phase: String, key: String, value) -> Error:
	var club := _club(world, club_id)
	if club.is_empty(): return ERR_DOES_NOT_EXIST
	if not club.has("tactic"): club["tactic"] = TacticsManagerClass.new().create_tactic("4-3-3")
	return TacticsManagerClass.new().set_instruction(club.tactic, phase, key, value)

func make_player_promise(world: Dictionary, club_id: String, player_id: String, promise_type: String, target_value: int, days: int) -> Dictionary:
	var player := _player(world, player_id)
	if player.is_empty() or String(player.get("club_id", "")) != club_id:
		return {"error":ERR_INVALID_PARAMETER}
	var promise := PlayerPromisesClass.new().make_promise(world, player_id, promise_type, target_value, int(world.get("day_index", 0)) + maxi(1, days))
	InboxServiceClass.new().add_message(world, "dressing_room", "Promise made to %s" % _player_name(player), "You promised %s a %s target." % [_player_name(player), promise_type])
	return promise

func hold_team_meeting(world: Dictionary, club_id: String, tone: String) -> Dictionary:
	var club := _club(world, club_id)
	if club.is_empty(): return {"error":ERR_DOES_NOT_EXIST}
	var room := PlayerPromisesClass.new().hold_team_meeting(world, club_id, tone)
	InboxServiceClass.new().add_message(world, "dressing_room", "Team meeting completed", "The %s team meeting changed dressing-room atmosphere to %.1f." % [tone, float(room.get("atmosphere", 0.0))])
	return room

func assign_scout(world: Dictionary, club_id: String, player_id: String) -> Dictionary:
	var scout := _best_staff(world, club_id, "scout")
	if scout.is_empty(): return {"error":ERR_DOES_NOT_EXIST,"reason":"no_scout"}
	var player := _player(world, player_id)
	if player.is_empty(): return {"error":ERR_DOES_NOT_EXIST,"reason":"player_missing"}
	var assignment := ScoutingServiceClass.new().assign_scout(world, String(scout.id), "player", player_id, int(world.get("day_index", 0)))
	InboxServiceClass.new().add_message(world, "scouting", "Scouting assignment started", "%s has been assigned to scout %s." % [String(scout.get("name", "Scout")), _player_name(player)])
	return assignment

func submit_transfer_offer(world: Dictionary, club_id: String, player_id: String, fee: int, clauses: Dictionary = {}, seed: int = 1) -> Dictionary:
	var buyer := _club(world, club_id); var player := _player(world, player_id)
	if buyer.is_empty() or player.is_empty(): return {"error":ERR_DOES_NOT_EXIST}
	var negotiation = TransferNegotiationClass.new()
	if not negotiation.is_window_open(world, String(world.get("date", ""))): return {"error":ERR_UNAVAILABLE,"reason":"transfer_window_closed"}
	if String(player.get("club_id", "")) == club_id: return {"error":ERR_INVALID_PARAMETER,"reason":"player_already_at_club"}
	_ensure_finance_defaults(buyer)
	var offer: Dictionary = negotiation.create_offer(world, player, buyer, fee, clauses)
	var status := negotiation.evaluate_offer(world, offer, seed)
	InboxServiceClass.new().add_message(world, "transfers", "Transfer offer %s" % status, "Your offer for %s was %s." % [_player_name(player), status], status == "accepted", [{"id":"negotiate_contract","label":"Negotiate contract"}] if status == "accepted" else [])
	return offer

func contract_demand(world: Dictionary, club_id: String, player_id: String, seed: int = 1) -> Dictionary:
	var buyer := _club(world, club_id); var player := _player(world, player_id)
	if buyer.is_empty() or player.is_empty(): return {"error":ERR_DOES_NOT_EXIST}
	_ensure_finance_defaults(buyer)
	var market = TransferMarketClass.new()
	return AgentServiceClass.new().wage_demand(player, buyer, market.recommended_wage(player), seed)

func complete_transfer(world: Dictionary, offer_id: String, weekly_wage: int, signing_bonus: int, years: int, seed: int = 1) -> Dictionary:
	var offer := _offer(world, offer_id)
	if offer.is_empty() or String(offer.get("status", "")) != "accepted": return {"error":ERR_INVALID_PARAMETER,"reason":"offer_not_accepted"}
	var buyer := _club(world, String(offer.buyer_id)); var player := _player(world, String(offer.player_id))
	if buyer.is_empty() or player.is_empty(): return {"error":ERR_DOES_NOT_EXIST}
	_ensure_finance_defaults(buyer)
	var agent_result: Dictionary = AgentServiceClass.new().evaluate_offer(player, buyer, weekly_wage, signing_bonus, years, seed)
	if not bool(agent_result.get("accepted", false)):
		offer["contract_status"] = "rejected"
		return {"error":ERR_UNAUTHORIZED,"reason":"contract_rejected","agent":agent_result}
	var market = TransferMarketClass.new()
	var err := market.execute_transfer(world, String(player.id), String(buyer.id), int(offer.fee), weekly_wage, years, int(world.get("season_year", 2026)), seed)
	if err != OK: return {"error":err,"reason":"transfer_execution_failed","agent":agent_result}
	var ledger = LedgerClass.new(); ledger.ensure(world)
	if signing_bonus > 0: ledger.post(world, String(buyer.id), -signing_bonus, "signing_bonus", offer_id, int(world.get("season_year", 2026)))
	var agent_fee := int(agent_result.get("demand", {}).get("agent_fee", 0))
	if agent_fee > 0: ledger.post(world, String(buyer.id), -agent_fee, "agent_fee", offer_id, int(world.get("season_year", 2026)))
	var contract := _contract(world, String(player.id))
	contract["clauses"] = offer.get("clauses", {}).duplicate(true)
	contract["signing_bonus"] = signing_bonus
	contract["agent_fee"] = agent_fee
	offer.status = "completed"; offer["contract_status"] = "accepted"; offer["weekly_wage"] = weekly_wage; offer["years"] = years
	InboxServiceClass.new().add_message(world, "transfers", "%s signs" % _player_name(player), "%s has completed a transfer for %d and signed a %d-year contract." % [_player_name(player), int(offer.fee), years])
	return {"error":OK,"offer":offer,"contract":contract,"agent":agent_result}

func execute_loan(world: Dictionary, club_id: String, player_id: String, fee: int, seed: int = 1) -> Dictionary:
	var player := _player(world, player_id); var club := _club(world, club_id)
	if player.is_empty() or club.is_empty(): return {"error":ERR_DOES_NOT_EXIST}
	_ensure_finance_defaults(club)
	if not TransferNegotiationClass.new().is_window_open(world, String(world.get("date", ""))): return {"error":ERR_UNAVAILABLE,"reason":"transfer_window_closed"}
	var err := TransferMarketClass.new().execute_loan(world, player_id, club_id, fee, int(world.get("season_year", 2026)))
	if err == OK: InboxServiceClass.new().add_message(world, "transfers", "Loan completed", "%s has joined on loan." % _player_name(player))
	return {"error":err,"player_id":player_id,"fee":fee}

func renew_contract(world: Dictionary, club_id: String, player_id: String, weekly_wage: int, signing_bonus: int, years: int, seed: int = 1) -> Dictionary:
	var player := _player(world, player_id); var club := _club(world, club_id)
	if player.is_empty() or club.is_empty() or String(player.get("club_id", "")) != club_id: return {"error":ERR_INVALID_PARAMETER}
	_ensure_finance_defaults(club)
	var agent_result := AgentServiceClass.new().evaluate_offer(player, club, weekly_wage, signing_bonus, years, seed)
	if not bool(agent_result.accepted): return {"error":ERR_UNAUTHORIZED,"agent":agent_result}
	var contract := _contract(world, player_id)
	if contract.is_empty(): return {"error":ERR_DOES_NOT_EXIST}
	contract.start_year = int(world.get("season_year", 2026)); contract.end_year = int(contract.start_year) + years; contract.weekly_wage = weekly_wage; contract["signing_bonus"] = signing_bonus
	var ledger = LedgerClass.new(); ledger.ensure(world)
	if signing_bonus > 0: ledger.post(world, club_id, -signing_bonus, "signing_bonus", "renewal-"+player_id, int(world.get("season_year",2026)))
	InboxServiceClass.new().add_message(world, "contracts", "Contract renewed", "%s signed a new %d-year contract." % [_player_name(player), years])
	return {"error":OK,"contract":contract,"agent":agent_result}

func shortlist(world: Dictionary, club_id: String, limit: int = 30) -> Array:
	var club := _club(world, club_id)
	if club.is_empty(): return []
	var candidates: Array = []
	for player in world.get("players", []):
		if String(player.get("club_id", "")) == club_id or bool(player.get("retired", false)): continue
		var score := float(player.get("current_ability", 50)) + float(player.get("potential", 50)) * 0.35 - maxf(0.0,float(int(player.get("age",25))-27))*2.0
		candidates.append({"player":player,"score":score})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary):
		if is_equal_approx(float(a.score),float(b.score)): return String(a.player.id)<String(b.player.id)
		return float(a.score)>float(b.score)
	)
	var result: Array = []
	for i in range(mini(limit,candidates.size())): result.append(candidates[i].player)
	return result

func _ensure_finance_defaults(club: Dictionary) -> void:
	club["cash"] = int(club.get("cash", 20_000_000))
	club["transfer_budget"] = int(club.get("transfer_budget", maxi(1_000_000, int(club.cash * 0.35))))
	club["wage_budget"] = int(club.get("wage_budget", 500_000))

func _club(world: Dictionary, club_id: String) -> Dictionary:
	for club in world.get("clubs", []):
		if String(club.get("id", "")) == club_id: return club
	return {}

func _player(world: Dictionary, player_id: String) -> Dictionary:
	for player in world.get("players", []):
		if String(player.get("id", "")) == player_id: return player
	return {}

func _offer(world: Dictionary, offer_id: String) -> Dictionary:
	for offer in world.get("transfer_offers", []):
		if String(offer.get("id", "")) == offer_id: return offer
	return {}

func _contract(world: Dictionary, player_id: String) -> Dictionary:
	for contract in world.get("contracts", []):
		if String(contract.get("player_id", "")) == player_id: return contract
	return {}

func _best_staff(world: Dictionary, club_id: String, role: String) -> Dictionary:
	var best := {}
	for member in world.get("staff", []):
		if String(member.get("club_id", "")) != club_id or String(member.get("role", "")) != role: continue
		if best.is_empty() or int(member.get("ability", 0)) > int(best.get("ability", 0)): best = member
	return best

func _player_name(player: Dictionary) -> String:
	if player.has("name"): return String(player.name)
	return (String(player.get("first_name", "")) + " " + String(player.get("last_name", ""))).strip_edges()
