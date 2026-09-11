extends SceneTree

const WorldGeneratorClass = preload("res://simulation/world/world_generator.gd")
const SeasonRunnerClass = preload("res://application/season/season_runner.gd")
const EquilibriumClass = preload("res://simulation/economy/equilibrium_audit.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var world: Dictionary = WorldGeneratorClass.new().create_world(31337)
	var runner = SeasonRunnerClass.new()
	var history: Array = []
	# 5 full seasons at launch scale; background stays tactical tier (audit item 15).
	for season in range(5):
		var outcome: Dictionary = runner.complete_and_rollover(world, history, 31337 + season)
		var report: Dictionary = EquilibriumClass.audit_world(world)
		assert(EquilibriumClass.healthy(report))
		print("[ECONOMY] season=%d next=%d concentration=%.2f indebted=%.2f bankrupt=%d" % [season, int(outcome.next_season_year), float(report.concentration), float(report.indebted_share), int(report.bankrupt)])
	print("[TEST] ECONOMY EQUILIBRIUM PASS")
	quit(0)
