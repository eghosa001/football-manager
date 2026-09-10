extends Control

const WorldGeneratorClass = preload("res://simulation/world/world_generator.gd")
const TacticsClass = preload("res://simulation/tactics/tactics_manager.gd")
const EconomyClass = preload("res://simulation/finance/club_economy.gd")
const SpatialMatchClass = preload("res://simulation/match/spatial_match_engine.gd")
const QueryClass = preload("res://application/career/career_query.gd")
const MatchViewerClass = preload("res://game/match_viewer.gd")

var world: Dictionary
var club_id := ""
var query = QueryClass.new()
var detailed_match: Dictionary = {}

func _ready() -> void:
	world = WorldGeneratorClass.new().create_world(12345)
	TacticsClass.new().ensure_world(world, 12345)
	EconomyClass.new().ensure_world(world)
	club_id = String(world.clubs[0].id)
	detailed_match = SpatialMatchClass.new().simulate_match(world.clubs[0], world.clubs[1], world.players, 827183927)
	_build_ui()

func _build_ui() -> void:
	for child in get_children(): child.queue_free()
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)
	var header := Label.new()
	header.text = "FOOTBALL DYNASTY  •  %s  •  %s" % [world.clubs[0].name, world.date]
	header.add_theme_font_size_override("font_size", 24)
	root.add_child(header)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)
	_add_text_tab(tabs, "Dashboard", _dashboard_text())
	_add_text_tab(tabs, "Squad", _rows_text(query.squad(world, club_id)))
	_add_text_tab(tabs, "Tactics", str(query.tactics(world, club_id)))
	_add_text_tab(tabs, "Medical", _rows_text(query.medical(world, club_id)))
	_add_text_tab(tabs, "Schedule", _rows_text(query.schedule(world, club_id, 12)))
	_add_text_tab(tabs, "Competitions", _rows_text(query.competition_table(world, String(world.competitions[0].id))))
	_add_text_tab(tabs, "Transfers", _rows_text(query.transfers(world, club_id)))
	_add_text_tab(tabs, "Staff", _rows_text(query.staff(world, club_id)))
	_add_text_tab(tabs, "Finances", str(query.finances(world, club_id)))
	_add_text_tab(tabs, "World Search", _rows_text(query.world_search(world, "", 20)))
	_add_match_tab(tabs)

func _dashboard_text() -> String:
	var data: Dictionary = query.dashboard(world, club_id)
	return "Club: %s\nSeason: %d\nSquad: %d\nCash: %d\nTransfer budget: %d\nNext fixture: %s" % [data.club.name, data.season_year, data.squad_size, data.cash, data.transfer_budget, str(data.next_fixture)]

func _add_text_tab(tabs: TabContainer, title: String, text: String) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = title
	var label := RichTextLabel.new()
	label.bbcode_enabled = false
	label.fit_content = true
	label.text = text
	label.custom_minimum_size = Vector2(700, 440)
	scroll.add_child(label)
	tabs.add_child(scroll)

func _add_match_tab(tabs: TabContainer) -> void:
	var box := VBoxContainer.new()
	box.name = "Match Analysis"
	var analysis: Dictionary = query.match_analysis(detailed_match)
	var summary := Label.new()
	summary.text = "%s %d–%d %s  |  xG %.2f–%.2f  |  spatial frames %d" % [world.clubs[0].name, detailed_match.home_goals, detailed_match.away_goals, world.clubs[1].name, detailed_match.stats.home.xg, detailed_match.stats.away.xg, analysis.frames.size()]
	box.add_child(summary)
	var viewer = MatchViewerClass.new()
	viewer.custom_minimum_size = Vector2(720, 420)
	viewer.set_match(detailed_match)
	box.add_child(viewer)
	tabs.add_child(box)

func _rows_text(rows: Array) -> String:
	var lines: Array[String] = []
	for row in rows: lines.append(str(row))
	return "\n".join(lines)
