extends SceneTree

const Builder = preload("res://data/launch_world_builder.gd")
const ModernRules = preload("res://simulation/competitions/modern_rules_catalog.gd")
const Continental = preload("res://application/season/continental_competitions.gd")
const Registration = preload("res://simulation/competitions/registration_service.gd")
const Audit = preload("res://core/schema/world_integrity_audit.gd")

var failures := 0
var checks := 0

func _init() -> void:
	var world: Dictionary = Builder.new().build(441199,0,25,true)
	_require(not world.is_empty(),"world must build")
	ModernRules.new().apply_to_world(world)
	var continental = Continental.new(); continental.prepare(world); continental.initialize_formats(world,int(world.get("season_year",2026)),true)
	Registration.new().auto_register_world(world,int(world.get("season_year",2026)))
	var report := Audit.new().audit(world)
	for error in report.errors: _fail("clean-world integrity error: " + str(error))
	_require(bool(report.ok),"clean launch world must pass integrity audit")
	_require(int(report.stats.players) == world.players.size(),"audit must account for players")
	_require(int(report.stats.competitions) == world.competitions.size(),"audit must account for competitions")
	_test_corruption_detection(world)
	if failures == 0:
		print("[TEST] WORLD INTEGRITY PASS: references, rules, fixtures, registrations, finances, transfers and contracts verified")
		quit(0)
		return
	push_error("[TEST] WORLD INTEGRITY FAIL: %d failures across %d checks" % [failures,checks])
	quit(1)

func _test_corruption_detection(clean_world: Dictionary) -> void:
	var broken := clean_world.duplicate(true)
	if not broken.players.is_empty(): broken.players[0]["club_id"] = "missing-club"
	if not broken.fixtures.is_empty(): broken.fixtures[0]["away_club_id"] = String(broken.fixtures[0].get("home_club_id",""))
	if not broken.contracts.is_empty(): broken.contracts[0]["weekly_wage"] = -5
	var report := Audit.new().audit(broken)
	_require(not bool(report.ok),"deliberately corrupted world must fail")
	var codes := {}
	for error in report.errors: codes[String(error.get("code",""))] = true
	_require(codes.has("player_missing_club"),"audit must detect orphaned player")
	_require(codes.has("fixture_same_club"),"audit must detect self fixture")
	_require(codes.has("negative_contract_wage"),"audit must detect negative contract wage")

func _require(condition: bool, message: String) -> void:
	checks += 1
	if not condition: _fail(message)

func _fail(message: String) -> void:
	failures += 1
	push_error("[WORLD INTEGRITY] " + message)
