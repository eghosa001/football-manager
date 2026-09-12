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

const CAREER_TABS := [
	{"id":"dashboard","title":"Dashboard","builder":"add_dashboard","owner":"views"},
	{"id":"squad","title":"Squad","builder":"add_squad","owner":"views"},
	{"id":"training","title":"Training","builder":"add_training","owner":"views"},
	{"id":"tactics","title":"Tactics","builder":"add_tactics","owner":"views"},
	{"id":"medical","title":"Medical","builder":"add_medical","owner":"views"},
	{"id":"scouting","title":"Scouting","builder":"add_scouting","owner":"views"},
	{"id":"transfers","title":"Transfers","builder":"add_transfers","owner":"views"},
	{"id":"schedule","title":"Schedule","builder":"add_schedule","owner":"views"},
	{"id":"competitions","title":"Competitions","builder":"add_competitions","owner":"views"},
	{"id":"inbox","title":"Inbox","builder":"_add_inbox_tab","owner":"app"},
	{"id": "staff", "title": "Staff", "builder": "add_staff", "owner": "views"},
	{"id": "youth", "title": "Youth Academy", "builder": "add_youth", "owner": "views"},
	{"id": "finances", "title": "Finances", "builder": "add_finances", "owner": "views"},
	{"id":"search","title":"Search","builder":"add_search","owner":"views"},
	{"id":"match_analysis","title":"Match Analysis","builder":"add_match_analysis","owner":"views"},
]

func descriptor(screen_id:String)->Dictionary:
	return SCREENS.get(screen_id,{}).duplicate(true)

func tab_plan()->Array:
	return CAREER_TABS.duplicate(true)

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
	var seen := {}
	for row in CAREER_TABS:
		var tab_id := String(row.get("id", ""))
		var builder := String(row.get("builder", ""))
		var owner := String(row.get("owner", ""))
		if tab_id == "":
			errors.append({"screen":"","code":"missing_tab_id"})
		elif seen.has(tab_id):
			errors.append({"screen":tab_id,"code":"duplicate_tab_id"})
		else:
			seen[tab_id] = true
		if builder == "": errors.append({"screen":tab_id,"code":"missing_builder"})
		if owner not in ["views", "app"]: errors.append({"screen":tab_id,"code":"invalid_owner","owner":owner})
	return {"ok":errors.is_empty(),"errors":errors,"count":SCREENS.size(),"tab_count":CAREER_TABS.size()}
