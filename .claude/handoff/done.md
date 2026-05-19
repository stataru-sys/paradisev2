# История закрытых слайсов

## Slice H — Work Result Screen ✓

**Коммит:** `0f234f1`
**Ревью keeper'а:** ✓ принято 2026-05-19

**Что добавлено:**

| Файл | Что |
|---|---|
| `scripts/run2/WorkResult.gd` *(новый)* | Overlay результата работы. `setup(earned, errors, energy_used)` — заполняет лейблы, считает качество (0 ошибок → «Отлично», ≤2 → «Сойдёт», >2 → «Провал»), показывает случайный сатирический комментарий из трёх пулов. Сигнал `return_to_hub`. Кнопка «На рабочий стол» → `program_closed`. Все `get_node()` напрямую (без `@onready`) для надёжности при вызове `setup()` сразу после `instantiate()`. |
| `scenes/run2/WorkResult.tscn` *(новый)* | Control full_rect, Bg (полупрозрачный чёрный), PanelContainer по центру (520×440) с StyleBoxFlat. VBox: TitleLabel «Результат работы», HSeparator, EarnedLabel (зелёный), ErrorsLabel (красный, скрыт если 0), EnergyLabel (серо-голубой), QualityLabel (золотой), CommentLabel (серый, autowrap), HSeparator, ButtonsBox с HubBtn «Вернуться к работе» и DesktopBtn «На рабочий стол». |
| `scripts/run1/WorkProgram.gd` *(изменён)* | Добавлены `_errors_today`, `_energy_spent`. Убраны `finish_panel`/`finish_button`. При `_words_remaining == 0` → `_show_work_result()`: загружает WorkResult, инстанциирует, вызывает `setup()`, эмитит `work_day_finished`. |
| `scenes/run1/WorkProgram.tscn` *(изменён)* | Удалён `FinishPanel`. |
| `scripts/run2/WorkHub.gd` *(изменён)* | Убран reconnect `_finish_button`. Добавлена подписка `work_day_finished.connect(_on_game_finished, CONNECT_ONE_SHOT)` при старте игры. `_on_game_finished` ищет WorkResult в детях игры, подключает `return_to_hub` → `_on_game_return`. |

**Smoke через MCP (5/5 зелёных):**
1. Desktop → WorkHub → «Начать» → force-complete → WorkResult с данными (+40$, ошибок 2, энергия 3, «Сойдёт», случайный комментарий) ✓
2. «Вернуться к работе» → WorkHub (cards visible, game_host cleaned) ✓
3. «Назад» в WorkHub → Desktop ✓
4. Отдельно: «На рабочий стол» в WorkResult → Desktop напрямую ✓
5. Полный цикл: Desktop→Hub→Game→WorkResult→Hub→Desktop без утечек ✓

**Решения keeper'а:**
- Тон комментариев — **принято без правок**. «Без ошибок. Подозрительно», «Сойдёт. В отчёте напишем стабильно», «Много ошибок. Но тебе заплатили» — ровно сухая ирония, попадание в стилистику.
- `get_node()` вместо `@onready` в `setup()` — **правильно**, это не баг-фикс а архитектурное решение: setup вызывается сразу после instantiate, _ready мог не успеть.
- Два трека `_errors_today` и `_energy_spent` в WorkProgram — ок, для WorkResult нужно.
- Дублирование логики `_on_start_sorting` / `_on_game_finished` — пока ок для 1 игры. В Slice I будет дублирование для Почты, в Slice J для Фиксов — на третьей игре вынесем в общий `_start_work_game(scene_path, energy_cost)`.

**Известные компромиссы:**
- Удалённый `node_paths=PackedStringArray(...)` из заголовка .tscn — это редактор-специфичные метаданные, которые Godot не требует для рантайма. Без них @export NodePath десериализуются корректно. Если сцена когда-либо пересохранится из редактора — Godot добавит их обратно (и они уже не сломают).
- WorkHub ищет WorkResult по `c.name == "WorkResult"` и сигналу `return_to_hub`. Если переименовать root-ноду в WorkResult.tscn — сломается. Диагностируется: кнопка «Вернуться к работе» перестанет работать.
- WorkResult не `class_name` (был конфликт с глобальным классом при создании). Это мешает статической проверке типов, но не мешает рантайму.

**Следующий слайс (Slice I — Corporate Mail Mini-game):** `next.md` обновлён.

---

# История закрытых слайсов

Каждый завершённый слайс пишется сверху коротким блоком. История идёт от свежего к старому.

---

## Slice G — Work Hub MVP ✓

**Коммит:** `будет создан`
**Ревью keeper'а:** ✓ принято 2026-05-19

**Что добавлено:**

| Файл | Что |
|---|---|
| `scripts/run2/WorkHub.gd` *(новый)* | Экран выбора работы. TopBar с заголовком «Работа», EnergyLabel и BackBtn. ScrollContainer с 3 карточками (1 доступная + 2 locked). GameHost — Control поверх карточек для хостинга мини-игры. При клике «Начать» инстанциирует WorkProgram внутрь GameHost, переподключает back_button и finish_button WorkProgram на возврат в карточки. BackBtn → `program_closed` → Desktop. EnergyLabel обновляется по `energy_changed`, кнопка «Начать» disabled при energy ≤ 0. |
| `scenes/run2/WorkHub.tscn` *(новый)* | Полная сцена: Bg (тёмный ColorRect), TopBar (TitleLabel «Работа» / Spacer / EnergyLabel / BackBtn «Назад»), ScrollContainer → CardsList (VBoxContainer, separation=10), 3 карточки PanelContainer с StyleBoxFlat (Card_Sorting — зелёный оттенок, Card_Mail/Card_Bugfix — серые), GameHost (Control full_rect, visible=false). Карточка Sorting: NameLabel («Сортировка задач»), DescLabel (описание + autowrap), StatsBox (RewardLabel «3–30$» / CostLabel «-1 за категорию» / RiskLabel «Риск: Низкий»), StartBtn «Начать». Locked-карточки: NameLabel + DescLabel «Откроется позже» + LockIcon «🔒», цвета приглушённые. |
| `scripts/run1/Run1.gd` *(изменён)* | `SCENE_PATHS["work"]` → `res://scenes/run2/WorkHub.tscn` (вместо прямого WorkProgram). |
| `scripts/run2/Run2.gd` *(изменён)* | Аналогично Run1.gd. |

**Восстановлен из git:**
| `scenes/run1/DatingProgram.tscn` | Случайно повреждён MCP-операциями (в него попали ноды WorkHub). Восстановлен через `git checkout`. |

**Smoke через MCP:**
1. `play_scene main` → «Начать Run 1» → «ВКЛЮЧИТЬ» → Desktop ✓
2. `GameEvents.program_open_requested.emit("work")` → WorkHub загружен в MonitorScreen ✓
3. WorkHub: 3 карточки — «Сортировка задач» (зелёная, кнопка «Начать»), «Корпоративная почта» (серая, замок), «Фикс багов» (серая, замок) ✓
4. `click_button_by_text("Начать")` → WorkProgram (сортировка) загружена в GameHost, карточки скрыты ✓
5. `click_button_by_text("← Назад")` → WorkProgram убран, карточки WorkHub снова видны ✓
6. `click_button_by_text("Назад")` → Desktop загружен ✓

**Что keeper'у проверить вручную:**
- Тон текстов карточек (описание сортировки «Раскидай слова по категориям. Проще чем звучит. Буквально.»).
- Стиль карточек: зелёный оттенок для доступной vs серый для locked — достаточно ли контрастно.
- Иконка замка 🔒 — ок ли эмодзи в игровом интерфейсе или заменить на спрайт.
- Поведение при энергии=0: кнопка «Начать» должна быть disabled (проверено по коду, не в рантайме т.к. в Run 1 энергия 3/3).

**Компромиссы / known issues:**
- WorkHub переподключает кнопки WorkProgram через `game.get("_back_button")` / `game.get("_finish_button")` — доступ к «приватным» полям по соглашению GDScript. Если в WorkProgram переименуют `_back_button` → сломается без ошибки компиляции (btn == null → return). Диагностируется визуально: кнопка «← Назад» будет уводить на Desktop вместо WorkHub.
- Сцена WorkHub.tscn написана вручную (минуя MCP batch_add_nodes из-за бага с дублированием нод в текущей открытой сцене редактора). UID скрипта захардкожен. При пересоздании скрипта через MCP UID изменится → сцена сломается. Решается открытием сцены в редакторе и перепривязкой script.
- DatingProgram.tscn был восстановлен из git после случайного повреждения MCP-операциями. Keeper'у стоит убедиться что дейтинг работает (открыть на Desktop2 в Run 2).

**Пост-ревью правки:**
- Исправлено перекрытие TopBar скролл-контейнером: `anchor_top = 0.05` → `offset_top = 52.0` (фиксированный отступ вместо процента от высоты окна).
- Добавлен guard от двойного клика «Начать»: `if _game_host.get_child_count() > 0: return` в `_on_start_sorting()`.

**Решения keeper'а по замечаниям:**
- Run 1 тоже проходит через WorkHub (не расходимся с дизайн-документом — работает как тизер контента).
- Пункты 3 (доступ к приватным полям), 4 (нет обратной связи на locked-карточки), 5 (цвет RiskLabel) — отложены на будущие слайсы.

**Следующий слайс (Slice H — Work Result Screen):** см. `next.md`.

---

## Мастер-план A → F закрыт ✓

Шесть слайсов задеплоены: Run 1 + Run 2 + Магазин + Казино + Агенты + EventLog/DaySummary. Полная idle-кликер петля с пятью апгрейдами, четырьмя агентами, казино, лентой событий и расширенным DaySummary с четырьмя ветками вердиктов под Run 2.

| # | Слайс | Коммит | Состояние |
|---|---|---|---|
| A | Run 1 как первый день + RunService + MainScene-роутер | `dc93b9b` | ✓ |
| B | Run 2 каркас — Desktop2 с 6 иконками + роутер day>=2 | `19ab94f` | ✓ |
| C | Магазин апгрейдов — 5 апгрейдов + эффекты в Work/Dating/Mail | `c495bcd` | ✓ |
| D | Казино — 3 ставки, 5 исходов, история последних 5 | `d6a6185` | ✓ |
| E | ИИ-агенты — 4 агента с эффектами в Run 2 | `00f1f76` | ✓ |
| F | Event Log + Day Summary Run 2 + полировка | (текущий) | ✓ |

Дальнейшие итерации (Save с версионированием, Telemetry, цели Run 2, перенос content на `.tres`, имплантация, Run 3+, анимации) перечислены в `next.md` как кандидаты.

---

## Slice F — Event Log + Day Summary Run 2 + полировка ✓

**Коммит:** будет создан после ревью keeper'ом.

**Что добавлено:**

| Файл | Что |
|---|---|
| `scripts/ui/EventLog.gd` *(новый)* | `PanelContainer` с подпиской на `GameEvents.event_log_added` и `day_changed`. На новое сообщение — Label сверху, хвост обрезается до MAX_LINES=6. Через FADE_AFTER_SEC=12 секунд старые сообщения переходят на `modulate.a = 0.4`. На `day_changed` лента очищается. `set_process(true)` для проверки таймстампов раз в кадр. |
| `scenes/Run2.tscn` *(изменён)* | Добавлен `EventLog` (PanelContainer + Margin + VBox с Header + LinesBox) как фиксированный виджет внизу-слева (anchor 0.0–0.34 / 0.62–0.97). `mouse_filter=2` чтобы не перехватывать клики. Sibling-после-Layout = z-order поверх RoomOverview/Computer. |
| `scripts/core/RunService.gd` *(изменён)* | `const INTERESTING_PREFIXES` (Казино/Стажёр-GPT/Людмила/Ответчик-3000/Мини-делегатор) + `var _day_events: Array[String]` буфер. В `_ready()` подписка на `event_log_added` → `_on_event_log_added` фильтрует по префиксу и записывает в буфер. Очистка в `reset()` и `next_day()`. `_finish_day()` достаёт `funniest_event = _day_events[randi() % size]` и кладёт в summary. Расширен summary: `purchased_upgrades` / `active_agents` / `casino_won` / `casino_lost` / `funniest_event`. `_build_verdict()` для `current_day >= 2` имеет 4 ветки в приоритете (агенты ≥2 / казино игрался / апгрейды ≥3 / пустой день), иначе fall-through на Run 1 вердикты. |
| `scripts/run1/DaySummary.gd` *(переписан)* | `const UPGRADE_NAMES` + `AGENT_NAMES` для человекочитаемых имён id→название. В `_apply()` дополнительные опциональные строки в Stats: «Купленные апгрейды», «Активные агенты», «Казино: +X / -Y», «Самое абсурдное событие». Stats Label-ы теперь с autowrap. Новая утилита `_join_names()`. |
| `scenes/run1/DaySummary.tscn` *(изменён)* | Panel вырос с 520×440 на 640×560 (offsets ±320 × ±280) — чтобы вместить новые секции и длинный funniest_event. |
| `scripts/run2/Desktop2.gd` *(изменён)* | Добавлен `@export var hint_path: NodePath`. В `_refresh_lock_visuals()` после обновления modulate слотов: если все 3 нижние программы разблокированы — `Hint.visible = false`. |
| `scenes/run2/Desktop2.tscn` *(изменён)* | `hint_path = NodePath("Monitor/Layout/Hint")` на root-Control. |

**Smoke через MCP:**
1. `play_scene main` → setup `current_day=2 + Economy.add(500)` → Run2 загружен ✓
2. Программно: куплено 2 апгрейда (coffee + monitor), нанято 2 агента (mini_delegator + answerer_3000), 3 крутки казино с разными исходами (x0/x2/x7). Money 500 → 260, `casino_won=70 / casino_lost=10`, `_day_events.size()=3`. ✓
3. Дожить до конца дня → DaySummary показал все 4 новые секции:
   - «Купленные апгрейды: Кофе из автомата, Второй монитор» ✓
   - «Активные агенты: Мини-делегатор, Ответчик-3000» ✓
   - «Казино: +70$ / -10$» ✓
   - «Самое абсурдное событие: Казино: x7. Ты сорвал джекпот. Лучше уходи прямо сейчас. (+60$)» ✓
   - Вердикт: «Делегировал даже жизнь. ИИ справился. Ты — не очень.» (ветка `active_agents.size() >= 2`) ✓
4. EventLog внизу-слева в Run2 показал 3 строки казино с приглушением старых через ~12 секунд. ✓

**Что keeper'у проверить вручную:**
- Тон 4 новых вердиктов (особенно «Просто ещё один день. Это страшнее всего.» — попадает ли в авторскую сатиру).
- Положение EventLog (внизу-слева, перекрывает «Окно» и «Кровать» в RoomOverview). Если мешает обзору комнаты — можно подвинуть в правый нижний или сделать collapsible.
- Имена в `UPGRADE_NAMES` / `AGENT_NAMES` дублируют `name` из `const UPGRADES` в ShopApp.gd и `const AGENTS` в AgentShopApp.gd. Когда перенесём content в `.tres`, это разрулится одним источником.
- `INTERESTING_PREFIXES` фильтрует funniest_event. «Куплено: X» / «Нанят: X» не попадают (это сознательно — иначе «самое абсурдное» бы всегда было «Куплено: Кофе из автомата»). Если keeper хочет иначе — массив правится одним местом.
- 4 ветки `_build_verdict` для day >= 2 имеют чёткие приоритеты. Если игрок попадает под несколько — берётся первая по списку (агенты → казино → шопоголик → пустой). Хочется ли иначе — обсуждаемо.
- Когда все 3 нижние иконки разблокированы (типично после day 2), нижний Hint «Серые иконки пока заперты. Не время.» теперь скрывается. Это убирает визуальный артефакт.

**Компромиссы / known issues:**
- Funniest_event фильтруется по префиксу строки. Если префикс изменится (например «Стажёр-GPT» → «Стажёр GPT»), фильтр перестанет ловить. Но это редкий рефакторинг, и поломка тривиально диагностируется (DaySummary перестанет показывать «Самое абсурдное событие»).
- `purchased_upgrades.duplicate()` / `active_agents.duplicate()` в summary — копии массивов, чтобы DaySummary не мог случайно мутировать state. Незначительная аллокация, не оптимизировал.
- EventLog _process крутится каждый кадр для проверки modulate. На 6 Label-ах это копейки, но если когда-то увеличим MAX_LINES до сотен — нужен set_process_interval или Timer.
- DaySummary при отсутствии секции (например не играл в казино) просто не добавляет строку. Не показывает «Казино: не играл» — keeper может попросить такое поведение, это +1 elif в `_apply()`.
- Verdict «Просто ещё один день. Это страшнее всего.» срабатывает только если `money_earned_today == 0 and matches_today == 0`. Если игрок совсем не открывал программы — да, это попадание. Если хоть один drop карточки → money_earned >= 0 (но 0 если не закрыл категорию) — всё равно может сработать. Возможно надо тоньше: «не открыл ни одной программы».

**Следующие шаги:** см. блок «Дальше — на усмотрение keeper'а» в `next.md`. Мастер-план A→F закрыт. Самый приоритетный кандидат — Save с версионированием для playtest.

---

## Slice E — ИИ-агенты ✓

**Коммит:** будет создан после ревью keeper'ом.

**Что добавлено:**

| Файл | Что |
|---|---|
| `scenes/run2/AgentShopApp.tscn` *(новый)* | UI программы «ИИ-агенты». Bg тёмно-фиолетовый. Header: BackBtn + Title + MoneyLabel. Body: ScrollContainer/VBoxContainer/Inner — секция «Каталог агентов» (4 PanelContainer-карточки) + секция «Мои агенты» (EmptyHired placeholder + HiredBox со зеленовато-modulate карточками). |
| `scripts/run2/AgentShopApp.gd` *(новый)* | `const AGENTS: Array[Dictionary]` с 4 агентами. `_rebuild_shop_list()` + `_rebuild_hired_list()` rebuild на `money_changed`/`agent_hired`. На клик «Нанять» → `RunService.purchase_agent(id, cost)`, если true — `event_log_added("Нанят: <имя>")`. |
| `scripts/core/RunService.gd` *(изменён)* | `purchase_agent(agent_id, cost) -> bool` (по образцу `purchase_upgrade`: проверка дубликата, money, Economy.spend, append в `active_agents`, эмит `agent_hired`). `has_agent(id) -> bool`. **`apply_agents_for_new_day()`** — вызывается из `next_day()` сразу после `day_changed.emit()`, до `energy_changed.emit()`. Внутри: если has_agent("mini_delegator") — `Economy.add(10)` + event_log; 10% шанс — `energy -= 1` + event_log. |
| `scripts/core/GameEvents.gd` *(изменён)* | Добавлен `signal agent_hired(agent_id: String)`. |
| `scripts/run2/Run2.gd` *(изменён)* | `SCENE_PATHS["agents"] = "res://scenes/run2/AgentShopApp.tscn"` + в `_ready()` `if not _run.has_unlock("agents"): _run.unlock("agents")`. |
| `scripts/run1/WorkProgram.gd` *(изменён)* | В `_ready()` после построения words/categories: если `_run.has_agent("intern_gpt")` — `call_deferred("_intern_auto_solve")`. Новые функции `_intern_auto_solve()` (берёт случайное слово, 25% выбирает чужую категорию) и `_intern_drop()` (повторяет логику `_on_word_dropped`, но **без `spend_energy(1)`**). Эмитит `event_log_added` с пометкой «правильно»/«ошибка, штраф 1$». |
| `scripts/run1/DatingProgram.gd` *(изменён)* | `_on_like`: после dating_plus-проверки добавлен блок `if has_agent("lyudmila"): chance = clampf(chance + 0.15, 0.0, 1.0)`. `_on_dislike`: 20% шанс «промашки» — выбирает случайный матч из `_run.matches`, снижает симпатию на 0.1, эмитит sympathy_changed + event_log. |
| `scripts/run1/MailProgram.gd` *(изменён)* | `_roll_reply_buttons()` — если `has_agent("answerer_3000")` — `_add_agent_reply_button()` (фиолетовая Button «Пусть Ответчик-3000 ответит» первой в HBox). Новая функция `_on_agent_reply_pressed()` — выбор реакции 60/40, симпатия ±0.1, **не тратит энергию**, `register_reply_sent`, event_log_added. |

**Smoke через MCP:**
1. `play_scene main` → setup `current_day=2 + Economy.add(500)` → «Начать Run 1» → routing day 2 → Run2 ✓
2. Computer → Включить → Desktop2: **все 6 иконок яркие** (включая ИИ-агенты) ✓
3. Клик «ИИ-агенты» → AgentShopApp с 4 карточками, header «Деньги: 500$» ✓
4. `purchase_agent("mini_delegator", 120)` → true, money 500→380. `purchase_agent("answerer_3000", 100)` → true, money 380→280. `active_agents=["mini_delegator","answerer_3000"]` ✓
5. `next_day()` → money 280→290 (delta +10 от Мини-делегатора), event_log: «Мини-делегатор: +10$ за «работу пока ты спал»» ✓
6. Повторный `purchase_agent("mini_delegator", 120)` → false ✓
7. Добавлен fake match anya, открыта Mail → видна фиолетовая Button «Пусть Ответчик-3000 ответит» первой в ряду reply-buttons ✓
8. Программно `agent_btn.pressed.emit()` → energy 8→8 (delta 0, **не тратит энергию**), sympathy anya 0.50→0.40 (negative reaction). ✓

**Что keeper'у проверить вручную:**
- Тон описаний агентов (особенно «Решит за тебя 1 карточку в Работе при открытии. 25% шанс ошибки. Энергию не тратит — твою.» и «20% шанс «нажать не туда» — снижает симпатию у случайного матча.»).
- Цены агентов 60 / 80 / 100 / 120 — соотносятся ли с экономикой (4–5 полных-категорий-в-Work на одного агента).
- Intern_gpt и Людмила НЕ тестировались визуально (intern_gpt теоретически должен сработать на открытии Work, проверял только что код компилируется и логика drop-без-энергии написана). Если в реальной игре будет странное поведение (например intern_gpt дропает дважды или его эффект применяется на каждом перезаходе в Work) — это надо посмотреть.
- В Run2 hint снизу всё ещё «Серые иконки пока заперты. Не время.» — но серых иконок больше нет, hint выглядит странно. Поправляется одним modulate-update в Desktop2.gd или просто текстом — но это нюанс для Slice F.

**Компромиссы / known issues:**
- Каталог агентов как `const AGENTS` в `AgentShopApp.gd` (не `.tres`) — сознательно, по аналогии с UPGRADES в C.
- `mini_delegator` хаос-задача (10%) применяется через прямую модификацию `rs.energy` минуя `spend_energy()`. Это потому, что `spend_energy(1)` при `energy=max_energy` сразу после `next_day` мог бы триггернуть `_finish_day()` если max_energy=1 (теоретически). Обходим явным `energy = max(0, energy - 1)`. На практике в текущем балансе этой проблемы нет, но решил перестраховаться.
- intern_gpt дропает на первой открытой сессии Work. Если игрок выйдет в Desktop и снова войдёт в Work в тот же день — intern_gpt сработает заново. Это «фича для тестов», keeper может попросить ограничить «один раз в день» через флаг `_intern_used_today` в RunService.
- Answerer-3000 при наличии нескольких матчей применяется к **текущему** диалогу. Если игрок не открыл диалог — кнопка тоже не появится (т.к. она в `_roll_reply_buttons`, который вызывается из `_open_chat`).
- При активном `confident_replies` + `answerer_3000`: confident_replies НЕ стакается с answerer (тот всегда 60/40 — описание агента «60% позитивных» зафиксировано). Если keeper хочет стакать — изменить в `_on_agent_reply_pressed` на `0.6 + (0.1 if has_upgrade("confident_replies") else 0.0)`.

**Следующий слайс (Slice F — Event Log + Day Summary Run 2 + полировка):** см. `next.md`. Это финальный слайс мастер-плана.

---

## Slice D — Казино ✓

**Коммит:** будет создан после ревью keeper'ом (см. `git status`).

**Что добавлено:**

| Файл | Что |
|---|---|
| `scenes/run2/CasinoApp.tscn` *(новый)* | UI «Казино «Парадайз»». Bg тёмно-винный ColorRect → Margin → VBox. Header: BackBtn + Title (золотой акцент) + MoneyLabel + EnergyLabel. Body: HBox(LeftPanel 320px / MidSp 24px / RightPanel). LeftPanel: BetsHeader + BetButtons (HBox под 3 кнопки 10/25/50) + Selection-label + SpinBtn (большая, 56px высоты, начально disabled) + Disclaimer о шансах. RightPanel: HistoryHeader + EmptyHistory placeholder + HistoryBox (VBox 5 строк FIFO). |
| `scripts/run2/CasinoApp.gd` *(новый)* | `const OUTCOMES: Array[Dictionary]` с накопительными порогами 0.45/0.75/0.90/0.98/1.00 → multiplier 0/1/2/3/7. `_build_bet_buttons()` создаёт 3 Button с привязкой к `_select_bet()`. `_select_bet(bet)` запоминает `_selected_bet`, обновляет Selection label и подсвечивает выбранную кнопку через `modulate`. `_update_bet_button_states()` дизаблит кнопку ставки если `money < bet`. `_update_spin_button_state()` дизаблит «Крутить» если ставка не выбрана / money недостаточно / energy ≤ 0. `_on_spin_pressed()`: `Economy.spend(bet)` → `_roll_outcome()` → если multiplier>0, `Economy.add(bet*multiplier)` → `register_casino_win(delta)` (если delta>0) или `register_casino_loss(bet)` (если multiplier=0) → `_push_history()` → `event_log_added` → `spend_energy(1)`. История: новые строки в верх через `move_child(line, 0)`, хвост обрезается до `HISTORY_MAX=5`. Подписан на `money_changed`/`energy_changed`. |
| `scripts/core/RunService.gd` *(изменён)* | Добавлены `register_casino_win(amount)` (увеличивает `casino_won_today` если amount > 0) и `register_casino_loss(amount)` (аналогично `casino_lost_today`). |
| `scripts/run2/Run2.gd` *(изменён)* | `SCENE_PATHS["casino"] = "res://scenes/run2/CasinoApp.tscn"`. В `_ready()` после auto-unlock `shop` добавлен `if not _run.has_unlock("casino"): _run.unlock("casino")`. |

**Smoke через MCP:**
1. `play_scene main` → MainMenu → форс `current_day=2`, `Economy.add(500)` → клик «Начать Run 1» → routing day 2 → Run2.tscn ✓
2. Computer → Включить → Desktop2: иконка «Казино» **больше не приглушена** (только «ИИ-агенты» остаются locked) ✓
3. Клик «Казино» → CasinoApp открыт: header «$500 / Деньги: 500$ / Энергия 8/8», ставки 10/25/50 активны, «Крутить» disabled, «История пустая: Пока ни одной крутки. Можно начать.» ✓
4. Несколько одиночных круток ставкой 10$ через `spin_btn.pressed.emit()` — money меняется, история растёт, energy уменьшается. ✓

**Что НЕ проверено в smoke (отложено):**
- Статистическое распределение 45/30/15/8/2 на 200+ круток — попытка проверить программно через цикл повесила MCPGameInspector (сцена/компьютер). Распределение проверено только математически (накопительные пороги корректные). Если keeper хочет визуальной верификации — крутить вручную и читать историю/`casino_won_today`/`casino_lost_today`.
- Acceptance «История содержит не больше 5 строк» — проверено по коду (`while get_child_count() > HISTORY_MAX: queue_free` хвоста), не запущено runtime после фикса.

**Что keeper'у проверить вручную:**
- Тексты исходов (особенно «x7. Ты сорвал джекпот. Лучше уходи прямо сейчас.» и «Ничего. Просто ничего.») — попадают ли в тон.
- Цвета строк истории: зелёный для delta>0, красный для delta<0, нейтральный для delta=0. Может быть слишком ярко.
- Disclaimer «Шансы: 45% / 30% / 15% / 8% / 2%» — нужна ли вообще в проде или это spoiler от честного казино. Это сатира на казино, так что наверное норм.
- Подсветка выбранной кнопки ставки через modulate — на тёмном фоне может быть малозаметно.

**Компромиссы / known issues:**
- В крутке нет анимации барабана — просто мгновенный результат. Это OK для MVP.
- При недостатке денег для выбранной ставки `_selected_bet` сбрасывается и Selection текст → «Выбери ставку». Это может «сбросить» намерение игрока, если он выбрал ставку и в этот момент пришёл какой-то списания. На практике редко, но keeper может попросить менее агрессивный сброс.
- История не сохраняется между запусками программы (Назад → снова Казино → пусто). Это сознательно — история per-session.
- `event_log_added` эмитится, но UI EventLog ещё нет — увидим только в Slice F. Пока сообщения идут «в никуда» (никто не подписан, кроме внутренних подписчиков).

**Следующий слайс (Slice E — ИИ-агенты):** см. `next.md`.

---

## Slice C — Магазин апгрейдов ✓

**Коммит:** будет создан после ревью keeper'ом (см. `git status`).

**Что добавлено:**

| Файл | Что |
|---|---|
| `scenes/run2/ShopApp.tscn` *(новый)* | Программа «Магазин апгрейдов». Корневой `Control` с `Bg` (бежевый ColorRect) → MarginContainer → VBox. TopBar: BackBtn + Title «Магазин апгрейдов» + MoneyLabel. Под TopBar — ScrollContainer/VBox `ListBox`, который наполняет `ShopApp.gd` карточками. |
| `scripts/run2/ShopApp.gd` *(новый)* | `const UPGRADES: Array[Dictionary]` с 5 апгрейдами (coffee/monitor/dating_plus/confident_replies/autoclicker). `_rebuild_list()` создаёт PanelContainer для каждого: HBox info(title+desc autowrap) + right(price+button). `_apply_button_state()` ставит «Куплено»/disabled, если уже куплено, или disabled если денег не хватает. Подписан на `GameEvents.money_changed` (обновляет MoneyLabel + кнопки) и `upgrade_purchased` (rebuild list). На клик «Купить» → `RunService.purchase_upgrade(id, cost)`; если true — эмитит `event_log_added("Куплено: <название>")`. |
| `scripts/core/RunService.gd` *(изменён)* | `purchase_upgrade(upgrade_id: String, cost: int) -> bool` — проверяет has_upgrade (дубликат → false), берёт `/root/Economy`, проверяет `money >= cost`, вызывает `economy.spend(cost)`, добавляет в `purchased_upgrades`, эмитит `GameEvents.upgrade_purchased`. `has_upgrade(id) -> bool`. `_compute_max_energy()` возвращает `MAX_ENERGY_BASE + (2 if has_upgrade("coffee") else 0)` — вызывается в `next_day()` (то есть кофе вступает в силу со **следующего** дня после покупки). `reset()` уже ставил `max_energy = MAX_ENERGY_BASE`, поэтому coffee при сбросе run-а пропадает. |
| `scripts/core/GameEvents.gd` *(изменён)* | Добавлен `signal upgrade_purchased(upgrade_id: String)`. |
| `scripts/run2/Run2.gd` *(изменён)* | `SCENE_PATHS["shop"] = "res://scenes/run2/ShopApp.tscn"`. В `_ready()` до подписок: `if not _run.has_unlock("shop"): _run.unlock("shop")` — Магазин разблокирован автоматически в день 2+. |
| `scripts/run2/Desktop2.gd` *(изменён)* | `_refresh_lock_visuals()` после connect'ов: для каждого слота из bottom-ряда снимает modulate 0.5 если `_run.has_unlock(program_id)`. Локированный `_on_lockable_pressed` стал `_on_lockable_pressed` (переименован) и проверяет has_unlock — если есть, эмитит `program_open_requested`. |
| `scripts/run1/WorkProgram.gd` *(изменён)* | `const MONITOR_BONUS: int = 5`. В `_on_word_dropped` при закрытии категории: `bonus = CATEGORY_FULL_BONUS + (MONITOR_BONUS if has_upgrade("monitor") else 0)`. Новые функции `_setup_autoclicker_button()` (создаёт Button «Решить 1 карточку» программно и вставляет в TopBar перед EarnedLabel, только если has_upgrade("autoclicker")) и `_on_autoclicker_pressed()` (берёт первое WordCard в `_words_box`, ищет нужный CategorySlot, вызывает `_on_word_dropped` — это списывает 1 энергию + даёт правильный ответ). |
| `scripts/run1/DatingProgram.gd` *(изменён)* | `_on_like` теперь `chance = clampf(match_chance + 0.1, 0.0, 1.0)` если has_upgrade("dating_plus"). |
| `scripts/run1/MailProgram.gd` *(изменён)* | `_on_reply_picked` — `positive_chance = 0.6 if has_upgrade("confident_replies") else 0.5`. |

**Smoke через MCP (8/8 зелёных):**
1. `play_scene main` → MainMenu виден ✓
2. `execute_game_script` форсит `rs.current_day=2` + `eco.add(300)` → клик «Начать Run 1» → routing day 2 → Run2.tscn, шапка «$300 День 2 / Энергия 8/8» ✓
3. Клик «Компьютер» → «ВКЛЮЧИТЬ» → Desktop2 с **разблокированной** ярко-жёлтой иконкой «Магазин» (Казино/Агенты — приглушённые) ✓
4. Клик «Магазин» → ShopApp с 5 карточками + ScrollContainer, MoneyLabel «Деньги: 300$» ✓
5. `execute_game_script`: `purchase_upgrade()` × 5 → все 5 true, money 300→270→220→180→145→85 ✓
6. Защита от дубликата: повторный `purchase_upgrade("coffee", 30)` → false, money не изменилась ✓
7. 8×spend_energy → `next_day()` → шапка «День 3 / Энергия 10/10» — coffee bonus сработал ✓
8. `GameEvents.program_open_requested.emit("work")` → WorkProgram: кнопка «Решить 1 карточку» в TopBar; 5 нажатий с предварительной перестановкой нужного слова в начало → money 85 → 100 (delta +15$), `work_correct_today=5`, `energy 10 → 5` — monitor (15$ за категорию) + autoclicker (списание энергии и автоматическое правильное решение) подтверждены ✓

**Что keeper'у проверить вручную:**
- UX покупки: после клика «Купить» карточка визуально становится «Куплено» — это происходит через rebuild списка, может моргнуть scroll position. Если будет мешать, заменим `_rebuild_list()` на точечное обновление одной карточки.
- Тон описаний (особенно «Кофе из автомата: Спишет когнитивный долг позже.», «Дешёвый автокликер: Тратит 1 энергию, как всё в этой жизни.»).
- Цены: 30 / 40 / 35 / 50 / 60 — соответствуют ли балансу первых дней (если коробка зарплаты ≈30$ за полную категорию × 3 категории = 90$/день, цены укладываются в 1–2 дня заработка).
- В Desktop2: иконка «Магазин» сейчас разблокирована **автоматически в день 2+**. Если хочется gating через цель «доживи до дня 3» или достижение по деньгам — это делается одной строкой в `Run2.gd._ready()`.

**Компромиссы / known issues:**
- Контент апгрейдов — `const UPGRADES: Array[Dictionary]` в `ShopApp.gd`, не `.tres`. Это сознательное упрощение (подсказка в next.md). Переезд на Resource будет тривиальным, когда понадобится Inspector-редактирование или баланс через keeper'а.
- Кнопка «Решить 1 карточку» добавляется программно — в `WorkProgram.tscn` её нет. Это сделано чтобы не разделять сцену на «with_autoclicker» / «without». Стиль кнопки наследует тему по умолчанию, что выглядит ок.
- При перезагрузке Run 2 (после `next_day()`) сцена пересоздаётся, и подписки на `money_changed` теряют последнее значение → шапка показывает «$0» пока какое-то событие не эмитнёт `money_changed`. В smoke-тесте я форсил это вручную через `GameEvents.money_changed.emit(eco.money)`. **Потенциальная улучшалка:** в `Run2._ready()` после connect'а сразу `_on_money_changed(int(_economy.money))` — чтобы пробросить текущее значение. Я этого делать не стал, потому что в реальной игре деньги начинаются с 0 и эмитятся через Work-программу до того как игрок откроет Run 2 шапку. Но keeper может попросить добавить — это +2 строки в `Run2._ready()`.
- `dating_plus` подтверждён только тем что код добавляет +0.1 (визуальный тест не делался — рандом). `confident_replies` аналогично — тестируется только статистически.

**Следующий слайс (Slice D — Казино):** см. `next.md`.

---

## Slice B — Run 2 каркас + переход через RunService ✓

**Коммит:** будет создан после ревью keeper'ом (см. `git status`).

**Что добавлено:**

| Файл | Что |
|---|---|
| `scenes/Run2.tscn` *(новый)* | Корневой Control дня 2+. Структура полностью совпадает с Run1.tscn (NavBar / Computer-view / RoomOverview / GoalsPanel) — те же `@export`-пути нод. Отличия: text StartOverlay-hint = «Новый день. Опять компьютер.», начальный текст DayLabel = «День 2», script — Run2.gd. |
| `scripts/run2/Run2.gd` *(новый)* | Полный клон Run1.gd с одним отличием: `SCENE_PATHS["desktop"]` → `res://scenes/run2/Desktop2.tscn`. Все остальные программы (work/dating/mail) переиспользуют сцены из `res://scenes/run1/`. |
| `scenes/run2/Desktop2.tscn` *(новый)* | Рабочий стол Run 2 — 6 иконок в 2 ряда (Monitor → Layout(VBox) → IconsTop(HBox 3 шт) + GapMid + IconsBottom(HBox 3 шт) + Hint). Слоты: WorkSlot/DatingSlot/MailSlot сверху, ShopSlot/CasinoSlot/AgentsSlot снизу. У нижних трёх `modulate = Color(1,1,1,0.5)` на слот-Control (приглушает Rect+Caption+Btn разом, кнопка кликабельна). Цвета: голубой/розовый/зелёный сверху, жёлтый/красный/фиолетовый снизу. Hint снизу: «Серые иконки пока заперты. Не время.». |
| `scripts/run2/Desktop2.gd` *(новый)* | 6 NodePath @export, 6 Button.pressed.connect в `_ready()`. Top-3 → `GameEvents.program_open_requested.emit(id)`. Bottom-3 → `_on_locked_pressed(id)`: если `RunService.has_unlock(id)` — открыть программу, иначе `GameEvents.event_log_added.emit("Откроется позже. Тебе пока хватает проблем.")`. |
| `scripts/ui/MainScene.gd` *(изменён)* | `_ready()` теперь: `day <= 1 → Run1.tscn`, `day >= 2 → Run2.tscn`. Константы `RUN1_SCENE`/`RUN2_SCENE` для читаемости. |
| `scripts/core/RunService.gd` *(изменён)* | Добавлено `var unlocks: Array[String] = []` + сброс в `reset()` + методы `unlock(id)` (идемпотентный) и `has_unlock(id) -> bool`. Slice C/D/E будут вызывать `unlock("shop"|"casino"|"agents")`. |
| `scripts/run1/Run1State.gd` *(удалён)* | Файл + `.uid` удалены. Параллельно вычищены no-op `attach_state()` из `Desktop.gd`/`WorkProgram.gd`/`DatingProgram.gd`/`MailProgram.gd` (стояли с типом `Run1State` или `_state` без типа — мешали удалению класса). |

**Smoke через MCP (8/8 зелёных):**
1. `play_scene main` → MainMenu виден ✓
2. Клик «Начать Run 1» → Output: `[MainScene] routing day 1 → res://scenes/Run1.tscn`, шапка «День 1 / Энергия 8/8» ✓
3. `execute_game_script` 8 × `RunService.spend_energy(1)` → DaySummary поверх Run1 («День 1 закрыт / Заработано 0$ / Цели: [ ][ ][ ][x] / Вердикт: Ты почти функционировал. Почти.») ✓
4. Клик «Начать следующий день» → Output: `[MainScene] routing day 2 → res://scenes/Run2.tscn`, шапка «День 2 / Энергия 8/8», цели сброшены ✓
5. Клик «Компьютер» → Computer-view, новый StartOverlay-hint «Новый день. Опять компьютер.» ✓
6. Клик «ВКЛЮЧИТЬ» → Desktop2: 6 иконок, top-3 яркие, bottom-3 приглушённые, Hint виден ✓
7. `execute_game_script` shop_btn/casino_btn/agents_btn `pressed.emit()` → подписчик собрал 3 сообщения «Откроется позже. Тебе пока хватает проблем.» ✓
8. Клик «Работа» (top) → WorkProgram запустился в monitor_screen, карточки слов на месте ✓

**Что keeper'у проверить вручную:**
- Тон Hint в Desktop2 и hint на StartOverlay Run2 («Серые иконки пока заперты. Не время.» / «Новый день. Опять компьютер.»).
- Цвета приглушённых иконок (modulate 0.5) — не слишком ли блёкло? Можно поднять до 0.6 если плохо читается.
- Должно ли в день 2 при отсутствии разблокировок цели быть теми же что в день 1, или уже разные? Сейчас — те же DAY1_GOALS (см. Out-of-scope в next.md Slice B / Slice F).
- В Run2.tscn DayLabel инициализируется текстом «День 2» — это лишь дефолт ноды до того как `_on_day_changed` обновит его; в реальном раннере перезапишется первым же сигналом из `_ready()`.

**Компромиссы / known issues:**
- `Run2.tscn` — полная копия Run1.tscn (~250 строк). При изменении layout'а комнаты придётся править оба. Альтернатива — вынести RoomOverview/Computer в общий PackedScene; отложено до момента когда обе сцены реально начнут расходиться (Slice F).
- В Desktop2 «приглушение» сделано через `modulate` на Slot-Control. Кнопка остаётся кликабельной (это нужно чтобы поймать клик и эмитнуть locked-сигнал) — пользователь визуально может подумать что иконка disabled, но при клике получит «лог события». Если в Slice F появится EventLog UI, эти сообщения станут видны.
- Цели в Run 2 пока `DAY1_GOALS` — формально цели «День 2» это другая история. Расширение целей под день 2 запланировано в Slice F.

**Следующий слайс (Slice C — Магазин апгрейдов):** см. `next.md`.

---

## Slice A — Run 1 как первый день + RunService + MainScene-роутер ✓

**Коммит:** см. `git log` (последний после "Run 1: общий план...").

**Что добавлено:**

| Файл | Что |
|---|---|
| `scripts/core/RunService.gd` *(новый autoload)* | `current_day`, `energy`, `max_energy`, `money_earned_today`, `work_errors/correct_today`, `matches`, `sympathies`, `purchased_upgrades`, `active_agents` + методы `spend_energy()`, `next_day()`, `reset()`, `register_money_earned()`, `register_work_correct/error()`, `register_program_opened()`, `register_reply_sent()`, `register_match_added()`, `get_goals_view()`. Цели Run 1 (`DAY1_GOALS`): «Заработать 30$», «Проверить дейтинг», «Ответить на сообщение», «Дожить до вечера». Вердикт: <30$ — «Ты почти функционировал. Почти.»; 30–49$ — «День прожит без позора.»; ≥50$ — «Подозрительно продуктивно. Тревожно.». |
| `scripts/core/GameEvents.gd` *(расширен)* | Сигналы `day_changed(day)`, `day_finished(summary)`, `goal_completed(goal_id)`, `event_log_added(message)`. `energy_changed` теперь `(current, max)`. |
| `scripts/ui/MainScene.gd` + `scenes/MainScene.tscn` *(новые)* | Корневой роутер. В `_ready` читает `RunService.current_day`, печатает `[MainScene] routing day N → ...` и `change_scene_to_file` на нужный run. В A — всегда Run1. В B — добавится switch на Run2. |
| `scripts/run1/DaySummary.gd` + `scenes/run1/DaySummary.tscn` *(новые)* | Overlay-итог дня: затемнение + Panel в центре, разделы Итог/Цели/Вердикт + кнопка «Начать следующий день» → `RunService.next_day()` + `change_scene_to_file("MainScene.tscn")`. |
| `scripts/ui/MainMenu.gd` *(изменён)* | Кнопка «Начать Run 1» теперь грузит `MainScene.tscn`, не `Run1.tscn` напрямую. |
| `scenes/Run1.tscn` *(расширен)* | В NavBar: `DayLabel`, `EnergyLabel` (плюс к существующему `EarnedLabel`). В RoomOverview: `GoalsPanel` справа сверху с заголовком «Цели дня» и `GoalsBox` (4 строки `[ ] / [x] текст`). |
| `scripts/run1/Run1.gd` *(переписан)* | Убран локальный `Run1State` (заменён обращением к `RunService`). Подписки на `day_changed`/`energy_changed`/`goal_completed`/`day_finished`. По `day_finished` — instantiate `DaySummary.tscn` поверх Run1 root. `_rebuild_goals()` перерисовывает чек-боксы при изменении состояния целей. |
| `scripts/run1/WorkProgram.gd` *(дополнен)* | Подключен `_run = /root/RunService`. На правильный drop — `_run.register_work_correct()` + (при полной категории) `_run.register_money_earned(10)`. На ошибку — `_run.register_work_error()`. После каждого drop'а — `_run.spend_energy(1)`. |
| `scripts/run1/DatingProgram.gd` *(переписан)* | `attach_state` теперь noop, state читает из `_run`. На лайк — `_run.register_match_added(profile)` + `_run.spend_energy(1)`. На диз — только `spend_energy(1)`. При `energy <= 0` кнопки disabled. |
| `scripts/run1/MailProgram.gd` *(переписан)* | `attach_state` noop. Список матчей читается из `_run.matches`, симпатии — из `_run.sympathies`. На ответ — `_run.register_reply_sent()` + `_run.spend_energy(1)` + обновление `_run.sympathies[id]`. При `energy <= 0` кнопки ответов не показываются. |
| `project.godot` *(через MCP add_autoload)* | `RunService="*res://scripts/core/RunService.gd"`. |

**Smoke через MCP (8/8 зелёных):**
1. `play_scene` → MainMenu → клик «Начать Run 1» → Output: `[MainScene] routing day 1 → res://scenes/Run1.tscn` ✓
2. Шапка Run 1: `$0 | День 1 | Энергия 8/8` ✓
3. Виджет «Цели дня» справа в overview, 4 строки `[ ]` ✓
4. `register_money_earned(40)` → цель `earn_30` авто-mark, виджет обновился `[x] Заработать 30$` ✓
5. `register_program_opened("dating")` → `[x] Проверить дейтинг` ✓
6. `register_reply_sent()` → `[x] Ответить на сообщение` ✓
7. 8 × `spend_energy(1)` → энергия 8→0, `day_finished` эмитнут, DaySummary поверх Run1: «День 1 закрыт / Заработано 40$ / Цели [x][x][x][x] / Вердикт: День прожит без позора.» ✓
8. Клик «Начать следующий день» → Output: `[MainScene] routing day 2 → res://scenes/Run1.tscn`, шапка `День 2 | Энергия 8/8`, цели сброшены ✓

**Что keeper'у проверить вручную:**
- Тон вердиктов и текстов целей.
- Не «жжётся» ли цикл `_rebuild_goals()` (он перестраивает 4 Label на каждый goal_completed; для 4 целей это копейки, но если будет 10+ — нужен diff).
- Логика «дожить до вечера» — авто-mark в `_finish_day`. Прям сейчас «доживание» = достичь energy=0. Может стоит триггерить только если все 3 другие цели выполнены, иначе цель тривиальная.

**Компромиссы / known issues:**
- `Run1State.gd` фактически не используется, но файл остался в `scripts/run1/`. `attach_state` в программах = noop. Удалить в B.
- DaySummary `Verdict` — вердикт строится в RunService, в `done.md` Run 2 потребуется расширить (Slice F).
- Если игрок открыл DaySummary и кликнул «Назад» через `← Встать` Computer-вью — overlay остался поверх. Сейчас невозможно (energy=0 блокирует ввод программ), но в B/C/D/E надо аккуратнее.
- При `day=2` загружается тот же `Run1.tscn` — это плейсхолдер до Slice B. Игроку визуально кажется что день повторяется без новых иконок (но `current_day` реально = 2). Slice B переключит на `Run2.tscn`.

**Следующий слайс (Slice B):** см. `next.md`.
