class_name SeededRng
extends RefCounted

# Park-Miller minimal-standard PRNG. Keeping the algorithm in project code makes
# replay behaviour explicit and independent of engine RNG implementation changes.
const MODULUS := 2_147_483_647
const MULTIPLIER := 48_271

var seed_value: int
var _state: int
var _id_counter := 0

func _init(seed: int) -> void:
	seed_value = seed
	_state = abs(seed) % MODULUS
	_id_counter = 0
	if _state == 0:
		_state = 1

func _next_int() -> int:
	_state = (_state * MULTIPLIER) % MODULUS
	return _state

func randf() -> float:
	return float(_next_int()) / float(MODULUS)

func randf_range(min_value: float, max_value: float) -> float:
	var unit: float = randf()
	return min_value + (max_value - min_value) * unit

func randi_range(min_value: int, max_value: int) -> int:
	assert(max_value >= min_value)
	var span: int = max_value - min_value + 1
	var raw: int = _next_int()
	return min_value + (raw % span)

func chance(probability: float) -> bool:
	var roll: float = randf()
	return roll < clampf(probability, 0.0, 1.0)

func pick(values: Array) -> Variant:
	assert(not values.is_empty(), "Cannot pick from an empty array")
	# Keep the RNG draw and Array lookup as separate operations. This avoids
	# expression-evaluation ambiguity and makes seeded picks reproducible.
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
