class_name MatchDebugger
extends RefCounted

func summarize(result: Dictionary) -> Dictionary:
	var counts := {}
	for event in result.get("events", []):
		var type := String(event.get("type", "unknown"))
		counts[type] = int(counts.get(type, 0)) + 1
	return {"home_goals":int(result.get("home_goals",0)),"away_goals":int(result.get("away_goals",0)),"events":result.get("events", []).size(),"event_counts":counts,"home_xg":float(result.get("stats",{}).get("home",{}).get("xg",0.0)),"away_xg":float(result.get("stats",{}).get("away",{}).get("xg",0.0))}

func validate(result: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var home_goals := 0
	var away_goals := 0
	var previous_minute := -1
	for event in result.get("events", []):
		var minute := int(event.get("minute", previous_minute))
		if minute < 0 or minute > 130:
			errors.append("event minute out of range: %d" % minute)
		previous_minute = maxi(previous_minute, minute)
		if String(event.get("type", "")) == "shot" and String(event.get("outcome", "")) == "goal":
			if String(event.get("side", "")) == "home": home_goals += 1
			elif String(event.get("side", "")) == "away": away_goals += 1
	if home_goals != int(result.get("home_goals", home_goals)):
		errors.append("home score does not match goal events")
	if away_goals != int(result.get("away_goals", away_goals)):
		errors.append("away score does not match goal events")
	return errors
