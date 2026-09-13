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

	# Older or hand-edited saves can contain partially corrupt nested finance
	# structures. The production facade must normalize them instead of crashing.
	var malformed: Dictionary = {
		"id":"legacy-club","name":"Legacy FC","reputation":45,"cash":1_000_000,
		"stadium":"legacy","facilities":null,"supporters":[],"board":"old",
		"ticket_price":-10,"commercial_revenue":-100,"debt":-5
	}
	economy.ensure_club(malformed)
	assert(malformed.stadium is Dictionary and int(malformed.stadium.capacity) >= 500)
	assert(malformed.facilities is Dictionary and int(malformed.facilities.training) >= 1)
	assert(malformed.supporters is Dictionary and int(malformed.supporters.size) >= 500)
	assert(malformed.board is Dictionary and malformed.board.objectives is Array and not malformed.board.objectives.is_empty())
	assert(int(malformed.ticket_price) >= 1)
	assert(int(malformed.commercial_revenue) >= 0)
	assert(int(malformed.debt) == 0)
	assert(malformed.sponsorships is Array and not malformed.sponsorships.is_empty())

	print("[TEST] CLUB ECONOMY SERVICE PASS")
	quit(0)
