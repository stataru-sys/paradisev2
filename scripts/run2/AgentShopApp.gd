extends Control
## Программа «ИИ-агенты». Найм 4 агентов с эффектами на ежедневный цикл и программы.
## Покупка через RunService.purchase_agent(id, cost) — она же списывает деньги
## через Economy и эмитит GameEvents.agent_hired.

const AGENTS: Array[Dictionary] = [
	{
		"id": "intern_gpt",
		"name": "Стажёр-GPT",
		"description": "Решит за тебя 1 карточку в Работе при открытии. 25% шанс ошибки. Энергию не тратит — твою.",
		"cost": 60,
	},
	{
		"id": "lyudmila",
		"name": "Людмила",
		"description": "+15% к шансу матча в Дейтинге. 20% шанс «нажать не туда» — снижает симпатию у случайного матча.",
		"cost": 80,
	},
	{
		"id": "answerer_3000",
		"name": "Ответчик-3000",
		"description": "В Почте появляется кнопка авто-ответа. 60% позитивных, 40% негативных реакций. Без твоей энергии.",
		"cost": 100,
	},
	{
		"id": "mini_delegator",
		"name": "Мини-делегатор",
		"description": "+10$ пассивно в начале каждого дня. 10% шанс хаос-задачи — отнимет 1 энергию утром.",
		"cost": 120,
	},
]

@export var back_button_path: NodePath
@export var money_label_path: NodePath
@export var shop_box_path: NodePath
@export var hired_box_path: NodePath
@export var empty_hired_label_path: NodePath

@onready var _run: Node = get_node("/root/RunService")
@onready var _economy: Node = get_node("/root/Economy")
@onready var _back_button: Button = get_node(back_button_path) as Button
@onready var _money_label: Label = get_node(money_label_path) as Label
@onready var _shop_box: VBoxContainer = get_node(shop_box_path) as VBoxContainer
@onready var _hired_box: VBoxContainer = get_node(hired_box_path) as VBoxContainer
@onready var _empty_hired_label: Label = get_node(empty_hired_label_path) as Label

func _ready() -> void:
	_back_button.pressed.connect(func() -> void: GameEvents.program_closed.emit())
	GameEvents.money_changed.connect(_on_money_changed)
	GameEvents.agent_hired.connect(_on_agent_hired)
	_on_money_changed(int(_economy.money))
	_rebuild_shop_list()
	_rebuild_hired_list()

func _on_money_changed(value: int) -> void:
	_money_label.text = "Деньги: %d$" % value
	_refresh_buy_states()

func _on_agent_hired(_agent_id: String) -> void:
	_rebuild_shop_list()
	_rebuild_hired_list()

func _rebuild_shop_list() -> void:
	for c: Node in _shop_box.get_children():
		c.queue_free()
	for agent: Dictionary in AGENTS:
		_shop_box.add_child(_make_shop_card(agent))

func _rebuild_hired_list() -> void:
	for c: Node in _hired_box.get_children():
		c.queue_free()
	var any_hired: bool = false
	for agent: Dictionary in AGENTS:
		if _run.has_agent(String(agent["id"])):
			_hired_box.add_child(_make_hired_card(agent))
			any_hired = true
	_empty_hired_label.visible = not any_hired

func _make_shop_card(agent: Dictionary) -> Control:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 96)
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
	title.text = String(agent["name"])
	title.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	info.add_child(title)
	var desc: Label = Label.new()
	desc.text = String(agent["description"])
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.modulate = Color(0.85, 0.85, 0.85)
	info.add_child(desc)
	var right: VBoxContainer = VBoxContainer.new()
	right.custom_minimum_size = Vector2(160, 0)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(right)
	var price: Label = Label.new()
	price.text = "%d$" % int(agent["cost"])
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(price)
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(140, 36)
	right.add_child(btn)
	_apply_buy_button(btn, agent)
	var agent_id: String = String(agent["id"])
	var cost: int = int(agent["cost"])
	btn.pressed.connect(func() -> void: _on_hire_pressed(agent_id, cost))
	card.set_meta("agent_id", agent_id)
	card.set_meta("button", btn)
	return card

func _make_hired_card(agent: Dictionary) -> Control:
	var card: PanelContainer = PanelContainer.new()
	card.modulate = Color(0.85, 0.95, 0.85, 1)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 6)
	card.add_child(margin)
	var info: VBoxContainer = VBoxContainer.new()
	margin.add_child(info)
	var title: Label = Label.new()
	title.text = String(agent["name"])
	info.add_child(title)
	var desc: Label = Label.new()
	desc.text = String(agent["description"])
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.modulate = Color(0.4, 0.4, 0.4)
	info.add_child(desc)
	return card

func _apply_buy_button(btn: Button, agent: Dictionary) -> void:
	var agent_id: String = String(agent["id"])
	var cost: int = int(agent["cost"])
	if _run.has_agent(agent_id):
		btn.text = "Нанят"
		btn.disabled = true
		return
	btn.text = "Нанять"
	btn.disabled = int(_economy.money) < cost

func _refresh_buy_states() -> void:
	for card: Node in _shop_box.get_children():
		var btn: Button = card.get_meta("button") as Button
		if btn == null:
			continue
		var agent_id: String = String(card.get_meta("agent_id"))
		var agent: Dictionary = _find_agent(agent_id)
		if agent.is_empty():
			continue
		_apply_buy_button(btn, agent)

func _find_agent(agent_id: String) -> Dictionary:
	for a: Dictionary in AGENTS:
		if String(a["id"]) == agent_id:
			return a
	return {}

func _on_hire_pressed(agent_id: String, cost: int) -> void:
	var ok: bool = _run.purchase_agent(agent_id, cost)
	if not ok:
		return
	GameEvents.event_log_added.emit("Нанят: %s" % String(_find_agent(agent_id).get("name", agent_id)))
