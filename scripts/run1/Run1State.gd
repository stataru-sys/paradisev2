extends RefCounted
class_name Run1State
## Состояние первого Run-а. Живёт пока жив Run1.tscn (между переключениями программ
## не сбрасывается). Не autoload — потому что Slice 1 знает только один Run за раз;
## вынесем в RunService autoload, когда появится Run 2+.

var earned_today: int = 0
var matches: Array[Dictionary] = []
var sympathies: Dictionary = {}
var work_words_remaining: Array[String] = []
var work_categories_done: Dictionary = {}

func add_match(profile: Dictionary) -> void:
	for m: Dictionary in matches:
		if m.get("id", "") == profile.get("id", ""):
			return
	matches.append(profile)
	sympathies[profile["id"]] = 0.5

func set_sympathy(profile_id: String, value: float) -> void:
	sympathies[profile_id] = clampf(value, 0.0, 1.0)

func get_sympathy(profile_id: String) -> float:
	return float(sympathies.get(profile_id, 0.5))
