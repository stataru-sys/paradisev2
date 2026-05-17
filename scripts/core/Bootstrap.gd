extends Node
## Единственная точка инициализации. Висит в Bootstrap.tscn (main_scene проекта).
## Регистрирует сервисы, грузит сейв, переключает в MainMenu.

func _ready() -> void:
	# TODO Slice 1: подключить реальные сервисы когда они появятся.
	# ServiceLocator.register("economy", EconomyService.new())
	# ServiceLocator.register("run", RunService.new())
	# ServiceLocator.register("save", SaveService.new())
	# (ServiceLocator.get_service("save") as SaveService).load_game()
	print("[Bootstrap] Paradise 2033 — boot OK")
