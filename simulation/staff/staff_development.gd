class_name StaffDevelopment
extends RefCounted

const SeededRng = preload("res://core/rng/seeded_rng.gd")
const StaffMarket = preload("res://simulation/staff/staff_market.gd")

func ensure_world(world: Dictionary, seed: int) -> void:
	var market = StaffMarket.new()
	for member in world.get("staff", []):
		market.ensure_staff_attributes(member, seed)
		var key := _stable_key(String(member.get("id", "")))
		member["age"] = int(member.get("age", 30 + int(SeededRng.value_for(seed, key + 3) % 27)))
		member["experience_years"] = int(member.get("experience_years", maxi(0, int(member.age) - 25)))
		member["course_level"] = clampi(int(member.get("course_level", int(SeededRng.value_for(seed, key + 7) % 4))), 0, 5)
		member["potential"] = clampi(int(member.get("potential", int(member.get("ability", 50)) + 8 + int(SeededRng.value_for(seed, key + 11) % 18))), int(member.get("ability", 50)), 96)
		member["development_history"] = member.get("development_history", [])

func advance_year(world: Dictionary, season_records: Array, seed: int) -> Dictionary:
	ensure_world(world, seed)
	var improved := 0
	var declined := 0
	var courses := 0
	var retired := 0
	var club_performance := _club_performance(season_records)
	for member in world.get("staff", []):
		if bool(member.get("retired", false)):
			continue
		var before := int(member.get("ability", 50))
		member.age = int(member.age) + 1
		member.experience_years = int(member.experience_years) + 1
		var club_id := String(member.get("club_id", ""))
		var reputation := int(member.get("reputation", before))
		var performance := float(club_performance.get(club_id, 0.5))
		var key := _stable_key(String(member.get("id", ""))) + int(world.get("season_year", 2026)) * 31

		# Clubs with stronger resources occasionally fund formal qualifications.
		var club := _club(world, club_id)
		var course_chance := 0.04 + float(club.get("reputation", 45)) / 1400.0
		if int(member.course_level) < 5 and SeededRng.unit_for(seed, key + 101) < course_chance:
			member.course_level = int(member.course_level) + 1
			courses += 1

		var age := int(member.age)
		var age_curve := 1.0
		if age < 35: age_curve = 1.15
		elif age <= 48: age_curve = 0.85
		elif age <= 60: age_curve = 0.35
		elif age <= 67: age_curve = 0.0
		else: age_curve = -0.65
		var room := maxi(0, int(member.potential) - before)
		var learning := minf(1.0, float(room) / 18.0)
		var course_bonus := float(member.course_level) * 0.11
		var reputation_factor := clampf(float(reputation) / 100.0, 0.2, 1.0)
		var performance_factor := 0.7 + performance * 0.6
		var random_factor := 0.80 + SeededRng.unit_for(seed, key + 113) * 0.40
		var delta := 0
		if age_curve >= 0.0 and room > 0:
			delta = clampi(int(round(age_curve * learning * (0.55 + course_bonus + reputation_factor * 0.35) * performance_factor * random_factor)), 0, 2)
		elif age_curve < 0.0:
			delta = -clampi(int(round(absf(age_curve) * random_factor)), 0, 2)
		member.ability = clampi(before + delta, 20, int(member.potential))
		_update_attributes(member, delta)
		member.reputation = clampi(reputation + (1 if performance > 0.72 else (-1 if performance < 0.28 else 0)), 1, 100)
		if delta > 0: improved += 1
		elif delta < 0: declined += 1
		member.development_history.append({"year":int(world.get("season_year",2026)),"before":before,"after":int(member.ability),"delta":delta,"course_level":int(member.course_level),"club_performance":snappedf(performance,0.01)})
		if member.development_history.size() > 30:
			member.development_history = member.development_history.slice(member.development_history.size()-30)
		if int(member.age) >= 72 or (int(member.age) >= 66 and SeededRng.unit_for(seed, key + 211) < 0.12 + float(int(member.age)-66)*0.06):
			member.retired = true
			member.club_id = ""
			retired += 1
	return {"improved":improved,"declined":declined,"courses_completed":courses,"retired":retired}

func _update_attributes(member: Dictionary, delta: int) -> void:
	if delta == 0:
		return
	var attrs: Dictionary = member.get("staff_attributes", {})
	for key in attrs.keys():
		var change := delta
		if String(key) in ["adaptability","discipline"] and delta < 0:
			change = 0
		attrs[key] = clampi(int(attrs[key]) + change, 1, 100)
	member.staff_attributes = attrs

func _club_performance(records: Array) -> Dictionary:
	var result := {}
	for record in records:
		if String(record.get("competition_type", "league")) != "league":
			continue
		var table: Array = record.get("table", [])
		for i in range(table.size()):
			var score := 1.0 - float(i) / maxf(1.0, float(table.size()-1))
			result[String(table[i].get("club_id", ""))] = score
	return result

func _club(world: Dictionary, club_id: String) -> Dictionary:
	for club in world.get("clubs", []):
		if String(club.get("id", "")) == club_id:
			return club
	return {}

func _stable_key(text: String) -> int:
	var value := 149
	for character in text.to_utf8_buffer():
		value = posmod(value * 223 + int(character), 2_147_483_647)
	return value
