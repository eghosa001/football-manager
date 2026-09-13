extends SceneTree

const Market = preload("res://simulation/transfers/transfer_market.gd")

func _init() -> void:
	var market = Market.new()
	var elite := {"id":"elite","current_ability":90,"potential":94,"age":24,"position":"ST","form":70,"morale":75,"reputation":92,"traits":["big_matches"]}
	var strong := {"id":"strong","current_ability":75,"potential":82,"age":25,"position":"MC","form":60,"morale":70,"reputation":75,"traits":[]}
	var lower := {"id":"lower","current_ability":42,"potential":50,"age":26,"position":"DC","form":50,"morale":65,"reputation":40,"traits":[]}
	var veteran := elite.duplicate(true)
	veteran["age"] = 34
	var seller := {"id":"seller","reputation":80,"financial_status":"secure"}
	var buyer := {"id":"buyer","reputation":80}
	var elite_value := market.estimated_value(elite, seller, buyer, 2026)
	var strong_value := market.estimated_value(strong, seller, buyer, 2026)
	var lower_value := market.estimated_value(lower, seller, buyer, 2026)
	var veteran_value := market.estimated_value(veteran, seller, buyer, 2026)
	assert(elite_value >= 80_000_000)
	assert(elite_value > strong_value)
	assert(strong_value > lower_value)
	assert(veteran_value < elite_value)
	assert(market.recommended_wage(elite) >= 180_000)
	assert(market.recommended_wage(elite) > market.recommended_wage(strong))
	print("[MARKET] elite=%d strong=%d lower=%d veteran=%d wage=%d" % [elite_value,strong_value,lower_value,veteran_value,market.recommended_wage(elite)])
	print("[TEST] MARKET REALISM REGRESSION PASS")
	quit(0)
