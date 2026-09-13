extends SceneTree

const Realism = preload("res://data/realism_profile.gd")

func _init() -> void:
	var r = Realism.new()
	var elite: Array[int] = []
	var depth: Array[int] = []
	for i in range(25):
		var ability := r.squad_ability(90, i, 25, 4242, 1000 + i)
		if i < 15: elite.append(ability)
		else: depth.append(ability)
	assert(elite.max() >= 90)
	assert(float(_sum(elite)) / elite.size() > float(_sum(depth)) / depth.size())
	assert(r.player_wage(90, 92, 4242, 99) >= 100000)
	assert(r.player_wage(55, 55, 4242, 100) < r.player_wage(90, 92, 4242, 99))
	print("[TEST] SQUAD REALISM REGRESSION PASS")
	quit(0)

func _sum(values: Array[int]) -> int:
	var total := 0
	for value in values: total += value
	return total
