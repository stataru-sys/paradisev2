extends PanelContainer
## Виджет ленты событий. Подписан на GameEvents.event_log_added.
## Держит FIFO до MAX_LINES последних сообщений; новые сверху.
## Сообщения, которым больше FADE_AFTER_SEC секунд, становятся полупрозрачными.

const MAX_LINES: int = 6
const FADE_AFTER_SEC: float = 12.0

@export var lines_box_path: NodePath

@onready var _lines_box: VBoxContainer = get_node(lines_box_path) as VBoxContainer

func _ready() -> void:
	GameEvents.event_log_added.connect(_on_event_log_added)
	GameEvents.day_changed.connect(_on_day_changed)
	set_process(true)

func _process(_delta: float) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	for c: Node in _lines_box.get_children():
		var lbl: Label = c as Label
		if lbl == null:
			continue
		var t: float = float(lbl.get_meta("ts", now))
		if now - t > FADE_AFTER_SEC and lbl.modulate.a > 0.4:
			lbl.modulate = Color(1, 1, 1, 0.4)

func _on_event_log_added(message: String) -> void:
	var lbl: Label = Label.new()
	lbl.text = message
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.set_meta("ts", Time.get_ticks_msec() / 1000.0)
	_lines_box.add_child(lbl)
	_lines_box.move_child(lbl, 0)
	while _lines_box.get_child_count() > MAX_LINES:
		_lines_box.get_child(_lines_box.get_child_count() - 1).queue_free()

func _on_day_changed(_day: int) -> void:
	for c: Node in _lines_box.get_children():
		c.queue_free()
