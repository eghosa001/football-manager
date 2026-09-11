class_name TransferNegotiation
extends RefCounted

const TransferMarketClass = preload("res://simulation/transfers/transfer_market.gd")
const SeededRngClass = preload("res://core/rng/seeded_rng.gd")

func ensure_world(world: Dictionary) -> void:
	world["transfer_offers"] = world.get("transfer_offers", [])
	world["transfer_windows"] = world.get("transfer_windows", [{"start_month":6,"start_day":15,"end_month":9,"end_day":1},{"start_month":1,"start_day":1,"end_month":1,"end_day":31}])

func is_window_open(world: Dictionary, date_string: String) -> bool:
	ensure_world(world)
	var parts := date_string.split("-")
	if parts.size() != 3:
		return false
	var mmdd := int(parts[1]) * 100 + int(parts[2])
	for window in world.transfer_windows:
		var start := int(window.start_month) * 100 + int(window.start_day)
		var finish := int(window.end_month) * 100 + int(window.end_day)
		if mmdd >= start and mmdd <= finish:
			return true
	return false

func create_offer(world: Dictionary, player: Dictionary, buyer: Dictionary, fee: int, clauses: Dictionary = {}) -> Dictionary:
	ensure_world(world)
	var normalized := _normalize_clauses(clauses)
	var offer := {
		"id":"offer-%s-%s-%d" % [String(player.id), String(buyer.id), world.transfer_offers.size()+1],
		"player_id":String(player.id),
		"buyer_id":String(buyer.id),
		"seller_id":String(player.get("club_id", "")),
		"fee":maxi(0, fee),
		"clauses":normalized,
		"status":"submitted"
	}
	world.transfer_offers.append(offer)
	return offer

func evaluate_offer(world: Dictionary, offer: Dictionary, seed: int) -> String:
	var player := _find_player(world.get("players", []), String(offer.player_id))
	var seller := _find_club(world.get("clubs", []), String(offer.seller_id))
	if player.is_empty() or (String(offer.seller_id) != "" and seller.is_empty()):
		offer.status = "invalid"
		return offer.status
	var market := TransferMarketClass.new()
	var value := market.player_value(player, int(world.get("season_year", 2026)))
	var seller_pressure := 1.0
	if not seller.is_empty():
		var cash := int(seller.get("cash", 0))
		if cash < 0: seller_pressure = 0.82
		elif cash > 25_000_000: seller_pressure = 1.15
	var happiness := float(player.get("happiness", player.get("morale", 70)))
	var desire_factor := 0.9 if happiness < 45.0 else 1.0
	var required := int(float(value) * seller_pressure * desire_factor)
	var variability := 90 + int(SeededRngClass.value_for(seed, _stable_key(String(offer.id))) % 21)
	required = required * variability / 100
	var effective_value := _effective_offer_value(offer, value)
	offer["effective_value"] = effective_value
	offer["required_value"] = required
	if effective_value >= required:
		offer.status = "accepted"
	else:
		offer.status = "rejected"
		offer["counter_fee"] = maxi(int(offer.fee) + 1, required - _non_cash_clause_value(offer, value))
	return offer.status

func player_interest(player: Dictionary, buyer: Dictionary, agent: Dictionary = {}) -> float:
	var ambition := float(player.get("hidden_attributes", {}).get("ambition", 50))
	var loyalty := float(player.get("hidden_attributes", {}).get("loyalty", 50))
	var buyer_rep := float(buyer.get("reputation", 50))
	var greed := float(agent.get("greed", 50))
	return clampf(0.3 + buyer_rep / 180.0 + ambition / 300.0 - loyalty / 500.0 + greed / 1000.0, 0.0, 1.0)

func _normalize_clauses(clauses: Dictionary) -> Dictionary:
	var sell_on := int(clauses.get("sell_on_percentage", clauses.get("sell_on_percent", 0)))
	var installments := clampi(int(clauses.get("installments", 1)), 1, 4)
	var installment_fee := maxi(0, int(clauses.get("installment_fee", 0)))
	var appearance_bonus := maxi(0, int(clauses.get("appearance_bonus", 0)))
	return {
		"sell_on_percentage": clampi(sell_on, 0, 50),
		"installments": installments,
		"installment_fee": installment_fee,
		"appearance_bonus": appearance_bonus,
	}

func _effective_offer_value(offer: Dictionary, player_value: int) -> int:
	return int(offer.get("fee", 0)) + _non_cash_clause_value(offer, player_value)

func _non_cash_clause_value(offer: Dictionary, player_value: int) -> int:
	var clauses: Dictionary = _normalize_clauses(offer.get("clauses", {}))
	var deferred := int(clauses.installment_fee)
	var sell_on_expected := int(float(player_value) * float(clauses.sell_on_percentage) / 100.0 * 0.30)
	var appearance_expected := int(float(clauses.appearance_bonus) * 0.50)
	return deferred + sell_on_expected + appearance_expected

func _find_player(players: Array, player_id: String) -> Dictionary:
	for player in players:
		if String(player.id) == player_id: return player
	return {}

func _find_club(clubs: Array, club_id: String) -> Dictionary:
	for club in clubs:
		if String(club.id) == club_id: return club
	return {}

func _stable_key(text: String) -> int:
	var value := 43
	for character in text.to_utf8_buffer():
		value = posmod(value * 149 + int(character), 2_147_483_647)
	return value
