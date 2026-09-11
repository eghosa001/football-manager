extends SceneTree

const WorldGenerator = preload("res://simulation/world/world_generator.gd")
const EventBus = preload("res://core/events/domain_event_bus.gd")
const NewsConsumer = preload("res://application/career/news_event_consumer.gd")

var checks := 0
var failures := 0

func _init() -> void:
	var world := WorldGenerator.new().create_world(88101, 1, 4, 20)
	var bus = EventBus.new()
	var consumer = NewsConsumer.new()
	bus.emit(world, "PLAYER_INJURED", {"player_id":"p1","injury":"ankle sprain","club_id":"c1"}, "test")
	bus.emit(world, "CONTRACT_SIGNED", {"player_id":"p1","club_id":"c1"}, "test")
	_expect(world.get("news", []).is_empty(), "Domain events must exist before news presentation is generated")
	var first := consumer.consume(world)
	_expect(int(first.get("created", 0)) == 2, "News consumer must create one article for each newsworthy unconsumed event")
	_expect(world.get("news", []).size() == 2, "News archive must retain consumed event articles")
	_expect(int(world.get("news_event_cursor", 0)) == int(world.get("domain_event_sequence", 0)), "News cursor must advance to latest consumed event")
	var second := consumer.consume(world)
	_expect(int(second.get("created", 0)) == 0 and world.get("news", []).size() == 2, "Re-consuming without new events must not duplicate articles")
	bus.emit(world, "MATCH_FINISHED", {"home_club_id":"a","away_club_id":"b","home_goals":2,"away_goals":1}, "test")
	var third := consumer.consume(world)
	_expect(int(third.get("created", 0)) == 1 and world.get("news", []).size() == 3, "Only newly emitted events must generate later articles")
	if failures == 0:
		print("[TEST] EVENT NEWS PASS — %d checks" % checks)
		quit(0)
	else:
		push_error("[TEST] EVENT NEWS FAIL — %d failures across %d checks" % [failures, checks])
		quit(1)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[TEST] " + message)
