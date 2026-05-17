# Slice 1 (Run 1 vertical MVP) — done

## Что сделано
Run 1 переделан под макет `5210878899217176813.jpg`. Главное меню → большая кнопка «Начать Run 1» → сцена `Run1.tscn` с шапкой-навигатором (Работа / Tinder / Питомцы / Пожрать / Уход за домом / `$N`), которая хостит три кликабельные программы на рабочем столе компа:

1. **Работа** — drag-and-drop: 15 слов (3 категории × 5), по макету **−$1 за ошибку, +$10 за заполненную категорию из 5 слов**. На пустой пул — финальная панель «День закрыт» + кнопка возврата.
2. **Дейтинг (Tinder)** — свайп Лайк/Диз по 6 моков-профилям, рандомный матч по `match_chance` профиля, после **5** свайпов появляется подсказка «Пора работать» (по нарративу с макета).
3. **Почта** — двупанельный экран: слева список матчей (или текст-заглушка «Пока никто не пишет. Даже алгоритмы заняты.»), справа диалог с именем матча, **ProgressBar симпатии** (0–100), 3 случайных ответа из общего пула на каждом шаге, ±10% симпатии случайно, ауткомы при 0 / 100.

Все три программы возвращаются на десктоп через кнопку «← Назад» (эмитит `GameEvents.program_closed`).

## Файлы созданы / изменены

### Скрипты
- `scripts/core/Economy.gd` *(новый autoload)* — `money:int`, `add(int)`, `spend(int, allow_negative=false)`, `reset()`, эмитит `money_changed`.
- `scripts/core/GameEvents.gd` *(дополнен)* — новые сигналы: `program_open_requested(program_id)`, `program_closed`, `work_day_finished(earned)`, `dating_match_added(profile_id)`, `sympathy_changed(profile_id, value)`.
- `scripts/run1/Run1State.gd` *(новый RefCounted)* — `earned_today`, `matches: Array[Dictionary]`, `sympathies: Dictionary`, методы `add_match`, `set_sympathy`, `get_sympathy`. Не autoload — переедет в `RunService` когда появится Run 2.
- `scripts/run1/Run1.gd` *(новый)* — корневой контроллер Run 1. Хостит `Run1State`, переключает программы по `GameEvents.program_open_requested`, обновляет `EarnedLabel` в шапке через подписку на `Economy.money_changed`.
- `scripts/run1/Desktop.gd` *(новый)* — 3 кнопки → эмитят `program_open_requested("work"/"dating"/"mail")`.
- `scripts/run1/WorkProgram.gd` *(новый)* — словарь `WORDS_BY_CATEGORY` (Стройка/Кухня/Улица × 5 слов), drag-and-drop через inner-классы `WordCard extends Control` (`_get_drag_data`) и `CategorySlot extends Control` (`_can_drop_data`/`_drop_data`).
- `scripts/run1/DatingProgram.gd` *(новый)* — 6 моков-профилей с `match_chance`, свайпы + матч-тост на 1 сек.
- `scripts/run1/MailProgram.gd` *(новый)* — список матчей слева, чат+симпатия+ответы справа. 10 фраз в `REPLY_POOL`, реакции делятся на `REACTIONS_POS`/`NEG`.
- `scripts/ui/MainMenu.gd` *(изменён)* — добавлена кнопка `StartBtn` → `change_scene_to_file("res://scenes/Run1.tscn")`.

### Сцены
- `scenes/Run1.tscn` *(новая, main_scene для Slice 2+ будет менять MainMenu)*
- `scenes/run1/Desktop.tscn` *(новая)*
- `scenes/run1/WorkProgram.tscn` *(новая)*
- `scenes/run1/DatingProgram.tscn` *(новая)*
- `scenes/run1/MailProgram.tscn` *(новая)*
- `scenes/MainMenu.tscn` *(изменена — добавлены Bg/Title/StartBtn)*

### Конфиг
- `project.godot` *(изменён через MCP `add_autoload`)* — в `[autoload]` добавлен `Economy="*res://scripts/core/Economy.gd"`.

## Что проверено через MCP

1. `play_scene` → `[MainMenu] ready — Paradise 2033 boot OK` в Output ✓
2. `click_button_by_text "Начать Run 1"` → переход на Run 1 ✓ (скриншот)
3. Run 1 показывает шапку + 3 цветные иконки + подсказку ✓
4. Открытие «Работа» через event-bus → drag-drop сцена видна ✓
5. Программный drag-drop: 5 слов «Стройка» (правильных) → `Economy.money` 50→60, `earned_today` 0→10 ✓
6. Программный drag-drop: «Фонарь» в «Кухню» (неверно) → `Economy.money` 60→59 (−$1) ✓
7. Шапка `EarnedLabel` обновляется через `GameEvents.money_changed` ✓
8. Открытие «Дейтинг»: 6 лайков с `seed(1234)` → 4 матча в `Run1State.matches` ✓
9. После 5 свайпов: `Пора работать` visible ✓; кнопки disable при пустом пуле ✓
10. Открытие «Почта» с матчами: список матчей виден, диалог открыт на первом, 3 кнопки ответов, ProgressBar симпатии = 50 (старт) ✓
11. Нажатие ответа: симпатия 0.5→0.4 (negative roll), 2 строки в диалоге («Ты:…», «Тест 1:…»), новые 3 кнопки ✓
12. «← Назад» из любой программы → Desktop возвращается ✓
13. Пустое состояние Mail (когда матчей нет) — текст «Пока никто не пишет. Даже алгоритмы заняты.» ✓
14. Нет красных ошибок в Output (только predv. компилятор-warning'и про `Economy` пока редактор кеширует старые autoload-ы — пропадает после первого `play_scene`).

## Сюрпризы / архитектурные решения

- **Парсер редактора не видит свежие autoload'ы до полного рестарта.** `add_autoload` записывает в `project.godot`, `get_project_info` подтверждает регистрацию, но `validate_script` падает «Identifier not found: Economy». Обход: в `WorkProgram.gd` использован `@onready var _economy: Node = get_node("/root/Economy")` вместо прямого `Economy.add(...)`. В Run1.gd проблема решена иначе — обращений к `Economy.*` нет, всё через `GameEvents.money_changed`. В рантайме (`play_scene`) всё работает корректно.
- **`attach_state` должен идти ДО `add_child`.** Иначе `_ready()` программы стартует с `_state == null`, и `_refresh_matches_list()` показывает empty даже когда матчи есть. В `Run1.gd._open_program` порядок: `instantiate → attach_state → add_child`. Это обнаружилось при первом запуске Mail; зафиксировано.
- **MCP `batch_add_nodes` теряет имена нод, если в активной сцене уже есть конфликтующие.** При вызове `open_scene MailProgram.tscn` редактор фактически не переключился, и батч с именами `Bg`/`Margin`/`Layout`/`TopBar`/`Body` записался в WorkProgram (где те же имена уже занимали слоты). Откатилось `delete_node`-ами, после `reload_project` + повторного `open_scene` всё легло куда надо. **Lesson для будущих слайсов:** после `open_scene` всегда верифицировать `get_scene_tree` перед `batch_add_nodes`.
- **Drag-and-drop через inner-классы `WordCard`/`CategorySlot`.** Это значит конструкторы создают ноды программно в `_make_word_card`/`_make_category_slot`. UI не хранится в `.tscn` для самих карточек — только контейнеры. Если позже захочется тематический стиль карточек — вынести в отдельную сцену и `instantiate`.

## Компромиссы / known issues

- **Фон-цвет программ (голубой/розовый) не виден в плеер-окне** — `ColorRect` с anchor_right=1 / anchor_bottom=1 без явных offset не растягивается на full rect, поэтому за UI просвечивает дефолтный тёмно-серый. Видны только содержимые элементы (кнопки, лейблы, карточки) — структура читается, но фоновая «заливка» макета теряется. Чинится одним проходом: задать всем `Bg`-нодам `offset_left=0, offset_right=0, offset_top=0, offset_bottom=0` (или anchors_preset=15 + grow_direction = both). Не правил в этом слайсе, чтобы не разъезжалось layout-дерево.
- **Категории в WorkProgram остаются после заполнения** (счётчик 5/5 виден, но карточки уже разложены). Текст победы — только финальная панель «День закрыт» появляется когда `_words_remaining == 0`. Категории можно подсветить «✓» — не сделал.
- **Анимаций нет нигде.** Match-тост — просто `visible = true` на 1 сек; свайп — мгновенная смена карточки; drag-preview — простой ColorRect+Label.
- **Голос Сверху не подключён.** Запланирован отдельным слайсом — диалог-overlay поверх Run1, который слушает `GameEvents.work_day_finished` / `dating_match_added` и кидает реплику.
- **Питомцы / Пожрать / Уход за домом — пустые лейблы в шапке.** По ТЗ их экраны не входили в текущий слайс.
- **Сейв не сохраняется.** `Economy` autoload живёт всю сессию, но не пишет в `user://save.json`. Save autoload — отдельный слайс из исходного `next.md`.
- **MainMenu не обновляется при возврате через `change_scene_to_file`** — после провала Run 1 пока нет автоматического возврата в меню. Это будет триггер из `EndScreen` (Slice 2+).

## Что keeper'у проверить

1. **Тон текстов** в `DatingProgram.PROFILES`, `MailProgram.REPLY_POOL`, `REACTIONS_POS/NEG` — соответствует ли «сухая ирония + лёгкий мат». Я держался в сторону иронии без мата, чтобы не пережать. Поправить — массивы локально в файлах.
2. **Балансовые числа** в `WorkProgram.CATEGORY_FULL_BONUS=10`, `MISTAKE_PENALTY=1` (по макету) — окей или поднять штраф?
3. **`WORK_HINT_AFTER_SWIPES = 5`** — порог появления «Пора работать» в Dating. Подходит ли темп.
4. **Layout-фикс Bg-нод** — отдельный косметический слайс или присоединить к следующему.

## Коммит
Сделаю отдельно — keeper подтвердит и я зафиксирую (`Slice 1 (Run 1 vertical MVP) ...`).
