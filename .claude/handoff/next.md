# Run 1 + Run 2 петля — мастер-план A → F

Большое ТЗ от keeper'а разбито на 6 независимых слайсов. Каждый — отдельный coder-чат (открывается командой `claude` в этой папке, первое действие — прочитать этот файл).

**Маркер прогресса** держится в этом же файле. Кончил слайс → допиши `done.md` → обнови маркер.

---

## Общий план

| # | Слайс | Что добавляет | Статус |
|---|---|---|---|
| A | **Run 1 как первый день** + RunService + MainScene-router | Энергия, day topbar, цели, DaySummary, end-of-day, autoload-сервис состояния run-а, роутер сцен | **✓ закрыт** |
| B | **Run 2 каркас** + переход через RunService | Run2.tscn с 6 иконками Desktop'а (3 рабочих + 3 заглушки), `next_day()` в роутере | **✓ закрыт** |
| C | **Магазин апгрейдов** | ShopApp с 5 апгрейдами (кофе / монитор / дейтинг+ / курс ответов / автокликер), интеграция эффектов в Economy/Work/Dating/Mail | **✓ закрыт** |
| D | **Казино** | CasinoApp с 3 ставками (10/25/50), 5 исходов (45/30/15/8/2%), история последних 5 | **✓ закрыт** |
| E | **ИИ-агенты** | AgentShopApp с 4 агентами (Стажёр-GPT / Людмила / Ответчик-3000 / Мини-делегатор), применение в начале дня и при действиях, побочки | **активный** |
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

## Что готово после Slice C

- `scenes/run2/ShopApp.tscn` + `scripts/run2/ShopApp.gd` — программа «Магазин апгрейдов». 5 карточек (PanelContainer → HBox: info + price/button), ScrollContainer для длинных списков. Список апгрейдов — `const UPGRADES: Array[Dictionary]` прямо в скрипте (на момент 5 элементов это короче, чем 5 `.tres`).
- `RunService.purchase_upgrade(id, cost) -> bool` — проверяет дубликат + достаток денег через `/root/Economy`, списывает, добавляет в `purchased_upgrades`, эмитит `GameEvents.upgrade_purchased`. `has_upgrade(id) -> bool`. `_compute_max_energy()` = `MAX_ENERGY_BASE + (2 if has_upgrade("coffee") else 0)` — вызывается в `next_day()`. То есть кофе вступает в силу со **следующего** дня после покупки.
- `Run2.gd` — `SCENE_PATHS["shop"]` + auto-`_run.unlock("shop")` в `_ready()`.
- `Desktop2.gd` — `_refresh_lock_visuals()` снимает `modulate(1,1,1,0.5)` со слота, если апгрейд разблокирован (`has_unlock(id)`).
- Эффекты подключены: `WorkProgram` — `monitor` даёт +5$ к бонусу за полную категорию (10 → 15$); `autoclicker` рисует кнопку «Решить 1 карточку» в TopBar и при нажатии берёт первое слово из `_words_box`, ищет правильную категорию, эмулирует drop. `DatingProgram._on_like` — `dating_plus` накидывает +0.1 к `match_chance`. `MailProgram._on_reply_picked` — `confident_replies` поднимает positive-шанс с 0.5 до 0.6.
- `GameEvents.upgrade_purchased(upgrade_id)` — новый сигнал.

---

## Что готово после Slice D

- `scenes/run2/CasinoApp.tscn` + `scripts/run2/CasinoApp.gd` — программа «Казино «Парадайз»». TopBar: ← Назад + Title + MoneyLabel + EnergyLabel. Body: слева панель ставок (3 кнопки 10/25/50, Selection label, кнопка «Крутить», disclaimer о шансах), справа — VBox-история последних 5 круток с EmptyHistory placeholder.
- 5 исходов с накопительными порогами (0.45/0.75/0.90/0.98/1.00) → multiplier 0/1/2/3/7. На крутку: `Economy.spend(bet)` → если multiplier>0, `Economy.add(bet*multiplier)` → `register_casino_win(delta)` или `register_casino_loss(bet)` → `spend_energy(1)` → строка в историю + `event_log_added`.
- `RunService.register_casino_win(amount)` и `register_casino_loss(amount)`.
- `Run2.gd` — `SCENE_PATHS["casino"]` + `_run.unlock("casino")` в `_ready()`.

---

## Текущий слайс — E (ИИ-агенты)

### Goal
Реализовать AgentShopApp — программу найма ИИ-агентов. 4 агента с эффектами, применяющимися либо в начале дня (`apply_agents_for_new_day()` из `next_day()`), либо при конкретных действиях (Work-карточка, Mail-ответ). У большинства агентов есть **побочка** (chance провала). Slice E разблокирует `agents`.

### Files to touch

**Создать:**
- `scripts/data/AgentData.gd` (optional — допустимо держать список агентов как `const AGENTS: Array[Dictionary]` в `AgentShopApp.gd`, по аналогии с апгрейдами Slice C).
- `scenes/run2/AgentShopApp.tscn` + `scripts/run2/AgentShopApp.gd` — UI с двумя секциями: «Магазин агентов» (4 карточки с кнопкой «Нанять») и «Мои агенты» (список нанятых).

**Изменить:**
- `scripts/core/RunService.gd` — `purchase_agent(agent_id, cost) -> bool` (по образцу `purchase_upgrade`), `has_agent(id) -> bool`, метод `apply_agents_for_new_day()` (вызывается **из `next_day()` в конце**, после сброса статистики). Внутри `apply_agents_for_new_day()` — реализация эффектов «в начале дня» (см. ниже).
- `scripts/core/GameEvents.gd` — `signal agent_hired(agent_id: String)`.
- `scripts/run2/Run2.gd` — `SCENE_PATHS["agents"]` + auto-unlock в `_ready()`.
- `scripts/run1/WorkProgram.gd` — если has_agent("intern_gpt") и в `_ready` есть карточки → авто-решить 1 случайную карточку с 25% шансом ошибки (см. ниже).
- `scripts/run1/DatingProgram.gd` — если has_agent("lyudmila") — `chance += 0.15`. Но в `_on_dislike` 20% шанс «срезать симпатию у случайного матча» (Людмила сует не туда). Симпатия снижается на 0.1.
- `scripts/run1/MailProgram.gd` — если has_agent("answerer_3000") и есть матчи → авто-ответ на случайный матч с 60% positive / 40% negative реакцией. Тратит **0** энергии игрока (вместо 1). См. ниже.

### Каталог агентов

```
[
  {"id": "intern_gpt", "name": "Стажёр-GPT", "cost": 60,
   "description": "Решит за тебя 1 карточку в Работе. 25% шанс ошибки.",
   "effect": "work_card_auto"},
  {"id": "lyudmila", "name": "Людмила", "cost": 80,
   "description": "+15% к шансу матча. Иногда снижает симпатию у случайного матча — не туда нажала.",
   "effect": "dating_boost"},
  {"id": "answerer_3000", "name": "Ответчик-3000", "cost": 100,
   "description": "Отвечает за тебя в Почте. 60% позитивных реакций, 40% негативных. Без твоей энергии.",
   "effect": "mail_auto_reply"},
  {"id": "mini_delegator", "name": "Мини-делегатор", "cost": 120,
   "description": "+10$ пассивно в начале каждого дня. 10% шанс на «хаос-задачу» — отнимает 1 энергию утром.",
   "effect": "morning_passive"},
]
```

### Применение эффектов

- **Стажёр-GPT (`intern_gpt`)** — в `WorkProgram._ready()` после построения words/categories: если has_agent, через `call_deferred("_intern_auto_solve")` решить 1 случайное слово. 25% — решит **неправильно** (специально дропнуть в чужую категорию, чтобы триггернуть penalty). Иначе — правильно. Затем эмитнуть `event_log_added("Стажёр-GPT: <слово> → <категория> [правильно/ошибка]")`. **Не тратит энергию игрока** (это бонус, не его действие).
- **Людмила (`lyudmila`)** — `_on_like`: `chance += 0.15`. Также в `_on_dislike`: 20% шанс «промашки» — если в `_run.matches` есть хоть один матч, снизить симпатию случайному матчу на 0.1 + `event_log_added("Людмила вместо тебя написала <имя>: симпатия −0.1")`.
- **Ответчик-3000 (`answerer_3000`)** — добавь в Mail кнопку «Пусть Ответчик-3000 ответит» (видна только при has_agent). На клик: рандомный матч из `_run.matches` (если есть), generate 1 ответ, 60% positive → симпатия +0.1, 40% negative → −0.1. Не тратит энергию игрока. `event_log_added("Ответчик-3000 ответил <имя>: <положительная/отрицательная> реакция")`.
- **Мини-делегатор (`mini_delegator`)** — в `apply_agents_for_new_day()`: `Economy.add(10)` + `event_log_added("Мини-делегатор: +10$ за «работу пока ты спал»")`. С 10% шанса: `spend_energy(1)` + `event_log_added("Мини-делегатор: хаос-задача отняла 1 энергию")`. Тонкость: `spend_energy(1)` в день перед основными действиями может удивить — это намеренно (плата за пассивный доход).

### Acceptance
- [ ] В Run 2 day 2+ иконка «ИИ-агенты» больше не приглушена, открывает AgentShopApp.
- [ ] AgentShopApp: 4 карточки с «Нанять», состояние «Нанят» disabled-кнопка. Money-проверка как в ShopApp.
- [ ] После найма Мини-делегатора → `next_day()` → money +10 + event_log запись (визуальная — пока без UI, но в `print()`).
- [ ] После найма Ответчика-3000 → в Mail видна кнопка «Пусть Ответчик ответит», работает без расхода энергии.
- [ ] После найма Людмилы → match_chance очевидно выше; иногда в логе «Людмила: симпатия −0.1».
- [ ] После найма Стажёра-GPT → при открытии Work одна карточка решается автоматически (с 25% это будет ошибка − приведёт к penalty).

### Out of scope
- EventLog UI как виджет — Slice F.
- DaySummary с показом «купленные агенты» — Slice F.
- Перевод агентов на `.tres` файлы — допустимо позже.

### Подсказки
- Reuse `RunService.purchase_*` шаблон: можно сделать обобщённый `_spend_and_register(id, cost, list: Array, signal_name)`, но проще пара отдельных методов как в C — 5 строк каждый.
- `apply_agents_for_new_day()` вызывать в `next_day()` **после** обнуления статистики и эмита `day_changed`, но **до** `energy_changed` — иначе хаос-задача не успеет уменьшить энергию до того как UI отрисует «8/8».
- Mail-кнопка «Пусть Ответчик ответит» — добавь как программный Button над списком reply-buttons, по аналогии с автокликером в Work.

### Slice F — Event log + Day Summary Run 2 + полировка
`scripts/ui/EventLog.gd` — Control с FIFO-очередью последних 5–7 строк, подписан на `GameEvents.event_log_added(message)`. Виджет в Run2.tscn внизу или сбоку. Все системы эмитят `event_log_added`. DaySummary Run 2 — добавить разделы «купленные апгрейды», «купленные агенты», «казино: +X / -Y», «самое абсурдное событие» (рандом из EventLog). 4 новых вердикта (по ТЗ).
