class_name CompetitionFormSchema
extends RefCounted

const TYPES := ["league","knockout","group_knockout","two_leg"]

func schema() -> Dictionary:
	return {
		"competition":{"fields":[_field("name","text",true),_field("competition_type","select",true,TYPES),_field("country_id","entity",true),_field("reputation","number",false,[],1,100)]},
		"league":{"fields":[_field("teams","number",true,[],2,40),_field("rounds","number",true,[],1,4),_field("promotion_places","number",false,[],0,10),_field("relegation_places","number",false,[],0,10),_field("tie_breakers","multi_select",true,["points","goal_difference","goals_for","head_to_head","wins","fair_play"])]},
		"knockout":{"fields":[_field("extra_time","toggle",false),_field("penalties","toggle",false),_field("replays","toggle",false),_field("seeded_draw","toggle",false),_field("away_goals","toggle",false),_field("draw_restrictions","multi_select",false,["same_country","same_group","seeded_vs_seeded"])]},
		"registration":{"fields":[_field("max_squad","number",false,[],11,40),_field("homegrown_min","number",false,[],0,25),_field("foreign_max","number",false,[],0,40),_field("u21_exempt","toggle",false)]},
		"discipline":{"fields":[_field("yellow_limit","number",false,[],1,10),_field("red_ban_games","number",false,[],1,6),_field("reset_round","number",false,[],0,99)]},
	}

func validate(data: Dictionary) -> Dictionary:
	var errors: Array = []
	if String(data.get("name",""))=="": errors.append({"field":"name","code":"required"})
	if String(data.get("competition_type","")) not in TYPES: errors.append({"field":"competition_type","code":"invalid_type"})
	var teams:=int(data.get("teams",data.get("club_ids",[]).size()))
	if teams>0 and teams<2: errors.append({"field":"teams","code":"too_few_teams"})
	var max_squad:=int(data.get("max_squad",25)); var homegrown:=int(data.get("homegrown_min",0))
	if homegrown>max_squad: errors.append({"field":"homegrown_min","code":"exceeds_squad_size"})
	if bool(data.get("two_leg",false)) and bool(data.get("replays",false)): errors.append({"field":"replays","code":"incompatible_with_two_leg"})
	return {"ok":errors.is_empty(),"errors":errors,"preview":preview(data)}

func preview(data: Dictionary) -> Dictionary:
	var teams:=maxi(2,int(data.get("teams",data.get("club_ids",[]).size())))
	var kind:=String(data.get("competition_type","league"))
	var matches:=teams*(teams-1) if kind=="league" else maxi(1,teams-1)
	if kind=="league": matches*=maxi(1,int(data.get("rounds",2)))/2
	return {"teams":teams,"estimated_matches":matches,"type":kind,"uses_extra_time":bool(data.get("extra_time",false)),"uses_penalties":bool(data.get("penalties",false))}

func _field(name:String,kind:String,required:bool=false,options:Array=[],minimum:int=-1,maximum:int=-1)->Dictionary:
	var row={"name":name,"control":kind,"required":required}
	if not options.is_empty(): row["options"]=options
	if minimum>=0: row["min"]=minimum
	if maximum>=0: row["max"]=maximum
	return row
