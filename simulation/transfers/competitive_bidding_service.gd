class_name CompetitiveBiddingService
extends RefCounted

const Negotiation = preload("res://simulation/transfers/transfer_negotiation.gd")
const Market = preload("res://simulation/transfers/transfer_market.gd")
const Inbox = preload("res://application/career/inbox_service.gd")

func run(world: Dictionary, managed_club_id: String, seed: int) -> Dictionary:
	Negotiation.new().ensure_world(world)
	var day := int(world.get("day_index", 0))
	var created: Array = []
	var completed: Array = []
	var human_targets := _human_live_targets(world, managed_club_id)
	for player_id in human_targets:
		var player := _player(world, player_id)
		if player.is_empty() or String(player.get("club_id", "")) == "":
			continue
		if _has_live_ai_offer(world, player_id, managed_club_id):
			continue
		var rival := _best_rival(world, player, managed_club_id)
		if rival.is_empty():
			continue
		var seller := _club(world, String(player.get("club_id", "")))
		var value := Market.new().estimated_value(player, seller, rival, int(world.get("season_year", 2026)))
		var budget := int(rival.get("transfer_budget", 0))
		var fee := mini(int(float(value) * 1.04), int(float(budget) * 0.55))
		if fee < 50_000:
			continue
		var offer := Negotiation.new().create_offer(world, player, rival, fee, {"instalments":2 if fee >= 5_000_000 else 1,"squad_status":"first_team"})
		offer["created_day"] = day
		offer["ai_competitor"] = true
		var status := Negotiation.new().evaluate_offer(world, offer, seed + _stable_key(player_id + String(rival.get("id", ""))))
		created.append({"player_id":player_id,"club_id":String(rival.get("id", "")),"club_name":String(rival.get("name", "Rival club")),"fee":fee,"status":status})
		Inbox.new().add_message(world, "transfers", "Rival bid for %s" % _player_name(player), "%s has entered the race for %s with an offer of %s." % [String(rival.get("name", "A rival club")), _player_name(player), _money(fee)])
	# Accepted AI offers are deliberately not completed immediately. The player gets
	# one day to respond to a bidding war; after that, the strongest affordable AI
	# offer can close before a delayed human deal.
	for player_id in _ai_accepted_targets(world, managed_club_id):
		if _human_completed(world, player_id, managed_club_id):
			continue
		var candidates := _accepted_ai_offers(world, player_id, managed_club_id)
		if candidates.is_empty():
			continue
		candidates.sort_custom(func(a: Dictionary,b: Dictionary): return _package_value(a) > _package_value(b))
		var winner: Dictionary = candidates[0]
		if day - int(winner.get("created_day", day)) < 1:
			continue
		var player := _player(world, player_id)
		var buyer := _club(world, String(winner.get("buyer_id", "")))
		if player.is_empty() or buyer.is_empty() or String(player.get("club_id", "")) == String(buyer.get("id", "")):
			continue
		var wage := Market.new().recommended_wage(player)
		var err := Market.new().execute_transfer(world, player_id, String(buyer.get("id", "")), int(winner.get("fee", 0)), wage, 3, int(world.get("season_year", 2026)), seed + day + _stable_key(player_id), winner.get("clauses", {}))
		if err != OK:
			continue
		winner["status"] = "completed"
		completed.append({"player_id":player_id,"buyer_id":String(buyer.get("id", "")),"buyer_name":String(buyer.get("name", "Club")),"fee":int(winner.get("fee",0))})
		Inbox.new().add_message(world, "transfers", "%s joins %s" % [_player_name(player), String(buyer.get("name", "a rival"))], "%s completed the signing before your club finalised the deal." % String(buyer.get("name", "A rival club")))
		_close_losing_offers(world, player_id, String(winner.get("id", "")))
	return {"created":created,"completed":completed}

func _human_live_targets(world: Dictionary, managed_club_id: String) -> Array:
	var result: Array = []
	for offer in world.get("transfer_offers", []):
		if String(offer.get("buyer_id", "")) != managed_club_id: continue
		if String(offer.get("status", "")) not in ["submitted","accepted","rejected"]: continue
		var player_id := String(offer.get("player_id", ""))
		if player_id != "" and player_id not in result: result.append(player_id)
	return result

func _best_rival(world: Dictionary, player: Dictionary, managed_club_id: String) -> Dictionary:
	var position := String(player.get("position", ""))
	var seller_id := String(player.get("club_id", ""))
	var value := Market.new().player_value(player, int(world.get("season_year", 2026)))
	var options: Array = []
	for club in world.get("clubs", []):
		var club_id := String(club.get("id", ""))
		if club_id in [managed_club_id, seller_id]: continue
		if int(club.get("transfer_budget", 0)) < int(float(value) * 0.35): continue
		var need := _position_need(world, club_id, position)
		if need <= 0.15: continue
		var rep_gap := absf(float(club.get("reputation",50)) - float(player.get("reputation",player.get("current_ability",50))))
		if float(club.get("reputation",50)) + 15.0 < float(player.get("reputation",player.get("current_ability",50))): continue
		var score := need * 100.0 - rep_gap * 0.35 + minf(25.0,float(club.get("transfer_budget",0))/maxf(1.0,float(value))*5.0)
		options.append({"club":club,"score":score})
	if options.is_empty(): return {}
	options.sort_custom(func(a: Dictionary,b: Dictionary): return float(a.score) > float(b.score))
	return options[0].club

func _position_need(world: Dictionary, club_id: String, position: String) -> float:
	var count := 0
	var total := 0.0
	for player in world.get("players", []):
		if String(player.get("club_id", "")) != club_id or bool(player.get("retired", false)): continue
		if String(player.get("position", "")) != position: continue
		count += 1
		total += float(player.get("current_ability", 0))
	if count == 0: return 1.0
	if count == 1: return 0.82
	var average := total / float(count)
	return clampf((68.0 - average) / 35.0, 0.0, 0.65)

func _has_live_ai_offer(world: Dictionary, player_id: String, managed_club_id: String) -> bool:
	for offer in world.get("transfer_offers", []):
		if String(offer.get("player_id", "")) == player_id and String(offer.get("buyer_id", "")) != managed_club_id and String(offer.get("status", "")) in ["submitted","accepted"]:
			return true
	return false

func _ai_accepted_targets(world: Dictionary, managed_club_id: String) -> Array:
	var result: Array = []
	for offer in world.get("transfer_offers", []):
		if String(offer.get("buyer_id", "")) == managed_club_id: continue
		if not bool(offer.get("ai_competitor", false)) or String(offer.get("status", "")) != "accepted": continue
		var player_id := String(offer.get("player_id", ""))
		if player_id != "" and player_id not in result: result.append(player_id)
	return result

func _accepted_ai_offers(world: Dictionary, player_id: String, managed_club_id: String) -> Array:
	var result: Array = []
	for offer in world.get("transfer_offers", []):
		if String(offer.get("player_id", "")) == player_id and String(offer.get("buyer_id", "")) != managed_club_id and String(offer.get("status", "")) == "accepted" and bool(offer.get("ai_competitor", false)):
			result.append(offer)
	return result

func _human_completed(world: Dictionary, player_id: String, managed_club_id: String) -> bool:
	for offer in world.get("transfer_offers", []):
		if String(offer.get("player_id", "")) == player_id and String(offer.get("buyer_id", "")) == managed_club_id and String(offer.get("status", "")) == "completed": return true
	return false

func _close_losing_offers(world: Dictionary, player_id: String, winner_id: String) -> void:
	for offer in world.get("transfer_offers", []):
		if String(offer.get("player_id", "")) == player_id and String(offer.get("id", "")) != winner_id and String(offer.get("status", "")) in ["submitted","accepted","rejected"]:
			offer["status"] = "lost_race"

func _package_value(offer: Dictionary) -> int:
	var value := int(offer.get("fee",0))
	var clauses: Dictionary = offer.get("clauses",{})
	value += int(clauses.get("signing_bonus",0))
	value += int(float(offer.get("fee",0))*float(clauses.get("sell_on_pct",0.0))*0.35)
	return value

func _player(world: Dictionary,id: String) -> Dictionary:
	for player in world.get("players",[]):
		if String(player.get("id",""))==id:return player
	return {}

func _club(world: Dictionary,id: String) -> Dictionary:
	for club in world.get("clubs",[]):
		if String(club.get("id",""))==id:return club
	return {}

func _player_name(player: Dictionary) -> String:
	var name := String(player.get("name","")).strip_edges()
	return name if name!="" else (String(player.get("first_name",""))+" "+String(player.get("last_name",""))).strip_edges()

func _money(value: int) -> String:
	if value>=1000000:return "£%.1fm" % (float(value)/1000000.0)
	if value>=1000:return "£%.0fk" % (float(value)/1000.0)
	return "£%d" % value

func _stable_key(text: String) -> int:
	var value := 131
	for c in text.to_utf8_buffer(): value=posmod(value*227+int(c),2147483647)
	return value
