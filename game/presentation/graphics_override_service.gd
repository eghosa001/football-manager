class_name GraphicsOverrideService
extends RefCounted

func resolve_path(world: Dictionary, entity_id: String, key: String) -> String:
	var overrides: Dictionary = world.get("graphics_overrides", {})
	if not overrides.has(entity_id): return ""
	var relative := String((overrides[entity_id] as Dictionary).get(key, ""))
	if relative.is_empty(): return ""
	if FileAccess.file_exists(relative): return relative
	for metadata in world.get("active_mods", []):
		if typeof(metadata) != TYPE_DICTIONARY: continue
		var root := String(metadata.get("_source_dir", ""))
		if root.is_empty(): continue
		var candidate := root.path_join(relative)
		if FileAccess.file_exists(candidate): return candidate
	return ""

func texture(world: Dictionary, entity_id: String, key: String = "logo") -> Texture2D:
	var path := resolve_path(world, entity_id, key)
	if path.is_empty(): return null
	var image := Image.load_from_file(path)
	if image == null or image.is_empty(): return null
	return ImageTexture.create_from_image(image)

func available(world: Dictionary, entity_id: String) -> Dictionary:
	var result := {}
	for key in ["logo","kit_home","kit_away","kit_third","background"]:
		var path := resolve_path(world, entity_id, key)
		if not path.is_empty(): result[key] = path
	return result
