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
| E | **ИИ-агенты** | AgentShopApp с 4 агентами (Стажёр-GPT / Людмила / Ответчик-3000 / Мини-делегатор), применение в начале дня и при действиях, побочки | **✓ закрыт** |
| F | **Event log + Day Summary Run 2 + полировка** | EventLog widget, подписка на сигналы из всех систем, расширенный DaySummary с разделом «самое абсурдное событие», 4 вердикта | **✓ закрыт** |

**Мастер-план A → F закрыт.** Все 6 слайсов задеплоены. Следующий цикл итераций — на усмотрение keeper'а (баланс, новые программы, расширение Run-loop, сохранения и т.п.).

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

## Что готово после Slice F

- `scripts/ui/EventLog.gd` — PanelContainer с подпиской на `event_log_added`. MAX_LINES=6, новые сверху, хвост обрезается. Старше FADE_AFTER_SEC=12 секунд → `modulate.a = 0.4`. На `day_changed` лента очищается.
- `scenes/Run2.tscn` — EventLog как фиксированный виджет внизу-слева (anchor 0.0–0.34 / 0.62–0.97), `mouse_filter=2` чтобы клики проходили насквозь, виден поверх RoomOverview/Computer.
- `RunService` — `INTERESTING_PREFIXES` + `_day_events: Array[String]` буфер; подписка на `event_log_added` фильтрует только Казино/Стажёр/Людмила/Ответчик/Мини-делегатор; `_finish_day()` достаёт `funniest_event = random из _day_events`. Очистка в `reset()` и `next_day()`.
- `_finish_day()` теперь кладёт в summary: `purchased_upgrades`, `active_agents`, `casino_won`, `casino_lost`, `funniest_event` (всё duplicated копиями где надо).
- `_build_verdict()` — для `current_day >= 2` четыре новых ветки в приоритете: `active_agents.size() >= 2` → «Делегировал даже жизнь...»; играл в казино → «Сегодня казино было ближе...»; купил ≥3 апгрейдов → «Капитализм работает. На тебе.»; ничего не делал → «Просто ещё один день. Это страшнее всего.». Иначе — fall-through на Run 1 вердикты по money_earned.
- `DaySummary.gd` — `UPGRADE_NAMES` + `AGENT_NAMES` словари для человекочитаемых имён. В `_apply()` после базовых stats добавляются опциональные строки: «Купленные апгрейды», «Активные агенты», «Казино: +X$ / -Y$», «Самое абсурдное событие». Stats-Label-ы теперь с autowrap.
- `scenes/run1/DaySummary.tscn` — Panel вырос с 520×440 на 640×560 чтобы вместить новые секции.
- `Desktop2.gd` — `_refresh_lock_visuals()` дополнительно скрывает Hint «Серые иконки пока заперты. Не время.» если все три bottom-иконки разблокированы.

**Закрыли мастер-план Run 1 + Run 2 + апгрейды + казино + агенты + EventLog/полировка.**

---

## Дальше — на усмотрение keeper'а

Следующие итерации не входили в мастер-план A→F. Любая из задач ниже — отдельный слайс по тому же шаблону (next.md → coder-chat → done.md → коммит).

**Кандидаты:**
1. **Save с версионированием** (`user://save.json`, `save_version`, `migrate_if_needed()`) — рекомендуется первым после A→F, нужно для playtest.
2. **Telemetry CSV** (`user://playtest_log.csv`, append-mode) — параллельно save.
3. **Цели Run 2** (отличные от Run 1; сейчас day 2+ имеет те же DAY1_GOALS) — мелкая задача, ~30 минут.
4. **Перевод UPGRADES/AGENTS/OUTCOMES Dictionary → `.tres` файлы** — для подкручивания баланса без правки кода. Половина дня работы.
5. **Имплантация (правило #5)** — добавление визуальных частей-имплантов через swap Sprite2D-нод. Требует ассеты от художника.
6. **Run 3+ дифференциация** — сейчас day >= 2 всегда грузит Run2. Идеи для Run 3: новые иконки, новые цели, новые программы.
7. **Анимации** (крутка казино, выпадение апгрейда, появление матча) — UX-полировка после первого playtest.

