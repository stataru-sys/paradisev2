extends Control
## Root-контроллер первого Run-а. Держит Run1State и переключает программы.

const SCENE_PATHS: Dictionary = {
	"desktop": "res://scenes/run1/Desktop.tscn",
	"work": "res://scenes/run1/WorkProgram.tscn",
	"dating": "res://scenes/run1/DatingProgram.tscn",
	"mail": "res://scenes/run1/MailProgram.tscn",
}

@export var program_host_path: NodePath
@export var earned_label_path: NodePath

var _state: Run1State = Run1State.new()
@onready var _program_host: Control = get_node(program_host_path) as Control
@onready var _earned_label: Label = get_node(earned_label_path) as Label

func _ready() -> void:
	GameEvents.program_open_requested.connect(_on_program_open_requested)
	GameEvents.program_closed.connect(_on_program_closed)
	GameEvents.work_day_finished.connect(_on_work_day_finished)
	GameEvents.money_changed.connect(_on_money_changed)
	_earned_label.text = "$0"
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
