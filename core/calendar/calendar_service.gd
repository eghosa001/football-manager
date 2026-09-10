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
