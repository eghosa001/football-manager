class_name ModManifestService
extends RefCounted

const GAME_API_VERSION := 1

func normalize_manifest(manifest: Dictionary) -> Dictionary:
	return {
		"id":String(manifest.get("id","")),
		"name":String(manifest.get("name",manifest.get("id",""))),
		"version":String(manifest.get("version","1.0.0")),
		"game_api_min":int(manifest.get("game_api_min",1)),
		"game_api_max":int(manifest.get("game_api_max",GAME_API_VERSION)),
		"dependencies":manifest.get("dependencies",[]),
		"conflicts":manifest.get("conflicts",[]),
		"load_after":manifest.get("load_after",[]),
		"integrity_hash":String(manifest.get("integrity_hash","")),
		"safe_remove":bool(manifest.get("safe_remove",false)),
		"writes":manifest.get("writes",[])
	}

func validate_manifests(manifests: Array) -> Dictionary:
	var normalized: Array = []
	var by_id := {}
	var errors: Array = []
	for raw in manifests:
		var manifest := normalize_manifest(raw)
		if String(manifest.id) == "":
			errors.append({"code":"missing_mod_id"})
			continue
		if by_id.has(String(manifest.id)):
			errors.append({"code":"duplicate_mod_id","mod_id":String(manifest.id)})
			continue
		if GAME_API_VERSION < int(manifest.game_api_min) or GAME_API_VERSION > int(manifest.game_api_max):
			errors.append({"code":"game_version_incompatible","mod_id":String(manifest.id)})
		by_id[String(manifest.id)] = manifest
		normalized.append(manifest)
	for manifest in normalized:
		for dependency in manifest.dependencies:
			var dependency_id := String(dependency.get("id",dependency)) if typeof(dependency)==TYPE_DICTIONARY else String(dependency)
			if not by_id.has(dependency_id): errors.append({"code":"missing_dependency","mod_id":String(manifest.id),"dependency":dependency_id})
		for conflict in manifest.conflicts:
			if by_id.has(String(conflict)): errors.append({"code":"declared_conflict","mod_id":String(manifest.id),"conflict":String(conflict)})
	var writes := {}
	for manifest in normalized:
		for path in manifest.writes:
			var key := String(path)
			if writes.has(key): errors.append({"code":"write_conflict","path":key,"mods":[String(writes[key]),String(manifest.id)]})
			else: writes[key] = String(manifest.id)
	var ordered := _topological_order(normalized,by_id,errors)
	return {"ok":errors.is_empty(),"errors":errors,"load_order":ordered,"manifests":normalized}

func can_remove_from_career(active_manifests: Array, mod_id: String) -> Dictionary:
	var validation := validate_manifests(active_manifests)
	var by_id := {}
	for manifest in validation.manifests: by_id[String(manifest.id)] = manifest
	if not by_id.has(mod_id): return {"ok":false,"reason_codes":["mod_not_active"]}
	if not bool(by_id[mod_id].safe_remove): return {"ok":false,"reason_codes":["mod_not_marked_safe_remove"]}
	var dependents: Array = []
	for manifest in validation.manifests:
		for dep in manifest.dependencies:
			var dep_id := String(dep.get("id",dep)) if typeof(dep)==TYPE_DICTIONARY else String(dep)
			if dep_id == mod_id: dependents.append(String(manifest.id))
	if not dependents.is_empty(): return {"ok":false,"reason_codes":["required_by_other_mods"],"dependents":dependents}
	return {"ok":true,"reason_codes":["safe_remove"]}

func verify_integrity(manifest: Dictionary, actual_hash: String) -> Dictionary:
	var expected := String(normalize_manifest(manifest).integrity_hash)
	if expected == "": return {"ok":true,"reason_codes":["no_integrity_hash_declared"]}
	return {"ok":expected.to_lower()==actual_hash.to_lower(),"reason_codes":["integrity_match" if expected.to_lower()==actual_hash.to_lower() else "integrity_mismatch"]}

func _topological_order(manifests: Array, by_id: Dictionary, errors: Array) -> Array:
	var incoming := {}
	var edges := {}
	for manifest in manifests:
		var id := String(manifest.id); incoming[id]=0; edges[id]=[]
	for manifest in manifests:
		var id := String(manifest.id)
		var deps: Array = []
		for dep in manifest.dependencies:
			var dep_id := String(dep.get("id",dep)) if typeof(dep)==TYPE_DICTIONARY else String(dep)
			if by_id.has(dep_id): deps.append(dep_id)
		for dep_id in manifest.load_after:
			if by_id.has(String(dep_id)) and String(dep_id) not in deps: deps.append(String(dep_id))
		for dep_id in deps:
			edges[dep_id].append(id); incoming[id]=int(incoming[id])+1
	var queue: Array = []
	for id in incoming.keys():
		if int(incoming[id])==0: queue.append(String(id))
	queue.sort()
	var ordered: Array = []
	while not queue.is_empty():
		var id := String(queue.pop_front()); ordered.append(id)
		for target in edges[id]:
			incoming[target]=int(incoming[target])-1
			if int(incoming[target])==0: queue.append(String(target)); queue.sort()
	if ordered.size()!=manifests.size(): errors.append({"code":"dependency_cycle"})
	return ordered
