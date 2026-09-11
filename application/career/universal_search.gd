class_name UniversalSearch
extends RefCounted

var _index: Array = []
var _signature := ""

func search(world: Dictionary, text: String, limit: int = 40) -> Array:
	var signature := _world_signature(world)
	if _index.is_empty() or signature != _signature:
		_rebuild(world)
	var query := text.strip_edges().to_lower()
	var scored: Array = []
	for row in _index:
		var haystack := String(row.search_text)
		var score := _score(haystack, query)
		if score < 0: continue
		scored.append({"score":score,"row":row})
	scored.sort_custom(func(a: Dictionary,b: Dictionary):
		if int(a.score)==int(b.score): return String(a.row.name)<String(b.row.name)
		return int(a.score)>int(b.score)
	)
	var out: Array = []
	for i in range(mini(limit,scored.size())): out.append(scored[i].row.duplicate(true))
	return out

func _rebuild(world: Dictionary) -> void:
	_index.clear()
	_add_collection("club",world.get("clubs",[]),func(value): return String(value.get("name","")),func(value): return String(value.get("country_id","")))
	_add_collection("player",world.get("players",[]),func(value): return _person_name(value),func(value): return "%s %s" % [String(value.get("position","")),String(value.get("country_id",value.get("nationality_id","")))])
	_add_collection("staff",world.get("staff",[]),func(value): return _person_name(value),func(value): return String(value.get("role","")))
	_add_collection("competition",world.get("competitions",[]),func(value): return String(value.get("name","")),func(value): return "%s %s" % [String(value.get("country_id","")),String(value.get("competition_type",""))])
	_add_collection("country",world.get("countries",[]),func(value): return String(value.get("name","")),func(value): return String(value.get("code","")))
	_signature = _world_signature(world)

func _add_collection(kind: String, values: Array, name_fn: Callable, extra_fn: Callable) -> void:
	for value in values:
		if typeof(value)!=TYPE_DICTIONARY: continue
		var name := String(name_fn.call(value)).strip_edges()
		var id := String(value.get("id",""))
		if id=="" or name=="": continue
		var extra := String(extra_fn.call(value)).strip_edges()
		_index.append({"type":kind,"id":id,"name":name,"extra":extra,"search_text":("%s %s %s %s" % [name,id,kind,extra]).to_lower()})

func _score(haystack: String, query: String) -> int:
	if query=="": return 1
	if haystack.begins_with(query): return 1000-query.length()
	var pos := haystack.find(query)
	if pos>=0: return 700-pos-query.length()
	var tokens := query.split(" ",false)
	var matched := 0
	for token in tokens:
		if haystack.contains(token): matched += 1
	return matched*100 if matched==tokens.size() else -1

func _world_signature(world: Dictionary) -> String:
	return "%d:%d:%d:%d:%d:%d" % [world.get("clubs",[]).size(),world.get("players",[]).size(),world.get("staff",[]).size(),world.get("competitions",[]).size(),world.get("countries",[]).size(),int(world.get("season_year",0))]

func _person_name(value: Dictionary) -> String:
	var name := String(value.get("name","")).strip_edges()
	if name!="": return name
	return (String(value.get("first_name",""))+" "+String(value.get("last_name",""))).strip_edges()
