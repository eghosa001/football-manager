class_name DayRunner
extends RefCounted

const CalendarServiceClass = preload("res://core/calendar/calendar_service.gd")
const SeasonRunnerClass = preload("res://application/season/season_runner.gd")
const InboxServiceClass = preload("res://application/career/inbox_service.gd")

func advance_day(world: Dictionary, history: Array, seed: int) -> Dictionary:
	if world.is_empty():
		return {"error": ERR_INVALID_DATA}
	var previous_date := String(world.get("date", ""))
	var calendar = CalendarServiceClass.new()
	world["date"] = calendar.add_days(previous_date, 1)
	var matchday_result := {}
	var due: Array = _fixtures_due(world)
	if not due.is_empty():
		matchday_result = SeasonRunnerClass.new().play_fixtures(world, due, seed)
	var inbox = InboxServiceClass.new()
	var generated: Array = inbox.generate_daily(world, matchday_result)
	return {
		"date": world.date,
		"fixtures_played": due.size(),
		"matchday": matchday_result,
		"messages": generated,
	}

func _fixtures_due(world: Dictionary) -> Array:
	var due: Array = []
	var current_round: int = int(world.get("current_round", 1))
	for fixture in world.get("fixtures", []):
		if not bool(fixture.get("played", false)) and int(fixture.get("round", 0)) == current_round:
			due.append(fixture)
	if not due.is_empty():
		world["current_round"] = current_round + 1
	return due
