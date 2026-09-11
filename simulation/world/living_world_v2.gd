class_name LivingWorldV2
extends "res://simulation/world/living_world.gd"

const EventBusClass = preload("res://core/events/domain_event_bus.gd")
const AwardServiceClass = preload("res://simulation/world/award_service.gd")
const RelationshipServiceClass = preload("res://simulation/world/relationship_service.gd")

var _event_bus = EventBusClass.new()
var _awards = AwardServiceClass.new()
var _relationships = RelationshipServiceClass.new()

func ensure_world(world: Dictionary) -> void:
	super.ensure_world(world)
	_event_bus.ensure_world(world)
	_awards.ensure_world(world)
	_relationships.ensure_world(world)

func _emit_news(world: Dictionary, reasons: Array, year: int) -> void:
	# News is no longer manufactured directly here. The living-world layer emits
	# structured domain events; NewsEventConsumer is the only article producer.
	for reason in reasons:
		_event_bus.emit(world,"WORLD_UPDATE",{"completed_year":year,"reason":reason.duplicate(true)},"living_world")

func _create_awards(world: Dictionary, records: Array, year: int, reasons: Array) -> int:
	var before := world.get("awards",[]).size()
	var competition_ids: Array = []
	for record in records:
		var competition_id := String(record.get("competition_id",""))
		if competition_id != "" and competition_id not in competition_ids: competition_ids.append(competition_id)
	for competition_id in competition_ids:
		var created := _awards.calculate_season_awards(world,year,String(competition_id))
		for award in created:
			_event_bus.emit(world,"AWARD_WON",award.duplicate(true),"award_service")
	var count := world.get("awards",[]).size()-before
	if count>0: reasons.append({"type":"awards","count":count,"cause":"canonical_season_statistics"})
	return count

func _update_relationships(world: Dictionary, _seed: int, year: int, reasons: Array) -> void:
	_relationships.ensure_world(world)
	for event in world.get("domain_events",[]):
		if int(event.get("season_year",year)) >= year-1: _relationships.process_event(world,event)
	for club in world.get("clubs",[]):
		_relationships.build_social_groups(world,String(club.get("id","")),world.get("players",[]))
	_relationships.decay(world,1)
	reasons.append({"type":"relationship_tick","count":world.get("relationships",[]).size(),"cause":"events_social_groups_and_decay"})
