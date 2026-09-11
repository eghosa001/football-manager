class_name DomainEventBus
extends RefCounted

const CORE_EVENTS := [
	"MATCH_FINISHED",
	"GOAL_SCORED",
	"PLAYER_INJURED",
	"PLAYER_RECOVERED",
	"PLAYER_SIGNED",
	"CONTRACT_SIGNED",
	"MANAGER_FIRED",
	"MANAGER_HIRED",
	"PLAYER_RETIRED",
	"YOUTH_INTAKE",
	"CLUB_PROMOTED",
	"CLUB_RELEGATED",
	"COMPETITION_WON",
	"RECORD_BROKEN",
	"SEASON_ENDED",
	"PROMISE_RESOLVED",
]

func ensure_world(world: Dictionary) -> void:
	world["domain_events"] = world.get("domain_events", [])
	world["domain_event_sequence"] = int(world.get("domain_event_sequence", 0))

func emit(world: Dictionary, event_type: String, payload: Dictionary = {}, source: String = "simulation") -> Dictionary:
	ensure_world(world)
	world.domain_event_sequence = int(world.domain_event_sequence) + 1
	var event := {
		"id": "event-%09d" % int(world.domain_event_sequence),
		"sequence": int(world.domain_event_sequence),
		"type": event_type,
		"source": source,
		"date": String(world.get("date", "")),
		"season_year": int(world.get("season_year", 0)),
		"day_index": int(world.get("day_index", 0)),
		"payload": payload.duplicate(true),
	}
	world.domain_events.append(event)
	if world.domain_events.size() > 2000:
		world.domain_events = world.domain_events.slice(world.domain_events.size() - 2000)
	return event

func recent(world: Dictionary, event_type: String = "", limit: int = 100) -> Array:
	ensure_world(world)
	var rows: Array = []
	for i in range(world.domain_events.size() - 1, -1, -1):
		var event: Dictionary = world.domain_events[i]
		if event_type != "" and String(event.get("type", "")) != event_type:
			continue
		rows.append(event.duplicate(true))
		if rows.size() >= maxi(1, limit):
			break
	return rows

func since(world: Dictionary, sequence: int, event_types: Array = []) -> Array:
	ensure_world(world)
	var rows: Array = []
	for event in world.domain_events:
		if int(event.get("sequence", 0)) <= sequence:
			continue
		if not event_types.is_empty() and String(event.get("type", "")) not in event_types:
			continue
		rows.append(event.duplicate(true))
	return rows

func is_core_event(event_type: String) -> bool:
	return event_type in CORE_EVENTS
