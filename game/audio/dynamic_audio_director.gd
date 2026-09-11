class_name DynamicAudioDirector
extends Node

var enabled := true
var master_gain := 1.0
var crowd_intensity := 0.25
var reduce_sudden_sounds := false
var _last_event := ""
var _device_generation := 0

func configure(settings: Dictionary) -> void:
	enabled = bool(settings.get("audio_enabled",true))
	master_gain = clampf(float(settings.get("audio_gain",1.0)),0.0,1.0)
	reduce_sudden_sounds = bool(settings.get("reduce_sudden_sounds",false))

func update_match_state(minute: int, home_goals: int, away_goals: int, xg_swing: float, pressure: float) -> Dictionary:
	var closeness := 1.0-clampf(absf(float(home_goals-away_goals))/3.0,0.0,1.0)
	var late := clampf(float(minute-60)/30.0,0.0,1.0)
	crowd_intensity = clampf(0.20+closeness*0.25+late*0.22+clampf(absf(xg_swing),0.0,1.0)*0.13+clampf(pressure,0.0,1.0)*0.20,0.0,1.0)
	return {"crowd_intensity":crowd_intensity,"ambience_gain":_gain(crowd_intensity),"device_generation":_device_generation}

func cue(event: Dictionary) -> Dictionary:
	if not enabled: return {"play":false}
	var kind:=String(event.get("type","")); _last_event=kind
	var cue_name:="ui_tick"; var emphasis:=0.35
	match kind:
		"goal","GOAL_SCORED": cue_name="goal_roar"; emphasis=1.0
		"foul": cue_name="whistle"; emphasis=0.62
		"card": cue_name="whistle_card"; emphasis=0.58
		"substitution": cue_name="substitution"; emphasis=0.46
		"injury": cue_name="injury_stop"; emphasis=0.42
		"shot": cue_name="shot_contact"; emphasis=0.55
		"tackle","interception": cue_name="contact"; emphasis=0.40
		"kickoff","full_time","half_time": cue_name="referee_whistle"; emphasis=0.70
		"button": cue_name="ui_click"; emphasis=0.25
	if reduce_sudden_sounds: emphasis=minf(emphasis,0.55)
	return {"play":true,"cue":cue_name,"gain":_gain(emphasis),"crowd_intensity":crowd_intensity,"event_type":kind}

func on_audio_device_changed() -> void:
	_device_generation += 1

func lifecycle_state() -> Dictionary:
	return {"enabled":enabled,"master_gain":master_gain,"crowd_intensity":crowd_intensity,"last_event":_last_event,"device_generation":_device_generation,"reduce_sudden_sounds":reduce_sudden_sounds}

func _gain(value:float)->float:
	return clampf(value*master_gain,0.0,1.0)
