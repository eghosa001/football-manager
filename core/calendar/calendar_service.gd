class_name CalendarService
extends RefCounted

var current_date: Dictionary = {"year": 2026, "month": 7, "day": 1}

func set_date(year: int, month: int, day: int) -> void:
	current_date = {"year": year, "month": month, "day": day}

func get_date_string() -> String:
	return "%04d-%02d-%02d" % [current_date.year, current_date.month, current_date.day]

func advance_days(days: int = 1) -> void:
	assert(days >= 0)
	for _i in range(days):
		_advance_one_day()

func weekday() -> String:
	# Zeller-like anchor: 2026-07-01 is a Wednesday.
	var ordinal := _ordinal(int(current_date.year), int(current_date.month), int(current_date.day))
	var names := ["Wednesday", "Thursday", "Friday", "Saturday", "Sunday", "Monday", "Tuesday"]
	return names[posmod(ordinal, 7)]

func is_weekend() -> bool:
	return weekday() in ["Saturday", "Sunday"]

func season_phase() -> String:
	var month := int(current_date.month)
	if month == 7:
		return "pre_season"
	if month >= 8 and month <= 12:
		return "first_half"
	if month >= 1 and month <= 4:
		return "second_half"
	return "run_in" if month == 5 else "off_season"

func days_until(target: String) -> int:
	return _ordinal_from_string(target) - _ordinal(int(current_date.year), int(current_date.month), int(current_date.day))

func is_international_window(date_string: String = "") -> bool:
	var check := date_string if date_string != "" else get_date_string()
	var month_day := String(check).substr(5, 5)
	return month_day in ["09-02", "09-03", "09-04", "09-05", "09-06", "09-07", "10-07", "10-08", "11-11", "11-12", "03-20", "03-21", "06-03", "06-04"]

func _advance_one_day() -> void:
	current_date.day += 1
	var month_lengths := [31, _february_days(current_date.year), 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	if current_date.day > month_lengths[current_date.month - 1]:
		current_date.day = 1
		current_date.month += 1
		if current_date.month > 12:
			current_date.month = 1
			current_date.year += 1

func _february_days(year: int) -> int:
	if year % 400 == 0 or (year % 4 == 0 and year % 100 != 0):
		return 29
	return 28

func _ordinal(year: int, month: int, day: int) -> int:
	var total := 0
	for y in range(1, year):
		total += 366 if (y % 400 == 0 or (y % 4 == 0 and y % 100 != 0)) else 365
	var lengths := [31, _february_days(year), 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	for m in range(1, month):
		total += lengths[m - 1]
	return total + day - 1

func _ordinal_from_string(date_string: String) -> int:
	var parts := String(date_string).split("-")
	if parts.size() != 3:
		return _ordinal(int(current_date.year), int(current_date.month), int(current_date.day))
	return _ordinal(int(parts[0]), int(parts[1]), int(parts[2]))
