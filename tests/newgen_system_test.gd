extends SceneTree

const NewgenFactoryClass = preload("res://simulation/players/newgen_factory.gd")
const YouthAcademyClass = preload("res://simulation/players/youth_academy.gd")
const PlayerLifecycleV2Class = preload("res://simulation/players/player_lifecycle_v2.gd")

func _init() -> void:
	var world := _world()
	var club: Dictionary = world.clubs[0]
	var factory = NewgenFactoryClass.new()
	var striker: Dictionary = factory.create(world, club, 445566, "newgen-test-1", 1, 16)
	_check(bool(striker.get("newgen",false)), "Future players must be marked as newgens")
	_check(String(striker.get("first_name","")) != "Youth", "Newgens must use proper generated identities")
	_check(String(striker.get("last_name","")) != "1", "Newgens must never use numbered placeholder surnames")
	_check(not striker.get("attributes",{}).is_empty(), "Newgens must receive full football attributes")
	_check(striker.get("hidden_attributes",{}).has("professionalism"), "Newgens must receive hidden personality attributes")
	_check(striker.has("special_abilities"), "Newgens must participate in the special ability system")
	_check(float(striker.get("physical_maturity",1.0)) < 1.0, "Teenage newgens must begin physically immature")
	_check(int(striker.get("potential",0)) >= int(striker.get("current_ability",0)), "Potential must not be below current ability")

	var academy = YouthAcademyClass.new()
	var intake: Array = academy.materialize_intake(world, "england-test-club", 778899, 6)
	_check(intake.size() == 6, "Academy intake must materialize the requested number of players")
	var names := {}
	for player in intake:
		var full := "%s %s" % [String(player.get("first_name","")),String(player.get("last_name",""))]
		_check(full.strip_edges() != "", "Academy prospects need names")
		_check(not names.has(full), "Academy prospects must have unique identities")
		names[full] = true
		_check(player.get("attributes",{}).size() >= 30, "Academy prospects need a complete attribute model")
		_check(player.get("hidden_attributes",{}).size() >= 10, "Academy prospects need hidden attributes")
		_check(String(player.get("squad_status","")) == "academy", "Academy intake status must be preserved")

	var before_maturity := float(intake[0].get("physical_maturity",0.0))
	factory.mature_physical(intake[0], 998877)
	_check(float(intake[0].get("physical_maturity",0.0)) >= before_maturity, "Physical maturation must progress, not regress")

	# Annual lifecycle must use the same rich newgen path instead of legacy Youth 1 placeholders.
	var lifecycle_world := _world()
	var lifecycle = PlayerLifecycleV2Class.new()
	var result: Dictionary = lifecycle.advance_year(lifecycle_world, 112233, 2)
	_check(result.get("youth",[]).size() == 2, "Annual rollover must replenish future players")
	var generated := []
	for player in lifecycle_world.players:
		if bool(player.get("newgen",false)): generated.append(player)
	_check(generated.size() == 2, "Annual rollover youth must come from the authoritative newgen factory")
	for player in generated:
		_check(String(player.get("first_name","")) != "Youth", "Annual rollover must not recreate legacy placeholder players")
		_check(player.has("special_abilities"), "Annual rollover youth must carry special abilities/weaknesses")
		_check(player.get("attributes",{}).has("determination"), "Annual rollover youth must receive complete mental attributes")

	_check(result.has("country_evolution"), "Annual rollover must evolve national youth development")
	_check(result.has("academy_decisions"), "Annual rollover must include AI academy management")
	_check(result.has("mentored"), "Annual rollover must include youth mentoring")

	print("[TEST] NEWGEN SYSTEM PASS: identities, attributes, traits, maturation, academy intake and long-career ecosystem verified")
	quit(0)

func _world() -> Dictionary:
	return {
		"season_year":2026,
		"countries":[{"id":"england","name":"England","code":"ENG","youth_rating":72,"football_popularity":88,"youth_infrastructure":78,"national_success":70,"league_reputation":88}],
		"clubs":[{
			"id":"england-test-club","country_id":"england","name":"Test City","reputation":76,
			"training_facilities":78,"youth_facilities":82,"youth_recruitment":80,
			"academy":{"prospects":[],"recruitment":80,"coaching":78,"reputation":70,"region_knowledge":70,"intake_variance":2}
		}],
		"players":[],"staff":[],"contracts":[],"cities":[],"domain_events":[]
	}

func _check(condition: bool, message: String) -> void:
	if condition: return
	push_error("[TEST] NEWGEN SYSTEM FAIL: %s" % message)
	quit(1)
