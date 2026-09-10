class_name InstitutionCommands
extends RefCounted

const ClubEconomyClass = preload("res://simulation/finance/club_economy.gd")
const LedgerClass = preload("res://simulation/finance/ledger.gd")
const InboxClass = preload("res://application/career/inbox_service.gd")

func invest_facility(world: Dictionary, club_id: String, facility: String) -> Error:
	var err := ClubEconomyClass.new().invest_in_facility(world,club_id,facility,int(world.get("season_year",2026)))
	if err==OK: InboxClass.new().add_message(world,"board","Facility upgrade approved","The board approved the %s facility upgrade."%facility)
	return err

func set_ticket_price(world: Dictionary, club_id: String, price: int) -> Error:
	var club:=_club(world,club_id)
	if club.is_empty():return ERR_DOES_NOT_EXIST
	club.ticket_price=clampi(price,1,1000)
	return OK

func request_budget(world: Dictionary, club_id: String, request_type: String, amount: int) -> Dictionary:
	var club:=_club(world,club_id)
	if club.is_empty() or amount<=0:return {"approved":false,"error":ERR_INVALID_PARAMETER}
	ClubEconomyClass.new().ensure_club(club)
	var confidence:=int(club.board.get("confidence",50));var ambition:=int(club.board.get("ambition",50));var cash:=int(club.get("cash",0));var debt:=int(club.get("debt",0))
	var affordable:=cash-debt/3
	var threshold:=confidence+ambition/2
	var approved:=affordable>amount and threshold>=65
	if approved:
		if request_type=="transfer":club.transfer_budget=int(club.get("transfer_budget",0))+amount
		elif request_type=="wage":club.wage_budget=int(club.get("wage_budget",0))+amount
		else:return {"approved":false,"error":ERR_INVALID_PARAMETER}
		club.board.confidence=clampi(confidence-2,0,100)
	InboxClass.new().add_message(world,"board","Budget request %s"%("approved" if approved else "declined"),"The board %s your request for %d additional %s budget."%["approved" if approved else "declined",amount,request_type])
	return {"approved":approved,"request_type":request_type,"amount":amount,"confidence":int(club.board.confidence)}

func expand_stadium(world: Dictionary, club_id: String, seats: int) -> Error:
	var club:=_club(world,club_id)
	if club.is_empty() or seats<500:return ERR_INVALID_PARAMETER
	ClubEconomyClass.new().ensure_club(club)
	var cost:=seats*350
	if int(club.get("cash",0))<cost:return ERR_UNAVAILABLE
	var ledger=LedgerClass.new();ledger.ensure(world);ledger.post(world,club_id,-cost,"stadium_expansion","stadium-%s-%d"%[club_id,int(world.get("season_year",2026))],int(world.get("season_year",2026)))
	club.stadium.capacity=int(club.stadium.capacity)+seats
	club.stadium.condition=clampi(int(club.stadium.condition)+5,40,100)
	InboxClass.new().add_message(world,"board","Stadium expansion approved","Construction adds %d seats to the stadium."%seats)
	return OK

func _club(world:Dictionary,club_id:String)->Dictionary:
	for club in world.get("clubs",[]):
		if String(club.get("id",""))==club_id:return club
	return {}
