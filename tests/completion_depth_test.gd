extends SceneTree

# Completion-depth gate: full attribute system, AI transfer director
# (budget-safe, cash-conserving, deterministic) and boardroom services.

func _init() -> void:
	_test_player_attributes()
	_test_ai_transfer_director()
	_test_board_service()
	print("[TEST] COMPLETION DEPTH PASS")
	quit(0)

func _test_player_attributes() -> void:
	var lib = preload("res://simulation/players/player_attributes.gd").new()
	var striker := {"id": "p-test-st", "position": "ST", "current_ability": 70, "potential": 85, "age": 24}
	lib.ensure(striker, 4242)
	var attrs: Dictionary = striker.get("attributes", {})
	for name in ["finishing", "off_the_ball", "passing", "tackling", "technique", "pace", "stamina", "decisions", "vision", "composure"]:
		assert(attrs.has(name), "missing attribute: " + name)
	# Position shaping: strikers finish better than they tackle.
	assert(int(attrs.get("finishing", 0)) > int(attrs.get("tackling", 0)))
	assert(String(striker.get("personality", "")) != "")
	assert(striker.has("traits") and striker.has("preferred_foot") and striker.has("position_familiarity"))
	assert(int(striker.get("market_value", 0)) > 0)
	var keeper := {"id": "p-test-gk", "position": "GK", "current_ability": 68, "potential": 80, "age": 27}
	lib.ensure(keeper, 4242)
	assert(int(keeper.get("attributes", {}).get("reflexes", 0)) > int(keeper.get("attributes", {}).get("finishing", 99)))
	# Ensure is additive: never overwrites existing detail.
	var before: int = int(attrs.get("finishing", 0))
	lib.ensure(striker, 9999)
	assert(attrs.get("finishing", 0) == before)
	# Deterministic: same id+seed regenerates identical attributes.
	var twin := {"id": "p-test-st", "position": "ST", "current_ability": 70, "potential": 85, "age": 24}
	lib.ensure(twin, 4242)
	assert(str(twin.get("attributes", {})) == str(attrs))

func _test_ai_transfer_director() -> void:
	var world: Dictionary = preload("res://data/launch_world_builder.gd").new().build(5150, 2)
	preload("res://application/career/career_session.gd").new()
	# Seed known conditions: give AI clubs budgets and create a gap.
	for club in world.get("clubs", []):
		club["transfer_budget"] = 5000000
		club["wage_budget"] = 500000
		club["cash"] = 20000000
	var cash_before := _league_cash(world)
	var first: Dictionary = preload("res://simulation/transfers/ai_transfer_director.gd").new().run_season_market(world, 2026, 777)
	var cash_after := _league_cash(world)
	# League cash conserved: fees are buyer->seller transfers.
	assert(cash_before == cash_after, "AI market must conserve league cash")
	for signing in first.get("completed", []):
		assert(int(signing.get("fee", 0)) >= 5000)
		assert(String(signing.get("buyer_id", "")) != "" and String(signing.get("player_id", "")) != "")
	# Deterministic: identical world+seed repeats identical signings.
	var world_b: Dictionary = preload("res://data/launch_world_builder.gd").new().build(5150, 2)
	for club in world_b.get("clubs", []):
		club["transfer_budget"] = 5000000
		club["wage_budget"] = 500000
		club["cash"] = 20000000
	var second: Dictionary = preload("res://simulation/transfers/ai_transfer_director.gd").new().run_season_market(world_b, 2026, 777)
	assert(str(first.get("completed", [])) == str(second.get("completed", [])))
	# Squads remain viable after the market.
	var market = preload("res://simulation/transfers/transfer_market.gd").new()
	for club in world.get("clubs", []).slice(0, 12):
		assert(market.squad_is_viable(world, String(club.get("id", "")), 15))

func _test_board_service() -> void:
	var world: Dictionary = preload("res://data/launch_world_builder.gd").new().build(6161, 1)
	var session = preload("res://application/career/career_session.gd").new()
	session.new_career("Board Test", "eng-t1-c01", 6161, 1, [], false)
	var w: Dictionary = session.world
	var command = preload("res://application/career/career_command_service.gd").new()
	var review: Dictionary = command.board_season_review(w, session.managed_club_id)
	assert(review.has("overall") and review.has("objectives"))
	var security: Dictionary = command.job_security_report(w, session.managed_club_id)
	assert(String(security.get("status", "")) in ["secure", "stable", "under_pressure", "critical"])
	var fans: Dictionary = command.supporter_report(w, session.managed_club_id)
	assert(fans.has("mood") and fans.has("attendance_outlook"))
	var session_b = preload("res://application/career/career_session.gd").new()
	session_b.new_career("Board Test", "eng-t1-c01", 6161, 1, [], false)
	var session_c = preload("res://application/career/career_session.gd").new()
	session_c.new_career("Board Test", "eng-t1-c01", 6161, 1, [], false)
	var first: Dictionary = command.request_board_budget(session_b.world, session_b.managed_club_id, "transfer", 500000, 42)
	var second: Dictionary = command.request_board_budget(session_c.world, session_c.managed_club_id, "transfer", 500000, 42)
	assert(str(first) == str(second), "board decisions must be deterministic")

func _league_cash(world: Dictionary) -> int:
	var total := 0
	for club in world.get("clubs", []):
		total += int(club.get("cash", 0))
	return total
