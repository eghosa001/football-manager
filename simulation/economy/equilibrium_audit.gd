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
	var revenues: Array = []
	var debts := 0
	var bankrupt := 0
	var insolvent := 0
	for club in world.get("clubs", []):
		var cid := String(club.get("id", ""))
		var wage := float(bills.get(cid, float(club.get("wage_bill", club.get("wages", 0)))))
		wages.append(wage)
		var money := float(club.get("cash", 0))
		cash.append(money)
		revenues.append(float(club.get("commercial_revenue", 750_000)) + float(club.get("reputation", 50)) * 100_000.0)
		if money < 0:
			debts += 1
		if bool(club.get("bankrupt", false)) or money < -20_000_000:
			bankrupt += 1
		if bool(club.get("insolvent", false)):
			insolvent += 1
	wages.sort()
	cash.sort()
	var median_wage: float = float(wages[wages.size() / 2]) if not wages.is_empty() else 0.0
	var top_wage: float = float(wages[wages.size() - 1]) if not wages.is_empty() else 0.0
	var median_cash: float = float(cash[cash.size() / 2]) if not cash.is_empty() else 0.0
	var concentration: float = (top_wage / maxf(median_wage, 1.0)) if median_wage > 0.0 else 0.0
	var transfer_net := 0
	for entry in world.get("ledger", []):
		if String(entry.get("category", "")) in ["transfer_fee", "transfer_instalment", "sell_on_fee"]:
			transfer_net += int(entry.get("amount", 0))
	var wage_to_revenue := 0.0
	if not revenues.is_empty():
		var total_wages := 0.0
		var total_revenue := 0.0
		for i in range(wages.size()):
			total_wages += float(wages[i])
			total_revenue += float(revenues[mini(i, revenues.size() - 1)])
		wage_to_revenue = total_wages / maxf(1.0, total_revenue)
	var youth_count := 0
	for player in world.get("players", []):
		if not bool(player.get("retired", false)) and int(player.get("age", 99)) <= 21:
			youth_count += 1
	return {
		"clubs": world.get("clubs", []).size(),
		"median_wage": median_wage,
		"top_wage": top_wage,
		"median_cash": median_cash,
		"concentration": concentration,
		"indebted_share": float(debts) / float(maxi(1, world.get("clubs", []).size())),
		"bankrupt": bankrupt,
		"insolvent": insolvent,
		"transfer_net": transfer_net,
		"wage_to_revenue": wage_to_revenue,
		"youth_share": float(youth_count) / float(maxi(1, world.get("players", []).size())),
	}

static func healthy(report: Dictionary) -> bool:
	# Rich-club dominance bounded; bankruptcy rare; wages finite; cash real;
	# transfer ledger conserved; wage-to-revenue sane; youth pipeline alive.
	# Transfer conservation only applies when transfer entries exist.
	var transfer_ok := true
	if int(report.get("transfer_entries", report.get("transfer_net", 0))) != 0 or abs(int(report.get("transfer_net", 0))) > 0:
		transfer_ok = abs(int(report.get("transfer_net", 0))) == 0
	return float(report.get("concentration", 99.0)) < 12.0 and float(report.get("indebted_share", 1.0)) < 0.35 and int(report.get("bankrupt", 99)) <= maxi(2, int(report.get("clubs", 0)) / 40) and is_finite(float(report.get("top_wage", INF))) and int(report.get("insolvent", 99)) <= maxi(3, int(report.get("clubs", 0)) / 25) and transfer_ok and float(report.get("wage_to_revenue", 9.0)) < 2.0 and float(report.get("youth_share", 0.0)) > 0.05
