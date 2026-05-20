# Slice K — Meeting Simulator Mini-game

## Goal
Мини-игра «Созвон без смысла» — выбор реакции на реплики с таймером. Четвёртая работа в WorkHub. Главная фишка — риск «стать ответственным».

## Context
Дизайн: `.claude/plans/work-expansion.md`, разделы 4.3 и 9 (Слайс K).

Сейчас:
- WorkHub (`scripts/run2/WorkHub.gd`) хостит 3 мини-игры: Сортировка, Почта, Фиксы. Метод `_start_work_game(scene, energy)` уже вынесен (Slice J) — **переиспользовать**.
- `_lock_card(card_name, start_btn)` блокирует карточку по имени — **переиспользовать** для Meeting.
- `WorkResult.setup(earned, errors, energy_used, comment_override="")` — 4-й параметр для кастомного комментария есть (Slice J).
- Фикс-слайс установил паттерн: мини-игра в конце сессии сама зовёт `Economy.add(_earned)` + `RunService.register_money_earned(_earned)` перед `work_day_finished.emit()`. **MeetingGame обязан делать так же с самого начала.**

## Flow
```
WorkHub (день ≥ 3) → клик «Начать» на Созвоне
  → энергия −2 → MeetingGame: 10 реплик подряд, на каждую таймер 3 сек
    → клик реакции (или таймаут = авто-«Молчать»)
    → после 10-й реплики:
        Economy.add + register_money_earned
        → WorkResult (earned, errors, energy_used, comment)
          → «Вернуться к работе» → WorkHub
          → «На рабочий стол» → Desktop
```

## Файлы

### Новые:
- `scenes/run2/MeetingGame.tscn`
- `scripts/run2/MeetingGame.gd`

### Изменяемые:
- `scenes/run2/WorkHub.tscn` — добавить 4-ю карточку `Card_Meeting`
- `scripts/run2/WorkHub.gd` — `MEETING_SCENE`, `MEETING_ENERGY_COST`, `meeting_start_button_path`, `_on_start_meeting`, гейтинг по дню
- `scripts/core/RunService.gd` — 1 строка: добавить `"Созвон:"` в `INTERESTING_PREFIXES`

## Решения keeper'а (заложены в спеку)
- **Гейтинг: `meeting` доступен с `current_day >= 3`.** В Run 1 (день 1) и Run 2 день 2 — карточка заблокирована (§7: «слишком много нового в Run 2»). Тонкую unlock-логику доделает Slice N — здесь достаточно проверки по дню.
- **Сессия = ровно 10 реплик.** Реплика-«волонтёр» включается в каждую сессию гарантированно (на случайной позиции), остальные 9 — случайны из пула.
- **Баланс — рабочий, не финальный.** Цифры наград подкрутит Slice N по таблице §7. Здесь — играбельные значения.

---

## MeetingGame spec

### Сатира
Стартовая строка в FeedbackLabel: «Дожить до конца созвона, не став ответственным — искусство 2033 года.»

### Реакции и константы
```gdscript
const REACTIONS: Array[String] = ["Кивнуть", "Сказать «согласен»", "Предложить follow-up", "Молчать"]
# индексы: 0 Кивнуть, 1 Согласен, 2 Follow-up, 3 Молчать

const SESSION_LENGTH: int = 10
const REPLICA_TIME: float = 3.0          # таймер на реакцию
const FEEDBACK_TIME: float = 1.6         # показ фидбэка + пауза перед следующей репликой

const CORRECT_REWARD: int = 2
const NEUTRAL_REWARD: int = 1
const ERROR_PENALTY: int = 1
const SURVIVE_BONUS: int = 5
const RESPONSIBLE_PENALTY: int = 5
```

### Пул реплик
Каждая реплика — `Dictionary`: `speaker`, `text`, `correct` (индекс в REACTIONS), `neutral` (индекс), опционально `volunteer: true`.
Любая реакция, не равная `correct`/`neutral` — ошибка. Таймаут = реакция «Молчать» (индекс 3).

Сид из 6 реплик (раздел 4.3) — расширить до **14–16** в том же тоне (сухая ирония, офис 2033):
```gdscript
const REPLICAS: Array[Dictionary] = [
    {"speaker": "Михаил, отдел синергии", "text": "Коллеги, давайте синхронизируемся по вчерашнему созвону.", "correct": 0, "neutral": 3},
    {"speaker": "Аноним без камеры", "text": "Извините, я без камеры — плохо выгляжу сегодня.", "correct": 3, "neutral": 0},
    {"speaker": "Кто-то из участников", "text": "А кто шарит экран? Я ничего не вижу.", "correct": 3, "neutral": 0},
    {"speaker": "Лена, проектный офис", "text": "Предлагаю вынести это в отдельный созвон.", "correct": 0, "neutral": 3},
    {"speaker": "Голос в наушниках", "text": "У меня через 2 минуты следующий, давайте быстрее.", "correct": 3, "neutral": 0},
    {"speaker": "Руководитель проекта", "text": "Нужен волонтёр на это направление. Кто готов?", "correct": 3, "neutral": 3, "volunteer": true},
    # ... ещё 8–10 в тему: «эхо», «вы на mute», «давайте запишем и пересмотрим»,
    #     «у меня вопрос не по теме», «закрепим договорённости», «отличный созвон, продуктивно» и т.п.
]
```
**В пуле ровно одна реплика с `volunteer: true`** — она же гарантированно попадает в каждую сессию.

### Состояние
```gdscript
var _session: Array[Dictionary] = []   # 10 реплик: волонтёр + 9 случайных, перемешаны
var _current: int = 0
var _earned: int = 0
var _errors: int = 0                   # только обычные ошибки реакций
var _became_responsible: bool = false  # волонтёр-провал, отдельно от _errors
var _energy_spent: int = 2
var _state: String = "replica"         # "replica" | "feedback"
var _time_left: float = 0.0
var _game_over: bool = false
```

### Сборка сессии (`_ready`)
- Взять единственную `volunteer`-реплику + 9 случайных не-volunteer из пула (без повторов), сложить в `_session`, `shuffle()`.
- Подключить `_back_button` → `GameEvents.program_closed.emit()`.
- Подключить 4 кнопки реакций → `_on_reaction(i)` (статичные ноды в .tscn, не пересоздавать).
- Показать первую реплику.

### Таймер — машина состояний в `_process(delta)`
Не использовать `await` (нода может быть удалена кнопкой «Назад» в середине сессии — `_process` останавливается чисто).
- `_state == "replica"`: `_time_left -= delta`; обновить `TimerBar.value = _time_left / REPLICA_TIME`; если `_time_left <= 0` → `_resolve(3)` (таймаут = Молчать).
- `_state == "feedback"`: `_time_left -= delta`; если `_time_left <= 0` → следующая реплика или финал.

### `_on_reaction(index)` и `_resolve(index)`
```gdscript
func _on_reaction(index: int) -> void:
    if _state != "replica" or _game_over:
        return
    _resolve(index)

func _resolve(index: int) -> void:
    var replica: Dictionary = _session[_current]
    if replica.get("volunteer", false) and index != 3:
        _became_responsible = true
        _show_feedback("Ты вызвался. Поздравляем. Это теперь твой созвон.", BAD)
    elif index == int(replica["correct"]):
        _earned += CORRECT_REWARD
        _show_feedback("Безупречно. Тебя даже не заметили. +%d$" % CORRECT_REWARD, GOOD)
    elif index == int(replica["neutral"]):
        _earned += NEUTRAL_REWARD
        _show_feedback("Сошло. Никто не понял, но и претензий нет. +%d$" % NEUTRAL_REWARD, HINT)
    else:
        _earned -= ERROR_PENALTY
        _errors += 1
        _show_feedback("Зря. Теперь у HR к тебе вопрос. −%d$" % ERROR_PENALTY, BAD)
    _update_earned_label()
    _state = "feedback"
    _time_left = FEEDBACK_TIME
```
Замечания:
- Волонтёр-провал в `_errors` **не** считается — иначе `WorkResult.errors_label` («−N$» = N×$1) соврёт. Ответственность бьёт через `_earned` (−5$) и комментарий.
- После `feedback` → `_current += 1`; если `_current >= SESSION_LENGTH` → `_finish_session()`, иначе показать следующую реплику, `_state = "replica"`, `_time_left = REPLICA_TIME`.

### Финал — `_finish_session()`
```gdscript
_game_over = true
_earned += SURVIVE_BONUS
var comment: String = ""
if _became_responsible:
    _earned -= RESPONSIBLE_PENALTY
    GameEvents.event_log_added.emit("Созвон: тебя назначили ответственным. Созвон кончился — ответственность нет.")
    comment = "Тебя назначили ответственным. Созвон закончился. Это — нет."
# зачисление (паттерн фикс-слайса)
var economy: Node = get_node_or_null("/root/Economy")
if economy != null and _earned != 0:
    economy.add(_earned)
var run: Node = get_node_or_null("/root/RunService")
if run != null:
    run.register_money_earned(_earned)
# WorkResult
var scene: PackedScene = load("res://scenes/run2/WorkResult.tscn") as PackedScene
var result: Control = scene.instantiate() as Control
add_child(result)
result.anchor_right = 1
result.anchor_bottom = 1
result.setup(_earned, _errors, _energy_spent, comment)
GameEvents.work_day_finished.emit(_earned)
```

### Структура сцены MeetingGame.tscn
```
MeetingGame (Control, anchor full_rect)
├── Bg (ColorRect, тёмный сине-серый — «офисный созвон»)
├── Margin (MarginContainer)
│   └── Layout (VBoxContainer)
│       ├── TopBar (HBoxContainer)
│       │   ├── BackBtn (Button «← Назад»)
│       │   ├── Spacer (Control, expand)
│       │   ├── ProgressLabel (Label «Реплика 1/10»)
│       │   └── EarnedLabel (Label «+0$», зеленоватый)
│       ├── ParticipantsRow (HBoxContainer) — 4–5 ColorRect ~48×48, декоративные «лица»
│       ├── SpeakerLabel (Label — имя говорящего, приглушённый)
│       ├── ReplicaPanel (PanelContainer + StyleBoxFlat)
│       │   └── ReplicaLabel (Label — текст реплики, font_size ~20, по центру, autowrap)
│       ├── TimerBar (ProgressBar, min 0 / max 1, show_percentage=false)
│       ├── FeedbackLabel (Label, по центру, autowrap)
│       └── ReactionsBox (HBoxContainer) — 4 кнопки: Кивнуть / Сказать «согласен» / Предложить follow-up / Молчать
```
- 4 кнопки реакций — статичные ноды, в `_ready` подключить по индексу.
- ParticipantsRow — чисто декор, цветные квадраты. Подсветка текущего спикера — по желанию, не обязательна.
- Цвета фидбэка: GOOD зеленоватый, HINT серо-голубой, BAD красноватый (см. палитру `BugfixGame.gd`).

---

## WorkHub integration

`scripts/run2/WorkHub.gd`:
- `const MEETING_SCENE: String = "res://scenes/run2/MeetingGame.tscn"`
- `const MEETING_ENERGY_COST: int = 2`
- `@export var meeting_start_button_path: NodePath` + `@onready var _start_meeting_btn`
- В `_ready()` рядом с гейтингом Mail/Bugfix:
  ```gdscript
  if int(_run.current_day) >= 3:
      _start_meeting_btn.pressed.connect(_on_start_meeting)
  else:
      _lock_card("Card_Meeting", _start_meeting_btn)
  ```
- `func _on_start_meeting() -> void: _start_work_game(MEETING_SCENE, MEETING_ENERGY_COST)`
- В `_update_energy()`: `if int(_run.current_day) >= 3: _start_meeting_btn.disabled = int(_run.energy) < MEETING_ENERGY_COST`

`scenes/run2/WorkHub.tscn`:
- Добавить `Card_Meeting` в `ScrollContainer/CardsList` после `Card_Bugfix` — структура идентична активной `Card_Bugfix` (PanelContainer + `StyleBoxFlat_sorting`, `Margin/Row/Info/{NameLabel,DescLabel,StatsBox{RewardLabel,CostLabel,RiskLabel}}` + `StartBtn`). Это обязательно — `_lock_card` ходит по пути `.../Card_Meeting/Margin/Row/Info/`.
- Контент карточки: NameLabel «Созвон без смысла», DescLabel «Реагируй на реплики. Главное — не вызваться добровольцем.», RewardLabel «5–20$», CostLabel «-2 энергии», RiskLabel «Риск: Средний» (желтоватый, как у Почты).
- Прописать `meeting_start_button_path` на root-ноде WorkHub.

## RunService (1 строка)
`scripts/core/RunService.gd` — в `const INTERESTING_PREFIXES` добавить `"Созвон:"`, чтобы «назначили ответственным» мог попасть в `funniest_event` DaySummary.

---

## Acceptance
- [ ] День ≥ 3 (Run 2): WorkHub показывает «Созвон без смысла» доступной (карточка-актив, кнопка «Начать»).
- [ ] День 1 и день 2: Созвон заблокирован («Откроется позже», 🔒, StatsBox скрыт).
- [ ] «Начать» на Созвоне → списывается 2 энергии → открывается MeetingGame.
- [ ] Реплики идут последовательно, ProgressLabel «Реплика N/10».
- [ ] На каждой реплике TimerBar убывает за 3 сек; по истечении — авто-«Молчать», игра идёт дальше.
- [ ] Правильная реакция +2$, нейтральная +1$, ошибка −1$ — EarnedLabel обновляется.
- [ ] Реплика-«волонтёр» есть в каждой сессии; не-«Молчать» на ней → в конце −5$, запись в EventLog, кастомный комментарий в WorkResult.
- [ ] После 10-й реплики: +5$ бонус за «дожил», деньги зачислены в `Economy` (шапка выросла), `register_money_earned` вызван.
- [ ] WorkResult показывает итог; «Вернуться к работе» → WorkHub, «На рабочий стол» → Desktop.
- [ ] Кнопка «Назад» в середине созвона → возврат в WorkHub без ошибок (нода чисто удаляется).
- [ ] `get_editor_errors` — чисто.
- [ ] Playtest через MCP: форсить `current_day = 3` → Desktop → WorkHub → Созвон → пройти сессию (включая волонтёр-реплику) → проверить рост `Economy.money` → WorkResult → WorkHub.

## Out of scope (НЕ делать)
- НЕ добавлять апгрейды Созвона (`anti_shame_mic`, `second_monitor`) — Slice L.
- НЕ добавлять агента `meeting_avatar` — Slice M.
- НЕ вводить новые сигналы в `GameEvents` (`event_log_added`, `work_day_finished` уже есть).
- НЕ трогать другие мини-игры, их баланс и WorkProgram.
- НЕ делать финальный баланс наград — это Slice N (цели Run 2 + balance pass).
- НЕ менять Run1.gd/Run2.gd — Созвон хостится внутри WorkHub, как Mail/Bugfix.
- НЕ добавлять Run 3 мини-игры (`report`, `ai_check`, `freelance`).
