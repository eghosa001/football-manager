extends SceneTree

const SeasonRunner = preload("res://application/season/season_runner.gd")
const RecordBook = preload("res://simulation/world/record_book_service.gd")

var failures := 0
var checks := 0

func _init() -> void:
	_test_record_decoration_before_rollover()
	_test_record_book_dedupe_and_match_records()
	if failures == 0:
		print("[TEST] RECORD BOOK DEPTH PASS: runner-up, match summaries and deduped all-time records verified")
		quit(0)
		return
	push_error("[TEST] RECORD BOOK DEPTH FAIL: %d failures across %d checks" % [failures,checks])
	quit(1)

func _test_record_decoration_before_rollover() -> void:
	var world := {"fixtures":[
		{"id":"f1","competition_id":"cup","played":true,"stage":"semifinal","round":1,"date":"2026-04-01","home_club_id":"A","away_club_id":"C","home_goals":2,"away_goals":0},
		{"id":"f2","competition_id":"cup","played":true,"stage":"final","round":2,"date":"2026-05-01","home_club_id":"A","away_club_id":"B","home_goals":3,"away_goals":1}
	]}
	var record := {"competition_id":"cup","competition_name":"Cup","competition_type":"knockout","champion_club_id":"A","table":[]}
	SeasonRunner.new()._decorate_record(world,record)
	_require(String(record.get("runner_up_club_id","")) == "B","knockout runner-up must be captured before fixtures roll over")
	var summary: Dictionary = record.get("record_summary",{})
	_require(int(summary.get("matches",0)) == 2,"record summary must count played fixtures")
	_require(int(summary.get("biggest_victory",{}).get("margin",0)) == 2,"record summary must capture biggest victory")
	_require(int(summary.get("total_goals",0)) == 6,"record summary must preserve season goals")

func _test_record_book_dedupe_and_match_records() -> void:
	var world := {"history_archive":{
		"competitions":[
			{"year":2026,"competition_id":"league","winner_club_id":"A","runner_up_club_id":"B","top_scorer_id":"p1","top_scorer_goals":20},
			{"year":2026,"competition_id":"league","winner_club_id":"A","runner_up_club_id":"B","top_scorer_id":"p1","top_scorer_goals":20}
		],
		"clubs":[
			{"year":2026,"competition_id":"league","club_id":"A","champion":true,"played":38,"won":28,"goals_for":80,"goals_against":25,"points":90},
			{"year":2026,"competition_id":"league","club_id":"B","champion":false,"played":38,"won":25,"goals_for":70,"goals_against":30,"points":84}
		],
		"players":[{"year":2026,"competition_id":"league","player_id":"p1","appearances":35,"goals":20,"assists":8}],
		"season_summaries":[
			{"year":2026,"competition_id":"league","summary":{"matches":380,"total_goals":1030,"average_goals":2.71,"shootouts":0,"biggest_victory":{"margin":7,"home_club_id":"A","away_club_id":"C","home_goals":7,"away_goals":0},"highest_scoring_match":{"goals":9,"home_club_id":"D","away_club_id":"E","home_goals":5,"away_goals":4},"longest_unbeaten":{"club_id":"A","matches":24},"longest_winning_streak":{"club_id":"A","matches":11},"most_clean_sheets":{"club_id":"A","matches":19}}},
			{"year":2026,"competition_id":"league","summary":{"matches":380,"total_goals":1030,"average_goals":2.71,"shootouts":0,"biggest_victory":{"margin":7,"home_club_id":"A","away_club_id":"C","home_goals":7,"away_goals":0}}}
		]
	}}
	var result := RecordBook.new().refresh(world)
	_require(int(result.get("competition_rows",0)) == 1,"duplicate competition-year rows must collapse")
	_require(int(result.get("season_summary_rows",0)) == 1,"duplicate competition season summaries must collapse")
	var book: Dictionary = world.history_archive.record_books.get("league",{})
	_require(not book.is_empty(),"competition record book must be generated")
	_require(int(book.get("titles",[])[0].get("titles",0)) == 1,"title table must not double-count duplicates")
	_require(int(book.get("match_records",{}).get("biggest_victory",{}).get("margin",0)) == 7,"all-time match record must consume season summaries")
	_require(int(book.get("player_records",{}).get("season_goals",{}).get("value",0)) == 20,"single-season scoring record must persist")
	var second := RecordBook.new().refresh(world)
	_require(int(second.get("competition_rows",0)) == 1 and int(second.get("season_summary_rows",0)) == 1,"record-book refresh must be idempotent")

func _require(condition: bool,message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[RECORD BOOK] "+message)
