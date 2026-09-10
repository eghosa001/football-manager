class_name SeededRng
extends RefCounted

var _rng := RandomNumberGenerator.new()
var seed_value: int

func _init(seed: int) -> void:
	seed_value = seed
	_rng.seed = seed

func randf() -> float:
	return _rng.randf()

func randf_range(min_value: float, max_value: float) -> float:
	return _rng.randf_range(min_value, max_value)

func randi_range(min_value: int, max_value: int) -> int:
	return _rng.randi_range(min_value, max_value)

func chance(probability: float) -> bool:
	return _rng.randf() < clampf(probability, 0.0, 1.0)

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

func stable_id(_namespace: String = "") -> String:
	# Deterministic RFC-4122-shaped UUID v4. The namespace parameter documents call intent;
	# uniqueness comes from this controlled RNG stream, not global randomness.
	var bytes: Array[int] = []
	for _i in range(16):
		bytes.append(randi_range(0, 255))
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	return "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % bytes
