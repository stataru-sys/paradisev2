extends Control
## Рабочий стол Run 2 — 6 иконок в 2 ряда.
## Верхний ряд: Работа / Дейтинг / Почта (рабочие, эмитят program_open_requested).
## Нижний ряд: Магазин / Казино / ИИ-агенты — статус берётся из RunService.unlocks.
## Если иконка разблокирована — она яркая и открывает программу. Если нет — приглушена,
## клик эмитит event_log_added с tooltip-текстом «Откроется позже...».

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
	(get_node(shop_button_path) as Button).pressed.connect(func() -> void: _on_lockable_pressed("shop"))
	(get_node(casino_button_path) as Button).pressed.connect(func() -> void: _on_lockable_pressed("casino"))
	(get_node(agents_button_path) as Button).pressed.connect(func() -> void: _on_lockable_pressed("agents"))
	_refresh_lock_visuals()

func _refresh_lock_visuals() -> void:
	_update_slot_modulate(shop_button_path, "shop")
	_update_slot_modulate(casino_button_path, "casino")
	_update_slot_modulate(agents_button_path, "agents")

func _update_slot_modulate(btn_path: NodePath, program_id: String) -> void:
	var btn: Button = get_node(btn_path) as Button
	if btn == null:
		return
	var slot: Control = btn.get_parent() as Control
	if slot == null:
		return
	slot.modulate = Color(1, 1, 1, 1) if _run.has_unlock(program_id) else Color(1, 1, 1, 0.5)

func _on_lockable_pressed(program_id: String) -> void:
	if _run.has_unlock(program_id):
		GameEvents.program_open_requested.emit(program_id)
		return
	GameEvents.event_log_added.emit(LOCKED_TOOLTIP)
