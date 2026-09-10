class_name FinanceLedger
extends RefCounted

func ensure(world: Dictionary) -> void:
	if not world.has("ledger"):
		world["ledger"] = []
	for club in world.clubs:
		club["transfer_budget"] = int(club.get("transfer_budget", int(club.get("cash", 0))))
		club["wage_budget"] = int(club.get("wage_budget", 250_000))

func post(world: Dictionary, club_id: String, amount: int, category: String, reference: String, season_year: int) -> void:
	ensure(world)
	world.ledger.append({"club_id": club_id, "amount": amount, "category": category, "reference": reference, "season_year": season_year})
	var club: Dictionary = _find_club(world.clubs, club_id)
	club.cash = int(club.cash) + amount
	club.transfer_budget = maxi(0, int(club.transfer_budget) + amount)

func balance(world: Dictionary, club_id: String) -> int:
	var total := 0
	for entry in world.get("ledger", []):
		if String(entry.club_id) == club_id:
			total += int(entry.amount)
	return total

func _find_club(clubs: Array, club_id: String) -> Dictionary:
	for club in clubs:
		if String(club.id) == club_id:
			return club
	assert(false, "Club not found: %s" % club_id)
	return {}
