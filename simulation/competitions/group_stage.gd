class_name GroupStage
extends RefCounted

const LeagueTableClass = preload("res://simulation/competitions/league_table.gd")

func seed_groups(club_ids: Array, group_count: int = 8) -> Array:
	var count: int = maxi(1, group_count)
	var groups: Array = []
	for i in range(count): groups.append([])
	var ordered: Array = club_ids.duplicate(); ordered.sort()
	for i in range(ordered.size()): groups[i % count].append(ordered[i])
	return groups

func fixtures_for_groups(groups: Array, competition_id: String) -> Array:
	var fixtures: Array = []; var fixture_index: int = 1
	for group_index in range(groups.size()):
		var clubs: Array = groups[group_index]
		for i in range(clubs.size()):
			for j in range(i + 1, clubs.size()):
				for leg in range(2):
					var home: String = String(clubs[i]) if leg == 0 else String(clubs[j])
					var away: String = String(clubs[j]) if leg == 0 else String(clubs[i])
					fixtures.append({"id":"%s-g%d-f%d" % [competition_id,group_index+1,fixture_index],"competition_id":competition_id,"group":group_index+1,"round":fixture_index,"home_club_id":home,"away_club_id":away,"played":false,"home_goals":0,"away_goals":0})
					fixture_index += 1
	return fixtures

func qualifiers(groups: Array, fixtures: Array, per_group: int = 2) -> Array:
	var result: Array = []
	for group_index in range(groups.size()):
		var group_fixtures: Array = []
		for fixture in fixtures:
			if int(fixture.get("group",0)) == group_index + 1: group_fixtures.append(fixture)
		var table: Array = LeagueTableClass.build(groups[group_index], group_fixtures, 3, 1)
		for i in range(mini(per_group, table.size())): result.append(String(table[i].club_id))
	return result
