extends SceneTree

const WorldGenerator = preload("res://simulation/world/world_generator.gd")
const LivingDepth = preload("res://simulation/world/living_world_depth.gd")

var checks := 0
var failures := 0

func _init() -> void:
	var world := WorldGenerator.new().create_world(88501,1,4,20)
	world["history_archive"] = {"players":[],"competitions":[],"clubs":[],"records":{}}
	var club_a: Dictionary = world.clubs[0]
	var club_b: Dictionary = world.clubs[1]
	club_a["city"] = "Shared City"
	club_b["city"] = "Shared City"
	var player: Dictionary = world.players[0]
	player.club_id = String(club_a.id)
	player["reputation"] = 90
	player["hidden_attributes"] = {"loyalty":92}
	club_a["captain_id"] = String(player.id)
	for year in range(2018,2027):
		world.history_archive.players.append({"year":year,"player_id":String(player.id),"club_id":String(club_a.id),"competition_id":String(world.competitions[0].id),"appearances":38,"goals":18,"assists":8,"rating":7.4})
	world.history_archive.competitions.append({"year":2026,"competition_id":"cup","competition_type":"knockout","winner_club_id":String(club_a.id),"runner_up_club_id":String(club_b.id)})
	world["domain_events"] = [{"season_year":2026,"type":"PLAYER_SIGNED","payload":{"seller_id":String(club_b.id),"buyer_id":String(club_a.id)}}]
	var result := LivingDepth.new().advance_year(world,2026)
	_expect(int(result.legends.recognized)>=1,"Long-serving productive captain must earn club recognition")
	var legend := _legend(world.club_legends,String(player.id),String(club_a.id))
	_expect(not legend.is_empty() and String(legend.level) in ["favoured","icon","legend"],"Club recognition must use Favoured/Icon/Legend tiers")
	var rivalry := _rivalry(world.rivalries,String(club_a.id),String(club_b.id))
	_expect(not rivalry.is_empty(),"Geography/cup-final/transfer causes must create a rivalry")
	_expect(int(rivalry.intensity)>=19,"Multiple rivalry causes must accumulate bounded intensity")
	_expect(rivalry.get("causes",{}).has("geography") and rivalry.get("causes",{}).has("cup_final") and rivalry.get("causes",{}).has("transfer"),"Rivalry must retain causal reasons")
	if failures==0:
		print("[TEST] LIVING WORLD DEPTH PASS — %d checks"%checks); quit(0)
	else:
		push_error("[TEST] LIVING WORLD DEPTH FAIL — %d failures across %d checks"%[failures,checks]); quit(1)

func _legend(rows:Array,player_id:String,club_id:String)->Dictionary:
	for row in rows:
		if String(row.get("player_id",""))==player_id and String(row.get("club_id",""))==club_id: return row
	return {}

func _rivalry(rows:Array,a:String,b:String)->Dictionary:
	for row in rows:
		if (String(row.get("club_a",""))==a and String(row.get("club_b",""))==b) or (String(row.get("club_a",""))==b and String(row.get("club_b",""))==a): return row
	return {}

func _expect(condition:bool,message:String)->void:
	checks+=1
	if not condition:
		failures+=1
		push_error("[TEST] "+message)
