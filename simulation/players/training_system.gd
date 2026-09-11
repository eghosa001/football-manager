class_name TrainingSystem
extends RefCounted

const SeededRngClass = preload("res://core/rng/seeded_rng.gd")
const TrainingDepthClass = preload("res://simulation/players/training_depth.gd")

const SESSIONS := ["recovery","physical","technical","attacking","defending","possession","tactical","set_piece","match_preparation","rest"]
const LEGACY_ALIASES := {"set_pieces":"set_piece","match_prep":"match_preparation"}
const FAMILIARITY_AXES := ["formation","role","tempo","pressing","defensive_shape","passing_style","set_pieces"]

func ensure_club(club: Dictionary) -> void:
	var existing: Array = club.get("training_schedule", ["recovery","technical","tactical","physical","set_piece","match_preparation","rest"])
	var migrated: Array = []
	for value in existing:
		var session := String(value)
		migrated.append(String(LEGACY_ALIASES.get(session, session)))
	if migrated.size() != 7:
		migrated = ["recovery","technical","tactical","physical","set_piece","match_preparation","rest"]
	club["training_schedule"] = migrated
	club["training_intensity"] = clampf(float(club.get("training_intensity",0.65)),0.15,1.0)
	if club.has("tactic"):
		var familiarity: Dictionary = club.tactic.get("familiarity_axes",{})
		var legacy := float(club.tactic.get("familiarity",50.0))
		for axis in FAMILIARITY_AXES: familiarity[axis] = clampf(float(familiarity.get(axis,legacy)),0.0,100.0)
		club.tactic["familiarity_axes"] = familiarity
		club.tactic["familiarity"] = _familiarity_average(familiarity)

func run_week(world: Dictionary, club_id: String, seed: int) -> Dictionary:
	var club := _club(world.get("clubs", []), club_id)
	if club.is_empty():
		return {"error":ERR_DOES_NOT_EXIST}
	ensure_club(club)
	var improved := 0
	var fatigue_added := 0
	var injuries := 0
	var individual_focus_gains := 0
	var learned_traits: Array = []
	var ceiling_changes := 0
	var coaching := _coaching_quality(world.get("staff", []), club_id)
	var facilities := float(club.get("training_facilities", 50))
	var mix := _session_mix(club.training_schedule)
	var work_days := int(mix.work_days)
	var recovery_days := int(mix.recovery_days)
	var development_multiplier := float(mix.development)
	var workload_multiplier := float(mix.workload)
	var morale_delta := int(mix.morale_delta)
	var depth = TrainingDepthClass.new()
	for player in world.get("players", []):
		if String(player.get("club_id", "")) != club_id or bool(player.get("retired", false)):
			continue
		depth.ensure_player(player)
		_ensure_development_state(player)
		if int(player.get("injured_days",0)) > 0:
			_update_development_trajectory(player,club,coaching,facilities,0.0,seed)
			continue
		var intensity := float(club.training_intensity)
		var professionalism := float(player.get("hidden_attributes", {}).get("professionalism", 50))
		var ceiling_before := int(player.development_ceiling)
		_update_development_trajectory(player,club,coaching,facilities,intensity,seed)
		if int(player.development_ceiling) != ceiling_before: ceiling_changes += 1
		var potential_gap := maxi(0, int(player.development_ceiling) - int(player.get("current_ability", 50)))
		var age := int(player.get("age", 25))
		var age_factor := 1.0 if age <= 21 else (0.75 if age <= 25 else (0.35 if age <= 29 else 0.12))
		var trajectory_factor := clampf(0.75+float(player.get("development_trajectory",0.5))*0.5,0.65,1.25)
		var development_score := potential_gap * 0.02 * age_factor * (0.6 + coaching / 125.0) * (0.7 + facilities / 170.0) * (0.7 + professionalism / 170.0) * intensity * development_multiplier * trajectory_factor
		var gain := clampi(int(floor(development_score * float(work_days) / 5.0 / 3.0)),0,2)
		if gain > 0:
			player.current_ability = mini(int(player.development_ceiling),int(player.get("current_ability",50))+gain)
			_apply_session_attribute_bias(player,mix,gain)
			improved += 1
		var individual := depth.apply_week(player,work_days,coaching,facilities,seed+_stable_key(String(player.get("id",""))))
		individual_focus_gains += int(individual.get("focus_gain",0))
		if String(individual.get("learned_trait","")) != "":
			learned_traits.append({"player_id":String(player.get("id","")),"trait":String(individual.learned_trait)})
		var fatigue := maxi(0,int(round(intensity*float(work_days)*2.0*workload_multiplier))-recovery_days*2)
		if work_days == 0:
			player.fitness = mini(100,int(player.get("fitness",100))+recovery_days*2)
		player.fitness = clampi(int(player.get("fitness",100))-fatigue,45,100)
		player.morale = clampi(int(player.get("morale",65))+morale_delta,0,100)
		fatigue_added += fatigue
		var injury_proneness := int(player.get("hidden_attributes", {}).get("injury_proneness",50))
		var prior_injuries := mini(12,player.get("injury_history",[]).size())
		var injury_risk := clampf((0.004+intensity*0.012+injury_proneness/10000.0+prior_injuries/5000.0-facilities/20000.0)*workload_multiplier,0.002,0.065)
		var key := _stable_key(String(player.get("id","")))
		if work_days > 0 and SeededRngClass.unit_for(seed,key) < injury_risk*float(work_days)/5.0:
			player.injured_days = maxi(int(player.get("injured_days",0)),5+int(SeededRngClass.value_for(seed,key+7)%24))
			injuries += 1
	_apply_tactical_familiarity(club,mix,float(club.training_intensity))
	return {"players_improved":improved,"individual_focus_gains":individual_focus_gains,"learned_traits":learned_traits,"fatigue_added":fatigue_added,"training_injuries":injuries,"ceiling_changes":ceiling_changes,"coaching_quality":coaching,"session_mix":mix.duplicate(true),"tactical_familiarity":float(club.get("tactic",{}).get("familiarity",0.0)),"familiarity_axes":club.get("tactic",{}).get("familiarity_axes",{}).duplicate(true)}

func set_schedule(club: Dictionary, sessions: Array, intensity: float) -> Error:
	if sessions.size() != 7 or not is_finite(intensity):
		return ERR_INVALID_PARAMETER
	var normalized: Array = []
	for raw in sessions:
		var session := String(LEGACY_ALIASES.get(String(raw),String(raw)))
		if session not in SESSIONS:
			return ERR_INVALID_PARAMETER
		normalized.append(session)
	club["training_schedule"] = normalized
	club["training_intensity"] = clampf(intensity,0.15,1.0)
	return OK

func _session_mix(sessions: Array) -> Dictionary:
	var counts := {}
	for session in SESSIONS:
		counts[session] = 0
	for raw in sessions:
		var session := String(LEGACY_ALIASES.get(String(raw),String(raw)))
		if counts.has(session): counts[session] = int(counts[session])+1
	var recovery_days := int(counts.recovery)+int(counts.rest)
	var work_days := sessions.size()-recovery_days
	var development := 1.0 + float(counts.technical+counts.attacking+counts.defending+counts.possession+counts.tactical)*0.045 + float(counts.physical)*0.025
	var workload := 1.0 + float(counts.physical)*0.14 + float(counts.attacking+counts.defending)*0.05 - float(recovery_days)*0.055
	var morale_delta := int(counts.rest)+int(counts.recovery)-maxi(0,int(counts.physical)-1)
	return {"counts":counts,"work_days":work_days,"recovery_days":recovery_days,"development":clampf(development,0.8,1.45),"workload":clampf(workload,0.65,1.55),"morale_delta":clampi(morale_delta,-3,3)}

func _apply_session_attribute_bias(player: Dictionary, mix: Dictionary, gain: int) -> void:
	if gain <= 0: return
	var attrs: Dictionary = player.get("attributes",{})
	if attrs.is_empty(): return
	var counts: Dictionary = mix.counts
	var targets: Array = []
	if int(counts.attacking)>0: targets.append_array(["finishing","off_the_ball","composure","dribbling"])
	if int(counts.defending)>0: targets.append_array(["tackling","marking","positioning","concentration"])
	if int(counts.possession)>0: targets.append_array(["passing","first_touch","vision","decisions"])
	if int(counts.technical)>0: targets.append_array(["technique","passing","dribbling","first_touch"])
	if int(counts.physical)>0: targets.append_array(["pace","acceleration","stamina","strength","agility"])
	if int(counts.set_piece)>0: targets.append_array(["set_pieces","crossing","penalties"])
	for name in targets:
		if attrs.has(String(name)): attrs[String(name)] = clampi(int(attrs[String(name)])+1,1,100)
	player["attributes"] = attrs

func _apply_tactical_familiarity(club: Dictionary, mix: Dictionary, intensity: float) -> void:
	if not club.has("tactic"): return
	var familiarity: Dictionary = club.tactic.get("familiarity_axes",{})
	var counts: Dictionary = mix.counts
	var axis_gain := {
		"formation":float(counts.tactical+counts.match_preparation)*0.55,
		"role":float(counts.tactical+counts.match_preparation)*0.45,
		"tempo":float(counts.possession+counts.match_preparation)*0.35,
		"pressing":float(counts.defending+counts.physical+counts.tactical)*0.28,
		"defensive_shape":float(counts.defending+counts.tactical)*0.42,
		"passing_style":float(counts.possession+counts.technical)*0.42,
		"set_pieces":float(counts.set_piece)*0.85
	}
	for axis in FAMILIARITY_AXES:
		familiarity[axis] = clampf(float(familiarity.get(axis,50.0))+float(axis_gain.get(axis,0.0))*intensity,0.0,100.0)
	club.tactic["familiarity_axes"] = familiarity
	club.tactic["familiarity"] = _familiarity_average(familiarity)

func _ensure_development_state(player: Dictionary) -> void:
	var base := int(player.get("potential",player.get("current_ability",50)))
	player["base_potential"] = int(player.get("base_potential",base))
	player["development_ceiling"] = clampi(int(player.get("development_ceiling",base)),int(player.get("current_ability",1)),100)
	player["development_trajectory"] = clampf(float(player.get("development_trajectory",0.5)),0.0,1.0)
	player["development_momentum"] = clampf(float(player.get("development_momentum",0.0)),-1.0,1.0)

func _update_development_trajectory(player: Dictionary, club: Dictionary, coaching: float, facilities: float, intensity: float, seed: int) -> void:
	var age := int(player.get("age",25))
	var hidden: Dictionary = player.get("hidden_attributes",{})
	var professionalism := float(hidden.get("professionalism",50))/100.0
	var determination := float(hidden.get("determination",50))/100.0
	var appearances := float(player.get("season_appearances",0))
	var morale := float(player.get("morale",65))/100.0
	var injury_days := float(player.get("injured_days",0))
	var environment := clampf((coaching+facilities)/200.0,0.2,1.0)
	var minutes_proxy := clampf(appearances/25.0,0.0,1.0)
	var youth_factor := 1.0 if age<=21 else (0.7 if age<=25 else 0.25)
	var injury_penalty := clampf(injury_days/120.0,0.0,0.5)
	var target := clampf(0.18+professionalism*0.20+determination*0.14+environment*0.18+minutes_proxy*0.12+morale*0.10+intensity*0.08-injury_penalty,0.0,1.0)
	player.development_trajectory = lerpf(float(player.development_trajectory),target,0.10)
	player.development_momentum = clampf(float(player.development_momentum)*0.75+(target-0.5)*0.25,-1.0,1.0)
	var key := _stable_key(String(player.get("id","")))+int(player.get("career_seasons",0))*911
	var variance := float(int(SeededRngClass.value_for(seed,key)%5)-2)
	var ceiling_shift := 0
	if youth_factor>0.5 and float(player.development_momentum)>0.18 and variance>0.0: ceiling_shift = 1
	elif (injury_penalty>0.25 or float(player.development_momentum)<-0.28) and variance<0.0: ceiling_shift = -1
	var base := int(player.get("base_potential",player.get("potential",50)))
	player.development_ceiling = clampi(int(player.development_ceiling)+ceiling_shift,maxi(int(player.get("current_ability",1)),base-12),mini(100,base+8))

func _familiarity_average(familiarity: Dictionary) -> float:
	var total := 0.0
	for axis in FAMILIARITY_AXES: total += float(familiarity.get(axis,50.0))
	return total/float(FAMILIARITY_AXES.size())

func _coaching_quality(staff: Array, club_id: String) -> float:
	var total := 0.0
	var count := 0
	for member in staff:
		if String(member.get("club_id", "")) == club_id and String(member.get("role", "")) in ["coach","assistant_manager","assistant","manager"]:
			total += float(member.get("ability", 50)); count += 1
	return total/maxf(float(count),1.0)

func _club(clubs: Array, id: String) -> Dictionary:
	for club in clubs:
		if String(club.get("id", "")) == id: return club
	return {}

func _stable_key(text: String) -> int:
	var value := 47
	for character in text.to_utf8_buffer(): value = posmod(value*151+int(character),2_147_483_647)
	return value
