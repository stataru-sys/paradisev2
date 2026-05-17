extends Control
## Рабочий стол Run 2 — 6 иконок в 2 ряда.
## Верхний ряд: Работа / Дейтинг / Почта (рабочие, эмитят program_open_requested).
## Нижний ряд: Магазин / Казино / ИИ-агенты — placeholder'ы до Slice C/D/E.
## Клик по locked-иконке эмитит event_log_added с tooltip-текстом «Откроется позже...».

const LOCKED_TOOLTIP: String = "Откроется позже. Тебе пока хватает проблем."

@export var work_button_path: NodePath
@export var dating_button_path: NodePath
@export var mail_button_path: NodePath
@export var shop_button_path: NodePath
@export var casino_button_path: NodePath
@export var agents_button_path: NodePath

@onready var _run: Node = get_node("/root/RunService")

func _ready() -> void:
	(get_node(work_button_path) as Button).pressed.connect(func() -> void: GameEvents.program_open_requested.emit("work"))
	(get_node(dating_button_path) as Button).pressed.connect(func() -> void: GameEvents.program_open_requested.emit("dating"))
	(get_node(mail_button_path) as Button).pressed.connect(func() -> void: GameEvents.program_open_requested.emit("mail"))
	(get_node(shop_button_path) as Button).pressed.connect(func() -> void: _on_locked_pressed("shop"))
	(get_node(casino_button_path) as Button).pressed.connect(func() -> void: _on_locked_pressed("casino"))
	(get_node(agents_button_path) as Button).pressed.connect(func() -> void: _on_locked_pressed("agents"))

func _on_locked_pressed(program_id: String) -> void:
	if _run.has_unlock(program_id):
		GameEvents.program_open_requested.emit(program_id)
		return
	GameEvents.event_log_added.emit(LOCKED_TOOLTIP)
