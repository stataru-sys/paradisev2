extends Control
## Программа «Казино «Парадайз»». 3 ставки (10/25/50), 5 исходов с разным шансом,
## история последних 5 круток.
##
## Распределение исходов (накопительные пороги):
##   roll < 0.45 → x0 (проигрыш на bet)
##   roll < 0.75 → x1 (вернули ставку)
##   roll < 0.90 → x2
##   roll < 0.98 → x3
##   roll < 1.00 → x7

const BETS: Array[int] = [10, 25, 50]
const HISTORY_MAX: int = 5

const OUTCOMES: Array[Dictionary] = [
	{"threshold": 0.45, "multiplier": 0, "text": "Ничего. Просто ничего."},
	{"threshold": 0.75, "multiplier": 1, "text": "Вернули ставку. Спасибо. Наверное."},
	{"threshold": 0.90, "multiplier": 2, "text": "x2. Сегодня ты молодец."},
	{"threshold": 0.98, "multiplier": 3, "text": "x3. Это даже немного подозрительно."},
	{"threshold": 1.00, "multiplier": 7, "text": "x7. Ты сорвал джекпот. Лучше уходи прямо сейчас."},
]

@export var back_button_path: NodePath
@export var money_label_path: NodePath
@export var energy_label_path: NodePath
@export var selection_label_path: NodePath
@export var bet_buttons_box_path: NodePath
@export var spin_button_path: NodePath
@export var history_box_path: NodePath
@export var empty_history_label_path: NodePath

@onready var _run: Node = get_node("/root/RunService")
@onready var _economy: Node = get_node("/root/Economy")
@onready var _back_button: Button = get_node(back_button_path) as Button
@onready var _money_label: Label = get_node(money_label_path) as Label
@onready var _energy_label: Label = get_node(energy_label_path) as Label
@onready var _selection_label: Label = get_node(selection_label_path) as Label
@onready var _bet_buttons_box: HBoxContainer = get_node(bet_buttons_box_path) as HBoxContainer
@onready var _spin_button: Button = get_node(spin_button_path) as Button
@onready var _history_box: VBoxContainer = get_node(history_box_path) as VBoxContainer
@onready var _empty_history_label: Label = get_node(empty_history_label_path) as Label

var _selected_bet: int = -1
var _bet_buttons: Array[Button] = []

func _ready() -> void:
	_back_button.pressed.connect(func() -> void: GameEvents.program_closed.emit())
	_spin_button.pressed.connect(_on_spin_pressed)
	GameEvents.money_changed.connect(_on_money_changed)
	GameEvents.energy_changed.connect(_on_energy_changed)
	_build_bet_buttons()
	_on_money_changed(int(_economy.money))
	_on_energy_changed(int(_run.energy), int(_run.max_energy))
	_refresh_empty_history()

func _build_bet_buttons() -> void:
	for c: Node in _bet_buttons_box.get_children():
		c.queue_free()
	_bet_buttons.clear()
	for bet: int in BETS:
		var btn: Button = Button.new()
		btn.text = "%d$" % bet
		btn.custom_minimum_size = Vector2(80, 44)
		var bet_value: int = bet
		btn.pressed.connect(func() -> void: _select_bet(bet_value))
		_bet_buttons_box.add_child(btn)
		_bet_buttons.append(btn)
	_update_bet_button_states()

func _select_bet(bet: int) -> void:
	_selected_bet = bet
	_selection_label.text = "Выбрана ставка: %d$" % bet
	_update_bet_button_states()
	_update_spin_button_state()

func _update_bet_button_states() -> void:
	for i: int in range(_bet_buttons.size()):
		var btn: Button = _bet_buttons[i]
		var bet: int = BETS[i]
		btn.disabled = int(_economy.money) < bet
		btn.modulate = Color(1, 1, 1, 1) if bet == _selected_bet else Color(0.85, 0.85, 0.85, 1)

func _update_spin_button_state() -> void:
	if _selected_bet <= 0:
		_spin_button.disabled = true
		return
	if int(_economy.money) < _selected_bet:
		_spin_button.disabled = true
		return
	_spin_button.disabled = int(_run.energy) <= 0

func _on_money_changed(value: int) -> void:
	_money_label.text = "Деньги: %d$" % value
	if _selected_bet > 0 and value < _selected_bet:
		_selected_bet = -1
		_selection_label.text = "Выбери ставку"
	_update_bet_button_states()
	_update_spin_button_state()

func _on_energy_changed(current: int, max_val: int) -> void:
	_energy_label.text = "Энергия %d/%d" % [current, max_val]
	_update_spin_button_state()

func _on_spin_pressed() -> void:
	if _selected_bet <= 0:
		return
	if int(_run.energy) <= 0:
		return
	if int(_economy.money) < _selected_bet:
		return
	var bet: int = _selected_bet
	_economy.spend(bet)
	var outcome: Dictionary = _roll_outcome()
	var multiplier: int = int(outcome["multiplier"])
	var payout: int = bet * multiplier
	if payout > 0:
		_economy.add(payout)
	var delta: int = payout - bet
	if delta > 0:
		_run.register_casino_win(delta)
	elif multiplier == 0:
		_run.register_casino_loss(bet)
	_push_history(bet, outcome, delta)
	GameEvents.event_log_added.emit("Казино: %s (%s$)" % [String(outcome["text"]), _format_delta(delta)])
	_run.spend_energy(1)

func _roll_outcome() -> Dictionary:
	var roll: float = randf()
	for outcome: Dictionary in OUTCOMES:
		if roll < float(outcome["threshold"]):
			return outcome
	return OUTCOMES[OUTCOMES.size() - 1]

func _push_history(bet: int, outcome: Dictionary, delta: int) -> void:
	var line: Label = Label.new()
	line.text = "Ставка %d$ → %s (%s$)" % [bet, String(outcome["text"]), _format_delta(delta)]
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if delta > 0:
		line.modulate = Color(0.7, 0.95, 0.7)
	elif delta < 0:
		line.modulate = Color(0.95, 0.6, 0.6)
	else:
		line.modulate = Color(0.9, 0.9, 0.9)
	_history_box.add_child(line)
	_history_box.move_child(line, 0)
	while _history_box.get_child_count() > HISTORY_MAX:
		_history_box.get_child(_history_box.get_child_count() - 1).queue_free()
	_refresh_empty_history()

func _refresh_empty_history() -> void:
	_empty_history_label.visible = _history_box.get_child_count() == 0

func _format_delta(delta: int) -> String:
	if delta > 0:
		return "+%d" % delta
	return "%d" % delta
