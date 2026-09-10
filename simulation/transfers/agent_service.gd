class_name AgentService
extends RefCounted

const SeededRngClass = preload("res://core/rng/seeded_rng.gd")

func ensure_player_agent(player: Dictionary, seed: int) -> Dictionary:
	if player.has("agent"):
		return player.agent
	var key := _stable_key(String(player.get("id", "player")))
	var agent := {
		"id":"agent-%s" % String(player.get("id", "unknown")),
		"greed":_rand(seed,key+1,20,95),
		"patience":_rand(seed,key+2,20,95),
		"influence":_rand(seed,key+3,10,90),
		"club_relationships":{}
	}
	player["agent"] = agent
	return agent

func wage_demand(player: Dictionary, club: Dictionary, base_wage: int, seed: int) -> Dictionary:
	var agent := ensure_player_agent(player, seed)
	var relationship: int = int(agent.club_relationships.get(String(club.get("id", "")), 0))
	var happiness: int = int(player.get("happiness", player.get("morale", 50)))
	var ambition: int = int(player.get("hidden_attributes", {}).get("ambition", 50))
	var multiplier := 1.0
	multiplier += (int(agent.greed) - 50) / 250.0
	multiplier += ambition / 500.0
	multiplier -= relationship / 500.0
	multiplier -= (happiness - 50) / 1000.0
	var target := maxi(250, int(round(base_wage * clampf(multiplier, 0.75, 1.65))))
	return {"weekly_wage":target,"signing_bonus":int(target * (2 + int(agent.greed) / 30)),"agent_fee":int(target * int(agent.influence) / 25),"years_preferred":clampi(2 + int(agent.patience) / 35, 2, 5)}

func evaluate_offer(player: Dictionary, club: Dictionary, offered_wage: int, signing_bonus: int, years: int, seed: int) -> Dictionary:
	var base := maxi(500, int(player.get("current_ability", 50)) * int(player.get("current_ability", 50)) * 5)
	var demand := wage_demand(player, club, base, seed)
	var score := 0.0
	score += float(offered_wage) / maxf(float(demand.weekly_wage), 1.0) * 60.0
	score += float(signing_bonus) / maxf(float(demand.signing_bonus), 1.0) * 20.0
	score += 20.0 - absf(float(years - int(demand.years_preferred))) * 5.0
	return {"accepted":score >= 95.0,"score":score,"demand":demand}

func _rand(seed: int, key: int, lo: int, hi: int) -> int:
	return lo + int(SeededRngClass.value_for(seed, key) % (hi - lo + 1))

func _stable_key(text: String) -> int:
	var value := 31
	for character in text.to_utf8_buffer():
		value = posmod(value * 149 + int(character), 2_147_483_647)
	return value
