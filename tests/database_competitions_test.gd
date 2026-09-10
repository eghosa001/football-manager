extends SceneTree

const DatabaseLoaderClass = preload("res://data/database_loader.gd")
const KnockoutClass = preload("res://simulation/competitions/knockout_competition.gd")

func _init() -> void:
	var loader = DatabaseLoaderClass.new()
	var data: Dictionary = loader.load_seed()
	assert(not data.is_empty())
	assert(loader.validate_seed(data).is_empty())
	var clubs := []
	for i in range(8): clubs.append("club-%d" % i)
	var bracket: Dictionary = KnockoutClass.new().create_bracket(clubs, 123)
	assert(bracket.matches.size() == 4)
	var results := []
	for match in bracket.matches:
		results.append({"home_goals":1,"away_goals":0})
	bracket = KnockoutClass.new().advance_round(bracket, results)
	assert(bracket.entrants.size() == 4)
	print("[TEST] DATABASE/COMPETITIONS PASS")
	quit(0)
