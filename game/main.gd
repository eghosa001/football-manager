extends Control

const WorldGeneratorClass = preload("res://simulation/world/world_generator.gd")
const MatchEngineClass = preload("res://simulation/match/abstract_match_engine.gd")

@onready var status_label: Label = $Margin/VBox/Status
@onready var match_label: Label = $Margin/VBox/Match

func _ready() -> void:
	var world: Dictionary = WorldGeneratorClass.new().create_world(12345)
	status_label.text = "World ready: %d countries • %d clubs • %d players • %d fixtures" % [
		world.countries.size(), world.clubs.size(), world.players.size(), world.fixtures.size()
	]
	var home: Dictionary = world.clubs[0]
	var away: Dictionary = world.clubs[1]
	var result: Dictionary = MatchEngineClass.new().simulate_match(home, away, world.players, 827183927)
	match_label.text = "%s %d–%d %s  |  xG %.2f–%.2f" % [
		home.name, result.home_goals, result.away_goals, away.name,
		result.stats.home.xg, result.stats.away.xg
	]
