extends SceneTree

const WorldGenerator = preload("res://simulation/world/world_generator.gd")
const HistoryRecords = preload("res://simulation/world/history_record_service.gd")

var checks := 0
var failures := 0

func _init() -> void:
	var world := WorldGenerator.new().create_world(88201,1,4,20)
	var competition: Dictionary = world.competitions[0]
	var table: Array = []
	for i in range(competition.club_ids.size()):
		table.append({"club_id":String(competition.club_ids[i]),"played":6,"won":maxi(0,6-i),"drawn":0,"lost":mini(6,i),"goals_for":20-i,"goals_against":5+i,"points":maxi(0,18-i*2)})
	world["player_history"] = [
		{"player_id":String(world.players[0].id),"season_year":2026,"club_id":String(world.players[0].club_id),"competition_id":String(competition.id),"appearances":30,"goals":18,"xg":15.2},
		{"player_id":String(world.players[1].id),"season_year":2026,"club_id":String(world.players[1].club_id),"competition_id":String(competition.id),"appearances":32,"goals":9,"xg":8.1}
	]
	var records := [{"competition_id":String(competition.id),"competition_name":String(competition.name),"competition_type":"league","champion_club_id":String(competition.club_ids[0]),"table":table}]
	var service = HistoryRecords.new()
	var result := service.record_season(world,records,2026)
	_expect(int(result.competition_rows)==1,"One completed competition must create one competition-history row")
	_expect(world.history_archive.clubs.size()==competition.club_ids.size(),"Every table club must get a permanent season finish row")
	_expect(world.history_archive.players.size()==2,"Player season totals must be archived")
	_expect(String(world.history_archive.records.most_decorated_club.club_id)==String(competition.club_ids[0]),"Champion must lead title record after first archived season")
	_expect(String(world.history_archive.records.most_goals.player_id)==String(world.players[0].id),"Career-goals record must derive from archived player totals")
	service.record_season(world,records,2026)
	_expect(world.history_archive.players.size()==2,"Re-recording same player season must not duplicate player-history rows")
	if failures==0:
		print("[TEST] HISTORY ARCHIVE PASS — %d checks"%checks); quit(0)
	else:
		push_error("[TEST] HISTORY ARCHIVE FAIL — %d failures across %d checks"%[failures,checks]); quit(1)

func _expect(condition:bool,message:String)->void:
	checks+=1
	if not condition:
		failures+=1
		push_error("[TEST] "+message)
