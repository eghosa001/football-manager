class_name SeededRng
extends RefCounted

# Use a dedicated RandomNumberGenerator instance rather than global RNG state.
# The project pins Godot 4.7.2, so the generator implementation is stable for
# saves/tests built against this phase while remaining isolated per world/match.
var seed_value: int
var _rng: RandomNumberGenerator
var _id_counter := 0

func _init(seed: int) -> void:
	seed_value = seed
	_id_counter = 0
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed

func randf() -> float:
	return _rng.randf()

func randf_range(min_value: float, max_value: float) -> float:
	return _rng.randf_range(min_value, max_value)

func randi_range(min_value: int, max_value: int) -> int:
	assert(max_value >= min_value)
	return _rng.randi_range(min_value, max_value)

func chance(probability: float) -> bool:
	return randf() < clampf(probability, 0.0, 1.0)

func pick(values: Array) -> Variant:
	assert(not values.is_empty(), "Cannot pick from an empty array")
	var index: int = randi_range(0, values.size() - 1)
	return values[index]

func shuffled_copy(values: Array) -> Array:
	var result := values.duplicate()
	for i in range(result.size() - 1, 0, -1):
		var j: int = randi_range(0, i)
		var temp = result[i]
		result[i] = result[j]
		result[j] = temp
	return result

func stable_id(namespace_name: String = "entity") -> String:
	# Stable, opaque identifier. Identity semantics matter more than presentation,
	# and IDs are never user-facing. This counter does not consume the RNG stream.
	_id_counter += 1
	return namespace_name + "-" + str(seed_value) + "-" + str(_id_counter)
