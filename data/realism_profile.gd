class_name RealismProfile
extends RefCounted

const Loader = preload("res://data/database_loader.gd")
const SeededRng = preload("res://core/rng/seeded_rng.gd")

const FALLBACK_FIRST := ["Daniel","Victor","Samuel","David","Ibrahim","Michael","Joseph","Emmanuel","Tobi","Kelvin","Musa","Peter","Ahmed","John","Chinedu","Seyi"]
const FALLBACK_LAST := ["Okoro","Mensah","Diallo","Banda","Mokoena","Abdullahi","Adeyemi","Kamara","Ndlovu","Boateng","Ibrahim","Dlamini","Osei","Eze","Sow","Yusuf"]

func club_profile(country: Dictionary, index: int, tier: int, seed: int, club_id: String) -> Dictionary:
	var configured: Dictionary = Loader.new().club_profile(country, index, tier)
	var fallback_rep: int = _range(seed, _key(club_id), 34 + maxi(0, 2 - (tier - 1)) * 5, 79 - (tier - 1) * 5)
	var cities: Array = country.get("cities", [])
	return {
		"name": Loader.new().club_name(country, index, tier),
		"city": String(configured.get("city", cities[index % cities.size()] if not cities.is_empty() else country.get("name", ""))),
		"reputation": clampi(int(configured.get("reputation", fallback_rep)), 1, 100),
		"stadium_capacity": int(configured.get("stadium_capacity", _range(seed, _key(club_id) + 1, 7000, 52000))),
		"training_facilities": int(configured.get("training_facilities", _range(seed, _key(club_id) + 2, 35, 82)))
	}

func generated_name(data: Dictionary, country_id: String, seed: int, key: int, used: Dictionary, unique_key: String) -> Dictionary:
	var pool: Dictionary = Loader.new().name_pool(data, country_id)
	var first_names: Array = pool.get("first_names", FALLBACK_FIRST)
	var last_names: Array = pool.get("last_names", FALLBACK_LAST)
	if first_names.is_empty(): first_names = FALLBACK_FIRST
	if last_names.is_empty(): last_names = FALLBACK_LAST

	for attempt in range(16):
		var first: String = String(first_names[_range(seed, key + attempt * 3, 0, first_names.size() - 1)])
		var last: String = String(last_names[_range(seed, key + attempt * 3 + 1, 0, last_names.size() - 1)])
		var full: String = "%s %s" % [first, last]
		if not used.has(full):
			used[full] = true
			return {"first_name":first,"last_name":last,"full_name":full}

	for attempt in range(last_names.size() * 2):
		var first: String = String(first_names[_range(seed, key + 100 + attempt * 3, 0, first_names.size() - 1)])
		var left: String = String(last_names[_range(seed, key + 101 + attempt * 3, 0, last_names.size() - 1)])
		var right: String = String(last_names[_range(seed, key + 102 + attempt * 3, 0, last_names.size() - 1)])
		if left == right:
			right = String(last_names[(last_names.find(right) + 1) % last_names.size()])
		var last: String = "%s-%s" % [left, right]
		var full: String = "%s %s" % [first, last]
		if not used.has(full):
			used[full] = true
			return {"first_name":first,"last_name":last,"full_name":full}

	var first: String = String(first_names[_range(seed, key, 0, first_names.size() - 1)])
	var base_last: String = String(last_names[_range(seed, key + 1, 0, last_names.size() - 1)])
	var start_token: int = posmod(_key(unique_key), 26 * 26 * 26)
	for offset in range(26 * 26 * 26):
		var token: int = posmod(start_token + offset, 26 * 26 * 26)
		var suffix: String = _alpha_suffix(token)
		var last: String = "%s-%s" % [base_last, suffix]
		var full: String = "%s %s" % [first, last]
		if not used.has(full):
			used[full] = true
			return {"first_name":first,"last_name":last,"full_name":full}
	# A practical launch database cannot exhaust this path, but keep a readable
	# final fallback for extreme mod databases.
	var last: String = "%s-X" % base_last
	var full: String = "%s %s" % [first, last]
	return {"first_name":first,"last_name":last,"full_name":full}

func nationality(home_country: String, loaded_country_ids: Array, club_reputation: int, seed: int, key: int) -> String:
	if loaded_country_ids.size() <= 1: return home_country
	var home_chance := clampi(82 - maxi(0, club_reputation - 65), 52, 82)
	if _range(seed, key, 1, 100) <= home_chance: return home_country
	var options: Array = []
	for id in loaded_country_ids:
		if String(id) != home_country: options.append(String(id))
	if options.is_empty(): return home_country
	return String(options[_range(seed, key + 1, 0, options.size() - 1)])

func ability_band(club_reputation: int) -> Vector2i:
	return Vector2i(clampi(club_reputation - 24, 28, 78), clampi(club_reputation - 5, 45, 93))

func staff_ability_band(club_reputation: int) -> Vector2i:
	return Vector2i(clampi(club_reputation - 24, 28, 72), clampi(club_reputation - 4, 45, 94))

func role_profile(position: String, key: int) -> String:
	var profiles := {
		"GK":["sweeper keeper","shot stopper"], "DR":["full back","wing back"], "DL":["full back","wing back"],
		"DC":["ball playing defender","central defender"], "DM":["holding midfielder","deep playmaker"],
		"MC":["box to box","central playmaker"], "AMC":["advanced playmaker","shadow forward"],
		"AMR":["inverted winger","wide forward"], "AML":["inverted winger","wide forward"], "ST":["advanced forward","pressing forward"]
	}
	var values: Array = profiles.get(position, ["utility player"])
	return String(values[posmod(key, values.size())])

func wage_band(club_reputation: int) -> Vector2i:
	var low := maxi(350, int(pow(float(maxi(30, club_reputation - 20)), 2.05) * 1.3))
	var high := maxi(low + 500, int(pow(float(maxi(35, club_reputation)), 2.12) * 2.1))
	return Vector2i(low, high)

func range_value(seed: int, key: int, lo: int, hi: int) -> int:
	return _range(seed, key, lo, hi)

func stable_key(text: String) -> int:
	return _key(text)

func _alpha_suffix(token: int) -> String:
	var a: int = token / 676
	var b: int = (token / 26) % 26
	var c: int = token % 26
	return String.chr(65 + a) + String.chr(65 + b) + String.chr(65 + c)

func _range(seed: int, key: int, lo: int, hi: int) -> int:
	if hi <= lo: return lo
	return lo + int(SeededRng.value_for(seed, key) % (hi - lo + 1))

func _key(text: String) -> int:
	var value := 71
	for c in text.to_utf8_buffer(): value = posmod(value * 173 + int(c), 2147483647)
	return value
