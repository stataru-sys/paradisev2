extends Control
## Мини-игра «Работа» — drag-drop слов в категории.
## Экономика по макету: ошибка −$1, полные 5 слов в категории +$10.

const WORDS_BY_CATEGORY: Dictionary = {
	"Стройка": ["Дрель", "Каска", "Бетон", "Арматура", "Кирпич"],
	"Кухня": ["Тарелка", "Ложка", "Сковорода", "Кастрюля", "Венчик"],
	"Улица": ["Асфальт", "Фонарь", "Светофор", "Лавочка", "Бордюр"],
}
const CATEGORY_FULL_BONUS: int = 10
const MONITOR_BONUS: int = 5
const MISTAKE_PENALTY: int = 1
const FULL_COUNT_PER_CATEGORY: int = 5

@export var words_box_path: NodePath
@export var categories_box_path: NodePath
@export var earned_label_path: NodePath
@export var back_button_path: NodePath
@export var finish_panel_path: NodePath
@export var finish_button_path: NodePath

var _earned_today: int = 0
var _correct_lookup: Dictionary = {}
var _category_counters: Dictionary = {}
var _category_targets: Dictionary = {}
var _words_remaining: int = 0

@onready var _words_box: VBoxContainer = get_node(words_box_path) as VBoxContainer
@onready var _categories_box: VBoxContainer = get_node(categories_box_path) as VBoxContainer
@onready var _earned_label: Label = get_node(earned_label_path) as Label
@onready var _back_button: Button = get_node(back_button_path) as Button
@onready var _finish_panel: Control = get_node(finish_panel_path) as Control
@onready var _finish_button: Button = get_node(finish_button_path) as Button
@onready var _economy: Node = get_node("/root/Economy")
@onready var _run: Node = get_node("/root/RunService")

func _ready() -> void:
	_finish_panel.visible = false
	_back_button.pressed.connect(func() -> void: GameEvents.program_closed.emit())
	_finish_button.pressed.connect(func() -> void: GameEvents.program_closed.emit())
	_build_data()
	_build_words_pool()
	_build_categories()
	_update_earned_label()
	_setup_autoclicker_button()

func _build_data() -> void:
	var all_words: Array[String] = []
	for cat: String in WORDS_BY_CATEGORY.keys():
		_category_counters[cat] = 0
		_category_targets[cat] = (WORDS_BY_CATEGORY[cat] as Array).size()
		for w: String in WORDS_BY_CATEGORY[cat]:
			_correct_lookup[w] = cat
			all_words.append(w)
	_words_remaining = all_words.size()

func _build_words_pool() -> void:
	var shuffled: Array[String] = []
	for w: String in _correct_lookup.keys():
		shuffled.append(w)
	shuffled.shuffle()
	for w: String in shuffled:
		_words_box.add_child(_make_word_card(w))

func _build_categories() -> void:
	for cat: String in WORDS_BY_CATEGORY.keys():
		_categories_box.add_child(_make_category_slot(cat))

func _make_word_card(word: String) -> Control:
	var card: WordCard = WordCard.new()
	card.custom_minimum_size = Vector2(180, 40)
	card.word = word
	var rect: ColorRect = ColorRect.new()
	rect.color = Color(0.86, 0.32, 0.32)
	rect.anchor_right = 1
	rect.anchor_bottom = 1
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(rect)
	var lbl: Label = Label.new()
	lbl.text = word
	lbl.anchor_right = 1
	lbl.anchor_bottom = 1
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(lbl)
	return card

func _make_category_slot(cat: String) -> Control:
	var slot: CategorySlot = CategorySlot.new()
	slot.category_name = cat
	slot.on_word_dropped = _on_word_dropped
	slot.custom_minimum_size = Vector2(220, 56)
	var rect: ColorRect = ColorRect.new()
	rect.color = Color(0.55, 0.83, 0.45)
	rect.anchor_right = 1
	rect.anchor_bottom = 1
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(rect)
	var lbl: Label = Label.new()
	lbl.text = "%s 0/%d" % [cat, _category_targets[cat]]
	lbl.anchor_right = 1
	lbl.anchor_bottom = 1
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(lbl)
	slot.label = lbl
	return slot

func _on_word_dropped(slot: CategorySlot, word: String, card: Control) -> void:
	var correct_cat: String = String(_correct_lookup.get(word, ""))
	if correct_cat == slot.category_name:
		card.queue_free()
		var counter: int = int(_category_counters[slot.category_name]) + 1
		_category_counters[slot.category_name] = counter
		slot.label.text = "%s %d/%d" % [slot.category_name, counter, _category_targets[slot.category_name]]
		_words_remaining -= 1
		_run.register_work_correct()
		if counter == _category_targets[slot.category_name]:
			var bonus: int = CATEGORY_FULL_BONUS + (MONITOR_BONUS if _run.has_upgrade("monitor") else 0)
			_economy.add(bonus)
			_earned_today += bonus
			_run.register_money_earned(bonus)
		_update_earned_label()
		if _words_remaining == 0:
			_finish_panel.visible = true
			GameEvents.work_day_finished.emit(_earned_today)
	else:
		_economy.add(-MISTAKE_PENALTY)
		_earned_today -= MISTAKE_PENALTY
		_run.register_work_error()
		_update_earned_label()
	_run.spend_energy(1)

func _update_earned_label() -> void:
	_earned_label.text = "Заработано за день: %d$" % _earned_today

func _setup_autoclicker_button() -> void:
	if not _run.has_upgrade("autoclicker"):
		return
	var top_bar: HBoxContainer = _back_button.get_parent() as HBoxContainer
	if top_bar == null:
		return
	var btn: Button = Button.new()
	btn.text = "Решить 1 карточку"
	btn.custom_minimum_size = Vector2(180, 0)
	btn.pressed.connect(_on_autoclicker_pressed)
	top_bar.add_child(btn)
	top_bar.move_child(btn, top_bar.get_child_count() - 2)

func _on_autoclicker_pressed() -> void:
	if int(_run.energy) <= 0:
		return
	if _words_box.get_child_count() == 0:
		return
	var card: WordCard = _words_box.get_child(0) as WordCard
	if card == null:
		return
	var word: String = card.word
	var cat: String = String(_correct_lookup.get(word, ""))
	if cat.is_empty():
		return
	for slot_node: Node in _categories_box.get_children():
		if slot_node is CategorySlot and (slot_node as CategorySlot).category_name == cat:
			_on_word_dropped(slot_node as CategorySlot, word, card)
			return


class WordCard extends Control:
	var word: String

	func _get_drag_data(_pos: Vector2) -> Variant:
		var preview: Label = Label.new()
		preview.text = word
		preview.add_theme_color_override("font_color", Color.WHITE)
		var bg: ColorRect = ColorRect.new()
		bg.color = Color(0.86, 0.32, 0.32, 0.9)
		bg.size = Vector2(180, 40)
		var wrap: Control = Control.new()
		wrap.custom_minimum_size = Vector2(180, 40)
		wrap.add_child(bg)
		preview.position = Vector2(0, 10)
		preview.size = Vector2(180, 20)
		preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wrap.add_child(preview)
		set_drag_preview(wrap)
		return {"word": word, "card": self}


class CategorySlot extends Control:
	var category_name: String
	var label: Label
	var on_word_dropped: Callable

	func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("word")

	func _drop_data(_pos: Vector2, data: Variant) -> void:
		if on_word_dropped.is_valid():
			on_word_dropped.call(self, String(data["word"]), data["card"] as Control)
