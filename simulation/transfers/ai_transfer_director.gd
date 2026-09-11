class_name AiTransferDirector
extends RefCounted

# Seasonal AI transfer market: needs-based, budget-guarded, fully deterministic.
# Each AI club may complete at most one paid signing per season plus free-agent
# top-ups handled by TransferMarket.rebalance_ai_squads. All fees flow through
# TransferMarket.execute_transfer so league cash is conserved (buyer -fee,
# seller +fee). Wage demands must fit inside the buyer's wage budget.

const MarketClass = preload("res://simulation/transfers/transfer_market.gd")
const NegotiationClass = preload("res://simulation/transfers/transfer_negotiation.gd")
const SeededRngClass = preload("res://core/rng/seeded_rng.gd")

const POSITION_NEEDS := ["GK", "DC", "DR", "DL", "DM", "MC", "AMR", "AML", "AMC", "ST"]
const MAX_PAID_SIGNINGS_PER_CLUB := 1

func run_season_market(world: Dictionary, season_year: int, seed: int) -> Dictionary:
	NegotiationClass.new().ensure_world(world)
	var market = MarketClass.new()
	var completed: Array = []
	var bids := 0
	var rejected := 0
	var skipped_budget := 0
	var clubs: Array = _ordered_clubs(world)
	for club in clubs:
		if String(club.get("id", "")) == String(world.get("human_manager", {}).get("club_id", "")):
			continue
		if int(_paid_signings(completed, String(club.get("id", "")))) >= MAX_PAID_SIGNINGS_PER_CLUB:
			continue
		var need := _weakest_need(world, club)
		if need == "":
			continue
		var target := _find_target(world, club, need, market, season_year)
		if target.is_empty():
			continue
		bids += 1
		var result := _attempt_signing(world, club, target, market, season_year, seed + _stable_key(String(club.get("id", "")) + String(target.get("id", ""))))
		if String(result.get("status", "")) == "completed":
			completed.append(result)
		elif String(result.get("status", "")) == "skipped_budget":
			skipped_budget += 1
		else:
			rejected += 1
	return {"bids": bids, "completed": completed, "completed_count": completed.size(), "rejected": rejected, "skipped_budget": skipped_budget, "season_year": season_year}

func _attempt_signing(world: Dictionary, buyer: Dictionary, player: Dictionary, market: RefCounted, season_year: int, seed: int) -> Dictionary:
	var buyer_id := String(buyer.get("id", ""))
	var value := int(market.player_value(player, season_year))
	var fee := _affordable_fee(buyer, value, seed)
	if fee <= 0:
		return {"status": "skipped_budget", "buyer_id": buyer_id, "player_id": String(player.get("id", ""))}
	var wage := int(market.recommended_wage(player))
	if not market.negotiate_contract(player, buyer, wage, 3, seed):
		# Try one step down: younger/cheaper wage still respects the structure.
		wage = int(wage * 0.9)
		if not market.negotiate_contract(player, buyer, wage, 3, seed + 5):
			return {"status": "rejected_contract", "buyer_id": buyer_id, "player_id": String(player.get("id", "")), "fee": fee}
	var negotiation = NegotiationClass.new()
	var offer: Dictionary = negotiation.create_offer(world, player, buyer, fee, {"instalments": 1, "squad_status": "rotation"})
	var status := negotiation.evaluate_offer(world, offer, seed)
	if status != "accepted":
		return {"status": "rejected_fee", "buyer_id": buyer_id, "player_id": String(player.get("id", "")), "fee": fee, "offer_id": String(offer.get("id", ""))}
	var err: Error = market.execute_transfer(world, String(player.get("id", "")), buyer_id, fee, wage, 3, season_year, seed)
	if err != OK:
		return {"status": "failed_execution", "buyer_id": buyer_id, "player_id": String(player.get("id", "")), "fee": fee, "error": err}
	return {"status": "completed", "buyer_id": buyer_id, "seller_id": String(offer.get("seller_id", "")), "player_id": String(player.get("id", "")), "fee": fee, "wage": wage, "offer_id": String(offer.get("id", ""))}

func _affordable_fee(buyer: Dictionary, value: int, seed: int) -> int:
	var budget := int(buyer.get("transfer_budget", 0))
	if budget <= 0:
		return 0
	# Keep a 40% reserve so AI never bankrupts itself; add small seeded haggle.
	var haggle := 0.82 + float(SeededRngClass.value_for(seed, 41000) % 17) / 100.0
	var fee := int(minf(float(value) * haggle, float(budget) * 0.6))
	return fee if fee >= 5000 else 0

func _weakest_need(world: Dictionary, club: Dictionary) -> String:
	var club_id := String(club.get("id", ""))
	var best_avg := 999.0
	var need := ""
	for position in POSITION_NEEDS:
		var players := _squad_at_position(world.get("players", []), club_id, position)
		if players.size() >= 2:
			continue
		var avg := 0.0
		if players.is_empty():
			avg = 20.0
		else:
			for player in players:
				avg += float(player.get("current_ability", 40))
			avg /= float(players.size())
		# Prefer genuine gaps, then weakest covered slot.
		var score := avg - (10.0 if players.is_empty() else 0.0)
		if score < best_avg:
			best_avg = score
			need = position
	return need

func _find_target(world: Dictionary, buyer: Dictionary, position: String, market: RefCounted, season_year: int) -> Dictionary:
	var buyer_id := String(buyer.get("id", ""))
	var buyer_rep := int(buyer.get("reputation", 50))
	var budget := int(buyer.get("transfer_budget", 0))
	var best := {}
	var best_score := -999999.0
	for player in world.get("players", []):
		if bool(player.get("retired", false)):
			continue
		if String(player.get("club_id", "")) == buyer_id or String(player.get("club_id", "")) == "":
			continue
		if String(player.get("position", "")) != position:
			continue
		var seller := _club(world.get("clubs", []), String(player.get("club_id", "")))
		if seller.is_empty():
			continue
		# Sellers must be weaker-or-equal, have depth, or the player must be unhappy.
		var seller_squad := _squad_at_position(world.get("players", []), String(seller.get("id", "")), position)
		var unhappy := float(player.get("happiness", player.get("morale", 70))) < 55.0
		if int(seller.get("reputation", 50)) > buyer_rep + 6 and not unhappy:
			continue
		if seller_squad.size() <= 1 and not unhappy:
			continue
		var value := int(market.player_value(player, season_year))
		if value > int(float(budget) * 0.6) + 1:
			continue
		var score := float(player.get("current_ability", 40)) + float(maxi(0, int(player.get("potential", 50)) - int(player.get("current_ability", 40)))) * 0.4 - maxf(0.0, float(int(player.get("age", 26)) - 27)) * 2.5
		score += 5.0 if unhappy else 0.0
		if score > best_score or (is_equal_approx(score, best_score) and String(player.get("id", "")) < String(best.get("id", ""))):
			best = player
			best_score = score
	return best

func _squad_at_position(players: Array, club_id: String, position: String) -> Array:
	var result: Array = []
	for player in players:
		if String(player.get("club_id", "")) != club_id:
			continue
		if bool(player.get("retired", false)):
			continue
		if int(player.get("injured_days", 0)) > 180:
			continue
		if String(player.get("position", "")) == position:
			result.append(player)
	return result

func _ordered_clubs(world: Dictionary) -> Array:
	var clubs: Array = world.get("clubs", []).duplicate()
	clubs.sort_custom(func(a: Dictionary, b: Dictionary):
		if int(a.get("reputation", 0)) == int(b.get("reputation", 0)):
			return String(a.get("id", "")) < String(b.get("id", ""))
		return int(a.get("reputation", 0)) < int(b.get("reputation", 0))
	)
	return clubs

func _paid_signings(completed: Array, club_id: String) -> int:
	var count := 0
	for row in completed:
		if String(row.get("buyer_id", "")) == club_id:
			count += 1
	return count

func _club(clubs: Array, club_id: String) -> Dictionary:
	for club in clubs:
		if String(club.get("id", "")) == club_id:
			return club
	return {}

func _stable_key(text: String) -> int:
	var value := 67
	for c in text.to_utf8_buffer():
		value = posmod(value * 151 + int(c), 2_147_483_647)
	return value
