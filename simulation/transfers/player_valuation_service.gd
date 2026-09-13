class_name PlayerValuationService
extends RefCounted

const Market = preload("res://simulation/transfers/transfer_market.gd")

func refresh_world(world: Dictionary) -> Dictionary:
	var clubs := {}
	for club in world.get("clubs", []):
		clubs[String(club.get("id", ""))] = club
	var contracts := {}
	for contract in world.get("contracts", []):
		var player_id := String(contract.get("player_id", ""))
		if player_id != "" and not bool(contract.get("expired", false)):
			contracts[player_id] = contract
	var changed := 0
	var total_value := 0
	var season_year := int(world.get("season_year", 2026))
	var market = Market.new()
	for player in world.get("players", []):
		if bool(player.get("retired", false)):
			player["market_value"] = 0
			continue
		var enriched: Dictionary = player.duplicate(true)
		var contract: Dictionary = contracts.get(String(player.get("id", "")), {})
		if not contract.is_empty():
			enriched["contract_end_year"] = int(contract.get("end_year", season_year + 2))
		var seller: Dictionary = clubs.get(String(player.get("club_id", "")), {})
		var value := market.estimated_value(enriched, seller, {}, season_year)
		if int(player.get("market_value", -1)) != value:
			changed += 1
		player["market_value"] = value
		total_value += value
	world["market_values_refreshed_day"] = int(world.get("day_index", 0))
	return {"changed":changed,"players":world.get("players",[]).size(),"total_value":total_value}
