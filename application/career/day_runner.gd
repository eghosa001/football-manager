class_name DayRunner
extends RefCounted

const CalendarServiceClass = preload("res://core/calendar/calendar_service.gd")
const SeasonRunnerClass = preload("res://application/season/season_runner.gd")
const InboxServiceClass = preload("res://application/career/inbox_service.gd")
const DailyServicesClass = preload("res://application/career/daily_services.gd")

func advance_day(world: Dictionary, history: Array, seed: int) -> Dictionary:
	if world.is_empty():
		return {"error": ERR_INVALID_DATA}
	var calendar = CalendarServiceClass.new()
	var parts: PackedStringArray = String(world.get("date", "2026-07-01")).split("-")
	if parts.size() != 3:
		return {"error": ERR_INVALID_DATA}
	calendar.set_date(int(parts[0]), int(parts[1]), int(parts[2]))
	calendar.advance_days(1)
	var target_date := calendar.get_date_string()
	var season_runner = SeasonRunnerClass.new()
	season_runner.assign_fixture_dates(world)
	var results: Array = season_runner.play_date(world, target_date, seed)
	world["date"] = target_date
	var managed_club_id := String(world.get("human_manager", {}).get("club_id", ""))
	var services: Dictionary = DailyServicesClass.new().run(world, managed_club_id, seed)
	var generated: Array = InboxServiceClass.new().generate_daily(world, results)
	return {
		"date": target_date,
		"fixtures_played": results.size(),
		"results": results,
		"services": services,
		"messages": generated,
	}
