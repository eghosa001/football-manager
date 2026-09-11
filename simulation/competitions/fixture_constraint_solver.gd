class_name FixtureConstraintSolver
extends RefCounted

func solve(fixtures: Array, constraints: Dictionary = {}) -> Dictionary:
	var min_rest_days := maxi(1, int(constraints.get("min_rest_days", 2)))
	var blocked_dates: Dictionary = constraints.get("blocked_dates", {})
	var venue_blackouts: Dictionary = constraints.get("venue_blackouts", {})
	var international_dates: Dictionary = constraints.get("international_dates", {})
	var shared_venues: Dictionary = constraints.get("shared_venues", {})
	var ordered := fixtures.duplicate(true)
	ordered.sort_custom(func(a: Dictionary,b: Dictionary): return String(a.get("date","")) < String(b.get("date","")))
	var club_last_day := {}
	var venue_day := {}
	var changes: Array = []
	for fixture in ordered:
		var original := String(fixture.get("date", ""))
		var day := _date_to_day(original)
		if day < 0: continue
		var home := String(fixture.get("home_id", fixture.get("home_club_id", "")))
		var away := String(fixture.get("away_id", fixture.get("away_club_id", "")))
		var venue := String(fixture.get("venue_id", home))
		var attempts := 0
		while not _valid_day(day, home, away, venue, min_rest_days, club_last_day, venue_day, blocked_dates, venue_blackouts, international_dates, shared_venues) and attempts < 60:
			day += 1
			attempts += 1
		if attempts >= 60:
			fixture["schedule_error"] = "no_valid_date_within_60_days"
			continue
		var resolved := _day_to_date(day)
		fixture["date"] = resolved
		club_last_day[home] = day
		club_last_day[away] = day
		venue_day["%s:%d" % [venue, day]] = true
		if original != resolved:
			changes.append({"fixture_id":String(fixture.get("id","")),"from":original,"to":resolved,"reason_codes":["rest_or_calendar_constraint"]})
	return {"fixtures":ordered,"changes":changes,"valid":_no_schedule_errors(ordered)}

func postpone(fixtures: Array, fixture_id: String, reason: String, constraints: Dictionary = {}) -> Dictionary:
	var target: Dictionary = {}
	for fixture in fixtures:
		if String(fixture.get("id","")) == fixture_id:
			target = fixture
			break
	if target.is_empty(): return {"status":"missing_fixture"}
	var old_date := String(target.get("date",""))
	var old_day := _date_to_day(old_date)
	if old_day < 0: return {"status":"invalid_date"}
	target.date = _day_to_date(old_day + 1)
	var solved := solve(fixtures, constraints)
	return {"status":"rescheduled","from":old_date,"to":String(target.date),"reason":reason,"result":solved}

func _valid_day(day: int, home: String, away: String, venue: String, min_rest_days: int, club_last_day: Dictionary, venue_day: Dictionary, blocked_dates: Dictionary, venue_blackouts: Dictionary, international_dates: Dictionary, shared_venues: Dictionary) -> bool:
	var date := _day_to_date(day)
	if bool(blocked_dates.get(date, false)) or bool(international_dates.get(date, false)): return false
	if bool(venue_blackouts.get(venue, {}).get(date, false)): return false
	for club in [home, away]:
		if club_last_day.has(club) and day - int(club_last_day[club]) < min_rest_days: return false
	var venue_key := "%s:%d" % [venue, day]
	if venue_day.has(venue_key): return false
	var group := String(shared_venues.get(venue, ""))
	if group != "":
		for key in venue_day.keys():
			var used_venue := String(key).split(":")[0]
			if String(shared_venues.get(used_venue, "")) == group and String(key).ends_with(":" + str(day)): return false
	return true

func _date_to_day(date: String) -> int:
	var p := date.split("-")
	if p.size() != 3: return -1
	var y := int(p[0]); var m := int(p[1]); var d := int(p[2])
	return y * 372 + (m - 1) * 31 + (d - 1)

func _day_to_date(value: int) -> String:
	var y := value / 372
	var rem := value % 372
	var m := rem / 31 + 1
	var d := rem % 31 + 1
	return "%04d-%02d-%02d" % [y,m,d]

func _no_schedule_errors(fixtures: Array) -> bool:
	for fixture in fixtures:
		if fixture.has("schedule_error"): return false
	return true
