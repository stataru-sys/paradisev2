extends Node
## Корневой роутер run-ов. Читает RunService.current_day и переключает на нужную сцену.
## Slice A: всегда грузит Run1.tscn (вне зависимости от дня).
## Slice B: для current_day >= 2 будет грузить Run2.tscn.

func _ready() -> void:
	var run: Node = get_node("/root/RunService")
	var day: int = int(run.current_day)
	var target: String = "res://scenes/Run1.tscn"
	print("[MainScene] routing day %d → %s" % [day, target])
	call_deferred("_switch_to", target)

func _switch_to(path: String) -> void:
	get_tree().change_scene_to_file(path)
