class_name LocalizationService
extends RefCounted

static var _career_translations: Array[Translation] = []

func install(locale: String) -> void:
	if _career_translations.is_empty():
		var catalogs: Array[Dictionary] = []
		for path in ["res://game/localization/career_strings.json", "res://game/localization/completion_strings.json"]:
			var loaded := _load_catalog(path)
			if not loaded.is_empty():
				catalogs.append(loaded)
		for index in range(2):
			var translation := Translation.new()
			translation.locale = "fr" if index == 0 else "pt"
			for catalog in catalogs:
				for source in catalog:
					var values = catalog[source]
					if typeof(values) == TYPE_ARRAY and values.size() > index:
						translation.add_message(String(source), String(values[index]))
			TranslationServer.add_translation(translation)
			_career_translations.append(translation)
	TranslationServer.set_locale(language(locale))

func _load_catalog(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

const SUPPORTED := ["en", "fr", "pt"]
const STRINGS := {
	"en": {"dashboard": "Dashboard", "squad": "Squad", "tactics": "Tactics", "medical": "Medical", "schedule": "Schedule", "competitions": "Competitions", "transfers": "Transfers", "staff": "Staff", "finances": "Finances", "world_search": "World Search", "match_analysis": "Match Analysis", "inbox": "Inbox", "training": "Training", "scouting": "Scouting", "club": "Club", "world": "World", "dynamics": "Dynamics", "save": "Save", "load": "Load", "continue": "Continue", "new_career": "New Career", "settings": "Settings", "language": "Language", "high_contrast": "High contrast", "large_text": "Large text", "reduced_motion": "Reduced motion", "screen_reader": "Screen reader labels", "ui_scale": "UI scale", "audio": "Audio", "mute": "Mute", "crowd": "Crowd", "whistle": "Whistle", "goals": "Goals", "season": "Season", "league": "League", "cup": "Cup", "fixtures": "Fixtures", "results": "Results", "table": "Table", "news": "News", "history": "History", "awards": "Awards", "legends": "Legends", "board": "Board", "supporters": "Supporters", "stadium": "Stadium", "sponsors": "Sponsors", "contracts": "Contracts", "youth": "Youth", "injuries": "Injuries"},
	"fr": {"dashboard": "Tableau de bord", "squad": "Effectif", "tactics": "Tactiques", "medical": "Médical", "schedule": "Calendrier", "competitions": "Compétitions", "transfers": "Transferts", "staff": "Personnel", "finances": "Finances", "world_search": "Recherche mondiale", "match_analysis": "Analyse du match", "inbox": "Boîte de réception", "training": "Entraînement", "scouting": "Recrutement", "club": "Club", "world": "Monde", "dynamics": "Dynamique", "save": "Sauvegarder", "load": "Charger", "continue": "Continuer", "new_career": "Nouvelle carrière", "settings": "Paramètres", "language": "Langue", "high_contrast": "Contraste élevé", "large_text": "Grand texte", "reduced_motion": "Mouvements réduits", "screen_reader": "Étiquettes lecteur d'écran", "ui_scale": "Échelle UI", "audio": "Audio", "mute": "Muet", "crowd": "Foule", "whistle": "Sifflet", "goals": "Buts", "season": "Saison", "league": "Championnat", "cup": "Coupe", "fixtures": "Calendrier", "results": "Résultats", "table": "Classement", "news": "Actualités", "history": "Histoire", "awards": "Récompenses", "legends": "Légendes", "board": "Direction", "supporters": "Supporters", "stadium": "Stade", "sponsors": "Sponsors", "contracts": "Contrats", "youth": "Jeunes", "injuries": "Blessures"},
	"pt": {"dashboard": "Painel", "squad": "Plantel", "tactics": "Táticas", "medical": "Médico", "schedule": "Calendário", "competitions": "Competições", "transfers": "Transferências", "staff": "Equipa técnica", "finances": "Finanças", "world_search": "Pesquisa mundial", "match_analysis": "Análise da partida", "inbox": "Caixa de entrada", "training": "Treino", "scouting": "Observação", "club": "Clube", "world": "Mundo", "dynamics": "Dinâmica", "save": "Guardar", "load": "Carregar", "continue": "Continuar", "new_career": "Nova carreira", "settings": "Definições", "language": "Idioma", "high_contrast": "Alto contraste", "large_text": "Texto grande", "reduced_motion": "Movimento reduzido", "screen_reader": "Rótulos de leitor de ecrã", "ui_scale": "Escala da UI", "audio": "Áudio", "mute": "Silenciar", "crowd": "Multidão", "whistle": "Apito", "goals": "Golos", "season": "Época", "league": "Liga", "cup": "Taça", "fixtures": "Jogos", "results": "Resultados", "table": "Tabela", "news": "Notícias", "history": "História", "awards": "Prémios", "legends": "Lendas", "board": "Direção", "supporters": "Adeptos", "stadium": "Estádio", "sponsors": "Patrocinadores", "contracts": "Contratos", "youth": "Juventude", "injuries": "Lesões"},
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
