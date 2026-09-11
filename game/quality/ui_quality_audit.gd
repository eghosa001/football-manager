class_name UIQualityAudit
extends RefCounted

func audit(root: Node, translation_catalog: Dictionary = {}) -> Dictionary:
	var issues: Array = []
	_walk(root,issues,translation_catalog)
	return {"ok":issues.is_empty(),"issues":issues,"checked":_count_nodes(root)}

func _walk(node:Node,issues:Array,catalog:Dictionary)->void:
	if node is Control:
		var control:=node as Control
		if control.visible and control.mouse_filter!=Control.MOUSE_FILTER_IGNORE:
			var size:=control.size
			if (control is Button or control is LineEdit or control is OptionButton) and (size.x<40.0 or size.y<32.0):
				issues.append({"code":"small_interactive_target","path":String(control.get_path()),"size":size})
			if control is Button and control.focus_mode==Control.FOCUS_NONE:
				issues.append({"code":"not_keyboard_focusable","path":String(control.get_path())})
			if control is Label:
				var label:=control as Label
				if label.text.length()>0 and label.text.length()>80 and label.autowrap_mode==TextServer.AUTOWRAP_OFF:
					issues.append({"code":"long_text_no_wrap","path":String(control.get_path())})
			_check_translation(control,issues,catalog)
	for child in node.get_children(): _walk(child,issues,catalog)

func _check_translation(control:Control,issues:Array,catalog:Dictionary)->void:
	var text:=""
	if control is Label: text=(control as Label).text
	elif control is Button: text=(control as Button).text
	if text=="" or catalog.is_empty(): return
	if text.begins_with("[") or text.is_valid_int() or text.is_valid_float(): return
	var known:=false
	for value in catalog.values():
		if typeof(value)==TYPE_DICTIONARY and text in value.values(): known=true; break
		if String(value)==text: known=true; break
	if not known: issues.append({"code":"literal_untranslated_text","path":String(control.get_path()),"text":text})

func _count_nodes(root:Node)->int:
	var total:=1
	for child in root.get_children(): total+=_count_nodes(child)
	return total
