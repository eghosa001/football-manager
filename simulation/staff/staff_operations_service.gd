class_name StaffOperationsService
extends RefCounted

const RESPONSIBILITIES := ["attacking","defending","possession","fitness","goalkeeping","set_pieces","recruitment","analysis","medical","sports_science"]

func ensure_world(world: Dictionary) -> void:
	world["staff_assignments"] = world.get("staff_assignments", {})
	world["staff_courses"] = world.get("staff_courses", [])

func assign(world: Dictionary, club_id: String, staff_id: String, responsibilities: Array) -> Dictionary:
	ensure_world(world)
	var valid: Array = []
	for responsibility in responsibilities:
		var value := String(responsibility)
		if value in RESPONSIBILITIES and value not in valid: valid.append(value)
	world.staff_assignments[staff_id] = {"club_id":club_id,"responsibilities":valid}
	return workload(world,staff_id)

func workload(world: Dictionary, staff_id: String) -> Dictionary:
	ensure_world(world)
	var assignment: Dictionary = world.staff_assignments.get(staff_id,{"responsibilities":[]})
	var count: int = int(assignment.get("responsibilities", []).size())
	var factor := clampf(1.0-float(maxi(0,count-2))*0.12,0.45,1.0)
	return {"staff_id":staff_id,"responsibility_count":count,"effectiveness":factor,"overloaded":count>4}

func coaching_quality(world: Dictionary, club_id: String, responsibility: String) -> float:
	ensure_world(world)
	var total := 0.0; var count := 0
	for member in world.get("staff",[]):
		if String(member.get("club_id","")) != club_id: continue
		var assignment: Dictionary = world.staff_assignments.get(String(member.get("id","")),{})
		if responsibility not in assignment.get("responsibilities",[]): continue
		var base := float(member.get("ability",50))
		var specialisms: Dictionary = member.get("specialisms",{})
		var speciality := float(specialisms.get(responsibility,base))
		var license_bonus := _license_bonus(String(member.get("license","none")))
		var effective := (base*0.45+speciality*0.45+license_bonus)*float(workload(world,String(member.id)).effectiveness)
		total += effective; count += 1
	return total/maxf(1.0,float(count))

func enroll_course(world: Dictionary, staff: Dictionary, target_license: String, cost: int, duration_days: int) -> Dictionary:
	ensure_world(world)
	var course := {"id":"course-%s-%d" % [String(staff.get("id","")),world.staff_courses.size()+1],"staff_id":String(staff.get("id","")),"target_license":target_license,"cost":maxi(0,cost),"remaining_days":maxi(1,duration_days),"status":"active"}
	world.staff_courses.append(course)
	return course

func advance_courses(world: Dictionary, days: int) -> Array:
	ensure_world(world)
	var completed: Array = []
	for course in world.staff_courses:
		if String(course.get("status","")) != "active": continue
		course.remaining_days = maxi(0,int(course.remaining_days)-maxi(0,days))
		if int(course.remaining_days)==0:
			course.status="complete"
			var staff := _staff(world.get("staff",[]),String(course.staff_id))
			if not staff.is_empty():
				staff.license = String(course.target_license)
				staff.ability = mini(100,int(staff.get("ability",50))+2)
			completed.append(String(course.id))
	return completed

func medical_effectiveness(world: Dictionary, club_id: String) -> Dictionary:
	return {"medical":coaching_quality(world,club_id,"medical"),"sports_science":coaching_quality(world,club_id,"sports_science")}

func recruitment_hierarchy(world: Dictionary, club_id: String) -> Dictionary:
	var head: Dictionary = {}; var scouts: Array = []; var analysts: Array = []
	for member in world.get("staff",[]):
		if String(member.get("club_id","")) != club_id: continue
		match String(member.get("role","")):
			"director_of_football","head_of_recruitment":
				if head.is_empty() or int(member.get("ability",0))>int(head.get("ability",0)): head=member
			"scout": scouts.append(member)
			"analyst","recruitment_analyst": analysts.append(member)
	return {"head":head,"scouts":scouts,"analysts":analysts,"coverage":clampf((scouts.size()*0.12+analysts.size()*0.08)+(float(head.get("ability",0))/100.0*0.30 if not head.is_empty() else 0.0),0.0,1.0)}

func _license_bonus(license: String) -> float:
	match license:
		"continental_pro": return 12.0
		"continental_a": return 9.0
		"continental_b": return 6.0
		"continental_c": return 3.0
	return 0.0

func _staff(values: Array, id: String) -> Dictionary:
	for member in values:
		if String(member.get("id",""))==id: return member
	return {}
