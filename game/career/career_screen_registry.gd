class_name CareerScreenRegistry
extends RefCounted

const SCREENS := {
	"dashboard":{"controller":"res://game/polish/dashboard_runtime.gd","requires":["club","season"]},
	"squad":{"controller":"res://game/polish/squad_runtime.gd","requires":["players","registration"]},
	"tactics":{"controller":"res://game/polish/tactics_runtime.gd","requires":["tactic","players"]},
	"training":{"controller":"res://game/polish/training_runtime.gd","requires":["players","staff"]},
	"management":{"controller":"res://game/polish/management_runtime.gd","requires":["manager","board"]},
	"search":{"controller":"res://game/polish/search_runtime.gd","requires":["world"]},
	"match":{"controller":"res://game/polish/match_hud_runtime.gd","requires":["fixture","match"]},
}

func descriptor(screen_id:String)->Dictionary:
	return SCREENS.get(screen_id,{}).duplicate(true)

func available(context:Dictionary)->Array:
	var rows:Array=[]
	for screen_id in SCREENS.keys():
		var row:Dictionary=SCREENS[screen_id]
		var ok:=true
		for requirement in row.get("requires",[]):
			if not context.has(String(requirement)): ok=false; break
		if ok: rows.append(String(screen_id))
	return rows

func controller_script(screen_id:String):
	var row:=descriptor(screen_id)
	var path:=String(row.get("controller",""))
	if path=="" or not ResourceLoader.exists(path): return null
	return load(path)

func validate_registry()->Dictionary:
	var errors:Array=[]
	for screen_id in SCREENS.keys():
		var path:=String(SCREENS[screen_id].get("controller",""))
		if path=="" or not ResourceLoader.exists(path): errors.append({"screen":screen_id,"code":"missing_controller","path":path})
	return {"ok":errors.is_empty(),"errors":errors,"count":SCREENS.size()}
