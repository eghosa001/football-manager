class_name TransferActions
extends RefCounted

const TransferMarketClass = preload("res://simulation/transfers/transfer_market.gd")
const TransferNegotiationClass = preload("res://simulation/transfers/transfer_negotiation.gd")
const InboxServiceClass = preload("res://application/career/inbox_service.gd")

func arrange_loan(world: Dictionary, borrower_id: String, player_id: String, fee: int, wage_contribution_percent: int, option_fee: int, duration_years: int = 1) -> Dictionary:
	var player := _player(world, player_id)
	var borrower := _club(world, borrower_id)
	if player.is_empty() or borrower.is_empty(): return {"error":ERR_DOES_NOT_EXIST}
	if not TransferNegotiationClass.new().is_window_open(world, String(world.get("date", ""))): return {"error":ERR_UNAVAILABLE,"reason":"transfer_window_closed"}
	_ensure_finance_defaults(borrower)
	var err := TransferMarketClass.new().execute_loan(world, player_id, borrower_id, fee, int(world.get("season_year", 2026)), wage_contribution_percent, option_fee, duration_years)
	if err == OK:
		InboxServiceClass.new().add_message(world, "transfers", "Loan completed", "%s has joined on loan. Wage contribution: %d%%. Purchase option: %d." % [_player_name(player), clampi(wage_contribution_percent,0,100), maxi(0,option_fee)])
	return {"error":err,"player_id":player_id,"fee":fee,"wage_contribution":clampi(wage_contribution_percent,0,100),"option_fee":maxi(0,option_fee),"duration_years":duration_years}

func activate_option(world: Dictionary, borrower_id: String, player_id: String, weekly_wage: int, years: int, seed: int = 1) -> Dictionary:
	var player := _player(world, player_id)
	var borrower := _club(world, borrower_id)
	if player.is_empty() or borrower.is_empty(): return {"error":ERR_DOES_NOT_EXIST}
	_ensure_finance_defaults(borrower)
	var fee := int(player.get("loan_option_fee", 0))
	var err := TransferMarketClass.new().activate_loan_option(world, player_id, borrower_id, weekly_wage, years, int(world.get("season_year", 2026)), seed)
	if err == OK:
		InboxServiceClass.new().add_message(world, "transfers", "Purchase option activated", "%s has joined permanently for %d." % [_player_name(player), fee])
	return {"error":err,"player_id":player_id,"fee":fee}

func _ensure_finance_defaults(club: Dictionary) -> void:
	club["cash"] = int(club.get("cash", 20_000_000))
	club["transfer_budget"] = int(club.get("transfer_budget", maxi(1_000_000, int(club.cash * 0.35))))
	club["wage_budget"] = int(club.get("wage_budget", 500_000))

func _player(world: Dictionary, player_id: String) -> Dictionary:
	for player in world.get("players", []):
		if String(player.get("id", "")) == player_id: return player
	return {}

func _club(world: Dictionary, club_id: String) -> Dictionary:
	for club in world.get("clubs", []):
		if String(club.get("id", "")) == club_id: return club
	return {}

func _player_name(player: Dictionary) -> String:
	return String(player.get("name", (String(player.get("first_name", "")) + " " + String(player.get("last_name", ""))).strip_edges()))
