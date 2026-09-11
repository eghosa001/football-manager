class_name TransferNegotiation
extends RefCounted

const TransferMarketClass = preload("res://simulation/transfers/transfer_market.gd")
const NegotiationDepthClass = preload("res://simulation/transfers/negotiation_depth.gd")
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
	var normalized := _normalized_clauses(fee, clauses)
	var offer := {
		"id":"offer-%s-%s-%d" % [String(player.id), String(buyer.id), world.transfer_offers.size()+1],
		"player_id":String(player.id),
		"buyer_id":String(buyer.id),
		"seller_id":String(player.get("club_id", "")),
		"fee":maxi(0, fee),
		"clauses":normalized,
		"status":"submitted",
		"reason_codes":[]
	}
	world.transfer_offers.append(offer)
	return offer

func evaluate_offer(world: Dictionary, offer: Dictionary, seed: int) -> String:
	var player := _find_player(world.get("players", []), String(offer.player_id))
	var seller := _find_club(world.get("clubs", []), String(offer.seller_id))
	if player.is_empty() or (String(offer.seller_id) != "" and seller.is_empty()):
		offer.status = "invalid"
		offer.reason_codes = ["missing_player_or_seller"]
		return offer.status
	var market := TransferMarketClass.new()
	var market_value := market.player_value(player, int(world.get("season_year", 2026)))
	var depth := NegotiationDepthClass.new()
	var structured := _normalized_clauses(int(offer.get("fee", 0)), offer.get("clauses", {}))
	structured["fee"] = int(offer.get("fee", structured.get("fee", 0)))
	# Keep the canonical market value in sync with the market engine used elsewhere.
	var valuation_player := player.duplicate(true)
	valuation_player["market_value"] = market_value
	var competing := _competing_live_offers(world, String(player.id), String(offer.id))
	var deadline := _deadline_day(world)
	var evaluation := depth.evaluate_structured(world, valuation_player, seller, structured, competing, seed, deadline)
	var happiness := float(player.get("happiness", player.get("morale", 70)))
	if happiness < 45.0:
		evaluation.required = int(float(evaluation.required) * 0.92)
		evaluation["player_pressure_discount"] = true
	var result_status := "accepted" if int(evaluation.get("package", 0)) >= int(evaluation.get("required", 0)) else "rejected"
	offer.status = result_status
	offer["valuation"] = evaluation
	offer["clauses"] = structured
	offer["reason_codes"] = _reason_codes(structured, evaluation, competing, deadline, seller, happiness)
	if result_status == "rejected":
		offer["counter_fee"] = maxi(int(offer.get("fee", 0)) + 1, int(evaluation.get("counter_fee", evaluation.get("required", market_value))))
	return offer.status

func player_interest(player: Dictionary, buyer: Dictionary, agent: Dictionary = {}) -> float:
	var ambition := float(player.get("hidden_attributes", {}).get("ambition", 50))
	var loyalty := float(player.get("hidden_attributes", {}).get("loyalty", 50))
	var buyer_rep := float(buyer.get("reputation", 50))
	var greed := float(agent.get("greed", 50))
	var tactical_fit := float(buyer.get("tactical_fit", 0.5))
	var playing_time := float(buyer.get("projected_playing_time", 0.5))
	return clampf(0.22 + buyer_rep / 180.0 + ambition / 300.0 - loyalty / 500.0 + greed / 1000.0 + tactical_fit * 0.08 + playing_time * 0.12, 0.0, 1.0)

func _normalized_clauses(fee: int, clauses: Dictionary) -> Dictionary:
	var sell_on_raw := float(clauses.get("sell_on_pct", clauses.get("sell_on", clauses.get("sell_on_percentage", 0.0))))
	if sell_on_raw > 1.0:
		sell_on_raw /= 100.0
	var sell_on_fraction := clampf(sell_on_raw, 0.0, 0.30)
	var normalized := {
		"fee":maxi(0, fee),
		"instalments":clampi(int(clauses.get("instalments", 1)), 1, 5),
		"sell_on_pct":sell_on_fraction,
		"sell_on_percentage":int(round(sell_on_fraction * 100.0)),
		"signing_bonus":maxi(0, int(clauses.get("signing_bonus", 0))),
		"wages":maxi(0, int(clauses.get("wages", 0))),
		"loan_fee":maxi(0, int(clauses.get("loan_fee", 0))),
		"wage_contribution_pct":clampf(float(clauses.get("wage_contribution_pct", 0.0)), 0.0, 1.0),
		"buy_option":maxi(0, int(clauses.get("buy_option", 0))),
		"buy_obligation":bool(clauses.get("buy_obligation", false)),
		"appearance_bonus":maxi(0, int(clauses.get("appearance_bonus", 0))),
		"goal_bonus":maxi(0, int(clauses.get("goal_bonus", 0))),
		"clean_sheet_bonus":maxi(0, int(clauses.get("clean_sheet_bonus", 0))),
		"release_clause":maxi(0, int(clauses.get("release_clause", 0))),
		"optional_extension_years":clampi(int(clauses.get("optional_extension_years", 0)), 0, 2),
		"promotion_wage_rise_pct":clampf(float(clauses.get("promotion_wage_rise_pct", 0.0)), 0.0, 1.0),
		"relegation_wage_drop_pct":clampf(float(clauses.get("relegation_wage_drop_pct", 0.0)), 0.0, 0.75),
		"squad_status":String(clauses.get("squad_status", "rotation"))
	}
	return normalized

func _competing_live_offers(world: Dictionary, player_id: String, offer_id: String) -> int:
	var count := 0
	for other in world.get("transfer_offers", []):
		if String(other.get("id", "")) == offer_id: continue
		if String(other.get("player_id", "")) == player_id and String(other.get("status", "")) in ["submitted", "accepted"]:
			count += 1
	return count

func _deadline_day(world: Dictionary) -> bool:
	var date_string := String(world.get("current_date", ""))
	var parts := date_string.split("-")
	if parts.size() != 3: return false
	var mmdd := int(parts[1]) * 100 + int(parts[2])
	for window in world.get("transfer_windows", []):
		if mmdd == int(window.get("end_month", 0)) * 100 + int(window.get("end_day", 0)):
			return true
	return false

func _reason_codes(structured: Dictionary, evaluation: Dictionary, competing: int, deadline: bool, seller: Dictionary, happiness: float) -> Array:
	var reasons: Array = []
	if int(structured.get("instalments", 1)) > 1: reasons.append("instalments_discounted")
	if float(structured.get("sell_on_pct", 0.0)) > 0.0: reasons.append("sell_on_value")
	if int(structured.get("buy_option", 0)) > 0: reasons.append("buy_option_value")
	if bool(structured.get("buy_obligation", false)): reasons.append("buy_obligation")
	if competing > 0: reasons.append("competing_bids")
	if deadline: reasons.append("deadline_premium")
	if int(seller.get("cash", 0)) < 0: reasons.append("seller_financial_pressure")
	if happiness < 45.0: reasons.append("player_wants_move")
	if int(evaluation.get("package", 0)) >= int(evaluation.get("required", 0)): reasons.append("package_meets_valuation")
	else: reasons.append("package_below_valuation")
	return reasons

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
