extends SceneTree

const EconomyClass = preload("res://simulation/finance/club_economy_service.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var economy = EconomyClass.new()
	var club: Dictionary = {
		"id": "club-regression",
		"name": "Regression FC",
		"reputation": 50,
		"cash": -2_000_000,
		"debt": 40_000_000,
		"transfer_budget": 1_000_000,
		"board": {"confidence": 60, "financial_prudence": 55},
		"supporters": {"mood": 60},
		"stadium": {},
		"facilities": {}
	}
	var world: Dictionary = {"clubs": [club], "players": [], "staff": [], "ledger": [], "domain_events": []}
	economy.ensure_world(world)
	economy._apply_insolvency(world, club, 2040)
	assert(int(club.debt) == 20_000_000)
	assert(bool(club.get("insolvent", false)))
	assert(String(club.get("financial_status", "")) == "insecure")
	var administration_events: Array = world.domain_events.filter(func(event): return String(event.get("type", "")) == "CLUB_ADMINISTRATION")
	var insolvency_events: Array = world.domain_events.filter(func(event): return String(event.get("type", "")) == "CLUB_INSOLVENT")
	assert(administration_events.size() == 1)
	assert(insolvency_events.size() == 1)
	assert(int(administration_events[0].payload.get("write_down", 0)) == 20_000_000)
	print("[TEST] CLUB ECONOMY SERVICE PASS")
	quit(0)
