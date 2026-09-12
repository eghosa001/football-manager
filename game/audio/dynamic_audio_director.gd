class_name DynamicAudioDirector
extends Node

const BUS_CATEGORIES := ["ui", "crowd", "whistle", "goals", "subs"]
const ASSET_PATHS := {
	"goal_roar": "res://assets/audio/goal_roar.ogg",
	"whistle": "res://assets/audio/whistle.ogg",
	"whistle_card": "res://assets/audio/whistle_card.ogg",
	"referee_whistle": "res://assets/audio/whistle.ogg",
	"substitution": "res://assets/audio/substitution.ogg",
	"shot_contact": "res://assets/audio/shot_contact.ogg",
	"contact": "res://assets/audio/shot_contact.ogg",
	"ui_click": "res://assets/audio/ui_click.ogg",
	"ui_tick": "res://assets/audio/ui_click.ogg",
	"crowd_ambience": "res://assets/audio/crowd_ambience.ogg",
	"injury_stop": "res://assets/audio/whistle.ogg",
}

var enabled := true
var master_gain := 1.0
var bus_gains := {"ui": 1.0, "crowd": 1.0, "whistle": 1.0, "goals": 1.0, "subs": 0.9}
var muted := false
var crowd_intensity := 0.25
var reduce_sudden_sounds := false
var _last_event := ""
var _device_generation := 0
var _players := {}

func configure(settings: Dictionary) -> void:
	enabled = bool(settings.get("audio_enabled", true))
	master_gain = clampf(float(settings.get("audio_gain", 1.0)), 0.0, 1.0)
	muted = bool(settings.get("audio_muted", settings.get("mute", false)))
	reduce_sudden_sounds = bool(settings.get("reduce_sudden_sounds", false))
	for bus in BUS_CATEGORIES:
		bus_gains[bus] = clampf(float(settings.get("audio_" + bus, settings.get(bus + "_volume", bus_gains[bus])), 0.0, 1.0)

func set_bus_volume(bus: String, value: float) -> void:
	if bus in BUS_CATEGORIES:
		bus_gains[bus] = clampf(value, 0.0, 1.0)

func set_muted(value: bool) -> void:
	muted = value

func update_match_state(minute: int, home_goals: int, away_goals: int, xg_swing: float, pressure: float) -> Dictionary:
	var closeness := 1.0-clampf(absf(float(home_goals-away_goals))/3.0,0.0,1.0)
	var late := clampf(float(minute-60)/30.0,0.0,1.0)
	crowd_intensity = clampf(0.20+closeness*0.25+late*0.22+clampf(absf(xg_swing),0.0,1.0)*0.13+clampf(pressure,0.0,1.0)*0.20,0.0,1.0)
	return {"crowd_intensity":crowd_intensity,"ambience_gain":_gain(crowd_intensity),"device_generation":_device_generation}

func cue(event: Dictionary) -> Dictionary:
	if not enabled or muted:
		return {"play": false}
	var kind := String(event.get("type", "")); _last_event = kind
	var cue_name := "ui_tick"; var emphasis := 0.35; var bus := "ui"
	match kind:
		"goal", "GOAL_SCORED": cue_name = "goal_roar"; emphasis = 1.0; bus = "goals"
		"foul": cue_name = "whistle"; emphasis = 0.62; bus = "whistle"
		"card": cue_name = "whistle_card"; emphasis = 0.58; bus = "whistle"
		"substitution": cue_name = "substitution"; emphasis = 0.46; bus = "subs"
		"injury": cue_name = "injury_stop"; emphasis = 0.42; bus = "whistle"
		"shot": cue_name = "shot_contact"; emphasis = 0.55; bus = "crowd"
		"tackle", "interception": cue_name = "contact"; emphasis = 0.40; bus = "crowd"
		"kickoff", "full_time", "half_time": cue_name = "referee_whistle"; emphasis = 0.70; bus = "whistle"
		"button": cue_name = "ui_click"; emphasis = 0.25; bus = "ui"
	if reduce_sudden_sounds:
		emphasis = minf(emphasis, 0.55)
	return {"play": true, "cue": cue_name, "bus": bus, "asset": asset_for(cue_name), "has_asset": has_asset(cue_name), "gain": _gain(emphasis * float(bus_gains.get(bus, 1.0))), "crowd_intensity": crowd_intensity, "event_type": kind}

func asset_for(cue_name: String) -> String:
	return String(ASSET_PATHS.get(cue_name, ""))

func has_asset(cue_name: String) -> bool:
	var path := asset_for(cue_name)
	return path != "" and ResourceLoader.exists(path)

func play_cue(cue_name: String, gain: float = 1.0) -> Dictionary:
	# Asset hook: committed .ogg files play; otherwise synthesize a short cue
	# so headless/CI and fresh checkouts still have sound. Never errors.
	var player := _players.get(cue_name, null)
	if player == null:
		player = AudioStreamPlayer.new()
		if has_asset(cue_name):
			player.stream = load(asset_for(cue_name))
		else:
			var generator = load("res://game/audio/audio_asset_generator.gd")
			player.stream = generator.synthesized(cue_name) if generator != null else null
		if player.stream == null:
			return {"played": false, "reason": "no_stream", "cue": cue_name}
		add_child(player)
		_players[cue_name] = player
	player.volume_db = linear_to_db(clampf(gain, 0.0, 1.0))
	player.play()
	return {"played": true, "cue": cue_name, "synthesized": not has_asset(cue_name)}

func on_audio_device_changed() -> void:
	_device_generation += 1

func lifecycle_state() -> Dictionary:
	return {"enabled": enabled, "muted": muted, "master_gain": master_gain, "bus_gains": bus_gains.duplicate(true), "crowd_intensity": crowd_intensity, "last_event": _last_event, "device_generation": _device_generation, "reduce_sudden_sounds": reduce_sudden_sounds}

func _gain(value:float)->float:
	return clampf(value*master_gain,0.0,1.0)
