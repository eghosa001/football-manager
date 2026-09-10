extends SceneTree

func _init() -> void:
	quit(preload("res://application/release/package_validator.gd").new().run())
