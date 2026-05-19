extends Control
## Мини-игра «Корпоративная почта» — распределение писем по папкам.
## Сатира: «Письма от тех, кто тоже не знает, зачем работает. Твой долг —
## рассортировать их так, чтобы никто ничего не заметил.»
##
## Механика: 5–7 случайных писем из пула 20. 4 папки. Правильная +4$,
## нейтральная +1$, ошибка −2$. Ловушки начальника: игнор → дополнительный −5$.
## Энергия −2 списывается при старте (в WorkHub).

const EMAILS: Array[Dictionary] = [
	# === Обычное рабочее (10 шт) ===
	{
		"sender": "Михаил, отдел синергии",
		"subject": "Синхронизация по созвону",
		"body": "Коллеги, предлагаю синхронизироваться по вчерашнему созвону. Когда всем удобно?",
		"correct": "ignore",
		"neutral": "template",
		"trap": false,
	},
	{
		"sender": "Елена, бухгалтерия",
		"subject": "Квартальный отчёт",
		"body": "Пришлите данные по расходам за Q2. Форма приложена. Дедлайн — вчера.",
		"correct": "template",
		"neutral": "delegate",
		"trap": false,
	},
	{
		"sender": "Игорь, разработка",
		"subject": "Баг в проде",
		"body": "Упал payment-service. Платежи не проходят уже 20 минут. Клиенты пишут.",
		"correct": "urgent",
		"neutral": "delegate",
		"trap": false,
	},
	{
		"sender": "Света, офис-менеджер",
		"subject": "Новый кулер",
		"body": "Друзья, старый кулер потек. Голосуем за цвет нового. Варианты: белый, серый, графит.",
		"correct": "ignore",
		"neutral": "template",
		"trap": false,
	},
	{
		"sender": "Алексей, маркетинг",
		"subject": "Согласование макета",
		"body": "Дизайнер прислал три варианта баннера. Нужен фидбек до пятницы. Посмотрите плиз.",
		"correct": "delegate",
		"neutral": "template",
		"trap": false,
	},
	{
		"sender": "Ольга, HR",
		"subject": "График отпусков",
		"body": "Заполните форму отпусков на следующий квартал. Это обязательно. Но не срочно.",
		"correct": "template",
		"neutral": "delegate",
		"trap": false,
	},
	{
		"sender": "Дмитрий, поддержка",
		"subject": "Тикет №4527",
		"body": "Клиент жалуется что кнопка «Оплатить» исчезла. Но скриншот приложил без кнопки Print Screen.",
		"correct": "delegate",
		"neutral": "template",
		"trap": false,
	},
	{
		"sender": "Наталья, юротдел",
		"subject": "Согласование договора",
		"body": "Срочно нужна подпись по договору с подрядчиком. Они ждут ответа сегодня.",
		"correct": "urgent",
		"neutral": "delegate",
		"trap": false,
	},
	{
		"sender": "Павел, девопс",
		"subject": "Сервер упал",
		"body": "Продакшен-сервер не отвечает. Пытаюсь поднять. Кому-то надо проверить логи.",
		"correct": "urgent",
		"neutral": "delegate",
		"trap": false,
	},
	{
		"sender": "Марина, рекрутинг",
		"subject": "Новый стажёр",
		"body": "Завтра выходит стажёр. Кто проведёт онбординг? Это займёт всего час.",
		"correct": "ignore",
		"neutral": "template",
		"trap": false,
	},
	# === Письмо-ловушка от начальника (3 шт) ===
	{
		"sender": "Виктор Степанович, директор",
		"subject": "FW: корпоратив",
		"body": "Перешли мне смету по корпоративу. Жду. И не говори что не видел письмо.",
		"correct": "urgent",
		"neutral": "delegate",
		"trap": true,
	},
	{
		"sender": "Виктор Степанович, директор",
		"subject": "Re: смета",
		"body": "Ещё раз. Смета. Сегодня. Ты же знаешь я не люблю повторять.",
		"correct": "urgent",
		"neutral": "delegate",
		"trap": true,
	},
	{
		"sender": "Виктор Степанович, директор",
		"subject": "Не игнорируй",
		"body": "Это уже третье письмо. Будешь игнорировать — будешь искать работу.",
		"correct": "urgent",
		"neutral": "template",
		"trap": true,
	},
	# === Письмо от AI-агента (2 шт) ===
	{
		"sender": "Стажёр-GPT",
		"subject": "Re: Re: Re: задание",
		"body": "Я проанализировал задание и предлагаю следующие варианты решения: пункт 1, пункт 2, пункт 1 снова. Жду подтверждения подтверждения.",
		"correct": "ignore",
		"neutral": "template",
		"trap": false,
	},
	{
		"sender": "Ответчик-3000",
		"subject": "Автоответ: я в отпуске",
		"body": "Автоматическое сообщение: агент в отпуске. Все запросы будут обработаны после возвращения. Дата возвращения: неизвестна. Статус отпуска: бессрочный.",
		"correct": "ignore",
		"neutral": "template",
		"trap": false,
	},
	# === Приглашение на митинг (2 шт) ===
	{
		"sender": "Календарь",
		"subject": "Еженедельный синк",
		"body": "Приглашение: еженедельная синхронизация команды. Понедельник 10:00. Присутствие обязательно. Повестка: синхронизация.",
		"correct": "delegate",
		"neutral": "urgent",
		"trap": false,
	},
	{
		"sender": "Календарь",
		"subject": "Ретроспектива спринта",
		"body": "Обсудим что пошло не так в этом спринте. Формат: каждый говорит 3 минуты. Всего участников: 18.",
		"correct": "delegate",
		"neutral": "urgent",
		"trap": false,
	},
	# === Спам (3 шт) ===
	{
		"sender": "Розыгрыш-Парадайз",
		"subject": "Вы выиграли!",
		"body": "Поздравляем! Вы выиграли 1 000 000$ в лотерее «Парадайз-Джекпот». Для получения приза отправьте 50$ на указанный кошелёк.",
		"correct": "ignore",
		"neutral": "template",
		"trap": false,
	},
	{
		"sender": "Крипто-гуру",
		"subject": "Пассивный доход 500% в день",
		"body": "Инвестируй в новый токен SYNERGYCOIN. Успей на старте. Наша команда профессионалов гарантирует результат.",
		"correct": "ignore",
		"neutral": "template",
		"trap": false,
	},
	{
		"sender": "Онлайн-университет",
		"subject": "Стань сеньором за 2 недели",
		"body": "Интенсивный курс «Python для чайников за 14 дней». Скидка 90% только сегодня. Не упусти возможность.",
		"correct": "ignore",
		"neutral": "template",
		"trap": false,
	},
]

const CORRECT_REWARD: int = 4
const NEUTRAL_REWARD: int = 1
const WRONG_PENALTY: int = 2
const TRAP_PENALTY: int = 5
const ALL_CORRECT_BONUS: int = 5
const WORK_RESULT_SCENE: String = "res://scenes/run2/WorkResult.tscn"
const EMAILS_PER_SESSION_MIN: int = 5
const EMAILS_PER_SESSION_MAX: int = 7
const FEEDBACK_DELAY: float = 0.7

@export var sender_label_path: NodePath
@export var subject_label_path: NodePath
@export var body_label_path: NodePath
@export var progress_label_path: NodePath
@export var earned_label_path: NodePath
@export var urgent_button_path: NodePath
@export var ignore_button_path: NodePath
@export var delegate_button_path: NodePath
@export var template_button_path: NodePath
@export var back_button_path: NodePath
@export var finish_button_path: NodePath
@export var feedback_label_path: NodePath

@onready var _sender_label: Label = get_node(sender_label_path) as Label
@onready var _subject_label: Label = get_node(subject_label_path) as Label
@onready var _body_label: Label = get_node(body_label_path) as Label
@onready var _progress_label: Label = get_node(progress_label_path) as Label
@onready var _earned_label: Label = get_node(earned_label_path) as Label
@onready var _urgent_btn: Button = get_node(urgent_button_path) as Button
@onready var _ignore_btn: Button = get_node(ignore_button_path) as Button
@onready var _delegate_btn: Button = get_node(delegate_button_path) as Button
@onready var _template_btn: Button = get_node(template_button_path) as Button
@onready var _back_button: Button = get_node(back_button_path) as Button
@onready var _finish_button: Button = get_node(finish_button_path) as Button
@onready var _feedback_label: Label = get_node(feedback_label_path) as Label

var _session_emails: Array[Dictionary] = []
var _current_index: int = 0
var _earned: int = 0
var _errors: int = 0
var _all_correct: bool = true
var _energy_spent: int = 2  # списано при старте в WorkHub
var _feedback_timer: float = 0.0
var _awaiting_feedback: bool = false

func _ready() -> void:
	_back_button.pressed.connect(func() -> void: GameEvents.program_closed.emit())
	_finish_button.pressed.connect(_on_finish_pressed)
	_urgent_btn.pressed.connect(func() -> void: _on_folder_picked("urgent"))
	_ignore_btn.pressed.connect(func() -> void: _on_folder_picked("ignore"))
	_delegate_btn.pressed.connect(func() -> void: _on_folder_picked("delegate"))
	_template_btn.pressed.connect(func() -> void: _on_folder_picked("template"))

	var count: int = EMAILS_PER_SESSION_MIN + randi() % (EMAILS_PER_SESSION_MAX - EMAILS_PER_SESSION_MIN + 1)
	var pool: Array[Dictionary] = EMAILS.duplicate()
	pool.shuffle()
	_session_emails = pool.slice(0, count)

	_show_current_email()

func _process(_delta: float) -> void:
	if _awaiting_feedback:
		_feedback_timer -= _delta
		if _feedback_timer <= 0.0:
			_awaiting_feedback = false
			_next_email()

func _show_current_email() -> void:
	if _current_index >= _session_emails.size():
		return
	var email: Dictionary = _session_emails[_current_index]
	_sender_label.text = "От: " + String(email["sender"])
	_subject_label.text = String(email["subject"])
	_body_label.text = String(email["body"])
	_feedback_label.text = ""
	_progress_label.text = "Письмо %d/%d" % [_current_index + 1, _session_emails.size()]

func _on_folder_picked(folder: String) -> void:
	if _awaiting_feedback:
		return
	if _current_index >= _session_emails.size():
		return

	var email: Dictionary = _session_emails[_current_index]

	if folder == email["correct"]:
		_earned += CORRECT_REWARD
		_show_feedback("Правильно", Color(0.467, 0.8, 0.533))
	elif folder == email.get("neutral", ""):
		_earned += NEUTRAL_REWARD
		_show_feedback("Сойдёт", Color(0.867, 0.8, 0.467))
		_all_correct = false
	else:
		_earned -= WRONG_PENALTY
		_errors += 1
		_all_correct = false
		_show_feedback("Ошибка", Color(0.867, 0.4, 0.333))
		if email.get("trap", false) and folder == "ignore":
			_earned -= TRAP_PENALTY

	_update_earned_label()

	_awaiting_feedback = true
	_feedback_timer = FEEDBACK_DELAY

func _next_email() -> void:
	_current_index += 1
	if _current_index >= _session_emails.size():
		_finish_game()
	else:
		_show_current_email()

func _show_feedback(text: String, color: Color) -> void:
	_feedback_label.text = text
	_feedback_label.add_theme_color_override("font_color", color)

func _update_earned_label() -> void:
	_earned_label.text = "%+d$" % _earned

func _on_finish_pressed() -> void:
	if _awaiting_feedback:
		return
	_finish_game()

func _finish_game() -> void:
	if _all_correct and _errors == 0 and _current_index >= _session_emails.size():
		_earned += ALL_CORRECT_BONUS

	_set_buttons_enabled(false)

	var scene: PackedScene = load(WORK_RESULT_SCENE) as PackedScene
	if scene == null:
		return
	var result: Control = scene.instantiate() as Control
	add_child(result)
	result.anchor_right = 1
	result.anchor_bottom = 1
	result.setup(_earned, _errors, _energy_spent)
	GameEvents.work_day_finished.emit(_earned)

func _set_buttons_enabled(p_enabled: bool) -> void:
	_urgent_btn.disabled = not p_enabled
	_ignore_btn.disabled = not p_enabled
	_delegate_btn.disabled = not p_enabled
	_template_btn.disabled = not p_enabled
	_finish_button.disabled = not p_enabled
