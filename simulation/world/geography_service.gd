class_name GeographyService
extends RefCounted

func ensure_world(world: Dictionary) -> void:
	world["regions"] = world.get("regions", [])
	world["cities"] = world.get("cities", [])
	world["travel_matrix"] = world.get("travel_matrix", {})

func add_region(world: Dictionary, id: String, country_id: String, name: String, youth_modifier: float = 1.0, scouting_modifier: float = 1.0) -> Dictionary:
	ensure_world(world)
	var region := {"id":id,"country_id":country_id,"name":name,"youth_modifier":clampf(youth_modifier,0.5,1.5),"scouting_modifier":clampf(scouting_modifier,0.5,1.5)}
	world.regions.append(region)
	return region

func add_city(world: Dictionary, id: String, region_id: String, name: String, latitude: float, longitude: float, population: int = 100000) -> Dictionary:
	ensure_world(world)
	var city := {"id":id,"region_id":region_id,"name":name,"latitude":clampf(latitude,-90.0,90.0),"longitude":clampf(longitude,-180.0,180.0),"population":maxi(1,population)}
	world.cities.append(city)
	return city

func assign_club_city(club: Dictionary, city_id: String) -> void:
	club["city_id"] = city_id

func assign_player_origin(player: Dictionary, city_id: String, region_id: String, birth_country_id: String) -> void:
	player["birth_city_id"] = city_id
	player["birth_region_id"] = region_id
	player["birth_country_id"] = birth_country_id

func distance_km(world: Dictionary, city_a: String, city_b: String) -> float:
	ensure_world(world)
	if city_a == city_b: return 0.0
	var key := "%s:%s" % [city_a,city_b]
	if world.travel_matrix.has(key): return float(world.travel_matrix[key])
	var a := _city(world.cities,city_a); var b := _city(world.cities,city_b)
	if a.is_empty() or b.is_empty(): return 0.0
	var lat1 := deg_to_rad(float(a.latitude)); var lat2 := deg_to_rad(float(b.latitude))
	var dlat := deg_to_rad(float(b.latitude)-float(a.latitude)); var dlon := deg_to_rad(float(b.longitude)-float(a.longitude))
	var h := sin(dlat/2.0)*sin(dlat/2.0)+cos(lat1)*cos(lat2)*sin(dlon/2.0)*sin(dlon/2.0)
	var distance := 6371.0 * 2.0 * atan2(sqrt(h),sqrt(maxf(0.0,1.0-h)))
	world.travel_matrix[key] = distance; world.travel_matrix["%s:%s" % [city_b,city_a]] = distance
	return distance

func travel_effects(world: Dictionary, home_club: Dictionary, away_club: Dictionary) -> Dictionary:
	var km := distance_km(world,String(home_club.get("city_id","")),String(away_club.get("city_id","")))
	return {"distance_km":km,"away_fatigue":clampf(km/4000.0,0.0,0.30),"supporter_travel_factor":clampf(1.0-km/5000.0,0.15,1.0)}

func local_rivalry_score(world: Dictionary, club_a: Dictionary, club_b: Dictionary) -> float:
	var same_city := String(club_a.get("city_id","")) != "" and String(club_a.get("city_id","")) == String(club_b.get("city_id",""))
	var km := distance_km(world,String(club_a.get("city_id","")),String(club_b.get("city_id","")))
	if same_city: return 1.0
	return clampf(1.0-km/500.0,0.0,0.9)

func scouting_knowledge(world: Dictionary, scout: Dictionary, target: Dictionary) -> float:
	var scout_region := String(scout.get("home_region_id","")); var target_region := String(target.get("birth_region_id",""))
	var languages: Array = scout.get("languages",[]); var target_language := String(target.get("language",""))
	var base := 0.35
	if scout_region != "" and scout_region == target_region: base += 0.35
	if target_language != "" and target_language in languages: base += 0.20
	return clampf(base,0.1,1.0)

func _city(cities: Array, id: String) -> Dictionary:
	for city in cities:
		if String(city.get("id","")) == id: return city
	return {}
