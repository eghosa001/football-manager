class_name SimulationTierPolicy
extends RefCounted

const USER_LEAGUE := 1
const DETAILED_LEAGUE := 2
const BACKGROUND_LEAGUE := 3
const INACTIVE_WORLD := 4

func tier_for_fixture(world: Dictionary, home_club: Dictionary, away_club: Dictionary, managed_club_id: String, competition_id: String) -> int:
	if managed_club_id != "" and (String(home_club.get("id", "")) == managed_club_id or String(away_club.get("id", "")) == managed_club_id):
		return USER_LEAGUE
	var competition := _competition(world, competition_id)
	if not bool(competition.get("active", true)):
		return INACTIVE_WORLD
	var managed := _club(world, managed_club_id)
	var managed_country := String(managed.get("country_id", ""))
	var competition_country := String(competition.get("country_id", ""))
	if managed_country != "" and (competition_country == managed_country or String(home_club.get("country_id", "")) == managed_country or String(away_club.get("country_id", "")) == managed_country):
		return DETAILED_LEAGUE
	var detailed: Array = world.get("detailed_country_ids", [])
	if competition_country != "" and competition_country in detailed:
		return DETAILED_LEAGUE
	var active: Array = world.get("active_country_ids", [])
	if not active.is_empty() and competition_country != "" and competition_country not in active:
		return INACTIVE_WORLD
	return BACKGROUND_LEAGUE

func label(tier: int) -> String:
	match tier:
		USER_LEAGUE: return "user_full"
		DETAILED_LEAGUE: return "detailed_event"
		BACKGROUND_LEAGUE: return "background_statistical"
		INACTIVE_WORLD: return "inactive_aggregate"
		_: return "unknown"

func _competition(world: Dictionary, competition_id: String) -> Dictionary:
	for competition in world.get("competitions", []):
		if String(competition.get("id", "")) == competition_id:
			return competition
	return {}

func _club(world: Dictionary, club_id: String) -> Dictionary:
	for club in world.get("clubs", []):
		if String(club.get("id", "")) == club_id:
			return club
	return {}
