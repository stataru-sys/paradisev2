extends Control
## Программа «Магазин апгрейдов». 5 карточек с эффектами на Economy/Work/Dating/Mail.
## Покупка через RunService.purchase_upgrade(id, cost) — она же списывает деньги
## через Economy и эмитит GameEvents.upgrade_purchased.

const UPGRADES: Array[Dictionary] = [
	{
		"id": "coffee",
		"name": "Кофе из автомата",
		"description": "+2 к максимальной энергии со следующего дня. Спишет когнитивный долг позже.",
		"cost": 30,
	},
	{
		"id": "monitor",
		"name": "Второй монитор",
		"description": "+5$ за каждую полностью разобранную категорию в Работе. Якобы повышает «контекст».",
		"cost": 50,
	},
	{
		"id": "dating_plus",
		"name": "Подписка дейтинг+",
		"description": "+10% к шансу матча. Алгоритм видит твою боль и притворяется заинтересованным.",
		"cost": 40,
	},
	{
		"id": "confident_replies",
		"name": "Курс уверенных ответов",
		"description": "В Почте позитивных реакций становится больше. Это не значит, что ты прав.",
		"cost": 35,
	},
	{
		"id": "autoclicker",
		"name": "Дешёвый автокликер",
		"description": "В Работе появится кнопка «Решить 1 карточку». Тратит 1 энергию, как всё в этой жизни.",
		"cost": 60,
	},
]

@export var back_button_path: NodePath
@export var money_label_path: NodePath
@export var list_box_path: NodePath

@onready var _run: Node = get_node("/root/RunService")
@onready var _economy: Node = get_node("/root/Economy")
@onready var _back_button: Button = get_node(back_button_path) as Button
@onready var _money_label: Label = get_node(money_label_path) as Label
@onready var _list_box: VBoxContainer = get_node(list_box_path) as VBoxContainer

func _ready() -> void:
	_back_button.pressed.connect(func() -> void: GameEvents.program_closed.emit())
	GameEvents.money_changed.connect(_on_money_changed)
	GameEvents.upgrade_purchased.connect(_on_upgrade_purchased)
	_on_money_changed(int(_economy.money))
	_rebuild_list()

func _on_money_changed(value: int) -> void:
	_money_label.text = "Деньги: %d$" % value
	_refresh_buy_states()

func _on_upgrade_purchased(_upgrade_id: String) -> void:
	_rebuild_list()

func _rebuild_list() -> void:
	for c: Node in _list_box.get_children():
		c.queue_free()
	for up: Dictionary in UPGRADES:
		_list_box.add_child(_make_card(up))

func _make_card(up: Dictionary) -> Control:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 90)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	var info: VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var title: Label = Label.new()
	title.text = String(up["name"])
	title.add_theme_color_override("font_color", Color(0.95, 0.95, 0.7))
	info.add_child(title)
	var desc: Label = Label.new()
	desc.text = String(up["description"])
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.modulate = Color(0.85, 0.85, 0.85)
	info.add_child(desc)
	var right: VBoxContainer = VBoxContainer.new()
	right.custom_minimum_size = Vector2(160, 0)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(right)
	var price: Label = Label.new()
	price.text = "%d$" % int(up["cost"])
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(price)
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(140, 36)
	right.add_child(btn)
	_apply_button_state(btn, up)
	var upgrade_id: String = String(up["id"])
	var cost: int = int(up["cost"])
	btn.pressed.connect(func() -> void: _on_buy_pressed(upgrade_id, cost))
	card.set_meta("upgrade_id", upgrade_id)
	card.set_meta("cost", cost)
	card.set_meta("button", btn)
	return card

func _apply_button_state(btn: Button, up: Dictionary) -> void:
	var upgrade_id: String = String(up["id"])
	var cost: int = int(up["cost"])
	if _run.has_upgrade(upgrade_id):
		btn.text = "Куплено"
		btn.disabled = true
		return
	btn.text = "Купить"
	btn.disabled = int(_economy.money) < cost

func _refresh_buy_states() -> void:
	for card: Node in _list_box.get_children():
		var btn: Button = card.get_meta("button") as Button
		if btn == null:
			continue
		var upgrade_id: String = String(card.get_meta("upgrade_id"))
		var up: Dictionary = _find_upgrade(upgrade_id)
		if up.is_empty():
			continue
		_apply_button_state(btn, up)

func _find_upgrade(upgrade_id: String) -> Dictionary:
	for up: Dictionary in UPGRADES:
		if String(up["id"]) == upgrade_id:
			return up
	return {}

func _on_buy_pressed(upgrade_id: String, cost: int) -> void:
	var bought: bool = _run.purchase_upgrade(upgrade_id, cost)
	if not bought:
		return
	GameEvents.event_log_added.emit("Куплено: %s" % String(_find_upgrade(upgrade_id).get("name", upgrade_id)))
