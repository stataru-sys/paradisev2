extends Control
## Экран рабочего стола компа. Три кликабельные иконки эмитят запрос на открытие
## программы через GameEvents.program_open_requested(id).

@export var work_button_path: NodePath
@export var dating_button_path: NodePath
@export var mail_button_path: NodePath

func _ready() -> void:
	(get_node(work_button_path) as Button).pressed.connect(func() -> void: GameEvents.program_open_requested.emit("work"))
	(get_node(dating_button_path) as Button).pressed.connect(func() -> void: GameEvents.program_open_requested.emit("dating"))
	(get_node(mail_button_path) as Button).pressed.connect(func() -> void: GameEvents.program_open_requested.emit("mail"))
