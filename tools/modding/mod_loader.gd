class_name ModLoader
extends RefCounted

const SUPPORTED_API_VERSION := 3
const ALLOWED_ROOT_KEYS := ["clubs", "players", "staff", "countries", "competitions"]
const ALLOWED_PATCH_KEYS := {
	"clubs": ["name", "reputation", "ticket_price", "training_facilities", "stadium_capacity", "tier", "country_id", "facilities", "board", "supporters", "kit", "logo"],
	"players": ["first_name", "last_name", "current_ability", "potential", "position", "country_id", "club_id", "preferred_foot", "weak_foot", "height_cm", "weight_kg", "traits", "position_familiarity", "attributes", "hidden_attributes"],
	"staff": ["name", "role", "club_id", "ability", "reputation", "staff_attributes", "manager_profile"],
	"countries": ["name", "code", "youth_rating"],
	"competitions": ["name", "country_id", "competition_type", "club_ids", "points_win", "points_draw", "tier", "promotion_places", "relegation_places", "registration_rules", "rules"],
}
const GRAPHIC_KEYS := ["logo", "kit_home", "kit_away", "kit_third", "background"]
const NamePoolServiceClass = preload("res://application/career/name_pool_service.gd")

func load_mod(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {"ok":false,"error":"missing_file","patches":{}}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"ok":false,"error":"open_failed","patches":{}}
	var parsed = JSON.parse_string(file.get_as_text()); file.close()
	if typeof(parsed) != TYPE_DICTIONARY: return {"ok":false,"error":"invalid_json","patches":{}}
	var validation := validate_mod(parsed)
	if not validation.ok: return validation
	return {"ok":true,"error":"","patches":parsed.get("patches",{}).duplicate(true),"additions":parsed.get("additions",{}).duplicate(true),"graphics":parsed.get("graphics",{}).duplicate(true),"names":parsed.get("names",{}).duplicate(true),"metadata":parsed.get("metadata",{}).duplicate(true)}

func validate_mod(data: Dictionary) -> Dictionary:
	var metadata = data.get("metadata", {})
	if typeof(metadata) != TYPE_DICTIONARY: return {"ok":false,"error":"metadata_must_be_dictionary","patches":{}}
	for key in ["id","name","version","author"]:
		if metadata.has(key) and not metadata[key] is String: return {"ok":false,"error":"metadata_text_required:"+key}
	if metadata.has("api_version") and typeof(metadata.api_version) not in [TYPE_INT,TYPE_FLOAT]: return {"ok":false,"error":"invalid_api_version"}
	if String(metadata.get("id","")).strip_edges()=="": return {"ok":false,"error":"metadata_id_required","patches":{}}
	if int(metadata.get("api_version",SUPPORTED_API_VERSION))>SUPPORTED_API_VERSION: return {"ok":false,"error":"unsupported_api_version","patches":{}}
	for key in ["dependencies","conflicts"]:
		if metadata.has(key) and typeof(metadata[key])!=TYPE_ARRAY: return {"ok":false,"error":"metadata_%s_must_be_array"%key,"patches":{}}
	var patches = data.get("patches",{})
	if typeof(patches)!=TYPE_DICTIONARY: return {"ok":false,"error":"patches_must_be_dictionary","patches":{}}
	var patch_validation := _validate_rows(patches,false)
	if not patch_validation.ok: return patch_validation
	var additions = data.get("additions",{})
	if typeof(additions)!=TYPE_DICTIONARY: return {"ok":false,"error":"additions_must_be_dictionary"}
	var addition_validation := _validate_rows(additions,true)
	if not addition_validation.ok: return addition_validation
	var graphics = data.get("graphics",{})
	if typeof(graphics)!=TYPE_DICTIONARY: return {"ok":false,"error":"graphics_must_be_dictionary"}
	for entity_id in graphics.keys():
		if String(entity_id).strip_edges()=="" or typeof(graphics[entity_id])!=TYPE_DICTIONARY: return {"ok":false,"error":"invalid_graphics_entry"}
		for key in graphics[entity_id].keys():
			if String(key) not in GRAPHIC_KEYS or not _safe_graphic_path(String(graphics[entity_id][key])): return {"ok":false,"error":"invalid_graphic:%s.%s"%[entity_id,key]}
	var names = data.get("names", {})
	var names_validation: Dictionary = NamePoolServiceClass.new().validate_names(names)
	if not bool(names_validation.get("ok", false)): return names_validation
	return {"ok":true,"error":"","patches":patches.duplicate(true),"additions":additions.duplicate(true),"graphics":graphics.duplicate(true),"names":names.duplicate(true)}

func _validate_rows(rows_by_collection: Dictionary, additions: bool) -> Dictionary:
	for root_key in rows_by_collection.keys():
		var collection := String(root_key)
		if collection not in ALLOWED_ROOT_KEYS: return {"ok":false,"error":"unsupported_root:%s"%collection}
		var rows = rows_by_collection[root_key]
		if typeof(rows)!=TYPE_ARRAY: return {"ok":false,"error":"patch_list_required:%s"%collection}
		var local_ids := {}
		for row in rows:
			if typeof(row)!=TYPE_DICTIONARY or not row.has("id") or not row.id is String or String(row.id).strip_edges()=="": return {"ok":false,"error":"invalid_entity_id"}
			if additions and local_ids.has(String(row.id)): return {"ok":false,"error":"duplicate_addition:%s:%s"%[collection,String(row.id)]}
			local_ids[String(row.id)] = true
			for field in row.keys():
				if String(field)=="id": continue
				if String(field) not in ALLOWED_PATCH_KEYS[collection]: return {"ok":false,"error":"unsupported_field:%s.%s"%[collection,String(field)]}
				if not _valid_value(String(field),row[field]): return {"ok":false,"error":"invalid_value:%s.%s"%[collection,String(field)]}
			if additions and not _required_addition_fields(collection,row): return {"ok":false,"error":"missing_required_fields:%s:%s"%[collection,String(row.id)]}
	return {"ok":true,"error":""}

func validate_load_order(mods: Array) -> Dictionary:
	var ids := {}
	for mod in mods:
		var metadata: Dictionary=mod.get("metadata",{}); var id:=String(metadata.get("id",""))
		if id=="": return {"ok":false,"error":"metadata_id_required"}
		if ids.has(id): return {"ok":false,"error":"duplicate_mod:%s"%id}
		ids[id]=metadata
	for id in ids.keys():
		var metadata: Dictionary=ids[id]
		for dependency in metadata.get("dependencies",[]):
			if not ids.has(String(dependency)): return {"ok":false,"error":"missing_dependency:%s:%s"%[String(id),String(dependency)]}
		for conflict in metadata.get("conflicts",[]):
			if ids.has(String(conflict)): return {"ok":false,"error":"mod_conflict:%s:%s"%[String(id),String(conflict)]}
	return {"ok":true,"error":""}

func apply_mods(world: Dictionary, mods: Array) -> Dictionary:
	for mod in mods:
		if not mod is Dictionary: return {"ok":false,"applied":0,"error":"invalid_mod"}
		var validation:=validate_mod(mod)
		if not validation.ok: return {"ok":false,"applied":0,"error":validation.error}
	var order:=validate_load_order(mods)
	if not order.ok: return {"ok":false,"applied":0,"error":order.error}
	var total:=0
	for mod in mods:
		var result:=apply_mod(world,mod)
		if not result.ok: return {"ok":false,"applied":total,"error":result.error}
		total+=int(result.applied)
	return {"ok":true,"applied":total,"error":""}

func apply_mod(world: Dictionary, data: Dictionary) -> Dictionary:
	var validation:=validate_mod(data)
	if not validation.ok: return {"ok":false,"applied":0,"error":validation.error}
	var applied:=0
	for root_key in data.get("additions",{}).keys():
		var collection_name:=String(root_key); world[collection_name]=world.get(collection_name,[])
		for row in data.additions[root_key]:
			if not _find(world[collection_name],String(row.id)).is_empty(): return {"ok":false,"applied":applied,"error":"duplicate_world_id:%s:%s"%[collection_name,String(row.id)]}
			var normalized:=_normalize_addition(collection_name,row)
			if not _references_valid(world,collection_name,normalized): return {"ok":false,"applied":applied,"error":"invalid_reference:%s:%s"%[collection_name,String(row.id)]}
			world[collection_name].append(normalized); applied+=1
	for root_key in data.get("patches",{}).keys():
		var collection: Array=world.get(String(root_key),[])
		for patch in data.patches[root_key]:
			var target:=_find(collection,String(patch.id))
			if target.is_empty(): continue
			for key in patch.keys():
				if String(key)!="id": target[key]=_sanitize_value(String(root_key),String(key),patch[key])
			applied+=1
	world["graphics_overrides"]=world.get("graphics_overrides",{})
	for entity_id in data.get("graphics",{}).keys(): world.graphics_overrides[String(entity_id)]=(data.graphics[entity_id] as Dictionary).duplicate(true)
	NamePoolServiceClass.new().apply_mod_names(world, [data])
	world["active_mods"]=world.get("active_mods",[])
	var metadata: Dictionary=data.get("metadata",{})
	if not metadata.is_empty(): world.active_mods.append(metadata.duplicate(true))
	return {"ok":true,"applied":applied,"error":""}

func _normalize_addition(collection: String, row: Dictionary) -> Dictionary:
	var value:=row.duplicate(true)
	for key in value.keys():
		if String(key)!="id": value[key]=_sanitize_value(collection,String(key),value[key])
	match collection:
		"countries": value["youth_rating"]=int(value.get("youth_rating",50))
		"clubs": value.merge({"reputation":50,"tier":1,"ticket_price":20,"stadium_capacity":10000},false)
		"players": value.merge({"current_ability":50,"potential":60,"preferred_foot":"right","weak_foot":50,"height_cm":180,"weight_kg":75,"traits":[],"attributes":{},"hidden_attributes":{}},false)
		"staff": value.merge({"ability":50,"reputation":25,"staff_attributes":{}},false)
		"competitions": value.merge({"competition_type":"league","club_ids":[],"points_win":3,"points_draw":1,"tier":1,"promotion_places":0,"relegation_places":0,"registration_rules":{},"rules":{}},false)
	return value

func _required_addition_fields(collection: String, row: Dictionary) -> bool:
	match collection:
		"countries": return String(row.get("name","")).strip_edges()!="" and String(row.get("code","")).strip_edges()!=""
		"clubs": return String(row.get("name","")).strip_edges()!="" and String(row.get("country_id","")).strip_edges()!=""
		"players": return String(row.get("club_id","")).strip_edges()!="" and String(row.get("position","")).strip_edges()!="" and (String(row.get("first_name","")).strip_edges()!="" or String(row.get("last_name","")).strip_edges()!="")
		"staff": return String(row.get("name","")).strip_edges()!="" and String(row.get("role","")).strip_edges()!=""
		"competitions": return String(row.get("name","")).strip_edges()!=""
	return false

func _references_valid(world: Dictionary, collection: String, value: Dictionary) -> bool:
	if collection=="clubs": return not _find(world.get("countries",[]),String(value.get("country_id",""))).is_empty()
	if collection=="players": return not _find(world.get("clubs",[]),String(value.get("club_id",""))).is_empty()
	if collection=="staff" and String(value.get("club_id",""))!="": return not _find(world.get("clubs",[]),String(value.get("club_id",""))).is_empty()
	if collection=="competitions":
		for club_id in value.get("club_ids",[]):
			if _find(world.get("clubs",[]),String(club_id)).is_empty(): return false
	return true

func _valid_value(key: String, value) -> bool:
	if key in ["id","name","first_name","last_name","position","country_id","club_id","preferred_foot","role","code","competition_type","kit","logo"]: return value is String
	if key in ["traits","club_ids"]:
		if not value is Array: return false
		for item in value:
			if not item is String: return false
		return true
	if key in ["attributes","hidden_attributes","position_familiarity","staff_attributes"]:
		if not value is Dictionary: return false
		for item in value.values():
			if typeof(item) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(item)): return false
		return true
	if key in ["facilities","board","supporters","manager_profile","registration_rules","rules"]: return value is Dictionary
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value))

func _sanitize_value(root_key: String, key: String, value):
	if key in ["reputation","current_ability","potential","youth_rating","weak_foot","ability"]: return clampi(int(value),1,100)
	if key=="ticket_price": return clampi(int(value),1,1000)
	if key in ["points_win","points_draw","tier","promotion_places","relegation_places","stadium_capacity"]: return maxi(0,int(value))
	if key=="height_cm": return clampi(int(value),150,220)
	if key=="weight_kg": return clampi(int(value),45,140)
	if key in ["attributes","hidden_attributes"] and typeof(value)==TYPE_DICTIONARY:
		var clean:={}; for attribute in value.keys(): clean[String(attribute)]=clampi(int(value[attribute]),1,100); return clean
	return value

func _safe_graphic_path(path: String) -> bool:
	if path.is_empty() or path.contains("..") or path.begins_with("/") or path.contains(":\\"): return false
	var lower:=path.to_lower(); return lower.ends_with(".png") or lower.ends_with(".jpg") or lower.ends_with(".jpeg") or lower.ends_with(".webp") or lower.ends_with(".svg")

func _find(values: Array, id: String) -> Dictionary:
	for value in values:
		if String(value.get("id",""))==id: return value
	return {}
