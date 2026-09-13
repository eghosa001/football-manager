class_name PlayerLifecycleService
extends "res://simulation/players/player_lifecycle_v2.gd"

const HomegrownTrainingServiceClass = preload("res://simulation/players/homegrown_training_service.gd")

# Stable production facade for the canonical player lifecycle implementation.
# The versioned implementation stays internal until RC3 soak/parity evidence
# makes physical flattening safe.

func advance_year(world: Dictionary, season_seed: int, youth_per_club: int = 2) -> Dictionary:
	# Accrue the season spent at the player's current club before the base
	# lifecycle increments age. Only ages 15-21 count toward homegrown status.
	var homegrown_report: Dictionary = HomegrownTrainingServiceClass.new().accrue_season(world)
	var result: Dictionary = super.advance_year(world, season_seed, youth_per_club)
	result["homegrown_training"] = homegrown_report
	return result
