extends Control
## Overlay с результатами работы. Показывает заработано, ошибки, энергию,
## качество и сатирический комментарий. Две кнопки: в хаб и на desktop.

signal return_to_hub

@export var earned_label_path: NodePath
@export var errors_label_path: NodePath
@export var energy_label_path: NodePath
@export var quality_label_path: NodePath
@export var comment_label_path: NodePath
@export var hub_button_path: NodePath
@export var desktop_button_path: NodePath

const COMMENTS: Dictionary = {
	"excellent": [
		"Без ошибок. Подозрительно.",
		"Идеально. Тебя проверят на бота.",
		"Ни одной ошибки. Точно не стажёр-GPT делал?",
	],
	"decent": [
		"Пара ошибок. Никто не заметил.",
		"Сойдёт. В отчёте напишем «стабильно».",
		"Нормально. Могло быть хуже. Бывало хуже.",
	],
	"terrible": [
		"Много ошибок. Но тебе заплатили.",
		"Провал. Но деньги те же.",
		"Клиент не заметит. Наверное.",
	],
}

func _ready() -> void:
	(get_node(hub_button_path) as Button).pressed.connect(func() -> void: return_to_hub.emit())
	(get_node(desktop_button_path) as Button).pressed.connect(func() -> void: GameEvents.program_closed.emit())

func setup(earned: int, errors: int, energy_used: int) -> void:
	var earned_label: Label = get_node(earned_label_path) as Label
	earned_label.text = "Заработано: +%d$" % earned

	var energy_label: Label = get_node(energy_label_path) as Label
	energy_label.text = "Энергии потрачено: %d" % energy_used

	var quality: String
	var comment_pool: Array[String]
	if errors == 0:
		quality = "Отлично"
		comment_pool.assign(COMMENTS["excellent"])
	elif errors <= 2:
		quality = "Сойдёт"
		comment_pool.assign(COMMENTS["decent"])
	else:
		quality = "Провал"
		comment_pool.assign(COMMENTS["terrible"])

	var quality_label: Label = get_node(quality_label_path) as Label
	quality_label.text = "Качество: %s" % quality

	var comment_label: Label = get_node(comment_label_path) as Label
	comment_label.text = comment_pool[randi() % comment_pool.size()]

	var errors_label: Label = get_node(errors_label_path) as Label
	if errors > 0:
		errors_label.text = "Ошибок: %d (-%d$)" % [errors, errors]
		errors_label.visible = true
	else:
		errors_label.visible = false
