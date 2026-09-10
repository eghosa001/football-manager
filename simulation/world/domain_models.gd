class_name DomainModels
extends RefCounted

static func country(id: String, name: String, code: String, youth_rating: int) -> Dictionary:
	return {
		"id": id,
		"name": name,
		"code": code,
		"youth_rating": youth_rating,
	}

static func club(id: String, country_id: String, name: String, reputation: int) -> Dictionary:
	return {
		"id": id,
		"country_id": country_id,
		"name": name,
		"reputation": reputation,
		"cash": 5_000_000,
	}

static func player(id: String, club_id: String, first_name: String, last_name: String, age: int, position: String, current_ability: int, potential: int) -> Dictionary:
	return {
		"id": id,
		"club_id": club_id,
		"first_name": first_name,
		"last_name": last_name,
		"age": age,
		"position": position,
		"current_ability": current_ability,
		"potential": potential,
		"fitness": 100,
		"morale": 70,
		"retired": false,
	}

static func staff(id: String, club_id: String, name: String, role: String, ability: int) -> Dictionary:
	return {
		"id": id,
		"club_id": club_id,
		"name": name,
		"role": role,
		"ability": ability,
	}

static func competition(id: String, country_id: String, name: String, club_ids: Array) -> Dictionary:
	return {
		"id": id,
		"country_id": country_id,
		"name": name,
		"club_ids": club_ids.duplicate(),
		"points_win": 3,
		"points_draw": 1,
		"tie_breakers": ["points", "goal_difference", "goals_scored", "wins"],
	}

static func contract(id: String, player_id: String, club_id: String, start_year: int, end_year: int, weekly_wage: int) -> Dictionary:
	return {
		"id": id,
		"player_id": player_id,
		"club_id": club_id,
		"start_year": start_year,
		"end_year": end_year,
		"weekly_wage": weekly_wage,
	}

static func fixture(id: String, competition_id: String, round_number: int, home_club_id: String, away_club_id: String) -> Dictionary:
	return {
		"id": id,
		"competition_id": competition_id,
		"round": round_number,
		"home_club_id": home_club_id,
		"away_club_id": away_club_id,
		"played": false,
		"home_goals": 0,
		"away_goals": 0,
	}
