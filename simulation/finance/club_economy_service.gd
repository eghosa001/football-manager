class_name ClubEconomyService
extends "res://simulation/finance/club_economy.gd"

# Stable production facade for finance execution. Keep insolvency event emission
# explicit: Array.append() returns void and must never be used as the value of
# a conditional expression in GDScript.
func _apply_insolvency(world: Dictionary, club: Dictionary, season_year: int) -> void:
	var debt := int(club.get("debt", 0))
	if debt > 30_000_000:
		var write_down := int(debt * 0.5)
		club.debt = debt - write_down
		_ledger.post(world, String(club.id), 0, "debt_service", "restructure-%s-%d" % [String(club.id), season_year], season_year)
		if world.has("domain_events"):
			world.domain_events.append({"type": "CLUB_ADMINISTRATION", "payload": {"club_id": String(club.get("id", "")), "write_down": write_down, "season_year": season_year}})
		debt = int(club.get("debt", 0))
	var ratio := float(debt) / maxf(1.0, float(int(club.get("cash", 0)) + debt))
	if ratio < 0.85 and int(club.get("cash", 0)) > -1_500_000:
		return
	club["insolvent"] = true
	club.financial_status = "insecure"
	club.transfer_budget = 0
	club.board.confidence = clampi(int(club.board.get("confidence", 60)) - 12, 0, 100)
	club.supporters.mood = clampi(int(club.supporters.get("mood", 60)) - 10, 0, 100)
	if not world.has("domain_events"):
		world["domain_events"] = []
	world.domain_events.append({"type": "CLUB_INSOLVENT", "payload": {"club_id": String(club.get("id", "")), "cash": int(club.get("cash", 0)), "debt": int(club.get("debt", 0)), "season_year": season_year}})
