extends SceneTree

const Service = preload("res://simulation/transfers/competitive_bidding_service.gd")

func _init() -> void:
	var world := {
		"date":"2026-07-20",
		"day_index":12,
		"season_year":2026,
		"transfer_windows":[{"start_month":6,"start_day":15,"end_month":9,"end_day":1}],
		"transfer_offers":[{
			"id":"offer-target-human-1","player_id":"target","buyer_id":"human","seller_id":"seller","fee":30_000_000,
			"clauses":{},"status":"accepted"
		}],
		"clubs":[
			{"id":"human","name":"Human FC","country_id":"eng","reputation":74,"transfer_budget":80_000_000,"wage_budget":900_000,"cash":100_000_000,"financial_status":"secure"},
			{"id":"seller","name":"Seller FC","country_id":"eng","reputation":68,"transfer_budget":20_000_000,"wage_budget":500_000,"cash":30_000_000,"financial_status":"secure"},
			{"id":"rival","name":"Rival FC","country_id":"eng","reputation":78,"transfer_budget":100_000_000,"wage_budget":1_000_000,"cash":120_000_000,"financial_status":"secure"}
		],
		"players":[
			{"id":"target","club_id":"seller","first_name":"Target","last_name":"Player","position":"ST","current_ability":78,"potential":84,"age":24,"reputation":77,"fitness":100,"morale":70},
			{"id":"rival-gk","club_id":"rival","position":"GK","current_ability":70,"potential":72,"age":27},
			{"id":"rival-dc1","club_id":"rival","position":"DC","current_ability":72,"potential":74,"age":26},
			{"id":"rival-dc2","club_id":"rival","position":"DC","current_ability":71,"potential":73,"age":25},
			{"id":"rival-st","club_id":"rival","position":"ST","current_ability":55,"potential":58,"age":29}
		],
		"contracts":[],
		"ledger":[]
	}
	var result: Dictionary = Service.new().run(world,"human",555)
	assert(result.get("created", []).size() >= 1)
	var found := false
	for offer in world.get("transfer_offers", []):
		if bool(offer.get("ai_competitor", false)) and String(offer.get("player_id", "")) == "target" and String(offer.get("buyer_id", "")) == "rival":
			found = true
			break
	assert(found)
	assert(not world.get("inbox", []).is_empty())
	print("[TEST] COMPETITIVE BIDDING REGRESSION PASS")
	quit(0)
