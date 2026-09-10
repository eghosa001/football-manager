class_name SaveRepository
extends RefCounted

# Persistence port used by application services. Concrete adapters may store the
# payload in files, SQLite, cloud storage, or another backend without changing
# simulation/domain code.
func save_atomic(_path: String, _world: Dictionary, _history: Array = []) -> Error:
	push_error("SaveRepository.save_atomic must be implemented by an adapter")
	return ERR_UNAVAILABLE

func load_save(_path: String) -> Dictionary:
	push_error("SaveRepository.load_save must be implemented by an adapter")
	return {}
