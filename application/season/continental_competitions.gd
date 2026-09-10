class_name ContinentalCompetitions
extends RefCounted

const REGIONS := {
	"europe": ["eng", "esp", "deu", "fra", "ita", "prt", "nld", "bel"],
	"africa": ["nga", "gha", "zaf", "egy", "mar", "sen", "cmr", "civ", "tun", "dza"],
	"south_america": ["bra", "arg", "uru", "col"],
	"asia": ["jpn", "kor"]
}

func prepare(world: Dictionary, records: Array = []) -> void:
	for region in REGIONS:
		var entrants: Array = []
		var nations := 0
		for competition in world.get("competitions", []).duplicate():
			if String(competition.get("competition_type", "league")) != "league" or int(competition.get("tier", 1)) != 1: continue
			if String(competition.get("country_id", "")) not in REGIONS[region]: continue
			nations += 1
			var ranked: Array = []
			for record in records:
				if String(record.get("competition_id", "")) == String(competition.id):
					for row in record.get("table", []): ranked.append(String(row.club_id))
			if ranked.is_empty():
				var clubs: Array = []
				for club in world.get("clubs", []):
					if String(club.id) in competition.get("club_ids", []): clubs.append(club)
				clubs.sort_custom(func(a: Dictionary, b: Dictionary):
					if int(a.get("reputation",0)) == int(b.get("reputation",0)): return String(a.id) < String(b.id)
					return int(a.get("reputation",0)) > int(b.get("reputation",0))
				)
				for club in clubs: ranked.append(String(club.id))
			entrants.append_array(ranked.slice(0, mini(4, ranked.size())))
		if nations < 2 or entrants.size() < 4: continue
		var id := "continental-%s-champions" % region
		var target: Dictionary = {}
		for competition in world.competitions:
			if String(competition.id) == id: target = competition; break
		if target.is_empty():
			target = {"id":id,"name":"%s Champions Cup" % String(region).replace("_", " ").capitalize(),"competition_type":"knockout","country_id":"","tier":0,"continental":true,"registration_rules":{"max_squad":25,"min_goalkeepers":2,"max_foreign":25}}
			world.competitions.append(target)
		target["club_ids"] = entrants
		target["qualification"] = "Top four from each participating top division; reputation used for the first season."
