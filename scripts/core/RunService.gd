extends Node
## Глобальное состояние run-а. Живёт между сценами (autoload).
## Заменяет Run1State.
##
## Терминология:
## - "day" / "run" — один игровой день. Run 1 = первый день, Run 2 = второй и т.д.
## - "energy" — счётчик действий: drop карточки, лайк/диз, ответ в чате.
##   Каждое действие тратит 1 единицу. При 0 — день завершён.

signal _internal_reset

const MAX_ENERGY_BASE: int = 8

var current_day: int = 1
var energy: int = MAX_ENERGY_BASE
var max_energy: int = MAX_ENERGY_BASE

# Статистика дня (сбрасывается на next_day)
var money_earned_today: int = 0
var work_errors_today: int = 0
var work_correct_today: int = 0
var casino_won_today: int = 0
var casino_lost_today: int = 0
var matches_today: int = 0

# Кросс-дневное состояние
var matches: Array[Dictionary] = []
var sympathies: Dictionary = {}
var purchased_upgrades: Array[String] = []
var active_agents: Array[String] = []
var unlocks: Array[String] = []

# Цели дня (заполняются в _ready, проверяются при day_finished)
const DAY1_GOALS: Array[Dictionary] = [
	{"id": "earn_30", "text": "Заработать 30$"},
	{"id": "open_dating", "text": "Проверить дейтинг"},
	{"id": "reply_once", "text": "Ответить на сообщение"},
	{"id": "survive", "text": "Дожить до вечера"},
]
var _goals_state: Dictionary = {}

func _ready() -> void:
	reset()

func reset() -> void:
	current_day = 1
	max_energy = MAX_ENERGY_BASE
	energy = max_energy
	money_earned_today = 0
	work_errors_today = 0
	work_correct_today = 0
	casino_won_today = 0
	casino_lost_today = 0
	matches_today = 0
	matches.clear()
	sympathies.clear()
	purchased_upgrades.clear()
	active_agents.clear()
	unlocks.clear()
	_goals_state.clear()
	for g: Dictionary in DAY1_GOALS:
		_goals_state[g["id"]] = false
	GameEvents.day_changed.emit(current_day)
	GameEvents.energy_changed.emit(energy, max_energy)

func spend_energy(amount: int = 1) -> bool:
	if energy <= 0:
		return false
	energy = max(0, energy - amount)
	GameEvents.energy_changed.emit(energy, max_energy)
	if energy == 0:
		_finish_day()
	return true

func register_money_earned(amount: int) -> void:
	if amount > 0:
		money_earned_today += amount
	if money_earned_today >= 30:
		_mark_goal("earn_30")

func register_work_correct() -> void:
	work_correct_today += 1

func register_work_error() -> void:
	work_errors_today += 1

func register_program_opened(program_id: String) -> void:
	if program_id == "dating":
		_mark_goal("open_dating")

func register_reply_sent() -> void:
	_mark_goal("reply_once")

func register_casino_win(amount: int) -> void:
	if amount > 0:
		casino_won_today += amount

func register_casino_loss(amount: int) -> void:
	if amount > 0:
		casino_lost_today += amount

func register_match_added(profile: Dictionary) -> void:
	matches_today += 1
	matches.append(profile)
	sympathies[profile.get("id", "")] = 0.5

func get_goals_view() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for g: Dictionary in DAY1_GOALS:
		result.append({
			"id": g["id"],
			"text": g["text"],
			"done": bool(_goals_state.get(g["id"], false)),
		})
	return result

func _mark_goal(goal_id: String) -> void:
	if not _goals_state.has(goal_id):
		return
	if _goals_state[goal_id]:
		return
	_goals_state[goal_id] = true
	GameEvents.goal_completed.emit(goal_id)

func _finish_day() -> void:
	_mark_goal("survive")
	var summary: Dictionary = {
		"day": current_day,
		"money_earned": money_earned_today,
		"work_correct": work_correct_today,
		"work_errors": work_errors_today,
		"matches": matches_today,
		"goals": get_goals_view(),
		"verdict": _build_verdict(),
	}
	GameEvents.day_finished.emit(summary)

func next_day() -> void:
	current_day += 1
	max_energy = _compute_max_energy()
	energy = max_energy
	money_earned_today = 0
	work_errors_today = 0
	work_correct_today = 0
	casino_won_today = 0
	casino_lost_today = 0
	matches_today = 0
	for k: String in _goals_state.keys():
		_goals_state[k] = false
	GameEvents.day_changed.emit(current_day)
	apply_agents_for_new_day()
	GameEvents.energy_changed.emit(energy, max_energy)

func apply_agents_for_new_day() -> void:
	if has_agent("mini_delegator"):
		var economy: Node = get_node_or_null("/root/Economy")
		if economy != null:
			economy.add(10)
			GameEvents.event_log_added.emit("Мини-делегатор: +10$ за «работу пока ты спал»")
		if randf() < 0.1 and energy > 0:
			energy = max(0, energy - 1)
			GameEvents.event_log_added.emit("Мини-делегатор: хаос-задача отняла 1 энергию")

func _compute_max_energy() -> int:
	var bonus: int = 0
	if has_upgrade("coffee"):
		bonus += 2
	return MAX_ENERGY_BASE + bonus

func purchase_upgrade(upgrade_id: String, cost: int) -> bool:
	if upgrade_id.is_empty():
		return false
	if has_upgrade(upgrade_id):
		return false
	var economy: Node = get_node_or_null("/root/Economy")
	if economy == null:
		return false
	if int(economy.money) < cost:
		return false
	if not economy.spend(cost):
		return false
	purchased_upgrades.append(upgrade_id)
	GameEvents.upgrade_purchased.emit(upgrade_id)
	return true

func has_upgrade(upgrade_id: String) -> bool:
	return purchased_upgrades.has(upgrade_id)

func purchase_agent(agent_id: String, cost: int) -> bool:
	if agent_id.is_empty():
		return false
	if has_agent(agent_id):
		return false
	var economy: Node = get_node_or_null("/root/Economy")
	if economy == null:
		return false
	if int(economy.money) < cost:
		return false
	if not economy.spend(cost):
		return false
	active_agents.append(agent_id)
	GameEvents.agent_hired.emit(agent_id)
	return true

func has_agent(agent_id: String) -> bool:
	return active_agents.has(agent_id)

func unlock(program_id: String) -> void:
	if program_id.is_empty():
		return
	if unlocks.has(program_id):
		return
	unlocks.append(program_id)

func has_unlock(program_id: String) -> bool:
	return unlocks.has(program_id)

func _build_verdict() -> String:
	if money_earned_today >= 50:
		return "Подозрительно продуктивно. Тревожно."
	if money_earned_today >= 30:
		return "День прожит без позора."
	return "Ты почти функционировал. Почти."
