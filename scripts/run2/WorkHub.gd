extends Control
## WorkHub — экран выбора работы между Desktop и мини-игрой.
## Показывает доступные и заблокированные работы, хостит мини-игру внутри себя.

const WORK_PROGRAM_SCENE: String = "res://scenes/run1/WorkProgram.tscn"

@export var energy_label_path: NodePath
@export var back_button_path: NodePath
@export var cards_list_path: NodePath
@export var start_sorting_button_path: NodePath
@export var game_host_path: NodePath

@onready var _energy_label: Label = get_node(energy_label_path) as Label
@onready var _back_button: Button = get_node(back_button_path) as Button
@onready var _cards_list: Control = get_node(cards_list_path) as Control
@onready var _start_sorting_btn: Button = get_node(start_sorting_button_path) as Button
@onready var _game_host: Control = get_node(game_host_path) as Control
@onready var _run: Node = get_node("/root/RunService")

func _ready() -> void:
	_game_host.visible = false
	_update_energy()
	GameEvents.energy_changed.connect(_on_energy_changed)
	_back_button.pressed.connect(func() -> void: GameEvents.program_closed.emit())
	_start_sorting_btn.pressed.connect(_on_start_sorting)

func _update_energy() -> void:
	_energy_label.text = "Энергия %d/%d" % [int(_run.energy), int(_run.max_energy)]
	_start_sorting_btn.disabled = int(_run.energy) <= 0

func _on_energy_changed(_current: int, _max_val: int) -> void:
	_update_energy()

func _on_start_sorting() -> void:
	if int(_run.energy) <= 0:
		return
	if _game_host.get_child_count() > 0:
		return
	_cards_list.visible = false
	_game_host.visible = true

	var scene: PackedScene = load(WORK_PROGRAM_SCENE) as PackedScene
	var game: Control = scene.instantiate() as Control
	_game_host.add_child(game)
	game.anchor_right = 1
	game.anchor_bottom = 1

	_reconnect_game_button(game, "_back_button")
	GameEvents.work_day_finished.connect(_on_game_finished, CONNECT_ONE_SHOT)

func _reconnect_game_button(game: Control, prop_name: String) -> void:
	var btn: Button = game.get(prop_name) as Button
	if btn == null:
		return
	for conn: Dictionary in btn.pressed.get_connections():
		btn.pressed.disconnect(conn["callable"])
	btn.pressed.connect(_on_game_return)

func _on_game_finished(_earned: int) -> void:
	var game: Node = _game_host.get_child(0) if _game_host.get_child_count() > 0 else null
	if game == null:
		return
	for c: Node in game.get_children():
		if c.name == "WorkResult" and c.has_signal("return_to_hub"):
			c.connect("return_to_hub", _on_game_return)
			return

func _on_game_return() -> void:
	for c: Node in _game_host.get_children():
		c.queue_free()
	_game_host.visible = false
	_cards_list.visible = true
	_update_energy()
