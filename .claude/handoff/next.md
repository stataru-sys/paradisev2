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
| D | **Казино** | CasinoApp с 3 ставками (10/25/50), 5 исходов (45/30/15/8/2%), история последних 5 | **активный** |
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

## Что готово после Slice C

- `scenes/run2/ShopApp.tscn` + `scripts/run2/ShopApp.gd` — программа «Магазин апгрейдов». 5 карточек (PanelContainer → HBox: info + price/button), ScrollContainer для длинных списков. Список апгрейдов — `const UPGRADES: Array[Dictionary]` прямо в скрипте (на момент 5 элементов это короче, чем 5 `.tres`).
- `RunService.purchase_upgrade(id, cost) -> bool` — проверяет дубликат + достаток денег через `/root/Economy`, списывает, добавляет в `purchased_upgrades`, эмитит `GameEvents.upgrade_purchased`. `has_upgrade(id) -> bool`. `_compute_max_energy()` = `MAX_ENERGY_BASE + (2 if has_upgrade("coffee") else 0)` — вызывается в `next_day()`. То есть кофе вступает в силу со **следующего** дня после покупки.
- `Run2.gd` — `SCENE_PATHS["shop"]` + auto-`_run.unlock("shop")` в `_ready()`.
- `Desktop2.gd` — `_refresh_lock_visuals()` снимает `modulate(1,1,1,0.5)` со слота, если апгрейд разблокирован (`has_unlock(id)`).
- Эффекты подключены: `WorkProgram` — `monitor` даёт +5$ к бонусу за полную категорию (10 → 15$); `autoclicker` рисует кнопку «Решить 1 карточку» в TopBar и при нажатии берёт первое слово из `_words_box`, ищет правильную категорию, эмулирует drop. `DatingProgram._on_like` — `dating_plus` накидывает +0.1 к `match_chance`. `MailProgram._on_reply_picked` — `confident_replies` поднимает positive-шанс с 0.5 до 0.6.
- `GameEvents.upgrade_purchased(upgrade_id)` — новый сигнал.

---

## Текущий слайс — D (Казино)

### Goal
Реализовать CasinoApp как полноценную программу Run 2. Контент: 3 уровня ставки (10/25/50), кнопка «Крутить», 5 исходов с разным шансом + 5-строчная история. Slice D разблокирует `casino`. Магазин и Агенты остаются как есть (Магазин уже разблокирован в C, Агенты locked до E).

### Files to touch

**Создать:**
- `scenes/run2/CasinoApp.tscn` + `scripts/run2/CasinoApp.gd` — программа казино. Layout: TopBar («← Назад» + Title «Казино «Парадайз»» + MoneyLabel). Body: слева — 3 кнопки ставки (10$ / 25$ / 50$), кнопка «Крутить» (disabled если ставка не выбрана / money < bet / energy ≤ 0), Label с текущим выбором ставки. Справа — VBox-история «История последних 5 круток» (5 строк, FIFO; новые сверху или снизу — на выбор).

**Изменить:**
- `scripts/core/RunService.gd` — методы `register_casino_win(amount: int)` и `register_casino_loss(amount: int)` (тривиально — увеличить `casino_won_today` / `casino_lost_today`). Поля уже есть из Slice A.
- `scripts/run2/Run2.gd` — `SCENE_PATHS["casino"] = "res://scenes/run2/CasinoApp.tscn"` + в `_ready()` `_run.unlock("casino")` (по аналогии с shop, держит UX простым).

### Логика крутки

```
outcomes = [
  {"weight": 0.45, "text": "Ничего. Просто ничего.", "multiplier": 0},
  {"weight": 0.30, "text": "Вернули ставку. Спасибо. Наверное.", "multiplier": 1},
  {"weight": 0.15, "text": "x2. Сегодня ты молодец.", "multiplier": 2},
  {"weight": 0.08, "text": "x3. Это даже немного подозрительно.", "multiplier": 3},
  {"weight": 0.02, "text": "x7. Ты сорвал джекпот. Лучше уходи прямо сейчас.", "multiplier": 7},
]
```

Распределение: random `randf()` → накопительный поиск по выбранным исходам (порог 0.45 → 0.75 → 0.90 → 0.98 → 1.0). Расчёт: `delta = bet * multiplier - bet`. Если 0 — проигрыш на `bet`. Если 1 — нейтрально (вернули). Если 2/3/7 — выигрыш `delta`.

Применение:
1. `Economy.spend(bet)` (списать ставку).
2. Если `multiplier > 0` — `Economy.add(bet * multiplier)` (вернуть/выиграть).
3. `_run.register_casino_win(delta)` если delta > 0, иначе `_run.register_casino_loss(bet)` при multiplier=0.
4. `_run.spend_energy(1)`.
5. История получает строку формата: `"Ставка 25$ → x2. Сегодня ты молодец. (+25$)"`.
6. `GameEvents.event_log_added.emit("Казино: <текст исхода> (<delta>$)")`.

### Acceptance
- [ ] В Run 2 day 2+: иконка «Казино» больше не приглушена, открывает CasinoApp.
- [ ] 3 кнопки ставок включаются/выключаются по `Economy.money >= bet`.
- [ ] Выбор ставки + клик «Крутить» → списывается ставка, появляется новая строка в истории, обновляется money.
- [ ] Энергия −1 за крутку. При energy=0 «Крутить» disabled.
- [ ] История содержит не больше 5 последних круток.
- [ ] Распределение шансов 45/30/15/8/2 фактически (через 100+ круток на стат).
- [ ] casino_won_today/casino_lost_today обновляются (видно через `RunService.casino_won_today` в логе).

### Out of scope
- DaySummary не показывает казино-сводку — оставлено для Slice F.
- Сохранение истории между днями — не нужно, история — внутри-сценный буфер.
- Анимации крутки барабана — оставлено на потом.

### Подсказки
- Выбор ставки можно держать как `_selected_bet: int = -1`, при клике на кнопку ставки `_selected_bet = 10|25|50` + визуально подсветить выбранную (`modulate` или ColorRect-индикатор).
- Чтобы не сосчитать вероятности руками — `roll = randf()`, потом `if roll < 0.45: outcome=0 elif roll < 0.75: outcome=1 ...`. Список thresholds можно сгенерировать из weights в `_ready()`.
- История: `VBoxContainer` + `_push_history(line: String)`. Когда `get_child_count() > 5` — `get_child(0).queue_free()`.

### Slice E — ИИ-агенты
`scripts/data/AgentData.gd` (Resource). 4 агента: Стажёр-GPT (60$, 1 карточка Work авто, 25% ошибка), Людмила (80$, +0.15 match_chance, иногда снижает симпатию), Ответчик-3000 (100$, 1 авто-ответ в Mail, 60% успех), Мини-делегатор (120$, +10$ пассивно в начале дня, 10% хаос-задача отнимает энергию). `AgentShopApp.tscn` с 2 секциями (Магазин / Мои агенты). `RunService.active_agents`, метод `apply_agents_for_new_day()` — вызывается из `next_day()`. Сигнал `event_log_added` для каждого срабатывания.

### Slice F — Event log + Day Summary Run 2 + полировка
`scripts/ui/EventLog.gd` — Control с FIFO-очередью последних 5–7 строк, подписан на `GameEvents.event_log_added(message)`. Виджет в Run2.tscn внизу или сбоку. Все системы эмитят `event_log_added`. DaySummary Run 2 — добавить разделы «купленные апгрейды», «купленные агенты», «казино: +X / -Y», «самое абсурдное событие» (рандом из EventLog). 4 новых вердикта (по ТЗ).
