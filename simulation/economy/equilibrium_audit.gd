class_name EquilibriumAudit
extends RefCounted

# Long-career economic equilibrium: bounded growth/decay checks.
# Prevents 50-100 year drift into nonsense (audit items 13-14).

static func audit_world(world: Dictionary) -> Dictionary:
	var bills := {}
	for contract in world.get("contracts", []):
		var cid := String(contract.get("club_id", ""))
		bills[cid] = float(bills.get(cid, 0.0)) + float(contract.get("weekly_wage", 0)) * 52.0
	var wages: Array = []
	var cash: Array = []
	var debts := 0
	var bankrupt := 0
	for club in world.get("clubs", []):
		var cid := String(club.get("id", ""))
		var wage := float(bills.get(cid, float(club.get("wage_bill", club.get("wages", 0)))))
		wages.append(wage)
		var money := float(club.get("cash", 0))
		cash.append(money)
		if money < 0:
			debts += 1
		if bool(club.get("bankrupt", false)) or money < -20_000_000:
			bankrupt += 1
	wages.sort()
	cash.sort()
	var median_wage: float = float(wages[wages.size() / 2]) if not wages.is_empty() else 0.0
	var top_wage: float = float(wages[wages.size() - 1]) if not wages.is_empty() else 0.0
	var concentration: float = (top_wage / maxf(median_wage, 1.0)) if median_wage > 0.0 else 0.0
	return {
		"clubs": world.get("clubs", []).size(),
		"median_wage": median_wage,
		"top_wage": top_wage,
		"concentration": concentration,
		"indebted_share": float(debts) / float(maxi(1, world.get("clubs", []).size())),
		"bankrupt": bankrupt,
	}

static func healthy(report: Dictionary) -> bool:
	# Rich-club dominance bounded; bankruptcy rare; wages finite.
	return float(report.get("concentration", 99.0)) < 12.0 and float(report.get("indebted_share", 1.0)) < 0.35 and int(report.get("bankrupt", 99)) <= maxi(2, int(report.get("clubs", 0)) / 40) and is_finite(float(report.get("top_wage", INF)))
