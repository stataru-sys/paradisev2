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
| F | **Event log + Day Summary Run 2 + полировка** | EventLog widget, подписка на сигналы из всех систем, расширенный DaySummary с разделом «самое абсурдное событие», 4 вердикта | **активный** |

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

## Что готово после Slice E

- `scenes/run2/AgentShopApp.tscn` + `scripts/run2/AgentShopApp.gd` — программа «ИИ-агенты». ScrollContainer/VBox с двумя секциями: «Каталог агентов» (4 карточки PanelContainer + кнопка Нанять/Нанят) и «Мои агенты» (зеленовато-modulate карточки с описанием; placeholder «Никого не нанял...» при пустом списке).
- 4 агента в `const AGENTS`: intern_gpt (60$), lyudmila (80$), answerer_3000 (100$), mini_delegator (120$).
- `RunService.purchase_agent(id, cost)`, `has_agent(id)`, `apply_agents_for_new_day()` — вызывается из `next_day()` сразу после `day_changed.emit()`, перед `energy_changed.emit()`. Внутри: `mini_delegator` → +10$ через Economy + event_log; 10% хаос-задача → −1 энергия + event_log.
- `GameEvents.agent_hired(agent_id)` — новый сигнал.
- `Run2.gd` — `SCENE_PATHS["agents"]` + auto-unlock.
- Эффекты:
  - **WorkProgram**: `intern_gpt` → в `_ready()` `call_deferred("_intern_auto_solve")`. Берёт случайную карточку, 25% — дропает в неправильную категорию (штраф), 75% — правильную (бонус). Использует отдельный `_intern_drop()`, чтобы **не тратить энергию игрока**. Эмитит event_log.
  - **DatingProgram**: `lyudmila` → `_on_like` накидывает +0.15 к chance (стакается с dating_plus +0.1). `_on_dislike` → 20% шанс «промашки»: снижает симпатию случайного существующего матча на 0.1 + event_log.
  - **MailProgram**: `answerer_3000` → в `_roll_reply_buttons()` добавляется отдельная фиолетовая кнопка «Пусть Ответчик-3000 ответит». Нажатие → 60% positive / 40% negative, симпатия ±0.1, **не тратит энергию**, регистрирует `register_reply_sent`, event_log.

---

## Текущий слайс — F (Event Log + Day Summary Run 2 + полировка)

### Goal
Закрыть петлю Run 2: добавить EventLog-виджет, который слушает `GameEvents.event_log_added` и показывает последние 5–7 сообщений; расширить DaySummary под Run 2 с новыми секциями (купленные апгрейды/агенты, казино, самое абсурдное событие); подобрать 4 новых вердикта дня для Run 2 (день 2+, с учётом разных стилей поведения). Это последний слайс мастер-плана.

### Files to touch

**Создать:**
- `scripts/ui/EventLog.gd` — `Control` с FIFO-очередью на 5–7 Label-ов. Подписан на `GameEvents.event_log_added(message: String)`. На каждое сообщение: добавить Label сверху списка, обрезать хвост, по таймеру (15-30 секунд) сообщения могут затухать (`tween modulate.a → 0.3`) — но это nice-to-have, MVP можно без затухания.
- (опционально) `scenes/run2/EventLog.tscn` — переиспользуемая сцена с PanelContainer + VBoxContainer + theme overrides. Можно и инлайн в Run2.tscn — на выбор.

**Изменить:**
- `scenes/Run2.tscn` — добавить EventLog как фиксированный виджет внизу-справа (под Computer-view), либо в самом нижнем углу RoomOverview. Должен быть виден из обоих view (overview/computer), чтобы пользователь видел эффекты Stażёра-GPT / Мини-делегатора, происходящие в фоне.
- `scripts/run2/Run2.gd` — после `_run.unlock(...)` пробросить EventLog как @export NodePath чтобы Run2 знал про него (не обязательно — он сам подпишется на GameEvents).
- `scripts/run1/DaySummary.gd` + `scenes/run1/DaySummary.tscn` — расширить отображение `summary` Dictionary. Сейчас показывает: Заработано / Карточек / Ошибок / Матчей / Цели / Вердикт. Добавить:
  - **Купленные апгрейды:** список названий через запятую (если есть).
  - **Активные агенты:** список (если есть).
  - **Казино:** `+%d$ / -%d$` (или «не играл» если оба 0).
  - **Самое абсурдное событие:** случайная строка из EventLog (см. ниже про источник).
- `scripts/core/RunService.gd`:
  - `_finish_day()` — расширить `summary` ключами `purchased_upgrades`, `active_agents`, `casino_won_today`, `casino_lost_today`, `funniest_event` (см. ниже).
  - `_build_verdict()` — добавить 4 новых вердикта (Run 2). Сейчас 3 вердикта по money_earned. Нужно завести логику тонко учитывающую: купил агентов? — «Делегировал даже жизнь». Был в казино? — «Сегодня казино было ближе чем партнёр». Купил >=3 апгрейдов? — «Капитализм работает. На тебе». Если ничего из этого — «Просто ещё один день. Это страшнее всего.». Точные формулировки оставляю keeper'у — допустимо отредактировать константы прямо в коде.
- `scripts/core/GameEvents.gd` — может потребоваться сигнал `event_log_added` уже есть, ничего нового добавлять не нужно.

### Источник «самого абсурдного события»

Самое простое — `EventLog.gd` держит свой массив всех сообщений за день (не только последних 5–7 в UI). На `day_finished` или по запросу через `RunService` берёт случайное из массива и кладёт в summary. При `day_changed` (новый день) — массив очищается.

Альтернатива: добавить в `RunService` свой буфер `_day_events: Array[String]`, который слушает `event_log_added` и сбрасывается в `next_day()`. В `_finish_day()` — выбрать случайное. Это проще и не зависит от UI.

### Acceptance
- [ ] В Run 2 виден EventLog-виджет с последними сообщениями. При покупке апгрейда / агента / крутке казино / автокликере / эффекте агента — новая строка появляется сверху.
- [ ] При исчерпании энергии DaySummary показывает: купленные апгрейды (если есть), активных агентов, казино +X/-Y, самое абсурдное событие (или «-» если ничего интересного).
- [ ] 4 новых вердикта работают по разным веткам (агенты / казино / шопоголик / пустой день).
- [ ] Smoke: купи апгрейд + найми агента + крути казино + дожить до конца → DaySummary показывает все 4 раздела + лог последних событий виден поверх Run2.

### Out of scope
- Сохранение event log между днями.
- Анимации появления event log строк (затухание/всплытие) — опционально.
- Перенос content (UPGRADES/AGENTS/OUTCOMES Dictionary) в `.tres` — после слайса F можно отдельным рефакторингом.
- Mobile-адаптация — отдельная задача после Steam playtest.

### Подсказки
- EventLog как `PanelContainer + MarginContainer + VBoxContainer` — самый дешёвый вариант. modulate.a понижай как `Color(1,1,1, 0.6)` через 5–10 секунд для старых строк, если хочется визуального ощущения «новизны».
- DaySummary: extend `show_summary(summary: Dictionary)`. Текущая структура summary в RunService._finish_day() — обогатить ключами, в DaySummary._on_show — добавить блоки Labels.
- Вердикты можно держать как `const VERDICTS: Array[Dictionary]` с предикатами (lambda → bool по summary). Но 4 if-ветки тоже норм для MVP.
- При вытаскивании случайного из event log: фильтр на «интересные» (Casino / Стажёр / Людмила / Ответчик / Мини-делегатор), не просто «Куплено: X».
