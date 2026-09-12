extends Node

## Re-composes career screens so they do not read as a single linear stack.
## It only rearranges existing PanelContainer sections and leaves simulation logic untouched.

const TARGET_TABS := {
	"Dashboard": 0,
	"Squad": 3,
	"Tactics": 2,
	"Transfers": 3,
	"Scouting": 3,
	"Finances": 3,
	"Board": 2,
	"Inbox": 2,
	"News": 2,
	"Match Analysis": 2,
	"Medical": 2,
	"Training": 2,
}

var _next_scan := 0

func _ready() -> void:
	set_process(true)
	call_deferred("_scan")

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now < _next_scan:
		return
	_next_scan = now + 1000
	_scan()

func _scan() -> void:
	_scan_node(get_tree().root)

func _scan_node(node: Node) -> void:
	if node is TabContainer:
		_compose_tabs(node as TabContainer)
	for child in node.get_children():
		_scan_node(child)

func _compose_tabs(tabs: TabContainer) -> void:
	for i in range(tabs.get_tab_count()):
		var page := tabs.get_tab_control(i)
		if page == null:
			continue
		var title := tabs.get_tab_title(i)
		if not TARGET_TABS.has(title):
			continue
		if title == "Dashboard":
			_compose_dashboard(page)
		else:
			_compose_page(page, title, int(TARGET_TABS[title]))

func _compose_dashboard(page: Control) -> void:
	if page.has_meta("nonlinear_dashboard"):
		return
	var overview := _find_named(page, "DynastyCommandOverview")
	if overview == null:
		return
	var old_grid := _find_named(overview, "ManagerOverviewGrid")
	if old_grid == null:
		return
	var cards: Array[Control] = []
	for child in old_grid.get_children():
		if child is Control:
			cards.append(child)
	if cards.size() < 4:
		return

	page.set_meta("nonlinear_dashboard", true)
	var parent := old_grid.get_parent()
	var insert_at := old_grid.get_index()
	parent.remove_child(old_grid)
	old_grid.queue_free()

	var shell := VBoxContainer.new()
	shell.name = "DashboardMosaic"
	shell.add_theme_constant_override("separation", 12)
	parent.add_child(shell)
	parent.move_child(shell, insert_at)

	var hero_row := HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 12)
	hero_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_child(hero_row)

	var hero := cards[1] if cards.size() > 1 else cards[0]
	hero.get_parent().remove_child(hero)
	hero.custom_minimum_size = Vector2(0, 210)
	hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.size_flags_stretch_ratio = 1.8
	hero.set_meta("composition_role", "hero")
	hero_row.add_child(hero)

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 12)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.size_flags_stretch_ratio = 1.0
	hero_row.add_child(side)
	for idx in [0, 2]:
		if idx >= cards.size():
			continue
		var card := cards[idx]
		card.get_parent().remove_child(card)
		card.custom_minimum_size = Vector2(0, 96)
		card.set_meta("composition_role", "support")
		side.add_child(card)

	var lower := GridContainer.new()
	lower.columns = 1 if OS.has_feature("mobile") else 3
	lower.add_theme_constant_override("h_separation", 12)
	lower.add_theme_constant_override("v_separation", 12)
	lower.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_child(lower)
	for idx in range(cards.size()):
		if idx in [0, 1, 2]:
			continue
		var card := cards[idx]
		card.get_parent().remove_child(card)
		card.custom_minimum_size = Vector2(230, 132)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.set_meta("composition_role", "tile")
		lower.add_child(card)

func _compose_page(page: Control, title: String, columns: int) -> void:
	if page.has_meta("nonlinear_composed"):
		return
	var root_box := _first_vbox(page)
	if root_box == null:
		return
	var panels: Array[PanelContainer] = []
	for child in root_box.get_children():
		if child is PanelContainer and not child.has_meta("composition_skip"):
			panels.append(child as PanelContainer)
	if panels.size() < 3:
		return

	page.set_meta("nonlinear_composed", true)
	var first_index := panels[0].get_index()
	var shell := VBoxContainer.new()
	shell.name = "%sComposition" % title.replace(" ", "")
	shell.add_theme_constant_override("separation", 12)
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.add_child(shell)
	root_box.move_child(shell, first_index)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_child(top)

	var feature := panels[0]
	feature.get_parent().remove_child(feature)
	feature.custom_minimum_size = Vector2(0, 190)
	feature.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feature.size_flags_stretch_ratio = 1.65
	feature.set_meta("composition_role", "feature")
	top.add_child(feature)

	var rail := VBoxContainer.new()
	rail.add_theme_constant_override("separation", 12)
	rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail.size_flags_stretch_ratio = 1.0
	top.add_child(rail)
	var rail_count := mini(2, panels.size() - 1)
	for i in range(1, 1 + rail_count):
		var panel := panels[i]
		panel.get_parent().remove_child(panel)
		panel.custom_minimum_size = Vector2(0, 88)
		panel.set_meta("composition_role", "rail")
		rail.add_child(panel)

	if panels.size() > 1 + rail_count:
		var grid := GridContainer.new()
		grid.columns = 1 if OS.has_feature("mobile") else maxi(2, columns)
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shell.add_child(grid)
		for i in range(1 + rail_count, panels.size()):
			var panel := panels[i]
			panel.get_parent().remove_child(panel)
			panel.custom_minimum_size = Vector2(220, 124)
			panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			panel.set_meta("composition_role", "tile")
			grid.add_child(panel)

func _find_named(node: Node, wanted: String) -> Node:
	if String(node.name) == wanted:
		return node
	for child in node.get_children():
		var found := _find_named(child, wanted)
		if found != null:
			return found
	return null

func _first_vbox(node: Node) -> VBoxContainer:
	if node is VBoxContainer:
		return node
	for child in node.get_children():
		var found := _first_vbox(child)
		if found != null:
			return found
	return null
