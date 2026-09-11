class_name NegotiationDepth
extends RefCounted

# Structured offer negotiation: instalments, sell-on, loan fees,
# wage contribution, buy options, competing offers, deadline behaviour.

const SeededRngClass = preload("res://core/rng/seeded_rng.gd")

func structured_offer(fee: int, instalments: int = 1, sell_on: float = 0.0, signing_bonus: int = 0, wages: int = 0) -> Dictionary:
	return {
		"fee": maxi(0, fee),
		"instalments": clampi(instalments, 1, 5),
		"instalment_value": maxi(0, fee) / float(maxi(1, instalments)),
		"sell_on_pct": clampf(sell_on, 0.0, 0.30),
		"signing_bonus": maxi(0, signing_bonus),
		"wages": maxi(0, wages),
	}

func loan_terms(fee: int, wage_pct: float, buy_option: int = 0, obligation: bool = false) -> Dictionary:
	return {
		"loan_fee": maxi(0, fee),
		"wage_contribution_pct": clampf(wage_pct, 0.0, 1.0),
		"buy_option": maxi(0, buy_option),
		"buy_obligation": obligation,
	}

func evaluate_structured(world: Dictionary, player: Dictionary, seller: Dictionary, offer: Dictionary, competing: int, seed: int, deadline_day: bool = false) -> Dictionary:
	var base_value := int(player.get("market_value", player.get("value", 1_000_000)))
	var cash := int(seller.get("cash", 0))
	var pressure := 0.82 if cash < 0 else (1.15 if cash > 25_000_000 else 1.0)
	var total_package := float(offer.get("fee", 0)) + float(offer.get("signing_bonus", 0)) * 0.4 + float(offer.get("sell_on_pct", 0.0)) * float(base_value) * 0.6
	# Instalments are discounted: sellers prefer cash now.
	total_package /= 1.0 + 0.04 * float(maxi(0, int(offer.get("instalments", 1)) - 1))
	var required := float(base_value) * pressure
	if competing > 0:
		required *= 1.0 + 0.06 * float(competing)
	if deadline_day:
		required *= 1.12
	var roll := float(SeededRngClass.value_for(seed, abs(hash(String(player.id))) % 100000) % 100) / 100.0
	required *= 0.92 + roll * 0.16
	if total_package >= required:
		return {"status": "accepted", "required": int(required), "package": int(total_package)}
	return {"status": "rejected", "required": int(required), "package": int(total_package), "counter_fee": int(required)}

func agent_fee(player: Dictionary, fee: int) -> int:
	var greed := float(player.get("hidden_attributes", {}).get("greed", 50))
	return int(float(fee) * (0.03 + greed / 2500.0))
