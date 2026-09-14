class_name DayRunner
extends RefCounted

const CalendarServiceClass = preload("res://core/calendar/calendar_service.gd")
const InboxServiceClass = preload("res://application/career/inbox_service.gd")
const DailyServicesClass = preload("res://application/career/daily_services.gd")
const RecruitmentDailyClass = preload("res://application/career/recruitment_daily.gd")
const CareerMatchdayServiceClass = preload("res://application/career/career_matchday_service.gd")
const CareerCycleClass = preload("res://application/career/career_cycle.gd")
const NewsEventConsumerClass = preload("res://application/career/news_event_consumer.gd")
const PlayerValuationClass = preload("res://simulation/transfers/player_valuation_service.gd")

func advance_day(world: Dictionary, history: Array, seed: int) -> Dictionary:
	if world.is_empty(): return {"error":ERR_INVALID_DATA}
	var calendar = CalendarServiceClass.new()
	var parts: PackedStringArray = String(world.get("date", "2026-07-01")).split("-")
	if parts.size() != 3: return {"error":ERR_INVALID_DATA}
	calendar.set_date(int(parts[0]), int(parts[1]), int(parts[2])); calendar.advance_days(1)
	var target_date := calendar.get_date_string()
	var rollover: Dictionary = {}
	var season_year := int(world.get("season_year", int(parts[0])))
	if target_date >= "%04d-07-01" % (season_year + 1):
		# Never silently simulate unplayed fixtures or charge annual finances twice.
		for fixture in world.get("fixtures", []):
			if not bool(fixture.get("played", false)):
				return {"error":ERR_BUSY,"message":"The season still has unplayed fixtures. Resolve the schedule before starting a new season."}
		for competition in world.get("competitions", []):
			if String(competition.get("competition_type", "league")) == "knockout" and not bool(competition.get("knockout_bracket", {}).get("complete", false)):
				return {"error":ERR_BUSY,"message":"A cup has not completed; the new season cannot start yet."}
		rollover = CareerCycleClass.new().complete_year(world, history, int(world.get("seed", seed)) + season_year * 97)
		# Loading a career canonicalizes player market values. Do the same immediately
		# after a live season rollover because ages, ability, contracts and squads all
		# change here. Without this, the in-memory career can diverge from the same save
		# after reopening it on the next season boundary.
		PlayerValuationClass.new().refresh_world(world)
		target_date = String(world.date)
		InboxServiceClass.new().add_message(world, "season", "Welcome to the new season", "Season %d is ready. Review your squad registration, contracts and new fixtures." % int(world.season_year))
	var managed_club_id := String(world.get("human_manager", {}).get("club_id", ""))
	var results: Array = []
	# Matchday preparation builds several world-wide indexes and assigns fixtures.
	# On the overwhelming majority of dates there is no fixture to process, so avoid
	# paying that cost on every Continue. An undated fixture still forces a pass so
	# the scheduler can assign dates exactly as before.
	if _needs_matchday_pass(world, target_date):
		results = CareerMatchdayServiceClass.new().play_date(world, target_date, managed_club_id, seed)
	else:
		world["date"] = target_date
	var services: Dictionary = DailyServicesClass.new().run(world, managed_club_id, seed)
	services["recruitment"] = RecruitmentDailyClass.new().run(world, managed_club_id, seed + 41_003)
	var generated: Array = InboxServiceClass.new().generate_daily(world, results)
	var news: Dictionary = NewsEventConsumerClass.new().consume(world)
	return {"date":target_date,"fixtures_played":results.size(),"results":results,"services":services,"messages":generated,"news":news,"rollover":rollover}

func _needs_matchday_pass(world: Dictionary, target_date: String) -> bool:
	for fixture in world.get("fixtures", []):
		if bool(fixture.get("played", false)):
			continue
		var date := String(fixture.get("date", ""))
		if date == "" or date == target_date:
			return true
	return false
