class_name TransferMarket
extends RefCounted

const LedgerClass = preload("res://simulation/finance/ledger.gd")
const SeededRngClass = preload("res://core/rng/seeded_rng.gd")

var _ledger = LedgerClass.new()

func player_value(player: Dictionary, season_year: int) -> int:
	if bool(player.get("retired", false)):
		return 0
	var ca: int = int(player.current_ability)
	var potential: int = int(player.potential)
	var age: int = int(player.age)
	var peak_factor: float = 1.0 if age <= 28 else maxf(0.35, 1.0 - float(age - 28) * 0.08)
	var upside: int = maxi(0, potential - ca)
	return maxi(5_000, int((ca * ca * 700 + upside * 45_000) * peak_factor))

func process_contracts(world: Dictionary, season_year: int, seed: int) -> Dictionary:
	_ledger.ensure(world)
	var renewed: Array = []
	var released: Array = []
	for contract in world.contracts:
		if int(contract.end_year) > season_year:
			continue
		var player: Dictionary = _find_player(world.players, String(contract.player_id))
		if player.is_empty() or bool(player.get("retired", false)):
			continue
		var club: Dictionary = _find_club(world.clubs, String(contract.club_id))
		var proposed_wage: int = recommended_wage(player)
		if int(player.current_ability) >= 45 and proposed_wage <= int(club.wage_budget):
			contract.start_year = season_year
			contract.end_year = season_year + 3
			contract.weekly_wage = proposed_wage
			renewed.append(String(player.id))
		else:
			player.club_id = ""
			released.append(String(player.id))
	return {"renewed": renewed, "released": released}

func recommended_wage(player: Dictionary) -> int:
	return clampi(int(player.current_ability) * int(player.current_ability) * 5, 500, 60_000)

func negotiate_contract(player: Dictionary, club: Dictionary, offered_wage: int, years: int, seed: int) -> bool:
	if years < 1 or years > 5:
		return false
	var target: int = recommended_wage(player)
	var tolerance: int = _rand_int(seed, _stable_key(String(player.id) + String(club.id)), 85, 110)
	return offered_wage * 100 >= target * tolerance and offered_wage <= int(club.get("wage_budget", 250_000))

func execute_transfer(world: Dictionary, player_id: String, buyer_id: String, fee: int, wage: int, years: int, season_year: int, seed: int) -> Error:
	_ledger.ensure(world)
	var player: Dictionary = _find_player(world.players, player_id)
	var buyer: Dictionary = _find_club(world.clubs, buyer_id)
	if player.is_empty() or buyer.is_empty() or bool(player.get("retired", false)):
		return ERR_INVALID_PARAMETER
	var seller_id: String = String(player.get("club_id", ""))
	if seller_id == buyer_id:
		return ERR_ALREADY_EXISTS
	if fee < 0 or int(buyer.transfer_budget) < fee:
		return ERR_UNAVAILABLE
	if not negotiate_contract(player, buyer, wage, years, seed):
		return ERR_UNAUTHORIZED
	var reference := "transfer-%s-%d" % [player_id, season_year]
	_ledger.post(world, buyer_id, -fee, "transfer_fee", reference, season_year)
	if seller_id != "":
		_ledger.post(world, seller_id, fee, "transfer_fee", reference, season_year)
	player.club_id = buyer_id
	player.erase("loan_parent_club_id")
	player.erase("loan_end_year")
	_upsert_contract(world, player_id, buyer_id, season_year, season_year + years, wage)
	return OK

func execute_loan(world: Dictionary, player_id: String, borrower_id: String, fee: int, season_year: int) -> Error:
	_ledger.ensure(world)
	var player: Dictionary = _find_player(world.players, player_id)
	var borrower: Dictionary = _find_club(world.clubs, borrower_id)
	if player.is_empty() or borrower.is_empty() or String(player.club_id) == "":
		return ERR_INVALID_PARAMETER
	if int(borrower.transfer_budget) < fee:
		return ERR_UNAVAILABLE
	var parent_id: String = String(player.club_id)
	var reference := "loan-%s-%d" % [player_id, season_year]
	_ledger.post(world, borrower_id, -fee, "loan_fee", reference, season_year)
	_ledger.post(world, parent_id, fee, "loan_fee", reference, season_year)
	player.loan_parent_club_id = parent_id
	player.loan_end_year = season_year + 1
	player.club_id = borrower_id
	return OK

func return_expired_loans(world: Dictionary, season_year: int) -> int:
	var count := 0
	for player in world.players:
		if int(player.get("loan_end_year", 9999)) <= season_year and String(player.get("loan_parent_club_id", "")) != "":
			player.club_id = String(player.loan_parent_club_id)
			player.erase("loan_parent_club_id")
			player.erase("loan_end_year")
			count += 1
	return count

func rebalance_ai_squads(world: Dictionary, season_year: int, seed: int, min_squad: int = 20, max_squad: int = 30) -> Dictionary:
	_ledger.ensure(world)
	var free_agents: Array = []
	for player in world.players:
		if not bool(player.get("retired", false)) and String(player.get("club_id", "")) == "":
			free_agents.append(player)
	var signings := 0
	var releases := 0
	for club in world.clubs:
		var squad: Array = _squad(world.players, String(club.id))
		while squad.size() > max_squad:
			var weakest: Dictionary = _weakest(squad)
			weakest.club_id = ""
			free_agents.append(weakest)
			squad.erase(weakest)
			releases += 1
		while squad.size() < min_squad and not free_agents.is_empty():
			var target: Dictionary = _best_fit(free_agents, squad)
			var wage: int = recommended_wage(target)
			if wage > int(club.wage_budget):
				free_agents.erase(target)
				continue
			target.club_id = String(club.id)
			_upsert_contract(world, String(target.id), String(club.id), season_year, season_year + 2, wage)
			squad.append(target)
			free_agents.erase(target)
			signings += 1
	return {"signings": signings, "releases": releases, "free_agents": free_agents.size()}

func squad_is_viable(world: Dictionary, club_id: String, min_squad: int = 18) -> bool:
	var squad: Array = _squad(world.players, club_id)
	if squad.size() < min_squad:
		return false
	var has_gk := false
	var has_dc := false
	var has_st := false
	for player in squad:
		has_gk = has_gk or String(player.position) == "GK"
		has_dc = has_dc or String(player.position) == "DC"
		has_st = has_st or String(player.position) == "ST"
	return has_gk and has_dc and has_st

func _best_fit(free_agents: Array, squad: Array) -> Dictionary:
	var need_gk := true
	var need_dc := true
	var need_st := true
	for player in squad:
		need_gk = need_gk and String(player.position) != "GK"
		need_dc = need_dc and String(player.position) != "DC"
		need_st = need_st and String(player.position) != "ST"
	var best: Dictionary = free_agents[0]
	var best_score := -99999
	for player in free_agents:
		var score: int = int(player.current_ability)
		if need_gk and String(player.position) == "GK": score += 200
		if need_dc and String(player.position) == "DC": score += 200
		if need_st and String(player.position) == "ST": score += 200
		if score > best_score:
			best = player
			best_score = score
	return best

func _weakest(squad: Array) -> Dictionary:
	var weakest: Dictionary = squad[0]
	for player in squad:
		if int(player.current_ability) < int(weakest.current_ability):
			weakest = player
	return weakest

func _squad(players: Array, club_id: String) -> Array:
	var result: Array = []
	for player in players:
		if String(player.get("club_id", "")) == club_id and not bool(player.get("retired", false)):
			result.append(player)
	return result

func _upsert_contract(world: Dictionary, player_id: String, club_id: String, start_year: int, end_year: int, wage: int) -> void:
	for contract in world.contracts:
		if String(contract.player_id) == player_id:
			contract.club_id = club_id
			contract.start_year = start_year
			contract.end_year = end_year
			contract.weekly_wage = wage
			return
	world.contracts.append({"id": "contract-" + player_id, "player_id": player_id, "club_id": club_id, "start_year": start_year, "end_year": end_year, "weekly_wage": wage})

func _find_player(players: Array, player_id: String) -> Dictionary:
	for player in players:
		if String(player.id) == player_id:
			return player
	return {}

func _find_club(clubs: Array, club_id: String) -> Dictionary:
	for club in clubs:
		if String(club.id) == club_id:
			return club
	return {}

func _stable_key(text: String) -> int:
	var value := 23
	for character in text.to_utf8_buffer():
		value = posmod(value * 137 + int(character), 2_147_483_647)
	return value

func _rand_int(seed: int, key: int, min_value: int, max_value: int) -> int:
	return min_value + (SeededRngClass.value_for(seed, key) % (max_value - min_value + 1))
