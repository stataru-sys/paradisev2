# Run 1 + Run 2 петля — мастер-план A → F

Большое ТЗ от keeper'а разбито на 6 независимых слайсов. Каждый — отдельный coder-чат (открывается командой `claude` в этой папке, первое действие — прочитать этот файл).

**Маркер прогресса** держится в этом же файле. Кончил слайс → допиши `done.md` → обнови маркер.

---

## Общий план

| # | Слайс | Что добавляет | Статус |
|---|---|---|---|
| A | **Run 1 как первый день** + RunService + MainScene-router | Энергия, day topbar, цели, DaySummary, end-of-day, autoload-сервис состояния run-а, роутер сцен | **✓ закрыт** |
| B | **Run 2 каркас** + переход через RunService | Run2.tscn с 6 иконками Desktop'а (3 рабочих + 3 заглушки), `next_day()` в роутере | **✓ закрыт** |
| C | **Магазин апгрейдов** | ShopApp с 5 апгрейдами (кофе / монитор / дейтинг+ / курс ответов / автокликер), интеграция эффектов в Economy/Work/Dating/Mail | **активный** |
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

## Что готово после Slice B

- `scenes/Run2.tscn` + `scripts/run2/Run2.gd` — копия Run1 с тем же routing-поведением, но `SCENE_PATHS["desktop"]` указывает на Desktop2. StartOverlay hint: «Новый день. Опять компьютер.».
- `scenes/run2/Desktop2.tscn` + `scripts/run2/Desktop2.gd` — 6 иконок в 2 ряда (VBox → HBox top + GapMid + HBox bottom). Нижние 3 (Shop/Casino/Agents) с `modulate Color(1,1,1,0.5)`. При клике на locked-кнопку — проверка `_run.has_unlock(id)`; если нет, эмитит `GameEvents.event_log_added("Откроется позже. Тебе пока хватает проблем.")`.
- `scripts/ui/MainScene.gd` — `_ready()` switch: `day <= 1 → Run1.tscn`, `day >= 2 → Run2.tscn`.
- `RunService.unlocks: Array[String]` + `unlock(id)` + `has_unlock(id)` + сброс в `reset()`. Slice C/D/E будут вызывать `unlock("shop"|"casino"|"agents")`.
- `Run1State.gd` удалён вместе с `.uid`. Из Desktop.gd / WorkProgram.gd / DatingProgram.gd / MailProgram.gd убраны no-op `attach_state()`.

---

## Текущий слайс — C (Магазин апгрейдов)

### Goal
Реализовать ShopApp (Магазин апгрейдов) как полноценную программу Run 2. Контент: 5 апгрейдов с эффектами на Economy/Work/Dating/Mail. Покупка через Run-стейт; повторная покупка одного апгрейда невозможна. Slice C **только** разблокирует «shop» — Казино и Агенты остаются locked до D/E.

### Files to touch

**Создать:**
- `scripts/data/UpgradeData.gd` — `Resource` с полями `id: String`, `name: String`, `description: String`, `cost: int`, `effect_id: String`, `@export` всё. `class_name UpgradeData`.
- `resources/upgrades/*.tres` × 5 — конкретные апгрейды:
  - `coffee` — «Кофе из автомата», 30$, +2 max_energy со следующего дня.
  - `monitor` — «Второй монитор», 50$, +5$ за полную категорию в Work.
  - `dating_plus` — «Подписка дейтинг+», 40$, +0.1 к match_chance в Dating.
  - `confident_replies` — «Курс уверенных ответов», 35$, +0.1 к шансу positive-реакции в Mail.
  - `autoclicker` — «Дешёвый автокликер», 60$, кнопка «Решить 1 карточку» в Work-программе.
- `scenes/run2/ShopApp.tscn` + `scripts/run2/ShopApp.gd` — программа, которую `Run2.open_program("shop")` вставит в monitor_screen. Layout: «← Назад» (program_closed) + ScrollContainer/VBox с 5 карточками апгрейдов (название / описание / цена / кнопка «Купить»). После покупки карточка disabled + «Куплено».

**Изменить:**
- `scripts/core/RunService.gd` — `purchase_upgrade(upgrade: UpgradeData) -> bool` (проверка денег через `/root/Economy`, добавление в `purchased_upgrades`, эмит `upgrade_purchased`). `has_upgrade(id) -> bool`. На `next_day()` — если в `purchased_upgrades` есть `coffee`, `max_energy += 2` (но только однократно — заведи флаг `coffee_applied` или просто пересчитывай max_energy каждый next_day от base + bonus_from_upgrades). При `reset()` — `max_energy = MAX_ENERGY_BASE`.
- `scripts/core/GameEvents.gd` — `signal upgrade_purchased(upgrade_id: String)`.
- `scripts/run2/Run2.gd` — в Slice C при загрузке Run 2 на день 2 автоматически разблокировать «shop»: в `_ready()` если `not _run.has_unlock("shop"): _run.unlock("shop")`. Альтернатива (если не хочется auto-unlock) — оставить как сейчас и keeper в `next.md` для D пропишет аналогично для casino. **Рекомендуется auto-unlock в Slice C, держит UX простым.** Также — поправить `SCENE_PATHS["shop"] = "res://scenes/run2/ShopApp.tscn"`.
- `scripts/run1/WorkProgram.gd` — если `_run.has_upgrade("monitor")`, бонус за полную категорию `15$` вместо `10$`. Если `_run.has_upgrade("autoclicker")`, в правой части UI кнопка «Решить 1 карточку» (тратит 1 энергию, выбирает первую word_card и сама дропает в правильную категорию).
- `scripts/run1/DatingProgram.gd` — если `_run.has_upgrade("dating_plus")`, в `_on_like` шанс матча = `clampf(match_chance + 0.1, 0.0, 1.0)`.
- `scripts/run1/MailProgram.gd` — если `_run.has_upgrade("confident_replies")`, `var positive: bool = randf() < 0.6` (вместо 0.5).

### Acceptance
- [ ] В Run 2, день 2: на Desktop2 иконка «Магазин» **больше не приглушена**, при клике открывается ShopApp.
- [ ] В ShopApp видны 5 апгрейдов, кнопка «Купить» disabled если money < cost.
- [ ] Покупка списывает деньги через Economy, апгрейд переходит в «Куплено», карточка disabled.
- [ ] «Кофе из автомата» куплен в день 2 → в день 3 шапка показывает «Энергия 10/10».
- [ ] «Второй монитор» — в Work закрытие полной категории даёт 15$ вместо 10$.
- [ ] «Подписка дейтинг+» — `match_chance` для всех профилей фактически выше на 0.1.
- [ ] «Курс уверенных ответов» — в Mail позитивных реакций становится заметно больше (визуально, не строго проверяется).
- [ ] «Дешёвый автокликер» — кнопка появляется в Work, при клике 1 правильная карточка решается, энергия −1.
- [ ] Smoke: купить «Кофе» в день 2 → дожить до конца → день 3 имеет max_energy=10.

### Out of scope (Slice C не делает)
- Казино / Агенты (D / E).
- EventLog (F).
- Перевод цен/эффектов в .tres файлы (можно держать Dictionary в `ShopApp.gd` или `RunService.gd`, как удобнее).

### Подсказки
- Если не хочется тратить время на 5 файлов `.tres` — допускается держать словарь апгрейдов прямо в `ShopApp.gd` как `const UPGRADES: Array[Dictionary] = [...]`. Это короче, и переезд на `.tres` будет тривиален когда понадобится.
- `Economy.add(-cost)` есть. Проверка `Economy.money >= cost` — посмотри scripts/core/Economy.gd, при необходимости расширь его геттером.
- Кнопка «← Назад» — `GameEvents.program_closed.emit()`. Это уже работает через Run2.gd.

---

## Заготовки следующих слайсов

### Slice D — Казино
`CasinoApp.tscn` + контроллер. 3 кнопки ставок (10/25/50, отключаются если money < bet). Кнопка «Крутить» — randf() против таблицы (45% проигрыш / 30% возврат / 15% x2 / 8% x3 / 2% x7). Тексты исходов по ТЗ. История 5 — VBox с лейблами. `_run.spend_energy(1)` на крутку. `_run.casino_won_today/lost_today` для статистики.

### Slice E — ИИ-агенты
`scripts/data/AgentData.gd` (Resource). 4 агента: Стажёр-GPT (60$, 1 карточка Work авто, 25% ошибка), Людмила (80$, +0.15 match_chance, иногда снижает симпатию), Ответчик-3000 (100$, 1 авто-ответ в Mail, 60% успех), Мини-делегатор (120$, +10$ пассивно в начале дня, 10% хаос-задача отнимает энергию). `AgentShopApp.tscn` с 2 секциями (Магазин / Мои агенты). `RunService.active_agents`, метод `apply_agents_for_new_day()` — вызывается из `next_day()`. Сигнал `event_log_added` для каждого срабатывания.

### Slice F — Event log + Day Summary Run 2 + полировка
`scripts/ui/EventLog.gd` — Control с FIFO-очередью последних 5–7 строк, подписан на `GameEvents.event_log_added(message)`. Виджет в Run2.tscn внизу или сбоку. Все системы эмитят `event_log_added`. DaySummary Run 2 — добавить разделы «купленные апгрейды», «купленные агенты», «казино: +X / -Y», «самое абсурдное событие» (рандом из EventLog). 4 новых вердикта (по ТЗ).
