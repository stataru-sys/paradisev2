extends Node
## Корневой роутер run-ов. Читает RunService.current_day и переключает на нужную сцену.
## Day 1 → Run1.tscn (стартовый каркас, 3 иконки Desktop).
## Day >= 2 → Run2.tscn (расширенный Desktop2 с 6 иконками: 3 рабочие + 3 заблокированные).

const RUN1_SCENE: String = "res://scenes/Run1.tscn"
const RUN2_SCENE: String = "res://scenes/Run2.tscn"

func _ready() -> void:
	var run: Node = get_node("/root/RunService")
	var day: int = int(run.current_day)
	var target: String = RUN1_SCENE if day <= 1 else RUN2_SCENE
	print("[MainScene] routing day %d → %s" % [day, target])
	call_deferred("_switch_to", target)

func _switch_to(path: String) -> void:
	get_tree().change_scene_to_file(path)
