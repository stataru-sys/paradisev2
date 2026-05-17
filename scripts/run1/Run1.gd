extends Control
## Root-контроллер первого Run-а. Два вида:
##   1. RoomOverview — общий план комнаты (старт-экран Run 1).
##   2. Computer — крупный план монитора, программы рендерятся в его экране.
## Переход overview → computer по клику на иконку компа в общем плане;
## обратно — кнопкой "← Встать" в Computer-виде.

const SCENE_PATHS: Dictionary = {
	"desktop": "res://scenes/run1/Desktop.tscn",
	"work": "res://scenes/run1/WorkProgram.tscn",
	"dating": "res://scenes/run1/DatingProgram.tscn",
	"mail": "res://scenes/run1/MailProgram.tscn",
}

@export var program_host_path: NodePath
@export var earned_label_path: NodePath
@export var start_overlay_path: NodePath
@export var power_button_path: NodePath
@export var view_overview_path: NodePath
@export var view_computer_path: NodePath
@export var computer_button_path: NodePath
@export var leave_button_path: NodePath

var _state: Run1State = Run1State.new()
@onready var _program_host: Control = get_node(program_host_path) as Control
@onready var _earned_label: Label = get_node(earned_label_path) as Label
@onready var _start_overlay: Control = get_node(start_overlay_path) as Control
@onready var _power_button: Button = get_node(power_button_path) as Button
@onready var _view_overview: Control = get_node(view_overview_path) as Control
@onready var _view_computer: Control = get_node(view_computer_path) as Control
@onready var _computer_button: Button = get_node(computer_button_path) as Button
@onready var _leave_button: Button = get_node(leave_button_path) as Button

func _ready() -> void:
	GameEvents.program_open_requested.connect(_on_program_open_requested)
	GameEvents.program_closed.connect(_on_program_closed)
	GameEvents.work_day_finished.connect(_on_work_day_finished)
	GameEvents.money_changed.connect(_on_money_changed)
	_earned_label.text = "$0"
	_start_overlay.visible = true
	_power_button.pressed.connect(_on_power_pressed)
	_computer_button.pressed.connect(_on_computer_clicked)
	_leave_button.pressed.connect(_on_leave_clicked)
	_show_overview()

func _show_overview() -> void:
	_view_overview.visible = true
	_view_computer.visible = false

func _show_computer() -> void:
	_view_overview.visible = false
	_view_computer.visible = true

func _on_computer_clicked() -> void:
	_show_computer()

func _on_leave_clicked() -> void:
	_show_overview()

func _on_power_pressed() -> void:
	_start_overlay.visible = false
	_open_program("desktop")

func _on_program_open_requested(program_id: String) -> void:
	_open_program(program_id)

func _on_program_closed() -> void:
	_open_program("desktop")

func _on_work_day_finished(earned: int) -> void:
	_state.earned_today += earned

func _on_money_changed(value: int) -> void:
	_earned_label.text = "$%d" % value

func _open_program(program_id: String) -> void:
	for c: Node in _program_host.get_children():
		c.queue_free()
	var path: String = String(SCENE_PATHS.get(program_id, ""))
	if path.is_empty():
		return
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		return
	var program: Node = scene.instantiate()
	if program.has_method("attach_state"):
		program.call("attach_state", _state)
	_program_host.add_child(program)
	if program is Control:
		var c: Control = program as Control
		c.anchor_right = 1
		c.anchor_bottom = 1
