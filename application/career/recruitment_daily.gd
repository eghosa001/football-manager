class_name RecruitmentDaily
extends RefCounted

const ScoutingServiceClass = preload("res://simulation/scouting/scouting_service.gd")
const InboxServiceClass = preload("res://application/career/inbox_service.gd")

func run(world: Dictionary, managed_club_id: String, seed: int) -> Array:
	var service = ScoutingServiceClass.new()
	service.ensure_world(world)
	var updates: Array = []
	for focus in world.get("recruitment_focuses", []):
		if not bool(focus.get("active", true)): continue
		var scout := _staff(world, String(focus.get("scout_id", "")))
		if scout.is_empty(): continue
		var before_count := focus.get("discovered", []).size()
		service.advance_focus(world, focus, 1, int(scout.get("ability", 50)), seed + _stable_key(String(focus.get("id", ""))))
		var after_count := focus.get("discovered", []).size()
		updates.append({"focus_id":String(focus.id),"progress":float(focus.progress),"new_players":after_count-before_count})
		if String(focus.get("club_id", "")) == managed_club_id and after_count > before_count:
			InboxServiceClass.new().add_message(world, "scouting", "Recruitment focus update", "%d new player%s discovered in %s." % [after_count-before_count,"" if after_count-before_count == 1 else "s",String(focus.get("country_id", "the target nation"))])
	return updates

func _staff(world: Dictionary, staff_id: String) -> Dictionary:
	for member in world.get("staff", []):
		if String(member.get("id", "")) == staff_id: return member
	return {}

func _stable_key(text: String) -> int:
	var value := 113
	for c in text.to_utf8_buffer(): value = posmod(value * 211 + int(c), 2_147_483_647)
	return value
