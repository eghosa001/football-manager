extends SceneTree

const WorldGeneratorClass = preload("res://simulation/world/world_generator.gd")
const PlayerProfileClass = preload("res://simulation/players/player_profile.gd")
const ScoutingClass = preload("res://simulation/scouting/scouting_service.gd")
const RecruitmentClass = preload("res://simulation/scouting/recruitment_focus.gd")
const AgentClass = preload("res://simulation/transfers/agent_service.gd")
const NegotiationClass = preload("res://simulation/transfers/transfer_negotiation.gd")
const MarketClass = preload("res://simulation/transfers/transfer_market.gd")
const TrainingClass = preload("res://simulation/players/training_system.gd")
const MedicalClass = preload("res://simulation/players/medical_system.gd")
const DressingRoomClass = preload("res://simulation/players/dressing_room.gd")
const StaffMarketClass = preload("res://simulation/staff/staff_market.gd")

func _init() -> void:
	var world: Dictionary = WorldGeneratorClass.new().create_world(50505)
	var player: Dictionary = world.players[0]
	var profile = PlayerProfileClass.new()
	for p in world.players: profile.ensure(p)
	assert(player.attributes.size() >= 40)
	assert(player.hidden_attributes.size() >= 12)
	assert(String(profile.personality(player)) != "")

	var scouting = ScoutingClass.new()
	scouting.ensure_world(world)
	var report: Dictionary = scouting.player_report(world, player, 35, 42)
	assert(report.knowledge < 0.95)
	var any_range := false
	for value in report.attributes.values():
		if int(value.max) > int(value.min): any_range = true
	assert(any_range)
	world.scouting_knowledge[String(player.id)] = 1.0
	report = scouting.player_report(world, player, 100, 42)
	for value in report.attributes.values(): assert(value.exact != null)

	var club: Dictionary = world.clubs[0]
	var recruitment = RecruitmentClass.new()
	var needs: Array[String] = recruitment.squad_needs(world.players, String(club.id))
	var shortlist: Array = recruitment.shortlist(world, String(club.id), "ST", 30, 30, 10)
	assert(shortlist.size() <= 10)
	assert(needs is Array)

	var agent: Dictionary = AgentClass.new().ensure_player_agent(player, 50505)
	assert(int(agent.greed) >= 20 and int(agent.greed) <= 95)
	var demand: Dictionary = AgentClass.new().wage_demand(player, club, 5000, 50505)
	assert(int(demand.weekly_wage) > 0)

	var target: Dictionary = _player_from_other_club(world, String(world.clubs[1].id))
	profile.ensure(target)
	var buyer: Dictionary = world.clubs[0]
	var negotiation = NegotiationClass.new()
	var market = MarketClass.new()
	var value := market.player_value(target, int(world.get("season_year", 2026)))
	var plain: Dictionary = negotiation.create_offer(world, target, buyer, int(value * 0.70), {})
	var structured: Dictionary = negotiation.create_offer(world, target, buyer, int(value * 0.70), {"sell_on_percentage":25,"installment_fee":int(value*0.18),"installments":3,"appearance_bonus":int(value*0.04)})
	negotiation.evaluate_offer(world, plain, 50505)
	negotiation.evaluate_offer(world, structured, 50505)
	assert(int(structured.effective_value) > int(plain.effective_value))
	assert(int(structured.clauses.sell_on_percentage) == 25)
	assert(int(structured.clauses.installments) == 3)
	assert(negotiation.player_interest(target, buyer, AgentClass.new().ensure_player_agent(target, 50505)) >= 0.0)

	var loan_target: Dictionary = _player_from_other_club(world, String(world.clubs[2].id))
	var parent_id := String(loan_target.club_id)
	buyer.transfer_budget = maxi(int(buyer.get("transfer_budget", 0)), 10_000_000)
	var loan_error := market.execute_loan(world, String(loan_target.id), String(buyer.id), 100_000, int(world.get("season_year", 2026)), 60, 1_500_000, 1)
	assert(loan_error == OK)
	assert(String(loan_target.club_id) == String(buyer.id))
	assert(String(loan_target.loan_parent_club_id) == parent_id)
	assert(int(loan_target.loan_wage_contribution) == 60)
	assert(int(loan_target.loan_option_fee) == 1_500_000)

	for c in world.clubs:
		c["training_facilities"] = 60
	var training_system = TrainingClass.new()
	var focus_player: Dictionary = _player_for_club(world, String(club.id))
	assert(training_system.set_individual_focus(focus_player, "technique") == OK)
	assert(String(focus_player.individual_training_focus) == "technique")
	assert(training_system.set_individual_focus(focus_player, "invalid") == ERR_INVALID_PARAMETER)
	var before_technique := int(focus_player.attributes.get("technique", 50))
	var improved_focus := false
	for week in range(80):
		var training: Dictionary = training_system.run_week(world, String(club.id), 50505 + week)
		assert(not training.has("error"))
		assert(int(training.fatigue_added) >= 0)
		if int(focus_player.attributes.get("technique", 50)) > before_technique:
			improved_focus = true
			break
	assert(improved_focus or int(focus_player.attributes.get("technique", 50)) == 100)

	var medical = MedicalClass.new()
	var injury: Dictionary = medical.suffer_injury(player, 50505, "test")
	assert(int(injury.days_total) > 0)
	assert(not bool(medical.availability(player).available))
	for i in range(400):
		medical.advance_day(player, 90, 1.0)
		if bool(medical.availability(player).available): break
	assert(bool(medical.availability(player).available))

	var room: Dictionary = DressingRoomClass.new().rebuild(world, String(club.id))
	assert(room.has("leaders"))
	assert(float(room.atmosphere) >= 0.0 and float(room.atmosphere) <= 100.0)

	var staff_market = StaffMarketClass.new()
	for member in world.staff: staff_market.ensure_staff_attributes(member, 50505)
	assert(world.staff.is_empty() or world.staff[0].has("staff_attributes"))
	print("[TEST] PLAYER/SCOUTING/TRANSFERS PASS")
	quit(0)

func _player_from_other_club(world: Dictionary, club_id: String) -> Dictionary:
	for candidate in world.players:
		if String(candidate.get("club_id", "")) == club_id and not bool(candidate.get("retired", false)):
			return candidate
	return {}

func _player_for_club(world: Dictionary, club_id: String) -> Dictionary:
	for candidate in world.players:
		if String(candidate.get("club_id", "")) == club_id and not bool(candidate.get("retired", false)):
			return candidate
	return {}
