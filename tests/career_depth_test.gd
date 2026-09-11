extends SceneTree

const TwoLegClass = preload("res://simulation/competitions/knockout_two_leg.gd")
const NegotiationClass = preload("res://simulation/transfers/negotiation_depth.gd")
const RecruitmentClass = preload("res://simulation/scouting/recruitment_workflow.gd")
const TrainingDepthClass = preload("res://simulation/players/training_depth.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	# Two-legged ties: aggregate + away goals + seeded draw determinism.
	var two_leg = TwoLegClass.new()
	var pairs_a: Array = two_leg.seeded_draw(["A", "B", "C", "D"], 4242, {"A": 90.0, "B": 80.0, "C": 40.0, "D": 30.0})
	var pairs_b: Array = two_leg.seeded_draw(["A", "B", "C", "D"], 4242, {"A": 90.0, "B": 80.0, "C": 40.0, "D": 30.0})
	assert(var_to_str(pairs_a) == var_to_str(pairs_b))
	assert(pairs_a.size() == 2)
	var decided: Dictionary = two_leg.resolve_tie("A", "B", {"home_goals": 2, "away_goals": 1}, {"home_goals": 1, "away_goals": 1}, true)
	assert(String(decided.winner) == "A")
	var away_win: Dictionary = two_leg.resolve_tie("A", "B", {"home_goals": 2, "away_goals": 1}, {"home_goals": 1, "away_goals": 0}, true)
	assert(String(away_win.winner) == "B" and String(away_win.decided) == "away_goals")

	# Structured negotiation: cash beats instalments; competition inflates price.
	var neg = NegotiationClass.new()
	var offer := neg.structured_offer(10_000_000, 1, 0.10, 500_000, 0)
	var instalment := neg.structured_offer(10_000_000, 5, 0.10, 500_000, 0)
	var player := {"id": "p1", "market_value": 9_000_000, "hidden_attributes": {"greed": 60}}
	var seller := {"id": "s1", "cash": 5_000_000}
	var cash_eval: Dictionary = neg.evaluate_structured({}, player, seller, offer, 0, 777, false)
	var inst_eval: Dictionary = neg.evaluate_structured({}, player, seller, instalment, 0, 777, false)
	assert(float(cash_eval.package) > float(inst_eval.package))
	var contested: Dictionary = neg.evaluate_structured({}, player, seller, offer, 3, 777, true)
	assert(int(contested.required) >= int(cash_eval.required))
	assert(neg.agent_fee(player, 10_000_000) > 0)

	# Recruitment: knowledge grows, uncertainty shrinks, shortlist dedupes.
	var rec = RecruitmentClass.new()
	var assignment := rec.create_assignment("scout1", "West Africa", 4, "youth")
	for i in range(4):
		rec.progress_assignment(assignment, 70.0)
	assert(float(assignment.knowledge) > 0.5)
	var early: Dictionary = rec.revealed_ability(70.0, 0.1, 99, "p9")
	var late: Dictionary = rec.revealed_ability(70.0, 0.95, 99, "p9")
	assert(float(late.uncertainty) < float(early.uncertainty))
	var shortlist: Array = []
	rec.shortlist_add(shortlist, "p9", " pacy winger")
	rec.shortlist_add(shortlist, "p9", "duplicate")
	assert(shortlist.size() == 1)

	# Training depth: focus, role, mentoring, risk bands.
	var depth = TrainingDepthClass.new()
	var trainee := {"id": "t1", "fitness": 92, "hidden_attributes": {"injury_proneness": 30}}
	assert(depth.set_individual_focus(trainee, "finishing", 0.8) == OK)
	assert(depth.set_individual_focus(trainee, "flying", 0.5) == ERR_INVALID_PARAMETER)
	depth.train_role(trainee, "poacher", 5)
	assert(float((trainee.role_familiarity as Dictionary).poacher) > 20.0)
	var youth := {"id": "y1"}
	depth.mentor({"hidden_attributes": {"professionalism": 80}}, youth, 3)
	assert(float(youth.mentoring_gain) > 0.0)
	var low: Dictionary = depth.injury_risk_feedback({"fitness": 95, "hidden_attributes": {"injury_proneness": 10}}, 0.3)
	var high: Dictionary = depth.injury_risk_feedback({"fitness": 55, "hidden_attributes": {"injury_proneness": 90}}, 1.0)
	assert(String(low.band) == "low")
	assert(String(high.band) == "high" and bool(high.recommend_rest))

	print("[TEST] CAREER DEPTH PASS")
	quit(0)
