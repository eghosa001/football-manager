class_name SeededRng
extends RefCounted

# Park-Miller minimal-standard PRNG. Keeping the algorithm in project code makes
# replay behaviour explicit and independent of engine RNG implementation changes.
const MODULUS := 2_147_483_647
const MULTIPLIER := 48_271
const HEX := "0123456789abcdef"

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
	# UUID-shaped deterministic identifier derived without consuming the random stream.
	_id_counter += 1
	var namespace_hash := _stable_string_hash(namespace)
	var a := _mix(seed_value, namespace_hash, _id_counter, 17)
	var b := _mix(seed_value, namespace_hash, _id_counter, 31)
	var c := _mix(seed_value, namespace_hash, _id_counter, 47)
	var d := _mix(seed_value, namespace_hash, _id_counter, 73)
	var hex := _hex_fixed(a, 8) + _hex_fixed(b, 8) + _hex_fixed(c, 8) + _hex_fixed(d, 8)
	return hex.substr(0, 8) + "-" + hex.substr(8, 4) + "-4" + hex.substr(13, 3) + "-8" + hex.substr(17, 3) + "-" + hex.substr(20, 12)

func _stable_string_hash(value: String) -> int:
	var hash_value: int = 5381
	for i in range(value.length()):
		hash_value = ((hash_value * 33) + value.unicode_at(i)) % MODULUS
	return hash_value

func _mix(seed: int, namespace_hash: int, counter: int, salt: int) -> int:
	var value: int = (abs(seed) + namespace_hash * salt + counter * 104729 + salt * 8191) % MODULUS
	if value == 0:
		value = salt
	value = (value * MULTIPLIER) % MODULUS
	value = (value * MULTIPLIER + counter * salt) % MODULUS
	return value

func _hex_fixed(value: int, width: int) -> String:
	var text := ""
	var current := abs(value)
	for _i in range(width):
		text = HEX[current & 0x0f] + text
		current = current >> 4
	return text
