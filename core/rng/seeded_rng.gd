class_name SeededRng
extends RefCounted

# Counter-based deterministic PRNG. Each draw is a pure function of the seed and
# draw index, so replay does not depend on mutable engine RNG internals. The
# nonlinear modular mixing prevents the strong seed/key correlations produced by
# an affine generator while staying inside signed 64-bit integer range.
const MODULUS := 2_147_483_647
const MULTIPLIER_A := 48_271
const MULTIPLIER_B := 69_621
const OFFSET := 12_345

var seed_value: int
var _draw_counter := 0
var _id_counter := 0

func _init(seed: int) -> void:
	seed_value = seed
	_draw_counter = 0
	_id_counter = 0

static func value_for(seed: int, draw_index: int) -> int:
	var normalized_seed: int = posmod(seed, MODULUS)
	var normalized_index: int = posmod(draw_index + 1, MODULUS)
	var value: int = posmod(normalized_seed * MULTIPLIER_A + normalized_index * MULTIPLIER_B + OFFSET, MODULUS)
	value = posmod(value * value + normalized_index * 104_729 + normalized_seed * 8_191 + OFFSET, MODULUS)
	var index_square: int = posmod(normalized_index * normalized_index, MODULUS)
	value = posmod(value * MULTIPLIER_A + index_square * MULTIPLIER_B + normalized_seed * 7_919 + OFFSET, MODULUS)
	value = posmod(value * value + normalized_seed * 104_729 + normalized_index * 7_919 + OFFSET, MODULUS)
	return value

static func unit_for(seed: int, draw_index: int) -> float:
	return float(value_for(seed, draw_index)) / float(MODULUS)

func _next_int() -> int:
	var value: int = value_for(seed_value, _draw_counter)
	_draw_counter += 1
	return value

func randf() -> float:
	return float(_next_int()) / float(MODULUS)

func randf_range(min_value: float, max_value: float) -> float:
	var unit: float = randf()
	return min_value + (max_value - min_value) * unit

func randi_range(min_value: int, max_value: int) -> int:
	assert(max_value >= min_value)
	var span: int = max_value - min_value + 1
	return min_value + (_next_int() % span)

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
	_id_counter += 1
	return namespace_name + "-" + str(seed_value) + "-" + str(_id_counter)
