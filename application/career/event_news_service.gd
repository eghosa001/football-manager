class_name EventNewsService
extends RefCounted

const DomainEventBusClass = preload("res://core/events/domain_event_bus.gd")

var _events = DomainEventBusClass.new()

func ensure_world(world: Dictionary) -> void:
	_events.ensure_world(world)
	world["news"] = world.get("news", [])
	world["news_event_cursor"] = int(world.get("news_event_cursor", 0))

func consume(world: Dictionary, max_events: int = 250) -> Dictionary:
	ensure_world(world)
	var cursor := int(world.news_event_cursor)
	var pending := _events.since(world, cursor)
	var created := 0
	var processed := 0
	for event in pending:
		if processed >= maxi(1, max_events):
			break
		processed += 1
		world.news_event_cursor = maxi(int(world.news_event_cursor), int(event.get("sequence", 0)))
		var article := _article(world, event)
		if article.is_empty():
			continue
		world.news.append(article)
		created += 1
	if world.news.size() > 1000:
		world.news = world.news.slice(world.news.size() - 1000)
	return {"processed":processed,"created":created,"cursor":int(world.news_event_cursor)}

func _article(world: Dictionary, event: Dictionary) -> Dictionary:
	var event_type := String(event.get("type", ""))
	var payload: Dictionary = event.get("payload", {})
	var headline := ""
	var body := ""
	match event_type:
		"MATCH_FINISHED":
			var home := _club_name(world, String(payload.get("home_club_id", "")))
			var away := _club_name(world, String(payload.get("away_club_id", "")))
			headline = "%s %d-%d %s" % [home, int(payload.get("home_goals", 0)), int(payload.get("away_goals", 0)), away]
			body = "%s and %s completed their fixture in %s." % [home, away, _competition_name(world, String(payload.get("competition_id", "")))]
		"GOAL_SCORED":
			# Individual goals remain structured events but do not each become a news
			# article; this intentionally demonstrates event/article independence.
			return {}
		"PLAYER_INJURED":
			var player := _player_name(world, String(payload.get("player_id", "")))
			headline = "%s suffers %s" % [player, String(payload.get("injury", "injury"))]
			body = "%s is expected to miss around %d days." % [player, int(payload.get("days_total", 0))]
		"PLAYER_RECOVERED":
			var recovered := _player_name(world, String(payload.get("player_id", "")))
			headline = "%s returns to training" % recovered
			body = "The medical team has cleared %s to resume training." % recovered
		"PLAYER_SIGNED":
			var signed := _player_name(world, String(payload.get("player_id", "")))
			var buyer := _club_name(world, String(payload.get("buyer_id", "")))
			headline = "%s joins %s" % [signed, buyer]
			body = "%s completed a %s move to %s for %d." % [signed, String(payload.get("transfer_type", "transfer")).replace("_", " "), buyer, int(payload.get("fee", 0))]
		"CONTRACT_SIGNED":
			var contracted := _player_name(world, String(payload.get("player_id", "")))
			var club := _club_name(world, String(payload.get("club_id", "")))
			headline = "%s signs contract with %s" % [contracted, club]
			body = "The agreement runs to %d on a weekly wage of %d." % [int(payload.get("end_year", 0)), int(payload.get("weekly_wage", 0))]
		"MANAGER_FIRED":
			var club_name := _club_name(world, String(payload.get("club_id", "")))
			headline = "%s dismiss manager" % club_name
			body = "The board acted after %s." % String(payload.get("reason", "poor results")).replace("_", " ")
		"YOUTH_INTAKE":
			headline = "New youth intake arrives"
			body = "%d academy players entered the football world, including %d elite-rated prospects." % [int(payload.get("count", 0)), int(payload.get("elite_prospects", 0))]
		"PROMISE_RESOLVED":
			if bool(payload.get("fulfilled", false)):
				return {}
			var promise_player := _player_name(world, String(payload.get("player_id", "")))
			headline = "Promise to %s broken" % promise_player
			body = "A broken promise may affect morale and dressing-room trust."
		"SEASON_ENDED":
			headline = "%d season concludes" % int(payload.get("completed_year", 0))
			body = "Domestic seasons have rolled over to %d." % int(payload.get("next_year", 0))
		_:
			return {}
	return {
		"id":"news-event-%s" % String(event.get("id", "")),
		"date":String(payload.get("date", event.get("date", world.get("date", "")))),
		"year":int(event.get("season_year", world.get("season_year", 0))),
		"type":event_type.to_lower(),
		"headline":headline,
		"body":body,
		"event_id":String(event.get("id", "")),
		"event_sequence":int(event.get("sequence", 0)),
	}

func _player_name(world: Dictionary, player_id: String) -> String:
	for player in world.get("players", []):
		if String(player.get("id", "")) != player_id:
			continue
		var name := String(player.get("name", "")).strip_edges()
		if name == "":
			name = (String(player.get("first_name", "")) + " " + String(player.get("last_name", ""))).strip_edges()
		return name if name != "" else player_id
	return player_id

func _club_name(world: Dictionary, club_id: String) -> String:
	for club in world.get("clubs", []):
		if String(club.get("id", "")) == club_id:
			return String(club.get("name", club_id))
	return club_id

func _competition_name(world: Dictionary, competition_id: String) -> String:
	for competition in world.get("competitions", []):
		if String(competition.get("id", "")) == competition_id:
			return String(competition.get("name", competition_id))
	return competition_id
