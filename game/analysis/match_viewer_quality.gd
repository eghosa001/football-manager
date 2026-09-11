class_name MatchViewerQuality
extends RefCounted

func policy(device: Dictionary, frame_count: int) -> Dictionary:
	var memory_mb:=int(device.get("memory_mb",4096)); var cpu_threads:=int(device.get("cpu_threads",4)); var mobile:=bool(device.get("mobile",false))
	var low_end:=memory_mb<4096 or cpu_threads<=4 or mobile
	return {"interpolation":true,"max_visible_players":22,"trail_length":3 if low_end else 8,"heatmap_resolution":16 if low_end else 32,"passing_network_limit":25 if low_end else 60,"frame_skip":2 if low_end and frame_count>1000 else 1,"camera_smoothing":0.18 if low_end else 0.12,"show_tactical_overlays":not low_end,"low_end":low_end}

func validate_frames(frames: Array) -> Dictionary:
	var issues:Array=[]; var last_tick:=-1
	for i in range(frames.size()):
		var frame:Dictionary=frames[i]
		var tick:=int(frame.get("tick",i))
		if tick<=last_tick: issues.append({"code":"non_monotonic_tick","index":i})
		last_tick=tick
		for side in ["home","away"]:
			var positions=frame.get(side,{})
			if typeof(positions)!=TYPE_DICTIONARY: issues.append({"code":"invalid_positions","index":i,"side":side}); continue
			for id in positions.keys():
				var p:Dictionary=positions[id]
				if float(p.get("x",-1.0))<0.0 or float(p.get("x",106.0))>105.0 or float(p.get("y",-1.0))<0.0 or float(p.get("y",69.0))>68.0:
					issues.append({"code":"position_outside_pitch","index":i,"player_id":String(id)})
	return {"ok":issues.is_empty(),"issues":issues,"frames":frames.size()}

func interpolate(a:Dictionary,b:Dictionary,weight:float)->Dictionary:
	var t:=clampf(weight,0.0,1.0); var result:=a.duplicate(true)
	if a.has("ball") and b.has("ball"):
		result.ball={"x":lerpf(float(a.ball.get("x",0)),float(b.ball.get("x",0)),t),"y":lerpf(float(a.ball.get("y",0)),float(b.ball.get("y",0)),t)}
	for side in ["home","away"]:
		var positions:Dictionary={}
		for id in a.get(side,{}).keys():
			var pa:Dictionary=a[side][id]; var pb:Dictionary=b.get(side,{}).get(id,pa)
			positions[id]={"x":lerpf(float(pa.get("x",0)),float(pb.get("x",0)),t),"y":lerpf(float(pa.get("y",0)),float(pb.get("y",0)),t)}
		result[side]=positions
	return result
