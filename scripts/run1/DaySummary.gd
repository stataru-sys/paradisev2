extends Control
## Overlay-итог дня. Получает summary через show_summary(Dictionary).
## Кнопка "Начать следующий день" → RunService.next_day() → MainScene-роутер.

@export var title_path: NodePath
@export var stats_box_path: NodePath
@export var goals_box_path: NodePath
@export var verdict_path: NodePath
@export var next_button_path: NodePath

@onready var _run: Node = get_node("/root/RunService")
@onready var _title: Label = get_node(title_path) as Label
@onready var _stats_box: VBoxContainer = get_node(stats_box_path) as VBoxContainer
@onready var _goals_box: VBoxContainer = get_node(goals_box_path) as VBoxContainer
@onready var _verdict: Label = get_node(verdict_path) as Label
@onready var _next_button: Button = get_node(next_button_path) as Button

var _pending_summary: Dictionary = {}

func show_summary(summary: Dictionary) -> void:
	_pending_summary = summary
	if is_node_ready():
		_apply()

func _ready() -> void:
	_next_button.pressed.connect(_on_next_pressed)
	if not _pending_summary.is_empty():
		_apply()

func _apply() -> void:
	var s: Dictionary = _pending_summary
	_title.text = "День %d закрыт" % int(s.get("day", 1))
	_fill_box(_stats_box, [
		"Заработано: %d$" % int(s.get("money_earned", 0)),
		"Правильно решено карточек: %d" % int(s.get("work_correct", 0)),
		"Ошибок на работе: %d" % int(s.get("work_errors", 0)),
		"Матчей: %d" % int(s.get("matches", 0)),
	])
	for c: Node in _goals_box.get_children():
		c.queue_free()
	var goals: Array = s.get("goals", []) as Array
	for g_var in goals:
		var g: Dictionary = g_var as Dictionary
		var lbl: Label = Label.new()
		var mark: String = "[x]" if bool(g.get("done", false)) else "[ ]"
		lbl.text = "%s %s" % [mark, String(g.get("text", ""))]
		if bool(g.get("done", false)):
			lbl.modulate = Color(0.7, 0.95, 0.7)
		else:
			lbl.modulate = Color(0.8, 0.5, 0.5)
		_goals_box.add_child(lbl)
	_verdict.text = String(s.get("verdict", ""))

func _fill_box(box: VBoxContainer, lines: Array) -> void:
	for c: Node in box.get_children():
		c.queue_free()
	for line_var in lines:
		var lbl: Label = Label.new()
		lbl.text = String(line_var)
		box.add_child(lbl)

func _on_next_pressed() -> void:
	_run.next_day()
	get_tree().change_scene_to_file("res://scenes/MainScene.tscn")
