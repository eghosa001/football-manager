extends SceneTree

const UIReadabilityRuntimeClass = preload("res://game/polish/ui_readability_runtime.gd")

func _init() -> void:
	var runtime = UIReadabilityRuntimeClass.new()

	var button := Button.new()
	button.text = "Continue"
	button.focus_mode = Control.FOCUS_NONE
	runtime.apply_control(button, true)
	assert(button.custom_minimum_size.y >= 48.0)
	assert(button.focus_mode == Control.FOCUS_ALL)

	var field := LineEdit.new()
	runtime.apply_control(field, false)
	assert(field.custom_minimum_size.y >= 38.0)
	assert(field.focus_mode == Control.FOCUS_ALL)

	var label := Label.new()
	label.text = "This is intentionally long interface guidance text that must wrap instead of escaping a narrow mobile panel."
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	runtime.apply_control(label, true)
	assert(label.autowrap_mode != TextServer.AUTOWRAP_OFF)

	var tabs := TabContainer.new()
	var page := Control.new()
	page.name = "Dashboard"
	tabs.add_child(page)
	runtime.apply_control(tabs, true)
	var bar := tabs.get_tab_bar()
	assert(bar != null)
	assert(bar.scrolling_enabled)
	assert(bar.custom_minimum_size.y >= 48.0)
	assert(bar.focus_mode == Control.FOCUS_ALL)

	button.free()
	field.free()
	label.free()
	tabs.free()
	runtime.free()
	print("[TEST] UI READABILITY PASS")
	quit(0)
