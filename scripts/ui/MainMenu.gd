extends Node
## main_scene проекта. Slice 0 — заглушка с print'ом. Slice 1 — кнопка перехода в Run1.

@export var start_button_path: NodePath

func _ready() -> void:
	print("[MainMenu] ready — Paradise 2033 boot OK")
	if start_button_path.is_empty():
		return
	var btn: Button = get_node(start_button_path) as Button
	if btn != null:
		btn.pressed.connect(_on_start_pressed)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainScene.tscn")
