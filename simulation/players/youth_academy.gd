class_name YouthAcademy
extends RefCounted

const SeededRngClass = preload("res://core/rng/seeded_rng.gd")

const POSITION_WEIGHTS := ["GK","DR","DC","DC","DL","DM","MC","MC","AMR","AML","AMC","ST","ST"]
const FEET := ["right","right","right","left","both"]
const BODY_TYPES := ["lean","balanced","powerful","compact","tall"]

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
	var result: Array = []
	var base := int(club.academy.recruitment) + int(club.academy.coaching) + int(club.get("reputation", 50))
	var country_id := String(club.get("country_id", ""))
	var city_id := String(club.get("city_id", ""))
	var region_id := String(club.get("region_id", ""))
	for i in range(intake_count):
		var key := base_key + i * 101
		var quality := clampi(int(float(base) / 3.0) + int(SeededRngClass.value_for(seed, key) % 31) - 15, 18, 88)
		var potential := clampi(quality + 8 + int(SeededRngClass.value_for(seed, key + 1) % 31), quality, 99)
		var nationality := _nationality(world,country_id,seed,key+3)
		var second_nationality := _second_nationality(world,nationality,seed,key+4)
		var origin := _origin(world,country_id,region_id,city_id,seed,key+5)
		var identity := _identity(world,nationality,seed,key+6,i)
		var height := _height_for_position(String(POSITION_WEIGHTS[int(SeededRngClass.value_for(seed,key+2)%POSITION_WEIGHTS.size())]), seed, key+7)
		var position := String(POSITION_WEIGHTS[int(SeededRngClass.value_for(seed,key+2)%POSITION_WEIGHTS.size())])
		result.append({
			"id":"academy-preview-%s-%d-%d" % [club_id,season,i],
			"first_name":identity.first_name,"last_name":identity.last_name,"name":"%s %s"%[identity.first_name,identity.last_name],
			"age":15+int(SeededRngClass.value_for(seed,key+8)%3),"position":position,"ability":quality,"current_ability":quality,"potential":potential,
			"nationality_id":nationality,"second_nationality_id":second_nationality,"country_id":nationality,
			"region_id":String(origin.get("region_id",region_id)),"city_id":String(origin.get("city_id",city_id)),"birthplace":String(origin.get("name","")),
			"preferred_foot":FEET[int(SeededRngClass.value_for(seed,key+9)%FEET.size())],"height_cm":height,"weight_kg":_weight(height,seed,key+10),
			"body_type":BODY_TYPES[int(SeededRngClass.value_for(seed,key+11)%BODY_TYPES.size())],
			"personality":{"professionalism":35+int(SeededRngClass.value_for(seed,key+12)%61),"ambition":35+int(SeededRngClass.value_for(seed,key+13)%61),"loyalty":30+int(SeededRngClass.value_for(seed,key+14)%66)},
			"development_ceiling":potential,"base_potential":potential,"development_trajectory":"late" if int(SeededRngClass.value_for(seed,key+15)%5)==0 else "normal",
		})
	return result

func materialize_intake(world: Dictionary, club_id: String, seed: int, count: int = -1) -> Array:
	var club := _club(world,club_id)
	if club.is_empty(): return []
	ensure_club(club)
	var previews := intake_preview(world,club_id,seed,count)
	var created: Array = []
	for preview in previews:
		var player := preview.duplicate(true)
		player["club_id"] = club_id
		player["squad_status"] = "academy"
		player["injured_days"] = 0
		world["players"] = world.get("players",[])
		world.players.append(player)
		add_prospect(club,String(player.id))
		created.append(player)
	world["domain_events"] = world.get("domain_events",[])
	return created

func add_prospect(club: Dictionary, player_id: String) -> void:
	ensure_club(club)
	if player_id not in club.academy.prospects: club.academy.prospects.append(player_id)

func promote(world: Dictionary, club_id: String, player_id: String) -> Error:
	var club := _club(world, club_id); var player := _player(world, player_id)
	if club.is_empty() or player.is_empty(): return ERR_DOES_NOT_EXIST
	ensure_club(club)
	if player_id not in club.academy.prospects: return ERR_INVALID_PARAMETER
	player.club_id = club_id
	player["squad_status"] = "first_team"
	club.academy.prospects.erase(player_id)
	return OK

func release(world: Dictionary, club_id: String, player_id: String) -> Error:
	var club := _club(world, club_id); var player := _player(world, player_id)
	if club.is_empty() or player.is_empty(): return ERR_DOES_NOT_EXIST
	ensure_club(club)
	club.academy.prospects.erase(player_id)
	player.club_id = ""
	player["squad_status"] = "free_agent"
	return OK

func develop_academy(world: Dictionary, club_id: String) -> Dictionary:
	var club := _club(world, club_id)
	if club.is_empty(): return {"error":ERR_DOES_NOT_EXIST}
	ensure_club(club)
	var improved := 0
	for player_id in club.academy.prospects:
		var player := _player(world, String(player_id))
		if player.is_empty(): continue
		var room := maxi(0, int(player.get("development_ceiling",player.get("potential", 50))) - int(player.get("current_ability", 50)))
		var personality: Dictionary = player.get("personality",{})
		var mentality_bonus := float(personality.get("professionalism",50))/100.0
		var gain := mini(room, 1 + int(club.academy.coaching) / 45 + (1 if mentality_bonus>0.75 else 0))
		if gain > 0:
			player.current_ability = mini(int(player.get("development_ceiling",player.potential)), int(player.current_ability) + gain)
			improved += 1
	return {"improved":improved,"prospects":club.academy.prospects.size()}

func _nationality(world:Dictionary, home_country:String, seed:int, key:int)->String:
	if home_country!="" and SeededRngClass.unit_for(seed,key)<0.82: return home_country
	var countries:Array=world.get("countries",[])
	if countries.is_empty(): return home_country
	return String(countries[int(SeededRngClass.value_for(seed,key+1)%countries.size())].get("id",home_country))

func _second_nationality(world:Dictionary, primary:String, seed:int, key:int)->String:
	if SeededRngClass.unit_for(seed,key)>0.18: return ""
	var candidates:Array=[]
	for country in world.get("countries",[]):
		if String(country.get("id",""))!=primary: candidates.append(country)
	if candidates.is_empty(): return ""
	return String(candidates[int(SeededRngClass.value_for(seed,key+1)%candidates.size())].get("id",""))

func _origin(world:Dictionary,country_id:String,region_id:String,city_id:String,seed:int,key:int)->Dictionary:
	var cities:Array=[]
	for city in world.get("cities",[]):
		if country_id=="" or String(city.get("country_id",""))==country_id: cities.append(city)
	if not cities.is_empty(): return cities[int(SeededRngClass.value_for(seed,key)%cities.size())]
	return {"country_id":country_id,"region_id":region_id,"city_id":city_id,"name":""}

func _identity(world:Dictionary,country_id:String,seed:int,key:int,index:int)->Dictionary:
	var first:Array=[]; var last:Array=[]
	for pool in world.get("name_pools",[]):
		if String(pool.get("country_id",""))==country_id:
			first=pool.get("first_names",[]); last=pool.get("last_names",[]); break
	if first.is_empty(): first=["Daniel","Victor","Samuel","David","Ibrahim","Michael","Joseph","Emmanuel","Tobi","Kelvin","Musa","Peter","Ahmed","John","Chinedu","Seyi","Kwame","Youssef","Amadou","Sipho"]
	if last.is_empty(): last=["Okoro","Mensah","Diallo","Banda","Mokoena","Abdullahi","Adeyemi","Kamara","Ndlovu","Boateng","Ibrahim","Dlamini","Osei","Eze","Sow","Yusuf","Traore","Benali","Mbeki","Owusu"]
	return {"first_name":String(first[int(SeededRngClass.value_for(seed,key)%first.size())]),"last_name":String(last[int(SeededRngClass.value_for(seed,key+1)%last.size())])}

func _height_for_position(position:String,seed:int,key:int)->int:
	var base:=188 if position=="GK" else (185 if position=="DC" else (181 if position=="ST" else 177))
	return clampi(base+int(SeededRngClass.value_for(seed,key)%17)-8,160,205)

func _weight(height:int,seed:int,key:int)->int:
	return clampi(int(float(height-100)*0.83)+int(SeededRngClass.value_for(seed,key)%9)-4,55,105)

func _club(world: Dictionary, club_id: String) -> Dictionary:
	for club in world.get("clubs", []):
		if String(club.get("id", "")) == club_id: return club
	return {}

func _player(world: Dictionary, player_id: String) -> Dictionary:
	for player in world.get("players", []):
		if String(player.get("id", "")) == player_id: return player
	return {}

func _stable_key(text: String) -> int:
	var value := 97
	for c in text.to_utf8_buffer(): value = posmod(value * 193 + int(c), 2_147_483_647)
	return value
