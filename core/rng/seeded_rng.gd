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
	if _state == 0:
		_state = 1

func _next_int() -> int:
	_state = (_state * MULTIPLIER) % MODULUS
	return _state

func randf() -> float:
	return float(_next_int()) / float(MODULUS)

func randf_range(min_value: float, max_value: float) -> float:
	return min_value + (max_value - min_value) * randf()

func randi_range(min_value: int, max_value: int) -> int:
	assert(max_value >= min_value)
	var span: int = max_value - min_value + 1
	return min_value + (_next_int() % span)

func chance(probability: float) -> bool:
	return randf() < clampf(probability, 0.0, 1.0)

func pick(values: Array) -> Variant:
	assert(not values.is_empty(), "Cannot pick from an empty array")
	return values[randi_range(0, values.size() - 1)]

func shuffled_copy(values: Array) -> Array:
	var result := values.duplicate()
	for i in range(result.size() - 1, 0, -1):
		var j := randi_range(0, i)
		var temp = result[i]
		result[i] = result[j]
		result[j] = temp
	return result

func stable_id(namespace: String = "entity") -> String:
	# IDs are generated independently of the simulation random stream. This means
	# adding an entity ID later cannot silently change match/development randomness.
	_id_counter += 1
	var source := str(seed_value) + ":" + namespace + ":" + str(_id_counter)
	var hex: String = source.md5_text()
	return hex.substr(0, 8) + "-" + hex.substr(8, 4) + "-4" + hex.substr(13, 3) + "-8" + hex.substr(17, 3) + "-" + hex.substr(20, 12)
