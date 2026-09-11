class_name LivingWorld
extends RefCounted

const SeededRngClass = preload("res://core/rng/seeded_rng.gd")

func ensure_world(world: Dictionary) -> void:
	world["relationships"] = world.get("relationships", [])
	world["rivalries"] = world.get("rivalries", [])
	world["awards"] = world.get("awards", [])
	world["legends"] = world.get("legends", [])
	world["news"] = world.get("news", [])
	world["manager_careers"] = world.get("manager_careers", [])
	for player in world.players:
		player["morale"] = clampi(int(player.get("morale", 65)), 0, 100)
		player["confidence"] = clampi(int(player.get("confidence", 60)), 0, 100)
		player["happiness"] = clampi(int(player.get("happiness", 65)), 0, 100)
		player["reputation"] = clampi(int(player.get("reputation", player.get("current_ability", 50))), 1, 100)
	for club in world.clubs:
		club["reputation"] = clampi(int(club.get("reputation", 50)), 1, 100)
	for member in world.staff:
		member["reputation"] = clampi(int(member.get("reputation", member.get("ability", 50))), 1, 100)
		if String(member.get("role", "")) == "manager":
			_ensure_manager_career(world, member)

func advance_year(world: Dictionary, season_records: Array, seed: int) -> Dictionary:
	ensure_world(world)
	var year: int = int(world.get("season_year", 2026)) - 1
	var reasons: Array = []
	_update_player_state(world, seed, year, reasons)
	_update_relationships(world, seed, year, reasons)
	_update_rivalries(world, season_records, year, reasons)
	_update_reputations(world, season_records, year, reasons)
	_update_manager_careers(world, season_records, year, reasons)
	var award_count := _create_awards(world, season_records, year, reasons)
	var legend_count := _update_legends(world, year, reasons)
	_emit_news(world, reasons, year)
	return {"year": year,"relationships": world.relationships.size(),"rivalries": world.rivalries.size(),"awards_created": award_count,"legends": legend_count,"reasons": reasons}

func relationship(world: Dictionary, source_id: String, target_id: String, relation_type: String = "respect") -> Dictionary:
	for item in world.get("relationships", []):
		if typeof(item) != TYPE_DICTIONARY: continue
		if String(item.get("source_person_id", "")) == source_id and String(item.get("target_person_id", "")) == target_id and String(item.get("relationship_type", "")) == relation_type: return item
	return {}

func _update_player_state(world: Dictionary, seed: int, year: int, reasons: Array) -> void:
	for index in range(world.players.size()):
		var player: Dictionary = world.players[index]
		if bool(player.get("retired", false)): continue
		var ability: int = int(player.get("current_ability", 50)); var club_rep: int = _club_reputation(world.clubs, String(player.get("club_id", ""))); var noise: int = int(SeededRngClass.value_for(seed, 1_000_000 + index + year * 31) % 7) - 3
		var morale_target: int = clampi(50 + int((club_rep - 50) * 0.35) + noise, 25, 90); var old_morale: int = int(player.morale)
		player.morale = clampi(old_morale + clampi(morale_target - old_morale, -4, 4), 0, 100)
		player.confidence = clampi(int(player.confidence) + clampi(int((ability - 50) / 12) + noise, -3, 3), 0, 100)
		player.happiness = clampi(int(round(float(player.happiness) * 0.85 + float(player.morale) * 0.15)), 0, 100)
		if abs(int(player.morale) - old_morale) >= 3: reasons.append({"type": "morale_change", "entity_id": player.id, "delta": int(player.morale) - old_morale, "cause": "club_environment"})

func _update_relationships(world: Dictionary, seed: int, year: int, reasons: Array) -> void:
	var by_club := {}
	for player in world.players:
		if bool(player.get("retired", false)): continue
		var club_id: String = String(player.get("club_id", ""))
		if club_id == "": continue
		if not by_club.has(club_id): by_club[club_id] = []
		by_club[club_id].append(player)
	for club_id in by_club.keys():
		var squad: Array = by_club[club_id]
		for i in range(mini(squad.size(), 8)):
			if squad.size() < 2: break
			var j: int = (i + 1 + int(SeededRngClass.value_for(seed, year * 1000 + i) % maxi(1, squad.size() - 1))) % squad.size()
			if i == j: continue
			var a: Dictionary = squad[i]; var b: Dictionary = squad[j]; var existing: Dictionary = relationship(world, String(a.id), String(b.id), "respect"); var delta: int = 1 + int((int(a.get("morale", 50)) + int(b.get("morale", 50))) / 80)
			if existing.is_empty(): world.relationships.append({"source_person_id": a.id, "target_person_id": b.id, "relationship_type": "respect", "strength": clampi(delta * 2, -100, 100), "last_changed": year})
			else: existing.strength = clampi(int(existing.strength) + delta, -100, 100); existing.last_changed = year
	for item in world.relationships:
		if int(item.get("last_changed", year)) < year:
			var strength: int = int(item.get("strength", 0)); item.strength = strength - signi(strength)
		reasons.append({"type": "relationship_tick", "count": world.relationships.size(), "cause": "shared_club_time_and_decay"})

func _update_rivalries(world: Dictionary, records: Array, year: int, reasons: Array) -> void:
	for record in records:
		var table: Array = record.get("table", [])
		if table.size() < 2: continue
		var first_id: String = String(table[0].club_id); var second_id: String = String(table[1].club_id); var rivalry: Dictionary = _find_pair(world.rivalries, first_id, second_id)
		if rivalry.is_empty(): world.rivalries.append({"club_a": first_id, "club_b": second_id, "intensity": 12, "last_changed": year})
		else: rivalry.intensity = clampi(int(rivalry.intensity) + 4, 0, 100); rivalry.last_changed = year
	for rivalry in world.rivalries:
		if int(rivalry.get("last_changed", year)) < year: rivalry.intensity = maxi(0, int(rivalry.intensity) - 1)
	world.rivalries = world.rivalries.filter(func(r): return int(r.intensity) > 0)
	if not records.is_empty(): reasons.append({"type": "rivalry_change", "count": world.rivalries.size(), "cause": "title_races"})

func _update_reputations(world: Dictionary, records: Array, year: int, reasons: Array) -> void:
	var positions := {}
	for record in records:
		var table: Array = record.get("table", [])
		for i in range(table.size()): positions[String(table[i].club_id)] = {"position": i + 1, "size": table.size()}
	for club in world.clubs:
		var old_rep: int = int(club.reputation)
		if positions.has(String(club.id)):
			var p: Dictionary = positions[String(club.id)]; var position: int = int(p.position); var size: int = int(p.size); var delta := 0
			if position <= maxi(1, int(size / 5.0)): delta = 2
			elif position > int(size * 0.8): delta = -2
			club.reputation = clampi(old_rep + delta, 10, 95)
		if int(club.reputation) != old_rep: reasons.append({"type": "club_reputation", "entity_id": club.id, "delta": int(club.reputation) - old_rep, "cause": "league_finish"})
	for player in world.players:
		if bool(player.get("retired", false)): continue
		var target: int = clampi(int(float(player.get("current_ability", 50)) * 0.7 + float(_club_reputation(world.clubs, String(player.get("club_id", "")))) * 0.3), 1, 100)
		player.reputation = clampi(int(player.reputation) + clampi(target - int(player.reputation), -2, 2), 1, 100)

func _update_manager_careers(world: Dictionary, records: Array, year: int, reasons: Array) -> void:
	var champion_ids := {}
	for record in records:
		var champion_id: String = String(record.get("champion_club_id", ""))
		if champion_id != "": champion_ids[champion_id] = true
	for member in world.staff:
		if String(member.get("role", "")) != "manager": continue
		_ensure_manager_career(world, member); var career: Dictionary = _manager_career(world, String(member.id)); career.seasons = int(career.get("seasons", 0)) + 1
		if champion_ids.has(String(member.get("club_id", ""))):
			career.trophies = int(career.get("trophies", 0)) + 1; member.reputation = clampi(int(member.reputation) + 3, 1, 100); reasons.append({"type": "manager_trophy", "entity_id": member.id, "club_id": member.club_id, "cause": "competition_champion"})

func _create_awards(world: Dictionary, records: Array, year: int, reasons: Array) -> int:
	var created := 0
	for record in records:
		var competition_id: String = String(record.get("competition_id", "")); var champion_id: String = String(record.get("champion_club_id", ""))
		if champion_id != "": world.awards.append({"id": "award-%d-%s-champion" % [year, competition_id], "year": year, "type": "champion", "competition_id": competition_id, "winner_id": champion_id}); created += 1
		var best: Dictionary = _best_player_for_competition(world, record)
		if not best.is_empty(): world.awards.append({"id": "award-%d-%s-player" % [year, competition_id], "year": year, "type": "player_of_year", "competition_id": competition_id, "winner_id": best.id}); created += 1
	if created > 0: reasons.append({"type": "awards", "count": created, "cause": "season_completion"})
	return created

func _update_legends(world: Dictionary, year: int, reasons: Array) -> int:
	var existing := {}
	for legend in world.legends: existing[String(legend.person_id)] = true
	for player in world.players:
		if not bool(player.get("retired", false)): continue
		var rep: int = int(player.get("reputation", player.get("current_ability", 0)))
		if rep >= 75 and not existing.has(String(player.id)):
			world.legends.append({"person_id": player.id, "name": "%s %s" % [player.first_name, player.last_name], "club_id": player.get("club_id", ""), "inducted_year": year, "reputation": rep}); existing[String(player.id)] = true
	if not world.legends.is_empty(): reasons.append({"type": "legends", "count": world.legends.size(), "cause": "retired_high_reputation_players"})
	return world.legends.size()

func _emit_news(world: Dictionary, reasons: Array, year: int) -> void:
	for index in range(mini(reasons.size(), 50)):
		var reason: Dictionary = reasons[index]; world.news.append({"id": "news-%d-%d-%s" % [year, index, String(reason.get("type", "event"))], "year": year, "type": reason.get("type", "event"), "reason": reason.duplicate(true)})
	if world.news.size() > 500: world.news = world.news.slice(world.news.size() - 500)

func _best_player_for_competition(world: Dictionary, record: Dictionary) -> Dictionary:
	var club_ids := {}
	for row in record.get("table", []): club_ids[String(row.club_id)] = true
	var best: Dictionary = {}
	for player in world.players:
		if bool(player.get("retired", false)) or not club_ids.has(String(player.get("club_id", ""))): continue
		if best.is_empty() or int(player.get("reputation", 0)) > int(best.get("reputation", 0)) or (int(player.get("reputation", 0)) == int(best.get("reputation", 0)) and String(player.id) < String(best.id)): best = player
	return best

func _ensure_manager_career(world: Dictionary, member: Dictionary) -> void:
	if _manager_career(world, String(member.id)).is_empty(): world.manager_careers.append({"manager_id": member.id, "current_club_id": member.get("club_id", ""), "seasons": 0, "trophies": 0, "clubs": [member.get("club_id", "")]})
func _manager_career(world: Dictionary, manager_id: String) -> Dictionary:
	for career in world.get("manager_careers", []):
		if String(career.manager_id) == manager_id: return career
	return {}
func _find_pair(values: Array, a: String, b: String) -> Dictionary:
	for value in values:
		if (String(value.club_a) == a and String(value.club_b) == b) or (String(value.club_a) == b and String(value.club_b) == a): return value
	return {}
func _club_reputation(clubs: Array, club_id: String) -> int:
	for club in clubs:
		if String(club.id) == club_id: return int(club.get("reputation", 50))
	return 50
