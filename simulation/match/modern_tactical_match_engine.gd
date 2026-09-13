class_name ModernTacticalMatchEngine
extends "res://simulation/match/tactical_match_engine.gd"

const ModernBaseMatchEngineClass = preload("res://simulation/match/modern_abstract_match_engine.gd")

func _init() -> void:
	_base = ModernBaseMatchEngineClass.new()
