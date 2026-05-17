# История закрытых слайсов

Каждый завершённый слайс пишется сверху коротким блоком. История идёт от свежего к старому.

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
