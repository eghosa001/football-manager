class_name ScheduleConstraints
extends RefCounted

func assign_dates(fixtures: Array, start_date: Dictionary, days_between_rounds: int = 7, min_rest_days: int = 2) -> Array:
	var calendar := _date_to_ordinal(start_date)
	var club_last_day := {}
	var assignments: Array = []
	var ordered := fixtures.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary):
		if int(a.get("round", 0)) == int(b.get("round", 0)):
			return String(a.get("id", "")) < String(b.get("id", ""))
		return int(a.get("round", 0)) < int(b.get("round", 0))
	)
	for fixture in ordered:
		var target := calendar + maxi(0, int(fixture.get("round", 1)) - 1) * maxi(1, days_between_rounds)
		var home := String(fixture.get("home_club_id", ""))
		var away := String(fixture.get("away_club_id", ""))
		var required := maxi(int(club_last_day.get(home, -9999)), int(club_last_day.get(away, -9999))) + min_rest_days + 1
		target = maxi(target, required)
		fixture["scheduled_ordinal"] = target
		club_last_day[home] = target
		club_last_day[away] = target
		assignments.append({"fixture_id":String(fixture.get("id", "")),"day":target})
	return assignments

func validate_rest(fixtures: Array, min_rest_days: int = 2) -> Array[String]:
	var errors: Array[String] = []
	var club_days := {}
	for fixture in fixtures:
		var day := int(fixture.get("scheduled_ordinal", -9999))
		for club_id in [String(fixture.get("home_club_id", "")), String(fixture.get("away_club_id", ""))]:
			if not club_days.has(club_id): club_days[club_id] = []
			club_days[club_id].append(day)
	for club_id in club_days.keys():
		var days: Array = club_days[club_id]
		days.sort()
		for i in range(1, days.size()):
			if int(days[i]) - int(days[i - 1]) <= min_rest_days:
				errors.append("%s has insufficient rest between %d and %d" % [club_id, int(days[i - 1]), int(days[i])])
	return errors

func _date_to_ordinal(date: Dictionary) -> int:
	return int(date.get("year", 2026)) * 372 + int(date.get("month", 1)) * 31 + int(date.get("day", 1))
