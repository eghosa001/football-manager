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
		var day := _date_to_ordinal(original)
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
		var resolved := _ordinal_to_date(day)
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
	var old_day := _date_to_ordinal(old_date)
	if old_day < 0: return {"status":"invalid_date"}
	target["date"] = _ordinal_to_date(old_day + 1)
	var solved := solve(fixtures, constraints)
	return {"status":"rescheduled","from":old_date,"to":String(target.get("date","")),"reason":reason,"result":solved}

func _valid_day(day: int, home: String, away: String, venue: String, min_rest_days: int, club_last_day: Dictionary, venue_day: Dictionary, blocked_dates: Dictionary, venue_blackouts: Dictionary, international_dates: Dictionary, shared_venues: Dictionary) -> bool:
	var date := _ordinal_to_date(day)
	if bool(blocked_dates.get(date, false)) or bool(international_dates.get(date, false)): return false
	if bool(venue_blackouts.get(venue, {}).get(date, false)): return false
	for club in [home, away]:
		if club_last_day.has(club) and day - int(club_last_day[club]) < min_rest_days: return false
	var venue_key := "%s:%d" % [venue, day]
	if venue_day.has(venue_key): return false
	var group := String(shared_venues.get(venue, ""))
	if group != "":
		for key in venue_day.keys():
			var key_text := String(key)
			var parts := key_text.rsplit(":", true, 1)
			if parts.size() != 2: continue
			var used_venue := String(parts[0])
			var used_day := int(parts[1])
			if used_day == day and String(shared_venues.get(used_venue, "")) == group: return false
	return true

func _date_to_ordinal(date: String) -> int:
	var p := date.split("-")
	if p.size() != 3: return -1
	var year := int(p[0]); var month := int(p[1]); var day := int(p[2])
	if year < 1 or month < 1 or month > 12 or day < 1 or day > _days_in_month(year, month): return -1
	var total := 0
	for y in range(1, year): total += 366 if _is_leap(y) else 365
	for m in range(1, month): total += _days_in_month(year, m)
	return total + day - 1

func _ordinal_to_date(ordinal: int) -> String:
	var remaining := maxi(0, ordinal)
	var year := 1
	while true:
		var days_year := 366 if _is_leap(year) else 365
		if remaining < days_year: break
		remaining -= days_year
		year += 1
	var month := 1
	while month <= 12:
		var dim := _days_in_month(year, month)
		if remaining < dim: break
		remaining -= dim
		month += 1
	return "%04d-%02d-%02d" % [year, month, remaining + 1]

func _is_leap(year: int) -> bool:
	return year % 400 == 0 or (year % 4 == 0 and year % 100 != 0)

func _days_in_month(year: int, month: int) -> int:
	match month:
		1,3,5,7,8,10,12: return 31
		4,6,9,11: return 30
		2: return 29 if _is_leap(year) else 28
	return 0

func _no_schedule_errors(fixtures: Array) -> bool:
	for fixture in fixtures:
		if fixture.has("schedule_error"): return false
	return true
