class_name CareerCycleService
extends "res://application/career/career_cycle_v2.gd"

const ClubEconomyServiceClass = preload("res://simulation/finance/club_economy_service.gd")

# Stable production facade for the canonical career rollover implementation.
# Versioned implementations remain behind this boundary until heavy RC3
# parity/soak validation proves they can be flattened safely.
func _init() -> void:
	# The base cycle owns the finance collaborator. Replace it at the stable
	# facade boundary so all production career rollovers use hardened insolvency
	# handling without leaking implementation details into callers.
	_economy = ClubEconomyServiceClass.new()
