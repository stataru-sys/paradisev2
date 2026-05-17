# Run 1 + Run 2 петля — мастер-план A → F

Большое ТЗ от keeper'а разбито на 6 независимых слайсов. Каждый — отдельный coder-чат (открывается командой `claude` в этой папке, первое действие — прочитать этот файл).

**Маркер прогресса** держится в этом же файле. Кончил слайс → допиши `done.md` → обнови маркер.

---

## Общий план

| # | Слайс | Что добавляет | Статус |
|---|---|---|---|
| A | **Run 1 как первый день** + RunService + MainScene-router | Энергия, day topbar, цели, DaySummary, end-of-day, autoload-сервис состояния run-а, роутер сцен | **✓ закрыт** |
| B | **Run 2 каркас** + переход через RunService | Run2.tscn с 6 иконками Desktop'а (3 рабочих + 3 заглушки), `next_day()` в роутере | **активный** |
| C | **Магазин апгрейдов** | ShopApp с 5 апгрейдами (кофе / монитор / дейтинг+ / курс ответов / автокликер), интеграция эффектов в Economy/Work/Dating/Mail | pending |
| D | **Казино** | CasinoApp с 3 ставками (10/25/50), 5 исходов (45/30/15/8/2%), история последних 5 | pending |
| E | **ИИ-агенты** | AgentShopApp с 4 агентами (Стажёр-GPT / Людмила / Ответчик-3000 / Мини-делегатор), применение в начале дня и при действиях, побочки | pending |
| F | **Event log + Day Summary Run 2 + полировка** | EventLog widget, подписка на сигналы из всех систем, расширенный DaySummary с разделом «самое абсурдное событие», 4 вердикта | pending |

**Зависимости:**
- B зависит от A (✓ есть RunService).
- C/D/E независимы между собой, все зависят от B (Run 2 как контейнер для новых иконок).
- F замыкает все системы.

---

## Что уже готово (после Slice A)

- `RunService` autoload — единое состояние run-а (`current_day`, `energy`, `matches`, `sympathies`, `purchased_upgrades`, `active_agents`). Цели Run 1 встроены в сервис.
- `MainScene.tscn` — корневой роутер. В A всегда грузит Run1, в B — добавляется switch на Run2 по `current_day >= 2`.
- DaySummary overlay с кнопкой «Начать следующий день» → `RunService.next_day()` → `MainScene.tscn` (роутер перезагружается, видит новый day).
- В Run 1: шапка показывает день/деньги/энергию, виджет целей в RoomOverview справа сверху, любое действие тратит 1 энергию, при 0 — DaySummary.
- `Run1State.gd` deprecated, не используется (но файл ещё лежит в `scripts/run1/`).

---

## Текущий слайс — B (Run 2 каркас)

### Goal
Создать `Run2.tscn` — сцену второго дня, в которой Desktop показывает 6 иконок: 3 базовых (Работа/Дейтинг/Почта) работают как в Run 1, 3 новых (Магазин/Казино/ИИ-агенты) — placeholder'ы с tooltip «Откроется позже. Тебе пока хватает проблем.». MainScene-роутер переключается на Run2.tscn при `current_day >= 2`. Никаких новых программ-сцен — только каркас. Магазин/Казино/ИИ-агенты придут в C/D/E.

### Files to touch

**Создать:**
- `scenes/Run2.tscn` + `scripts/run2/Run2.gd` — копия Run1 с расширенным Desktop. Лучший путь: дублировать `Run1.tscn` (через MCP `get_scene_file_content` → новый `.tscn`), переименовать root в `Run2`, поменять текст StartOverlay-hint если хочется, и заменить `Desktop.tscn` в SCENE_PATHS на `Desktop2.tscn`.
- `scenes/run2/Desktop2.tscn` + `scripts/run2/Desktop2.gd` — новый Desktop с 6 иконками в 2 ряда: [Работа / Дейтинг / Почта] + [Магазин(disabled) / Казино(disabled) / ИИ-агенты(disabled)]. Disabled-иконки серые, при нажатии показывают tooltip-overlay «Откроется позже. Тебе пока хватает проблем.».

**Изменить:**
- `scripts/ui/MainScene.gd` — `_ready()` switch по `RunService.current_day`: `1 → Run1.tscn`, `>= 2 → Run2.tscn`.
- `scripts/core/RunService.gd` — добавить поле `unlocks: Array[String]` (список разблокированных программ, для Slice C+). По умолчанию пуст. Метод `unlock(program_id)`. Slice C/D/E будут заполнять.
- Удалить `scripts/run1/Run1State.gd` (deprecated после A).

### Acceptance
- [ ] `Run2.tscn` запускается, основные элементы скопированы из Run1.
- [ ] Desktop2 показывает 6 иконок в 2 ряда, цвета по макету (Работа голубая, Дейтинг розовый, Почта зелёная; Магазин жёлтый, Казино красный, ИИ-агенты фиолетовый).
- [ ] Заблокированные иконки имеют пониженный modulate (alpha ~0.5) и при клике эмитят что-нибудь типа `GameEvents.event_log_added("Откроется позже...")` (без падения).
- [ ] Из DaySummary день 1 → клик «Начать следующий день» → Output: `[MainScene] routing day 2 → res://scenes/Run2.tscn`.
- [ ] Работа/Дейтинг/Почта в Run 2 работают как в Run 1.
- [ ] Виджет целей в Run 2 — пусть пока показывает тот же DAY1_GOALS (правка для нового дня — в Slice F вместе с расширенным DaySummary).
- [ ] Smoke: Run 1 → 8 действий → DaySummary → следующий день → Run 2 с 6 иконками → клик «Магазин» → лог события или невидимая реакция (но не краш).

### Out of scope (Slice B не делает)
- Реальный магазин апгрейдов (Slice C).
- Реальные программы Казино / Агенты (D / E).
- EventLog UI (F).
- Сброс целей под Run 2.
- Кнопки в Run 2 для возврата в Run 1 (это не задумано).

### Подсказки
- Самый простой путь скопировать Run1 — через файловую систему: `cp` через bash, потом отредактировать .tscn. Но проще через MCP: `get_scene_file_content` для исходника, новый `create_scene` + `batch_add_nodes` по полученной структуре.
- Иконки Desktop2 → переиспользовать pattern из `scenes/run1/Desktop.tscn` (HBoxContainer с слотами Control/ColorRect/Label/Button), но 2 ряда: VBoxContainer→HBoxContainer×2.
- Disabled-иконки — Button с `disabled=true` НЕ ловят клик. Чтобы показать tooltip-toast — оставить Button enabled и в обработчике pressed проверять `if not _run.unlocks.has("shop"): _show_tooltip()`. Либо просто `Control` с `mouse_filter=PASS` и Label сверху.
- При создании сцены Run2 через MCP — обязательно `open_scene` перед `batch_add_nodes`, иначе ноды попадут в активную сцену. Это укусило в Slice 1.

---

## Заготовки следующих слайсов

### Slice C — Магазин апгрейдов
`scripts/data/UpgradeData.gd` (Resource с id/name/description/cost/effect_id). 5 апгрейдов как `.tres` в `resources/upgrades/` или Dictionary-список в `ShopAppController.gd`. `ShopApp.tscn` + контроллер. `RunService.purchase_upgrade(id)`, `RunService.has_upgrade(id)`, signal `upgrade_purchased`. Эффекты: «Кофе из автомата» (+2 max_energy со следующего дня), «Второй монитор» (+5$ за карточку в Work), «Подписка дейтинг+» (+0.1 к match_chance), «Курс уверенных ответов» (+0.1 к positive в Mail), «Дешёвый автокликер» (открывает кнопку «Решить 1 карточку» в Work).

### Slice D — Казино
`CasinoApp.tscn` + контроллер. 3 кнопки ставок (10/25/50, отключаются если money < bet). Кнопка «Крутить» — randf() против таблицы (45% проигрыш / 30% возврат / 15% x2 / 8% x3 / 2% x7). Тексты исходов по ТЗ. История 5 — VBox с лейблами. `_run.spend_energy(1)` на крутку. `_run.casino_won_today/lost_today` для статистики.

### Slice E — ИИ-агенты
`scripts/data/AgentData.gd` (Resource). 4 агента: Стажёр-GPT (60$, 1 карточка Work авто, 25% ошибка), Людмила (80$, +0.15 match_chance, иногда снижает симпатию), Ответчик-3000 (100$, 1 авто-ответ в Mail, 60% успех), Мини-делегатор (120$, +10$ пассивно в начале дня, 10% хаос-задача отнимает энергию). `AgentShopApp.tscn` с 2 секциями (Магазин / Мои агенты). `RunService.active_agents`, метод `apply_agents_for_new_day()` — вызывается из `next_day()`. Сигнал `event_log_added` для каждого срабатывания.

### Slice F — Event log + Day Summary Run 2 + полировка
`scripts/ui/EventLog.gd` — Control с FIFO-очередью последних 5–7 строк, подписан на `GameEvents.event_log_added(message)`. Виджет в Run2.tscn внизу или сбоку. Все системы эмитят `event_log_added`. DaySummary Run 2 — добавить разделы «купленные апгрейды», «купленные агенты», «казино: +X / -Y», «самое абсурдное событие» (рандом из EventLog). 4 новых вердикта (по ТЗ).
