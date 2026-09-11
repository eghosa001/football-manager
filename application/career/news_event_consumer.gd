class_name NewsEventConsumer
extends RefCounted

const DomainEventBusClass = preload("res://core/events/domain_event_bus.gd")

const NEWSWORTHY := [
	"MATCH_FINISHED",
	"GOAL_SCORED",
	"PLAYER_INJURED",
	"PLAYER_RECOVERED",
	"PLAYER_SIGNED",
	"CONTRACT_SIGNED",
	"MANAGER_FIRED",
	"SEASON_ENDED",
	"YOUTH_INTAKE",
	"PROMISE_RESOLVED",
]

var _events = DomainEventBusClass.new()

func consume(world: Dictionary) -> Dictionary:
	_events.ensure_world(world)
	world["news"] = world.get("news", [])
	var cursor := int(world.get("news_event_cursor", 0))
	var events: Array = _events.since(world, cursor, NEWSWORTHY)
	var created := 0
	var last_sequence := cursor
	for event in events:
		last_sequence = maxi(last_sequence, int(event.get("sequence", 0)))
		var article := _article(event)
		if article.is_empty():
			continue
		world.news.append(article)
		created += 1
	world["news_event_cursor"] = last_sequence
	if world.news.size() > 500:
		world.news = world.news.slice(world.news.size() - 500)
	return {"created":created,"cursor":last_sequence,"events_seen":events.size()}

func _article(event: Dictionary) -> Dictionary:
	var event_type := String(event.get("type", ""))
	var payload: Dictionary = event.get("payload", {})
	var title := ""
	var summary := ""
	match event_type:
		"MATCH_FINISHED":
			title = "Match finished"
			summary = "%s %d-%d %s" % [String(payload.get("home_name", payload.get("home_club_id", "Home"))), int(payload.get("home_goals", 0)), int(payload.get("away_goals", 0)), String(payload.get("away_name", payload.get("away_club_id", "Away")))]
		"GOAL_SCORED":
			title = "Goal scored"
			summary = "%s scored in %s." % [String(payload.get("player_name", payload.get("player_id", "A player"))), String(payload.get("fixture_id", "a match"))]
		"PLAYER_INJURED":
			title = "Player injured"
			summary = "%s suffered %s." % [String(payload.get("player_name", payload.get("player_id", "A player"))), String(payload.get("injury", "an injury"))]
		"PLAYER_RECOVERED":
			title = "Player returns"
			summary = "%s has returned from injury." % String(payload.get("player_name", payload.get("player_id", "A player")))
		"PLAYER_SIGNED":
			title = "Player signed"
			summary = "%s joined %s." % [String(payload.get("player_name", payload.get("player_id", "A player"))), String(payload.get("club_name", payload.get("buyer_id", payload.get("club_id", "a club"))))]
		"CONTRACT_SIGNED":
			title = "Contract signed"
			summary = "%s signed a contract with %s." % [String(payload.get("player_name", payload.get("player_id", "A player"))), String(payload.get("club_name", payload.get("club_id", "a club")))]
		"MANAGER_FIRED":
			title = "Manager dismissed"
			summary = "%s dismissed their manager." % String(payload.get("club_name", payload.get("club_id", "A club")))
		"SEASON_ENDED":
			title = "Season completed"
			summary = "The %d season has concluded." % int(payload.get("season_year", event.get("season_year", 0)))
		"YOUTH_INTAKE":
			title = "Youth intake"
			summary = "%d academy players entered the football world." % int(payload.get("count", 0))
		"PROMISE_RESOLVED":
			title = "Player promise resolved"
			summary = "A player promise was %s." % ("kept" if bool(payload.get("fulfilled", false)) else "broken")
		_:
			return {}
	return {
		"id":"news-event-%09d" % int(event.get("sequence", 0)),
		"year":int(event.get("season_year", 0)),
		"date":String(event.get("date", "")),
		"type":event_type.to_lower(),
		"title":title,
		"summary":summary,
		"event_id":String(event.get("id", "")),
		"reason":event.duplicate(true),
	}
