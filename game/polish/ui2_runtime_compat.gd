extends "res://game/polish/ui2_runtime.gd"

# Most polish/UI runtimes are idempotent scene decorators. Historically each one
# polled the entire scene tree on its own 250–1200 ms timer. With a ~2,000-node
# career UI that means many complete tree walks every second while the game is
# otherwise idle. Production now uses one debounced node-added scheduler instead.
# AutosaveRuntime is intentionally excluded because its timer owns save policy,
# not just presentation wiring.
const SCAN_RUNTIME_NAMES := [
	"UI2Runtime",
	"UI2ExtendedRuntime",
	"UI2MatchdayRuntime",
	"UI2ProfileRuntime",
	"UI2IntegrationRuntime",
	"UI2RemainingRuntime",
	"UI2LayoutFixRuntime",
	"UI2MenuRuntime",
	"CompletionRuntime",
	"TacticsRuntime",
	"SearchRuntime",
	"MatchHudRuntime",
	"ManagementRuntime",
	"CareerControlsRuntime",
	"GraphicsRuntime",
	"SquadRuntime",
	"DashboardRuntime",
	"NavigationRuntime",
	"TrainingRuntime",
	"HappinessRuntime",
	"PresentationRuntime",
	"CompositionRuntime",
	"ArtDirectionRuntime",
	"PolishRuntime",
]

var _compat_scan_pending := false
var _compat_scan_running := false

func _ready() -> void:
	set_process(false)
	if not get_tree().node_added.is_connected(_on_ui_node_added):
		get_tree().node_added.connect(_on_ui_node_added)
	# Defer until every autoload has completed its own _ready(), otherwise a later
	# autoload could turn polling back on after we disabled it.
	call_deferred("_install_event_driven_scans")

func _process(_delta: float) -> void:
	# Intentionally empty. Screen enhancement is event driven in production.
	pass

func _install_event_driven_scans() -> void:
	for runtime_name in SCAN_RUNTIME_NAMES:
		var runtime := get_node_or_null("/root/%s" % runtime_name)
		if runtime != null:
			runtime.set_process(false)
	_queue_ui_scan()

func _on_ui_node_added(_node: Node) -> void:
	_queue_ui_scan()

func _queue_ui_scan() -> void:
	# A decoration pass can itself add controls. Coalesce those additions into one
	# follow-up stabilization pass instead of recursively scanning immediately.
	if _compat_scan_pending:
		return
	_compat_scan_pending = true
	call_deferred("_run_ui_scan_batch")

func _run_ui_scan_batch() -> void:
	if _compat_scan_running:
		return
	_compat_scan_pending = false
	_compat_scan_running = true
	for runtime_name in SCAN_RUNTIME_NAMES:
		var runtime := get_node_or_null("/root/%s" % runtime_name)
		if runtime == null:
			continue
		if runtime.has_method("_scan"):
			runtime.call("_scan")
		elif runtime.has_method("_scan_tree"):
			runtime.call("_scan_tree")
	_compat_scan_running = false
	# If any decorator created more nodes while this pass was running, node_added
	# has already queued one deferred follow-up; metadata guards make it cheap.

# The production scene uses registry_career_app.gd, which subclasses career_app.gd.
# Resolve the live app by capabilities rather than by an exact script filename.
func _career_app(node: Node) -> Node:
	var current: Node = node
	while current != null:
		if current.has_method("_show_career") and current.has_method("_advance_day"):
			return current
		current = current.get_parent()
	return null

# NavigationRuntime now places the desktop sidebar inside a ScrollContainer.
# Keep the visual enhancement logic while locating the sidebar recursively.
func _enhance_shell(tabs: TabContainer, session) -> void:
	var shell := tabs.get_parent()
	if shell == null or shell.has_meta("ui2_shell_enhanced"):
		return
	var sidebar := shell.find_child("CareerSidebar", true, false)
	if sidebar == null:
		return
	shell.set_meta("ui2_shell_enhanced", true)
	if sidebar is Control:
		(sidebar as Control).custom_minimum_size.x = 184
	var identity := sidebar.get_node_or_null("DynastyIdentity")
	if identity != null:
		var club := _club(session.world, session.managed_club_id)
		var crest := Label.new()
		crest.text = "◆"
		crest.add_theme_font_size_override("font_size", 32)
		crest.add_theme_color_override("font_color", UI.CYAN)
		identity.add_child(crest)
		identity.move_child(crest, 0)
		var club_label := Label.new()
		club_label.text = String(club.get("name", "Club"))
		club_label.add_theme_font_size_override("font_size", 12)
		club_label.add_theme_color_override("font_color", UI.MUTED)
		identity.add_child(club_label)
	for child in sidebar.get_children():
		if child is Button:
			var button := child as Button
			button.custom_minimum_size.y = 38
			button.add_theme_font_size_override("font_size", 13)
