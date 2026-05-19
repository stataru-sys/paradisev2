# Slice G — Work Hub MVP

## Goal
Work Hub становится точкой входа в «Работу» вместо прямого открытия сортировки. Текущая мини-игра сортировки — одна из карточек. 2 locked-заглушки для будущих работ.

## Context
Дизайн-документ всей системы: `.claude/plans/work-expansion.md` (читать перед реализацией для понимания общей картины).

Сейчас:
- Клик «Работа» на Desktop → сразу `WorkProgram.tscn` (сортировка слов).
- WorkProgram открывается через SCENE_PATHS["work"] в Run1.gd и Run2.gd.
- WorkProgram имеет finish_panel с кнопкой «Закончить» → emit `program_closed`.
- После program_closed → открывается Desktop (через `_on_program_closed` в Run1/Run2).

Нужно:
- Вставить WorkHub между Desktop и мини-игрой.
- WorkHub показывает доступные и заблокированные работы.
- После мини-игры — возврат в WorkHub, а не на Desktop.
- Из WorkHub можно уйти на Desktop (назад).

## Flow
```
Desktop → клик «Работа»
  → program_open_requested("work")
    → Run1.gd/Run2.gd → _open_program("work_hub")
      → WorkHub
        → клик «Начать» на Сортировке → WorkProgram
          → «Закончить работу» → emit work_day_finished
            → WorkHub (принял сигнал, переоткрылся)
        → клик «Назад» → program_closed → Desktop
```

## Files to touch

### Новые файлы:
- `scenes/run2/WorkHub.tscn` — сцена экрана выбора работы
- `scripts/run2/WorkHub.gd` — логика WorkHub

### Изменяемые файлы:
- `scripts/run1/Run1.gd` — добавить `"work_hub"` в SCENE_PATHS, `"work"` теперь ведёт на WorkHub
- `scripts/run2/Run2.gd` — то же самое
- `scripts/run1/WorkProgram.gd` — кнопка «Закончить» (уже есть finish_panel) → после закрытия emit-ить не `program_closed`, а специальный сигнал для возврата в WorkHub

## WorkHub spec

### Карточки работ:

1. **Сортировка задач** (доступна)
   - Название: «Сортировка задач»
   - Описание: «Раскидай слова по категориям. Проще чем звучит. Буквально.»
   - Награда: «3–30$»
   - Энергия: «-1 за категорию»
   - Риск: «Низкий»
   - Кнопка: «Начать»

2. **Корпоративная почта** (заблокирована)
   - Название: «Корпоративная почта»
   - Описание: «Откроется позже»
   - Замок, серая
   - Кнопка: нет / disabled

3. **Фикс багов** (заблокирована)
   - Название: «Фикс багов»
   - Описание: «Откроется позже»
   - Замок, серая
   - Кнопка: нет / disabled

### Структура сцены WorkHub:
```
WorkHub (Control, anchor full_rect)
├── TopBar (HBoxContainer)
│   ├── Title (Label: «Работа»)
│   ├── Spacer
│   └── BackBtn (Button: «Назад»)
├── ScrollContainer
│   └── CardsList (VBoxContainer)
│       ├── Card_Sorting (PanelContainer) — доступна
│       ├── Card_Mail (PanelContainer) — заблокирована
│       └── Card_Bugfix (PanelContainer) — заблокирована
└── BottomInfo (Label: «Энергия: X/Y»)
```

### Карточка (доступная):
```
PanelContainer
├── MarginContainer
│   └── HBoxContainer
│       ├── Info (VBoxContainer)
│       │   ├── Name (Label, bold, крупный)
│       │   ├── Description (Label, autowrap)
│       │   └── Stats (HBoxContainer — награда / энергия / риск, мелкие Label)
│       └── StartBtn (Button: «Начать»)
```

### Карточка (заблокированная):
```
Серая/приглушённая. Вместо кнопки — иконка замка или текст «🔒».
```

## Схема сигналов

WorkProgram уже эмитит `GameEvents.work_day_finished(earned)` когда finish_panel появляется. Сейчас это только ловится в Run1/Run2 (и ничего не делает). Надо:

1. WorkHub подписывается на `work_day_finished` — когда прилетает, переоткрывает сам себя (заменяет WorkProgram на WorkHub).
2. WorkProgram: кнопка «Закончить» в finish_panel → emit `work_day_finished` И `program_closed` НЕ эмитить.
3. Либо лучше: WorkHub сам управляет навигацией. WorkProgram просто эмитит `work_day_finished`, а WorkHub слушает и переключает вид.

**Вариант реализации (проще):**
- WorkHub при запуске мини-игры убирает себя (queue_free или visible=false), добавляет мини-игру в тот же program_host.
- Мини-игра при завершении эмитит `work_day_finished`.
- WorkHub ловит сигнал → заново показывает себя.
- WorkHub не нужно пересоздавать — можно использовать visible.

**Альтернатива (ещё проще):**
- WorkHub — это отдельная сцена, которая открывается через program_host в Run1/Run2.
- При клике «Начать» WorkHub эмитит `program_open_requested("work_sorting")` (новый id).
- Run1/Run2 знают `"work_sorting"` → WorkProgram.
- WorkProgram при завершении эмитит `program_closed` → Run1/Run2 открывает `"work_hub"`.
- WorkHub при «Назад» эмитит `program_closed` → Desktop.

**Выбираем альтернативу** — она чище и использует существующий механизм роутинга. Меньше переделок.

### Новая схема SCENE_PATHS:
```gdscript
# Run1.gd и Run2.gd:
const SCENE_PATHS: Dictionary = {
    "desktop": "res://scenes/run1/Desktop.tscn",
    "work_hub": "res://scenes/run2/WorkHub.tscn",
    "work_sorting": "res://scenes/run1/WorkProgram.tscn",
    "dating": "res://scenes/run1/DatingProgram.tscn",
    "mail": "res://scenes/run1/MailProgram.tscn",
    # ... остальное
}
```

### WorkHub.gd логика:
```gdscript
# Кнопка «Начать» для sorting:
_start_sorting_btn.pressed.connect(func():
    GameEvents.program_open_requested.emit("work_sorting")
)

# Кнопка «Назад»:
_back_btn.pressed.connect(func():
    GameEvents.program_closed.emit()
)

# При показе — обновить статус энергии:
func _ready():
    _update_energy_display()
    GameEvents.energy_changed.connect(_on_energy_changed)

# Заблокированные карточки — кнопки disabled, modulate тусклый.
```

### WorkProgram.gd — изменение:
Текущая finish_panel кнопка эмитит `program_closed`. Нужно:
```gdscript
_finish_button.pressed.connect(func():
    GameEvents.program_closed.emit()
)
# Оставить как есть. WorkHub через Run1/Run2 получит управление.
```

Стоп. Сейчас `_on_program_closed` в Run1/Run2 всегда открывает `"desktop"`. А нам нужно чтобы после WorkProgram открывался WorkHub.

**Решение:** WorkHub при открытии (в _ready) устанавливает флаг или просто Run1/Run2 отслеживают что последним был WorkHub и после закрытия дочерней программы возвращаются в WorkHub, а не на Desktop.

**Самое простое решение:** WorkHub использует свой собственный program_host внутри себя для запуска мини-игр. То есть WorkHub — это полноценная сцена-контейнер со своим program_host. Мини-игра инстанциируется внутрь WorkHub, а не наружу.

```gdscript
# WorkHub.gd
@export var game_host_path: NodePath  # Control для размещения мини-игры
@onready var _game_host: Control = get_node(game_host_path)

func _start_work(scene_path: String):
    _cards_container.visible = false  # прячем список
    var scene = load(scene_path)
    var game = scene.instantiate()
    _game_host.add_child(game)
    if game is Control:
        game.anchor_right = 1
        game.anchor_bottom = 1
    # Слушаем когда игра закончится
    GameEvents.work_day_finished.connect(_on_game_finished, CONNECT_ONE_SHOT)

func _on_game_finished(_earned: int):
    for c in _game_host.get_children():
        c.queue_free()
    _cards_container.visible = true
    _update_energy_display()
```

Но это дублирует логику Run1/Run2. Чтобы избежать дублирования...

**Финальное решение (самое чистое):**
- WorkHub НЕ использует SCENE_PATHS роутинг Run1/Run2.
- WorkHub вставляет мини-игру в свой собственный `game_host` (Control, anchor full_rect поверх карточек).
- WorkHub скрывает список карточек, показывает game_host, инстанциирует мини-игру.
- Мини-игра при завершении эмитит `work_day_finished`.
- WorkHub ловит, чистит game_host, показывает список снова.
- Кнопка «Назад» → `program_closed` → Run1/Run2 → Desktop.

Это проще и не требует менять роутинг в Run1/Run2. WorkHub становится самодостаточным контейнером.

### Сцена WorkHub (финальная структура):
```
WorkHub (Control, anchor full_rect)
├── TopBar (HBoxContainer)
│   ├── Title (Label: «Работа»)
│   ├── Spacer
│   ├── EnergyLabel (Label: «Энергия 8/8»)
│   └── BackBtn (Button: «Назад»)
├── CardsContainer (ScrollContainer / VBoxContainer)
│   ├── Card_Sorting (PanelContainer)
│   ├── Card_Mail (PanelContainer, locked)
│   └── Card_Bugfix (PanelContainer, locked)
└── GameHost (Control, anchor full_rect, visible=false)
    (сюда инстанциируется WorkProgram)
```

## Acceptance
- [ ] Клик «Работа» на Desktop (Run 1 и Run 2) → открывается WorkHub.
- [ ] WorkHub показывает 1 доступную карточку «Сортировка задач» с кнопкой «Начать».
- [ ] WorkHub показывает 2 заблокированные карточки «Корпоративная почта» и «Фикс багов».
- [ ] Кнопка «Начать» на Сортировке → открывается WorkProgram поверх карточек.
- [ ] Кнопка «Закончить работу» в WorkProgram → скрывается WorkProgram, показываются карточки WorkHub.
- [ ] Кнопка «Назад» в WorkHub → возврат на Desktop (через program_closed).
- [ ] Отображение текущей энергии в WorkHub обновляется.
- [ ] Когда энергия = 0, кнопка «Начать» заблокирована.
- [ ] Playtest через MCP: `play_scene` → клик «Работа» → WorkHub → «Начать» → сортировка → «Закончить» → WorkHub → «Назад» → Desktop.

## Out of scope (НЕ делать в этом слайсе)
- Не реализовывать новые мини-игры (mail_sort, bugfix, meeting и т.д.)
- Не добавлять апгрейды и агентов
- Не менять баланс сортировки
- Не добавлять WorkResult (пока finish_panel остаётся как есть)
- Не менять Desktop / Desktop2
- Не трогать Run Service — энергия и цели дня работают как раньше
