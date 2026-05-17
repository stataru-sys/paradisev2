extends Node
## main_scene проекта. Сейчас — заглушка под Slice 0: подтверждает что autoload-ы
## загрузились и сцена ready без ошибок.
##
## Slice 1+ — здесь появятся: чтение сейва (SaveService autoload), кнопка
## "New Game" → SceneTree.change_scene_to_file("res://scenes/MainScene.tscn").

func _ready() -> void:
	print("[MainMenu] ready — Paradise 2033 boot OK")
