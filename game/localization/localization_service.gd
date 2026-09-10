class_name LocalizationService
extends RefCounted

const SUPPORTED := ["en", "fr", "pt"]
const STRINGS := {
	"en": {"dashboard": "Dashboard", "squad": "Squad", "tactics": "Tactics", "medical": "Medical", "schedule": "Schedule", "competitions": "Competitions", "transfers": "Transfers", "staff": "Staff", "finances": "Finances", "world_search": "World Search", "match_analysis": "Match Analysis"},
	"fr": {"dashboard": "Tableau de bord", "squad": "Effectif", "tactics": "Tactiques", "medical": "Médical", "schedule": "Calendrier", "competitions": "Compétitions", "transfers": "Transferts", "staff": "Personnel", "finances": "Finances", "world_search": "Recherche mondiale", "match_analysis": "Analyse du match"},
	"pt": {"dashboard": "Painel", "squad": "Plantel", "tactics": "Táticas", "medical": "Médico", "schedule": "Calendário", "competitions": "Competições", "transfers": "Transferências", "staff": "Equipa técnica", "finances": "Finanças", "world_search": "Pesquisa mundial", "match_analysis": "Análise da partida"},
}

func language(value: String) -> String:
	return value if value in SUPPORTED else "en"

func text(key: String, locale: String = "en") -> String:
	var selected := language(locale)
	return String(STRINGS[selected].get(key, STRINGS.en.get(key, key)))

func coverage(locale: String) -> float:
	var selected := language(locale)
	if STRINGS.en.is_empty():
		return 1.0
	var matched := 0
	for key in STRINGS.en.keys():
		if STRINGS[selected].has(key) and String(STRINGS[selected][key]) != "":
			matched += 1
	return float(matched) / float(STRINGS.en.size())
