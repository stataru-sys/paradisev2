extends Control
## Мини-игра «Дейтинг» — свайпы Диз/Лайк, при совпадении лайк+лайк создаётся матч
## и добавляется в Run1State.matches. После 5 свайпов вылезает «Пора работать».

const PROFILES: Array[Dictionary] = [
	{"id": "anya", "name": "Аня, 24", "bio": "Промпт-инженер. Ищу того, кто понимает, что reset_history() — это про чувства.", "match_chance": 0.6},
	{"id": "lena", "name": "Лена, 27", "bio": "Бывшая UX-дизайнер, ныне фермер агентов на фриланс-бирже.", "match_chance": 0.3},
	{"id": "kris", "name": "Крис, 30", "bio": "Не хочу серьёзных. Хочу серьёзных. Я в процессе. Алгоритм тоже.", "match_chance": 0.45},
	{"id": "marina", "name": "Марина, 23", "bio": "Если ты сам отвечаешь на свои сообщения — мы уже совместимы.", "match_chance": 0.8},
	{"id": "dasha", "name": "Даша, 29", "bio": "Кошки, фронтенд, антидепрессанты. Не обязательно в этом порядке.", "match_chance": 0.5},
	{"id": "polina", "name": "Полина, 26", "bio": "Завтра рано. И послезавтра тоже.", "match_chance": 0.2},
]
const WORK_HINT_AFTER_SWIPES: int = 5

@export var back_button_path: NodePath
@export var like_button_path: NodePath
@export var dislike_button_path: NodePath
@export var name_label_path: NodePath
@export var bio_label_path: NodePath
@export var work_hint_path: NodePath
@export var match_toast_path: NodePath
@export var swipe_counter_path: NodePath

var _state: Run1State
var _index: int = 0
var _swipes: int = 0

@onready var _back_button: Button = get_node(back_button_path) as Button
@onready var _like_button: Button = get_node(like_button_path) as Button
@onready var _dislike_button: Button = get_node(dislike_button_path) as Button
@onready var _name_label: Label = get_node(name_label_path) as Label
@onready var _bio_label: Label = get_node(bio_label_path) as Label
@onready var _work_hint: Label = get_node(work_hint_path) as Label
@onready var _match_toast: Label = get_node(match_toast_path) as Label
@onready var _swipe_counter: Label = get_node(swipe_counter_path) as Label

func attach_state(state: Run1State) -> void:
	_state = state

func _ready() -> void:
	_work_hint.visible = false
	_match_toast.visible = false
	_back_button.pressed.connect(func() -> void: GameEvents.program_closed.emit())
	_like_button.pressed.connect(_on_like)
	_dislike_button.pressed.connect(_on_dislike)
	_show_current()

func _show_current() -> void:
	if _index >= PROFILES.size():
		_name_label.text = "Тиндер закончился"
		_bio_label.text = "Серьёзно. Алгоритмы тоже устают."
		_like_button.disabled = true
		_dislike_button.disabled = true
		return
	var p: Dictionary = PROFILES[_index]
	_name_label.text = String(p["name"])
	_bio_label.text = String(p["bio"])
	_swipe_counter.text = "Свайпов: %d" % _swipes
	if _swipes >= WORK_HINT_AFTER_SWIPES:
		_work_hint.visible = true

func _on_like() -> void:
	var p: Dictionary = PROFILES[_index]
	var roll: float = randf()
	if roll < float(p["match_chance"]):
		if _state != null:
			_state.add_match(p)
		GameEvents.dating_match_added.emit(String(p["id"]))
		_match_toast.text = "Матч с %s!" % String(p["name"])
		_match_toast.visible = true
		var timer: SceneTreeTimer = get_tree().create_timer(1.0)
		timer.timeout.connect(func() -> void: _match_toast.visible = false)
	_advance()

func _on_dislike() -> void:
	_advance()

func _advance() -> void:
	_index += 1
	_swipes += 1
	_show_current()
