extends Control
## Мини-игра «Фикс багов» — сопоставление баг ↔ правильный фикс.
## Сатира: «Баг — это фича, которую ещё не переименовали.
## А переименовать — твоя работа.»
##
## Механика: 3 бага слева, 3 фикса справа (перемешаны). Клик баг → клик фикс.
## Правильный фикс +5$, баг закрыт. Ошибка −1$ и порождает новый баг (каскад).
## Багов больше 5 → провал, 0$. Все закрыты без ошибок → бонус +5$.
## Энергия −2 списывается при старте мини-игры (в WorkHub).

const BUGS: Array[Dictionary] = [
	{
		"bug": "Кнопка исчезает после клика",
		"fix": "Проверить visible в _on_pressed",
		"traps": ["Переименовать кнопку", "Удалить сцену", "Сказать что это фича"],
	},
	{
		"bug": "Энергия не тратится",
		"fix": "Добавить spend_energy в метод",
		"traps": ["Увеличить max_energy", "Перезагрузить ноут", "Купить ещё энергии"],
	},
	{
		"bug": "Агент продаёт переписку налево",
		"fix": "Отозвать API-ключ агента",
		"traps": ["Купить второй ключ", "Обновить драйвер", "Дать агенту премию"],
	},
	{
		"bug": "Сейв перезаписывается пустым",
		"fix": "Проверять save_version перед записью",
		"traps": ["Удалить старый сейв", "Сохраняться почаще", "Запретить выходить из игры"],
	},
	{
		"bug": "Деньги уходят в минус",
		"fix": "Добавить clamp в Economy.add",
		"traps": ["Спрятать счётчик денег", "Объявить долг фичей", "Переименовать в «инвестиции»"],
	},
	{
		"bug": "Игра вылетает при смене дня",
		"fix": "Вызвать reset() перед сменой сцены",
		"traps": ["Убрать смену дня", "Ловить краш в try", "Просить игрока не спешить"],
	},
	{
		"bug": "Текст вылезает за край экрана",
		"fix": "Включить autowrap у Label",
		"traps": ["Уменьшить шрифт до 2px", "Купить монитор пошире", "Писать покороче"],
	},
	{
		"bug": "Звук уведомления играет дважды",
		"fix": "Убрать дубль AudioStreamPlayer",
		"traps": ["Сделать вид что это стерео", "Выключить звук совсем", "Списать на наушники"],
	},
	{
		"bug": "Кнопка «Назад» ведёт вперёд",
		"fix": "Поменять местами connect-сигналы",
		"traps": ["Переименовать в «Вперёд»", "Убрать кнопку", "Сказать что так задумано"],
	},
	{
		"bug": "FPS падает до трёх кадров",
		"fix": "Убрать тяжёлый цикл из _process",
		"traps": ["Назвать это кинематографичностью", "Просить новый ноутбук", "Добавить экран загрузки"],
	},
	{
		"bug": "Письма не доходят до Почты",
		"fix": "Подписаться на сигнал mail_received",
		"traps": ["Удалить папку «Входящие»", "Сказать что почты нет", "Перезагрузить роутер"],
	},
	{
		"bug": "Агент зациклил сам себя",
		"fix": "Добавить выход из рекурсии",
		"traps": ["Дать агенту второй ноутбук", "Подождать пока остановится", "Назвать вечным двигателем"],
	},
]

const FIX_REWARD: int = 5
const ERROR_PENALTY: int = 1
const FLAWLESS_BONUS: int = 5
const INITIAL_BUGS: int = 3
const FAIL_THRESHOLD: int = 5
const WORK_RESULT_SCENE: String = "res://scenes/run2/WorkResult.tscn"
const SATIRE_LINE: String = "Баг — это фича, которую ещё не переименовали. Переименовать — твоя работа."

const SELECTED_TINT: Color = Color(1, 0.84, 0.4)
const NEUTRAL_TINT: Color = Color(1, 1, 1)
const FEEDBACK_HINT: Color = Color(0.6, 0.6, 0.667)
const FEEDBACK_GOOD: Color = Color(0.467, 0.8, 0.533)
const FEEDBACK_BAD: Color = Color(0.867, 0.4, 0.333)
const FEEDBACK_WARN: Color = Color(0.867, 0.8, 0.467)

@export var progress_label_path: NodePath
@export var earned_label_path: NodePath
@export var back_button_path: NodePath
@export var bugs_box_path: NodePath
@export var fixes_box_path: NodePath
@export var feedback_label_path: NodePath

@onready var _progress_label: Label = get_node(progress_label_path) as Label
@onready var _earned_label: Label = get_node(earned_label_path) as Label
@onready var _back_button: Button = get_node(back_button_path) as Button
@onready var _bugs_box: VBoxContainer = get_node(bugs_box_path) as VBoxContainer
@onready var _fixes_box: VBoxContainer = get_node(fixes_box_path) as VBoxContainer
@onready var _feedback_label: Label = get_node(feedback_label_path) as Label

var _active_bugs: Array[Dictionary] = []
var _earned: int = 0
var _errors: int = 0
var _energy_spent: int = 2  # списано при старте в WorkHub
var _selected_bug_index: int = -1
var _game_over: bool = false
var _paid_closures_remaining: int = INITIAL_BUGS

func _ready() -> void:
	_back_button.pressed.connect(func() -> void: GameEvents.program_closed.emit())

	var pool: Array[Dictionary] = BUGS.duplicate()
	pool.shuffle()
	_active_bugs = pool.slice(0, INITIAL_BUGS)

	_show_feedback(SATIRE_LINE, FEEDBACK_HINT)
	_rebuild_columns()
	_update_progress()
	_update_earned_label()

func _rebuild_columns() -> void:
	for child: Node in _bugs_box.get_children():
		_bugs_box.remove_child(child)
		child.queue_free()
	for child: Node in _fixes_box.get_children():
		_fixes_box.remove_child(child)
		child.queue_free()

	for i: int in range(_active_bugs.size()):
		var bug: Dictionary = _active_bugs[i]
		var bug_index: int = i
		var bug_btn: Button = _make_slot_button(String(bug["bug"]))
		bug_btn.pressed.connect(func() -> void: _on_bug_clicked(bug_index))
		_bugs_box.add_child(bug_btn)

	var fixes: Array[String] = []
	for bug: Dictionary in _active_bugs:
		fixes.append(String(bug["fix"]))
	fixes.shuffle()
	for fix_text: String in fixes:
		var captured_fix: String = fix_text
		var fix_btn: Button = _make_slot_button(captured_fix)
		fix_btn.pressed.connect(func() -> void: _on_fix_clicked(captured_fix))
		_fixes_box.add_child(fix_btn)

	_selected_bug_index = -1

func _make_slot_button(text: String) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 52)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 14)
	return btn

func _on_bug_clicked(index: int) -> void:
	if _game_over:
		return
	if index < 0 or index >= _active_bugs.size():
		return
	_selected_bug_index = index
	_highlight_selection()
	_show_feedback("Баг выбран. Кликни нужный фикс справа.", FEEDBACK_HINT)

func _highlight_selection() -> void:
	for i: int in range(_bugs_box.get_child_count()):
		var btn: Button = _bugs_box.get_child(i) as Button
		if btn == null:
			continue
		btn.modulate = SELECTED_TINT if i == _selected_bug_index else NEUTRAL_TINT

func _on_fix_clicked(fix_text: String) -> void:
	if _game_over:
		return
	if _selected_bug_index < 0 or _selected_bug_index >= _active_bugs.size():
		_show_feedback("Сначала выбери баг слева.", FEEDBACK_WARN)
		return

	var bug: Dictionary = _active_bugs[_selected_bug_index]
	if fix_text == String(bug["fix"]):
		_active_bugs.remove_at(_selected_bug_index)
		if _paid_closures_remaining > 0:
			_earned += FIX_REWARD
			_paid_closures_remaining -= 1
			_show_feedback("Баг закрыт. +%d$" % FIX_REWARD, FEEDBACK_GOOD)
		else:
			_show_feedback("Баг закрыт. Этот — твой косяк, чинишь бесплатно.", FEEDBACK_WARN)
		_update_earned_label()
		_rebuild_columns()
		_update_progress()
		if _active_bugs.is_empty():
			_finish_game()
	else:
		_earned -= ERROR_PENALTY
		_errors += 1
		_show_feedback("Не тот фикс. Баг расплодился. −%d$" % ERROR_PENALTY, FEEDBACK_BAD)
		_spawn_new_bug()
		_update_earned_label()
		if _active_bugs.size() > FAIL_THRESHOLD:
			_fail_game()
			return
		_rebuild_columns()
		_update_progress()

func _spawn_new_bug() -> void:
	var candidates: Array[Dictionary] = []
	for bug: Dictionary in BUGS:
		if not _is_bug_active(bug):
			candidates.append(bug)
	if candidates.is_empty():
		candidates = BUGS.duplicate()
	_active_bugs.append(candidates[randi() % candidates.size()])

func _is_bug_active(bug: Dictionary) -> bool:
	for active: Dictionary in _active_bugs:
		if String(active["bug"]) == String(bug["bug"]):
			return true
	return false

func _finish_game() -> void:
	_game_over = true
	if _errors == 0:
		_earned += FLAWLESS_BONUS
		_update_earned_label()
		_show_feedback("Все баги закрыты без ошибок. Баг-слеер. Бонус +%d$." % FLAWLESS_BONUS, FEEDBACK_GOOD)
	else:
		_show_feedback("Баги закрыты. Не идеально, но закрыты.", FEEDBACK_GOOD)
	_show_result("")

func _fail_game() -> void:
	_game_over = true
	_earned = 0
	_update_earned_label()
	_update_progress()
	_show_feedback("Багов слишком много. Передано в аутсорс.", FEEDBACK_BAD)
	_show_result("Багов столько, что проект передали в аутсорс. Деньги — тоже.")

func _show_result(comment_override: String) -> void:
	var scene: PackedScene = load(WORK_RESULT_SCENE) as PackedScene
	if scene == null:
		return
	var result: Control = scene.instantiate() as Control
	add_child(result)
	result.anchor_right = 1
	result.anchor_bottom = 1
	result.setup(_earned, _errors, _energy_spent, comment_override)

	var economy: Node = get_node_or_null("/root/Economy")
	if economy != null and _earned != 0:
		economy.add(_earned)
	var run: Node = get_node_or_null("/root/RunService")
	if run != null:
		run.register_money_earned(_earned)
	GameEvents.work_day_finished.emit(_earned)

func _update_progress() -> void:
	_progress_label.text = "Багов: %d" % _active_bugs.size()

func _update_earned_label() -> void:
	_earned_label.text = "%+d$" % _earned

func _show_feedback(text: String, color: Color) -> void:
	_feedback_label.text = text
	_feedback_label.add_theme_color_override("font_color", color)
