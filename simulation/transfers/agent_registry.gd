class_name AgentRegistry
extends RefCounted

const SeededRngClass = preload("res://core/rng/seeded_rng.gd")

func ensure_world(world: Dictionary) -> void:
	world["agents"] = world.get("agents", [])
	world["agent_history"] = world.get("agent_history", [])

func create_agent(world: Dictionary, id: String, name: String, seed: int) -> Dictionary:
	ensure_world(world)
	var key := _stable_key(id)
	var agent := {
		"id":id,"name":name,"clients":[],"greed":_roll(seed,key+1,35,90),"patience":_roll(seed,key+2,25,90),
		"influence":_roll(seed,key+3,20,85),"reputation":_roll(seed,key+4,20,75),"preferred_clubs":[],"club_relationships":{},
		"manager_relationships":{},"conflicts":[],"active":true
	}
	world.agents.append(agent)
	return agent

func sign_client(world: Dictionary, agent_id: String, player: Dictionary, reason: String = "representation_agreement") -> Dictionary:
	ensure_world(world)
	var agent := _agent(world.agents,agent_id)
	if agent.is_empty(): return {"ok":false,"reason_codes":["agent_missing"]}
	var old_agent := String(player.get("agent_id",""))
	if old_agent != "" and old_agent != agent_id:
		release_client(world,old_agent,String(player.get("id","")),"changed_agent")
	var player_id := String(player.get("id",""))
	if player_id not in agent.clients: agent.clients.append(player_id)
	player["agent_id"] = agent_id
	world.agent_history.append({"type":"client_signed","agent_id":agent_id,"player_id":player_id,"reason":reason,"season_year":int(world.get("season_year",2026))})
	return {"ok":true,"reason_codes":[reason]}

func release_client(world: Dictionary, agent_id: String, player_id: String, reason: String) -> void:
	ensure_world(world)
	var agent := _agent(world.agents,agent_id)
	if agent.is_empty(): return
	agent.clients.erase(player_id)
	world.agent_history.append({"type":"client_released","agent_id":agent_id,"player_id":player_id,"reason":reason,"season_year":int(world.get("season_year",2026))})

func negotiation_profile(world: Dictionary, player: Dictionary, club_id: String) -> Dictionary:
	ensure_world(world)
	var agent := _agent(world.agents,String(player.get("agent_id","")))
	if agent.is_empty(): return {"greed":50,"patience":50,"influence":25,"club_relationship":0.0,"preferred":false}
	return {
		"greed":int(agent.greed),"patience":int(agent.patience),"influence":int(agent.influence),
		"club_relationship":float(agent.club_relationships.get(club_id,0.0)),"preferred":club_id in agent.preferred_clubs,
		"reputation":int(agent.reputation)
	}

func record_negotiation(world: Dictionary, agent_id: String, club_id: String, manager_id: String, outcome: String, value: int) -> void:
	ensure_world(world)
	var agent := _agent(world.agents,agent_id)
	if agent.is_empty(): return
	var delta := 4.0 if outcome == "accepted" else (-3.0 if outcome == "rejected" else -1.0)
	agent.club_relationships[club_id] = clampf(float(agent.club_relationships.get(club_id,0.0))+delta,-100.0,100.0)
	if manager_id != "": agent.manager_relationships[manager_id] = clampf(float(agent.manager_relationships.get(manager_id,0.0))+delta*0.7,-100.0,100.0)
	world.agent_history.append({"type":"negotiation","agent_id":agent_id,"club_id":club_id,"manager_id":manager_id,"outcome":outcome,"value":value,"season_year":int(world.get("season_year",2026))})

func recruit_clients(world: Dictionary, seed: int) -> Array:
	ensure_world(world)
	var changes: Array = []
	for player in world.get("players",[]):
		if bool(player.get("retired",false)) or int(player.get("age",99)) > 32: continue
		if String(player.get("agent_id","")) != "": continue
		var best: Dictionary = {}
		var best_score := -1.0
		for agent in world.agents:
			if not bool(agent.get("active",true)): continue
			var capacity := maxi(1,30-int(agent.get("clients",[]).size()))
			var score := float(agent.get("reputation",50))*0.6+float(agent.get("influence",50))*0.4+capacity*0.3
			if score > best_score: best_score=score; best=agent
		if best.is_empty(): continue
		var chance := clampf(0.01+best_score/2000.0+float(player.get("current_ability",50))/5000.0,0.01,0.10)
		if SeededRngClass.unit_for(seed,_stable_key(String(player.get("id","")))) < chance:
			sign_client(world,String(best.id),player,"agent_recruitment")
			changes.append({"player_id":String(player.id),"agent_id":String(best.id)})
	return changes

func _agent(agents: Array, id: String) -> Dictionary:
	for agent in agents:
		if String(agent.get("id","")) == id: return agent
	return {}

func _roll(seed: int, key: int, low: int, high: int) -> int:
	return low + int(SeededRngClass.value_for(seed,key)%maxi(1,high-low+1))

func _stable_key(text: String) -> int:
	var value := 113
	for b in text.to_utf8_buffer(): value=posmod(value*167+int(b),2_147_483_647)
	return value
