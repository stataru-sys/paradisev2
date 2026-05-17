extends Control
## Root-контроллер Run 2. Логика та же что в Run1.gd, но Desktop = Desktop2 (6 иконок).
## Подписан на RunService: обновляет шапку (день / деньги / энергия) и цели дня,
## по day_finished показывает DaySummary поверх всего.

const SCENE_PATHS: Dictionary = {
	"desktop": "res://scenes/run2/Desktop2.tscn",
	"work": "res://scenes/run1/WorkProgram.tscn",
	"dating": "res://scenes/run1/DatingProgram.tscn",
	"mail": "res://scenes/run1/MailProgram.tscn",
	"shop": "res://scenes/run2/ShopApp.tscn",
	"casino": "res://scenes/run2/CasinoApp.tscn",
	"agents": "res://scenes/run2/AgentShopApp.tscn",
}
const DAY_SUMMARY_SCENE: String = "res://scenes/run1/DaySummary.tscn"

@export var program_host_path: NodePath
@export var earned_label_path: NodePath
@export var day_label_path: NodePath
@export var energy_label_path: NodePath
@export var start_overlay_path: NodePath
@export var power_button_path: NodePath
@export var view_overview_path: NodePath
@export var view_computer_path: NodePath
@export var computer_button_path: NodePath
@export var leave_button_path: NodePath
@export var goals_box_path: NodePath

@onready var _run: Node = get_node("/root/RunService")
@onready var _program_host: Control = get_node(program_host_path) as Control
@onready var _earned_label: Label = get_node(earned_label_path) as Label
@onready var _day_label: Label = get_node(day_label_path) as Label
@onready var _energy_label: Label = get_node(energy_label_path) as Label
@onready var _start_overlay: Control = get_node(start_overlay_path) as Control
@onready var _power_button: Button = get_node(power_button_path) as Button
@onready var _view_overview: Control = get_node(view_overview_path) as Control
@onready var _view_computer: Control = get_node(view_computer_path) as Control
@onready var _computer_button: Button = get_node(computer_button_path) as Button
@onready var _leave_button: Button = get_node(leave_button_path) as Button
@onready var _goals_box: VBoxContainer = get_node(goals_box_path) as VBoxContainer

var _day_summary_open: bool = false

func _ready() -> void:
	if not _run.has_unlock("shop"):
		_run.unlock("shop")
	if not _run.has_unlock("casino"):
		_run.unlock("casino")
	if not _run.has_unlock("agents"):
		_run.unlock("agents")
	GameEvents.program_open_requested.connect(_on_program_open_requested)
	GameEvents.program_closed.connect(_on_program_closed)
	GameEvents.work_day_finished.connect(_on_work_day_finished)
	GameEvents.money_changed.connect(_on_money_changed)
	GameEvents.day_changed.connect(_on_day_changed)
	GameEvents.energy_changed.connect(_on_energy_changed)
	GameEvents.goal_completed.connect(_on_goal_completed)
	GameEvents.day_finished.connect(_on_day_finished)
	_earned_label.text = "$0"
	_on_day_changed(int(_run.current_day))
	_on_energy_changed(int(_run.energy), int(_run.max_energy))
	_rebuild_goals()
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
	_run.register_program_opened(program_id)
	_open_program(program_id)

func _on_program_closed() -> void:
	_open_program("desktop")

func _on_work_day_finished(_earned: int) -> void:
	pass

func _on_money_changed(value: int) -> void:
	_earned_label.text = "$%d" % value

func _on_day_changed(day: int) -> void:
	_day_label.text = "День %d" % day
	_rebuild_goals()

func _on_energy_changed(current: int, max_val: int) -> void:
	_energy_label.text = "Энергия %d/%d" % [current, max_val]

func _on_goal_completed(_goal_id: String) -> void:
	_rebuild_goals()

func _on_day_finished(summary: Dictionary) -> void:
	if _day_summary_open:
		return
	_day_summary_open = true
	var scene: PackedScene = load(DAY_SUMMARY_SCENE) as PackedScene
	if scene == null:
		return
	var overlay: Control = scene.instantiate() as Control
	add_child(overlay)
	overlay.anchor_right = 1
	overlay.anchor_bottom = 1
	if overlay.has_method("show_summary"):
		overlay.call("show_summary", summary)

func _rebuild_goals() -> void:
	for c: Node in _goals_box.get_children():
		c.queue_free()
	var goals: Array[Dictionary] = _run.get_goals_view()
	for g: Dictionary in goals:
		var lbl: Label = Label.new()
		var mark: String = "[x]" if bool(g["done"]) else "[ ]"
		lbl.text = "%s %s" % [mark, String(g["text"])]
		if bool(g["done"]):
			lbl.modulate = Color(0.7, 0.95, 0.7)
		else:
			lbl.modulate = Color(0.85, 0.85, 0.85)
		_goals_box.add_child(lbl)

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
	_program_host.add_child(program)
	if program is Control:
		var c: Control = program as Control
		c.anchor_right = 1
		c.anchor_bottom = 1
