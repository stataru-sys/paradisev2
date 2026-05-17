extends Control
## Мини-игра «Почта» — переписки с матчами, 3 случайных ответа, шкала симпатии.

const REPLY_POOL: Array[String] = [
	"Я вообще-то занят, но красиво страдаю",
	"Мой карьерный рост держится на скотче",
	"Давай после дедлайна, если он меня не добьёт",
	"Я умею слушать. Иногда даже людей",
	"Звучит как план, а планы я боюсь",
	"Поехали в IKEA, заодно проверим совместимость",
	"У меня кошка ревнует. Это её дом",
	"Скажи что-нибудь умное, я скриншот сделаю",
	"Я не пью кофе. Я пью дедлайны",
	"Романтика умерла вместе с email-этикетом",
]
const REACTIONS_POS: Array[String] = [
	"Ха, занятно. Расскажи ещё.",
	"Окей, ты странный, но мне нравится",
	"Когда увидимся?",
	"Я смеюсь. И не только из вежливости.",
]
const REACTIONS_NEG: Array[String] = [
	"Это было... необычно. До свидания.",
	"Ага. Удачи в твоих делах.",
	"Не пиши больше пожалуйста",
	"Слишком много букв.",
]
const SYMPATHY_STEP: float = 0.1
const SUCCESS_TEXT: String = "Договорились о свидании. Бронируй ресторан."
const FAIL_TEXT: String = "Тебя забанили. Алгоритм всё видел."

@export var back_button_path: NodePath
@export var matches_box_path: NodePath
@export var empty_label_path: NodePath
@export var body_path: NodePath
@export var dialog_name_path: NodePath
@export var sympathy_bar_path: NodePath
@export var dialog_box_path: NodePath
@export var reply_buttons_box_path: NodePath
@export var outcome_label_path: NodePath

var _state: Run1State
var _current_id: String = ""

@onready var _back_button: Button = get_node(back_button_path) as Button
@onready var _matches_box: VBoxContainer = get_node(matches_box_path) as VBoxContainer
@onready var _empty_label: Label = get_node(empty_label_path) as Label
@onready var _body: Control = get_node(body_path) as Control
@onready var _dialog_name: Label = get_node(dialog_name_path) as Label
@onready var _sympathy_bar: ProgressBar = get_node(sympathy_bar_path) as ProgressBar
@onready var _dialog_box: VBoxContainer = get_node(dialog_box_path) as VBoxContainer
@onready var _reply_buttons_box: HBoxContainer = get_node(reply_buttons_box_path) as HBoxContainer
@onready var _outcome_label: Label = get_node(outcome_label_path) as Label

func attach_state(state: Run1State) -> void:
	_state = state
	if is_node_ready():
		_refresh_matches_list()

func _ready() -> void:
	_back_button.pressed.connect(func() -> void: GameEvents.program_closed.emit())
	_outcome_label.visible = false
	_refresh_matches_list()

func _refresh_matches_list() -> void:
	for c: Node in _matches_box.get_children():
		c.queue_free()
	var has_matches: bool = _state != null and _state.matches.size() > 0
	_empty_label.visible = not has_matches
	_body.visible = has_matches
	if not has_matches:
		_empty_label.text = "Пока никто не пишет. Даже алгоритмы заняты."
		return
	for m: Dictionary in _state.matches:
		var btn: Button = Button.new()
		btn.text = String(m["name"])
		btn.custom_minimum_size = Vector2(180, 40)
		var profile_id: String = String(m["id"])
		btn.pressed.connect(func() -> void: _open_chat(profile_id))
		_matches_box.add_child(btn)
	if _current_id.is_empty():
		_open_chat(String(_state.matches[0]["id"]))

func _open_chat(profile_id: String) -> void:
	_current_id = profile_id
	var name_for: String = profile_id
	for m: Dictionary in _state.matches:
		if String(m["id"]) == profile_id:
			name_for = String(m["name"])
			break
	_dialog_name.text = name_for
	_sympathy_bar.value = _state.get_sympathy(profile_id) * 100.0
	_outcome_label.visible = false
	for c: Node in _dialog_box.get_children():
		c.queue_free()
	_roll_reply_buttons()

func _roll_reply_buttons() -> void:
	for c: Node in _reply_buttons_box.get_children():
		c.queue_free()
	var pool: Array[String] = REPLY_POOL.duplicate()
	pool.shuffle()
	for i: int in range(min(3, pool.size())):
		var phrase: String = pool[i]
		var btn: Button = Button.new()
		btn.text = phrase
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.custom_minimum_size = Vector2(0, 60)
		btn.pressed.connect(func() -> void: _on_reply_picked(phrase))
		_reply_buttons_box.add_child(btn)

func _on_reply_picked(phrase: String) -> void:
	_append_line("Ты", phrase)
	var positive: bool = randf() < 0.5
	var sympathy: float = _state.get_sympathy(_current_id)
	sympathy += SYMPATHY_STEP if positive else -SYMPATHY_STEP
	_state.set_sympathy(_current_id, sympathy)
	var reaction: String = _pick_reaction(positive)
	_append_line(_dialog_name.text, reaction)
	_sympathy_bar.value = _state.get_sympathy(_current_id) * 100.0
	GameEvents.sympathy_changed.emit(_current_id, _state.get_sympathy(_current_id))
	if _state.get_sympathy(_current_id) >= 1.0:
		_outcome_label.text = SUCCESS_TEXT
		_outcome_label.visible = true
	elif _state.get_sympathy(_current_id) <= 0.0:
		_outcome_label.text = FAIL_TEXT
		_outcome_label.visible = true
	else:
		_roll_reply_buttons()
		return
	for c: Node in _reply_buttons_box.get_children():
		c.queue_free()

func _pick_reaction(positive: bool) -> String:
	var pool: Array[String] = REACTIONS_POS if positive else REACTIONS_NEG
	return pool[randi() % pool.size()]

func _append_line(speaker: String, text: String) -> void:
	var lbl: Label = Label.new()
	lbl.text = "%s: %s" % [speaker, text]
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_box.add_child(lbl)
