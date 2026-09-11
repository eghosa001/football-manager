class_name DynamicsActions
extends RefCounted

const DressingRoomClass = preload("res://simulation/players/dressing_room.gd")

func set_captain(world: Dictionary, club_id: String, player_id: String) -> Error:
	var club := _club(world, club_id)
	var player := _player(world, player_id)
	if club.is_empty() or player.is_empty() or String(player.get("club_id", "")) != club_id or bool(player.get("retired", false)):
		return ERR_INVALID_PARAMETER
	var previous := String(club.get("captain_id", ""))
	club["captain_id"] = player_id
	if previous != "" and previous != player_id:
		DressingRoomClass.new().apply_event(world, club_id, "captain_changed", player_id)
	world["causal_records"] = world.get("causal_records", [])
	world.causal_records.append({"type":"captain_appointed","club_id":club_id,"player_id":player_id,"previous_player_id":previous,"date":String(world.get("date",""))})
	return OK

func captain_candidates(world: Dictionary, club_id: String) -> Array:
	var room := DressingRoomClass.new().rebuild(world, club_id)
	var ids: Array = []
	ids.append_array(room.get("leaders", []))
	ids.append_array(room.get("highly_influential", []))
	var rows: Array = []
	for id in ids:
		var player := _player(world, String(id))
		if player.is_empty(): continue
		rows.append({"id":String(id),"name":_name(player),"influence":DressingRoomClass.new().influence_score(player),"leadership":int(player.get("attributes",{}).get("leadership",50)),"age":int(player.get("age",0))})
	return rows

func _club(world: Dictionary, id: String) -> Dictionary:
	for club in world.get("clubs",[]):
		if String(club.get("id","")) == id: return club
	return {}

func _player(world: Dictionary, id: String) -> Dictionary:
	for player in world.get("players",[]):
		if String(player.get("id","")) == id: return player
	return {}

func _name(player: Dictionary) -> String:
	var name := String(player.get("name","")).strip_edges()
	if name != "": return name
	return (String(player.get("first_name",""))+" "+String(player.get("last_name",""))).strip_edges()
