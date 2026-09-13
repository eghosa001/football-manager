extends SceneTree

const WindowService = preload("res://simulation/transfers/transfer_window_service.gd")
const Negotiation = preload("res://simulation/transfers/transfer_negotiation.gd")

var failures := 0
var checks := 0

func _init() -> void:
	_test_managed_country_fallback()
	_test_explicit_club_country()
	_test_offer_rejects_closed_buyer_window()
	_test_invalid_calendar_dates_fail_closed()
	_test_malformed_country_windows_fail_closed()
	if failures == 0:
		print("[TEST] TRANSFER WINDOW COUNTRY PASS: managed-club, buyer-country and invalid-date windows verified")
		quit(0)
		return
	push_error("[TEST] TRANSFER WINDOW COUNTRY FAIL: %d failures across %d checks" % [failures,checks])
	quit(1)

func _world() -> Dictionary:
	return {
		"date":"2026-06-20",
		"default_country_id":"eng",
		"human_manager":{"club_id":"esp-club"},
		"clubs":[
			{"id":"eng-club","country_id":"eng","name":"England Club"},
			{"id":"esp-club","country_id":"esp","name":"Spain Club"}
		],
		"players":[{"id":"p1","club_id":"eng-club","current_ability":70,"potential":75,"age":24,"morale":70}],
		"transfer_windows_by_country":{
			"eng":[{"start_month":6,"start_day":10,"end_month":9,"end_day":1}],
			"esp":[{"start_month":7,"start_day":1,"end_month":9,"end_day":1}]
		},
		"transfer_windows":[{"start_month":6,"start_day":10,"end_month":9,"end_day":1}],
		"transfer_offers":[]
	}

func _test_managed_country_fallback() -> void:
	var world := _world()
	var service = WindowService.new()
	var status := service.window_status(world,"2026-06-20")
	_require(String(status.get("country_id","")) == "esp","generic human-manager checks must resolve the managed club country")
	_require(not bool(status.get("open",true)),"Spain window must still be closed on 20 June")
	world.human_manager.club_id = "eng-club"
	_require(service.is_open(world,"2026-06-20"),"managed English club must use England's open June window")

func _test_explicit_club_country() -> void:
	var world := _world()
	var service = WindowService.new()
	_require(service.is_open_for_club(world,"eng-club","2026-06-20"),"explicit English club lookup must be open")
	_require(not service.is_open_for_club(world,"esp-club","2026-06-20"),"explicit Spanish club lookup must be closed")

func _test_offer_rejects_closed_buyer_window() -> void:
	var world := _world()
	var buyer: Dictionary = world.clubs[1]
	var player: Dictionary = world.players[0]
	var offer := Negotiation.new().create_offer(world,player,buyer,10_000_000,{})
	_require(String(offer.get("status","")) == "invalid","offer creation must reject a buyer whose domestic window is closed")
	_require("transfer_window_closed" in offer.get("reason_codes",[]),"closed-window offer must expose transfer_window_closed reason")

func _test_invalid_calendar_dates_fail_closed() -> void:
	var world := _world()
	var service = WindowService.new()
	for date_value in ["2026-02-31","2025-02-29","2026-04-31","2026-aa-20","2026-13-01"]:
		var status := service.window_status(world,String(date_value),"eng")
		_require(not bool(status.get("open",true)),"invalid calendar date %s must never open a transfer window" % date_value)
		_require(String(status.get("reason","")) == "invalid_date","invalid calendar date %s must report invalid_date" % date_value)
	_require(service.is_open(world,"2028-02-29","eng") == false,"valid leap day outside England's summer window must parse normally and remain closed")

func _test_malformed_country_windows_fail_closed() -> void:
	var world := _world()
	world.transfer_windows_by_country.eng = "not-an-array"
	var status := WindowService.new().window_status(world,"2026-06-20","eng")
	_require(not bool(status.get("open",true)),"malformed country window data must fail closed")
	_require(String(status.get("reason","")) == "no_registered_window","malformed country window data must surface no_registered_window")

func _require(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[TRANSFER WINDOW COUNTRY] "+message)
