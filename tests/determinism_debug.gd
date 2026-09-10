extends SceneTree

const WorldGeneratorClass = preload("res://simulation/world/world_generator.gd")
const MatchEngineClass = preload("res://simulation/match/abstract_match_engine.gd")

func _init() -> void:
	var generator = WorldGeneratorClass.new()
	var a: Dictionary = generator.create_world(12345)
	var b: Dictionary = generator.create_world(12345)
	var world_diff := _first_difference(a, b)
	print("[DETERMINISM DEBUG] world: %s" % ("<identical>" if world_diff == "" else world_diff))
	var engine = MatchEngineClass.new()
	var first: Dictionary = engine.simulate_match(a.clubs[0], a.clubs[1], a.players, 827183927)
	var second: Dictionary = engine.simulate_match(a.clubs[0], a.clubs[1], a.players, 827183927)
	for key in ["lineups", "events", "substitutions", "stats", "ratings", "home_goals", "away_goals"]:
		var diff := _first_difference(first[key], second[key], "root.%s" % key)
		print("[DETERMINISM DEBUG] match %s: %s" % [key, "<identical>" if diff == "" else diff])
	quit(0)

func _first_difference(left: Variant, right: Variant, path: String = "root") -> String:
	var left_type: int = typeof(left)
	if left_type != typeof(right):
		return "%s type %d != %d" % [path, left_type, typeof(right)]
	if left_type == TYPE_DICTIONARY:
		if left.size() != right.size():
			return "%s dictionary size %d != %d" % [path, left.size(), right.size()]
		for key in left.keys():
			if not right.has(key):
				return "%s missing key %s" % [path, str(key)]
			var diff: String = _first_difference(left[key], right[key], "%s.%s" % [path, str(key)])
			if diff != "":
				return diff
		return ""
	if left_type == TYPE_ARRAY:
		if left.size() != right.size():
			return "%s array size %d != %d" % [path, left.size(), right.size()]
		for i in range(left.size()):
			var diff: String = _first_difference(left[i], right[i], "%s[%d]" % [path, i])
			if diff != "":
				return diff
		return ""
	if left != right:
		return "%s value %s != %s" % [path, str(left), str(right)]
	return ""
