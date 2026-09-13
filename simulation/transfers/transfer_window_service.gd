class_name TransferWindowService
extends RefCounted

func windows_for_country(world: Dictionary, country_id: String) -> Array:
	var by_country: Variant = world.get("transfer_windows_by_country",{})
	if by_country is Dictionary and by_country.has(country_id):
		return (by_country[country_id] as Array).duplicate(true)
	return world.get("transfer_windows",[]).duplicate(true)

func window_status(world: Dictionary, date_string: String, country_id: String = "") -> Dictionary:
	var parts := date_string.split("-")
	if parts.size() != 3: return {"open":false,"reason":"invalid_date","country_id":country_id,"window":{}}
	var month := int(parts[1]); var day := int(parts[2])
	if month < 1 or month > 12 or day < 1 or day > 31: return {"open":false,"reason":"invalid_date","country_id":country_id,"window":{}}
	var resolved_country := country_id if country_id != "" else String(world.get("default_country_id",""))
	var windows := windows_for_country(world,resolved_country)
	if windows.is_empty(): return {"open":false,"reason":"no_registered_window","country_id":resolved_country,"window":{}}
	var mmdd := month*100+day
	for value in windows:
		if not value is Dictionary: continue
		var window: Dictionary = value
		var start := int(window.get("start_month",0))*100+int(window.get("start_day",0))
		var finish := int(window.get("end_month",0))*100+int(window.get("end_day",0))
		var open := (mmdd >= start and mmdd <= finish) if start <= finish else (mmdd >= start or mmdd <= finish)
		if open: return {"open":true,"reason":"window_open","country_id":resolved_country,"window":window.duplicate(true),"deadline_day":mmdd==finish}
	return {"open":false,"reason":"transfer_window_closed","country_id":resolved_country,"window":{},"next_window":_next_window(windows,mmdd)}

func is_open(world: Dictionary, date_string: String, country_id: String = "") -> bool:
	return bool(window_status(world,date_string,country_id).get("open",false))

func is_open_for_club(world: Dictionary, club_id: String, date_string: String = "") -> bool:
	var country_id := club_country(world,club_id)
	var date := date_string if date_string != "" else String(world.get("date",world.get("current_date","")))
	return is_open(world,date,country_id)

func club_country(world: Dictionary, club_id: String) -> String:
	for club in world.get("clubs",[]):
		if String(club.get("id","")) == club_id: return String(club.get("country_id",""))
	return ""

func free_agent_can_sign(world: Dictionary, date_string: String, country_id: String, rules: Dictionary = {}) -> bool:
	if bool(rules.get("free_agents_outside_window",true)): return true
	return is_open(world,date_string,country_id)

func registration_deadline_status(world: Dictionary, date_string: String, country_id: String) -> Dictionary:
	var status := window_status(world,date_string,country_id)
	if bool(status.get("open",false)) and bool(status.get("deadline_day",false)): status["reason"]="deadline_day"
	return status

func _next_window(windows: Array, mmdd: int) -> Dictionary:
	var best: Dictionary = {}; var best_delta := 100000
	for value in windows:
		if not value is Dictionary: continue
		var window: Dictionary=value; var start:=int(window.get("start_month",0))*100+int(window.get("start_day",0)); var delta:=start-mmdd
		if delta < 0: delta += 1231
		if delta < best_delta: best_delta=delta; best=window.duplicate(true)
	return best
