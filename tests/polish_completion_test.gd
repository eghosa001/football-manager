extends SceneTree

const EngineRouterClass = preload("res://simulation/match/engine_router.gd")
const CareerCycleV2Class = preload("res://application/career/career_cycle_v2.gd")
const AudioClass = preload("res://game/audio/dynamic_audio_director.gd")
const ViewerQualityClass = preload("res://game/analysis/match_viewer_quality.gd")
const FormSchemaClass = preload("res://tools/modding/competition_form_schema.gd")
const ScreenRegistryClass = preload("res://game/career/career_screen_registry.gd")
const UIAuditClass = preload("res://game/quality/ui_quality_audit.gd")
const ArtDirectionClass = preload("res://game/polish/art_direction_runtime.gd")

var failures:Array=[]

func _init()->void:
	_test_router()
	_test_audio()
	_test_viewer()
	_test_form_schema()
	_test_screen_registry()
	_test_ui_audit()
	_test_art_direction()
	# Preloading the canonical cycle is itself a parser/dependency gate.
	_assert(CareerCycleV2Class!=null,"canonical career cycle preload")
	if failures.is_empty(): print("POLISH COMPLETION: PASS"); quit(0)
	else:
		for failure in failures: push_error(String(failure))
		quit(1)

func _test_router()->void:
	var router=EngineRouterClass.new()
	_assert(router.authoritative_engine()=="detailed","detailed engine authoritative")
	_assert(router.supported_tiers().size()==4,"four simulation tiers routed")

func _test_audio()->void:
	var audio=AudioClass.new()
	audio.configure({"audio_enabled":true,"audio_gain":0.8,"reduce_sudden_sounds":true})
	var state=audio.update_match_state(82,1,1,0.6,0.8)
	var cue=audio.cue({"type":"goal"})
	_assert(float(state.crowd_intensity)>0.4,"dynamic crowd intensity")
	_assert(String(cue.cue)=="goal_roar","goal cue")
	_assert(float(cue.gain)<=0.55,"reduced sudden sound accessibility")
	audio.free()

func _test_viewer()->void:
	var quality=ViewerQualityClass.new()
	var policy=quality.policy({"memory_mb":3000,"cpu_threads":4,"mobile":true},1500)
	_assert(bool(policy.low_end),"low end viewer policy")
	_assert(int(policy.frame_skip)>=2,"low end frame skip")
	var a={"tick":1,"ball":{"x":0.0,"y":0.0},"home":{"p":{"x":10.0,"y":10.0}},"away":{}}
	var b={"tick":2,"ball":{"x":10.0,"y":10.0},"home":{"p":{"x":20.0,"y":20.0}},"away":{}}
	var mid=quality.interpolate(a,b,0.5)
	_assert(is_equal_approx(float(mid.ball.x),5.0),"viewer interpolation")
	_assert(bool(quality.validate_frames([a,b]).ok),"viewer frame validation")

func _test_form_schema()->void:
	var forms=FormSchemaClass.new()
	var checked=forms.validate({"name":"Cup","competition_type":"knockout","teams":16,"max_squad":25,"homegrown_min":8,"extra_time":true,"penalties":true})
	_assert(bool(checked.ok),"competition form valid")
	_assert(forms.schema().has("discipline"),"discipline form section")

func _test_screen_registry()->void:
	var registry=ScreenRegistryClass.new()
	var checked=registry.validate_registry()
	_assert(bool(checked.ok),"screen controllers resolvable")
	_assert(int(checked.count)>=7,"career screens modularized")

func _test_ui_audit()->void:
	var root=Control.new(); var button=Button.new(); button.text="Known"; button.custom_minimum_size=Vector2(80,40); button.size=Vector2(80,40); button.focus_mode=Control.FOCUS_ALL; root.add_child(button)
	var result=UIAuditClass.new().audit(root,{"en":{"known":"Known"}})
	_assert(bool(result.ok),"basic accessibility audit")
	root.free()

func _test_art_direction()->void:
	_assert(ArtDirectionClass!=null,"art direction runtime parses")
	_assert(ArtDirectionClass.TAB_ART.size()>=15,"major career screens have dedicated artwork")
	for required in ["Dashboard","Squad","Tactics","Transfers","Scouting","Finances","Board","Inbox","News","Match Analysis","Medical","Training","Competitions","Club","World History"]:
		_assert(ArtDirectionClass.TAB_ART.has(required),"art coverage: %s" % required)

func _assert(condition:bool,label:String)->void:
	if not condition: failures.append(label)