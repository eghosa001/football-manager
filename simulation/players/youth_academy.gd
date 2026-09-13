class_name YouthAcademy
extends RefCounted

const SeededRngClass = preload("res://core/rng/seeded_rng.gd")
const NewgenFactoryClass = preload("res://simulation/players/newgen_factory.gd")

func ensure_club(club: Dictionary) -> void:
	club["academy"] = club.get("academy", {"prospects":[],"recruitment":50,"coaching":50,"reputation":40,"region_knowledge":50,"intake_variance":2})

func intake_preview(world: Dictionary, club_id: String, seed: int, count: int = -1) -> Array:
	var club := _club(world, club_id)
	if club.is_empty(): return []
	ensure_club(club)
	var season := int(world.get("season_year", 2026))
	var base_key := _stable_key("%s:%d" % [club_id, season])
	var intake_count := count
	if intake_count < 0:
		intake_count = clampi(6 + int(SeededRngClass.value_for(seed,base_key)%7) + int(club.academy.get("intake_variance",2))-2, 5, 14)
	var factory = NewgenFactoryClass.new()
	var result: Array = []
	for i in range(intake_count):
		var player_id := "academy-preview-%s-%d-%d" % [club_id, season, i]
		var prospect: Dictionary = factory.create(world, club, seed, player_id, i)
		prospect["ability"] = int(prospect.get("current_ability", 0))
		result.append(prospect)
	return result

func materialize_intake(world: Dictionary, club_id: String, seed: int, count: int = -1) -> Array:
	var club := _club(world, club_id)
	if club.is_empty(): return []
	ensure_club(club)
	var season := int(world.get("season_year", 2026))
	var previews := intake_preview(world, club_id, seed, count)
	var factory = NewgenFactoryClass.new()
	var created: Array = []
	for i in range(previews.size()):
		var player_id := "academy-%s-%d-%d" % [club_id, season, i]
		var player: Dictionary = factory.create(world, club, seed, player_id, i)
		player["squad_status"] = "academy"
		world["players"] = world.get("players", [])
		world.players.append(player)
		add_prospect(club, String(player.id))
		created.append(player)
	world["domain_events"] = world.get("domain_events", [])
	world.domain_events.append({"type":"youth_intake","season_year":season,"club_id":club_id,"player_ids":_ids(created)})
	return created

func add_prospect(club: Dictionary, player_id: String) -> void:
	ensure_club(club)
	if player_id not in club.academy.prospects: club.academy.prospects.append(player_id)

func promote(world: Dictionary, club_id: String, player_id: String) -> Error:
	var club := _club(world, club_id)
	var player := _player(world, player_id)
	if club.is_empty() or player.is_empty(): return ERR_DOES_NOT_EXIST
	ensure_club(club)
	if player_id not in club.academy.prospects: return ERR_INVALID_PARAMETER
	player.club_id = club_id
	player["squad_status"] = "first_team"
	club.academy.prospects.erase(player_id)
	return OK

func release(world: Dictionary, club_id: String, player_id: String) -> Error:
	var club := _club(world, club_id)
	var player := _player(world, player_id)
	if club.is_empty() or player.is_empty(): return ERR_DOES_NOT_EXIST
	ensure_club(club)
	club.academy.prospects.erase(player_id)
	player.club_id = ""
	player["squad_status"] = "free_agent"
	return OK

func develop_academy(world: Dictionary, club_id: String, seed: int = 12345) -> Dictionary:
	var club := _club(world, club_id)
	if club.is_empty(): return {"error":ERR_DOES_NOT_EXIST}
	ensure_club(club)
	var improved := 0
	var factory = NewgenFactoryClass.new()
	for player_id in club.academy.prospects:
		var player := _player(world, String(player_id))
		if player.is_empty(): continue
		var room := maxi(0, int(player.get("development_ceiling",player.get("potential",50))) - int(player.get("current_ability",50)))
		var hidden: Dictionary = player.get("hidden_attributes", {})
		var professionalism := float(hidden.get("professionalism", player.get("personality",{}).get("professionalism",50)))
		var ambition := float(hidden.get("ambition", player.get("personality",{}).get("ambition",50)))
		var coaching := float(club.academy.get("coaching",50))
		var facilities := float(club.get("youth_facilities", club.get("training_facilities",50)))
		var environment := (professionalism*0.30 + ambition*0.15 + coaching*0.30 + facilities*0.25) / 100.0
		var trajectory := String(player.get("development_trajectory","normal"))
		var trajectory_factor := 1.15 if trajectory == "early" else (0.82 if trajectory == "late" else (1.05 if trajectory == "volatile" else 1.0))
		var gain := mini(room, maxi(0, int(round((0.5 + environment*2.1) * trajectory_factor))))
		if gain > 0:
			player.current_ability = mini(int(player.get("development_ceiling",player.potential)), int(player.current_ability)+gain)
			improved += 1
		factory.mature_physical(player, seed)
	return {"improved":improved,"prospects":club.academy.prospects.size()}

func _club(world: Dictionary, club_id: String) -> Dictionary:
	for club in world.get("clubs", []):
		if String(club.get("id", "")) == club_id: return club
	return {}

func _player(world: Dictionary, player_id: String) -> Dictionary:
	for player in world.get("players", []):
		if String(player.get("id", "")) == player_id: return player
	return {}

func _ids(players: Array) -> Array:
	var result: Array = []
	for player in players: result.append(String(player.get("id", "")))
	return result

func _stable_key(text: String) -> int:
	var value := 97
	for c in text.to_utf8_buffer(): value = posmod(value * 193 + int(c), 2_147_483_647)
	return value
