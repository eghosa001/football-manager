extends SceneTree

const Medical = preload("res://simulation/players/medical_system.gd")

var checks := 0
var failures := 0

func _init() -> void:
	var medical = Medical.new()
	var healthy := _player("healthy",24,95,20,[])
	var fragile := _player("fragile",34,62,90,[{"body_region":"lower_limb","recurrence":0.18},{"body_region":"lower_limb","recurrence":0.16}])
	var healthy_risk := medical.injury_risk(healthy,{"fatigue":10.0,"match_intensity":0.55,"training_load":0.2,"surface":"good","body_region":"lower_limb"})
	var fragile_risk := medical.injury_risk(fragile,{"fatigue":80.0,"match_intensity":1.0,"training_load":0.8,"surface":"poor","body_region":"lower_limb"})
	_expect(float(fragile_risk.probability)>float(healthy_risk.probability),"Fatigue, age, proneness, poor surface and recurrence must increase injury risk")
	var injured := medical.suffer_injury(fragile,95001,"match")
	_expect(String(injured.get("severity",""))!="" and String(injured.get("rehab_stage",""))=="acute","Injury must store severity and rehabilitation stage")
	var low_quality := medical.availability(fragile,20)
	var high_quality := medical.availability(fragile,90)
	var low_width := int(low_quality.estimated_max_days)-int(low_quality.estimated_min_days)
	var high_width := int(high_quality.estimated_max_days)-int(high_quality.estimated_min_days)
	_expect(low_width>high_width,"Better medical staff must narrow recovery-date uncertainty")
	_expect(String(high_quality.estimated_range).contains("days"),"Medical availability must expose a recovery range rather than only an exact hidden timer")
	for i in range(300): medical.advance_day(fragile,90,0.8)
	_expect(bool(medical.availability(fragile,90).available),"Rehabilitation must eventually return player to availability")
	if failures==0:
		print("[TEST] MEDICAL UNCERTAINTY PASS — %d checks"%checks); quit(0)
	else:
		push_error("[TEST] MEDICAL UNCERTAINTY FAIL — %d failures across %d checks"%[failures,checks]); quit(1)

func _player(id:String,age:int,fitness:int,proneness:int,history:Array)->Dictionary:
	return {"id":id,"age":age,"fitness":fitness,"fatigue":100-fitness,"hidden_attributes":{"injury_proneness":proneness},"medical":{"current":{},"history":history.duplicate(true),"rehab_progress":0.0,"match_fitness":100.0}}

func _expect(condition:bool,message:String)->void:
	checks+=1
	if not condition:
		failures+=1
		push_error("[TEST] "+message)
