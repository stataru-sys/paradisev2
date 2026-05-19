# Slice J — Bug Fix Mini-game

## Goal
Мини-игра «Фикс багов» — сопоставление баг↔фикс. Третья и последняя работа в WorkHub (после Сортировки и Почты).

## Context
Дизайн-документ: `.claude/plans/work-expansion.md` раздел 4.4.

Сейчас:
- WorkHub показывает 2 активные карточки (Сортировка, Почта) и 1 заблокированную (Фиксы).
- WorkResult (Slice H) переиспользуется.
- Почта (Slice I) и Сортировка (Slice A) уже интегрированы.
- В WorkHub.gd есть два почти идентичных метода `_on_start_sorting` и `_on_start_mail_sorting`.

Нужно:
- Создать `BugfixGame` — мини-игру с сопоставлением багов и фиксов (клик-клик).
- Сделать карточку «Фикс багов» активной в WorkHub (Run 2).
- **Вынести общий метод `_start_work_game(scene_path, energy_cost)`** — на третьей игре дублирование уже не ок.
- Энергия: -2 при старте (как Почта).

## Flow
```
WorkHub → клик «Начать» на Фиксах
  → BugfixGame (3 бага + 3 фикса перемешаны)
    → клик баг → клик фикс → правильно / ошибка (+новый баг)
    → все баги закрыты (или >5 багов = провал)
      → WorkResult (earned, errors, energy_used, quality)
        → «Вернуться к работе» → WorkHub
        → «На рабочий стол» → Desktop
```

## Files to touch

### Новые файлы:
- `scenes/run2/BugfixGame.tscn` — сцена мини-игры
- `scripts/run2/BugfixGame.gd` — логика багов, фиксов, каскада ошибок

### Изменяемые файлы:
- `scenes/run2/WorkHub.tscn` — Card_Bugfix: заменить locked-лейаут на активный (stats + кнопка)
- `scripts/run2/WorkHub.gd` — вынести `_start_work_game(scene, energy)`, добавить `bugfix_start_button_path`, убрать дублирование `_on_start_sorting` / `_on_start_mail_sorting`

## BugfixGame spec

### Сатира:
«Баг — это фича, которую ещё не переименовали. А переименовать — твоя работа.»

### Механика:
- Показывается 3 бага и 3 фикса (перемешаны, каждый в своём столбце).
- Игрок кликает баг (он подсвечивается) → кликает фикс → проверка.
- Правильный фикс: +$5, баг и фикс убираются.
- Ошибка: -$1, появляется новый баг (каскад).
- Если багов > 5 → провал.
- Цель: закрыть все баги с минимумом ошибок.
- Нет кнопки «Закончить» досрочно — только полное закрытие или провал.

### Награда / штраф:
- Правильный фикс: **+$5**
- Ошибка: **−$1** + новый баг
- Все 3 закрыты без ошибок: бонус **+$5** («Баг-слеер»)
- Провал (>5 багов): **$0**, комментарий «Передано в аутсорс»
- Энергия: **−2** за сессию

### Структура сцены BugfixGame:
```
BugfixGame (Control, anchor full_rect)
├── Bg (ColorRect, тёмно-красный/бордовый оттенок)
├── Margin (MarginContainer)
│   └── Layout (VBoxContainer)
│       ├── TopBar (HBoxContainer)
│       │   ├── BackBtn (Button: «← Назад»)
│       │   ├── Spacer
│       │   ├── ProgressLabel (Label: «Багов: 3»)
│       │   └── EarnedLabel (Label: «+0$»)
│       ├── GameArea (HBoxContainer)
│       │   ├── BugsColumn (VBoxContainer)
│       │   │   ├── BugsHeader (Label: «Баги»)
│       │   │   └── BugsBox (VBoxContainer) — наполняется программно
│       │   ├── Spacer
│       │   └── FixesColumn (VBoxContainer)
│       │       ├── FixesHeader (Label: «Фиксы»)
│       │       └── FixesBox (VBoxContainer) — наполняется программно
│       └── FeedbackLabel (Label)
```

### Пул багов (в скрипте, 12 шт):
```gdscript
const BUGS: Array[Dictionary] = [
    {
        "bug": "Кнопка исчезает после клика",
        "fix": "Проверить visible в _on_pressed",
        "traps": ["Переименовать кнопку", "Удалить сцену", "Сказать что фича"],
    },
    {
        "bug": "Энергия не тратится",
        "fix": "Добавить spend_energy в метод",
        "traps": ["Увеличить max_energy", "Перезагрузить ноут", "Купить ещё энергии"],
    },
    # ... ещё 10
]
```

### Логика `_on_fix_picked(bug_index, fix_text)`:
```gdscript
var bug: Dictionary = _active_bugs[bug_index]
if fix_text == bug["fix"]:
    _earned += 5
    _active_bugs.remove_at(bug_index)
    _slots[bug_index].queue_free()
    _slots.remove_at(bug_index)
    _update_progress()
    if _active_bugs.is_empty():
        _finish_game()
else:
    _earned -= 1
    _errors += 1
    _all_correct = false
    _spawn_new_bug()  # добавить случайный баг из пула
    if _active_bugs.size() > 5:
        _fail_game()
```

### Логика `_spawn_new_bug()`:
- Взять случайный баг из `BUGS` (которого ещё нет в `_active_bugs`).
- Если все 12 уже использованы — взять любой.
- Добавить в `_active_bugs` и `_slots`.

### Интеграция с WorkHub:
- Card_Bugfix в WorkHub.tscn получает stats (8–25$, -2 энергии, Риск: Высокий) и кнопку «Начать».
- **Вынести `_start_work_game(scene_path: String, energy_cost: int)`** в WorkHub.gd:
  ```gdscript
  func _start_work_game(scene_path: String, energy_cost: int) -> void:
      if int(_run.energy) < energy_cost:
          return
      if _game_host.get_child_count() > 0:
          return
      _run.spend_energy(energy_cost)
      _cards_list.visible = false
      _game_host.visible = true
      var scene: PackedScene = load(scene_path) as PackedScene
      var game: Control = scene.instantiate() as Control
      _game_host.add_child(game)
      game.anchor_right = 1
      game.anchor_bottom = 1
      _reconnect_game_button(game, "_back_button")
      GameEvents.work_day_finished.connect(_on_game_finished, CONNECT_ONE_SHOT)
  ```
- `_on_start_sorting()` → `_start_work_game(WORK_PROGRAM_SCENE, 0)` (0 = проверка energy <= 0 внутри)
- `_on_start_mail_sorting()` → `_start_work_game(MAIL_SORT_SCENE, MAIL_ENERGY_COST)`
- `_on_start_bugfix()` → `_start_work_game(BUGFIX_SCENE, BUGFIX_ENERGY_COST)`

### Кнопка «Закончить»:
В отличие от Почты, в Фиксах нет кнопки «Закончить». Игрок либо закрывает все баги, либо доводит до >5 (провал). Это создаёт напряжение: каждая ошибка приближает к провалу.

## WorkHub.tscn — Card_Bugfix (активная версия)

Заменить текущий locked-лейаут на:
```
Card_Bugfix (PanelContainer, theme_override_styles/panel = StyleBoxFlat_sorting)
├── Margin (MarginContainer, margin 12/8/12/8)
│   └── Row (HBoxContainer)
│       ├── Info (VBoxContainer, size_flags_horizontal=3)
│       │   ├── NameLabel (Label: «Фикс багов», font_size=20, WHITE)
│       │   ├── DescLabel (Label: «Сопоставь баг с правильным фиксом. Ошибка плодит новые баги.», font_size=14, autowrap)
│       │   └── StatsBox (HBoxContainer)
│       │       ├── RewardLabel (Label: «8–25$», зеленоватый)
│       │       ├── CostLabel (Label: «-2 энергии», серый)
│       │       └── RiskLabel (Label: «Риск: Высокий», красноватый)
│       └── StartBtn (Button: «Начать»)
```

## Acceptance
- [ ] В Run 2 WorkHub показывает «Фикс багов» как доступную (зелёная/бордовая карточка, кнопка «Начать»).
- [ ] В Run 1 Фиксы остаются заблокированными.
- [ ] Кнопка «Начать» на Фиксах → списывается 2 энергии → открывается BugfixGame.
- [ ] Показаны 3 бага слева, 3 фикса справа.
- [ ] Клик баг → клик правильный фикс → +5$, оба убираются.
- [ ] Клик баг → клик неправильный фикс → −1$, появляется новый баг.
- [ ] Все 3 закрыты без ошибок → бонус +5$.
- [ ] >5 багов → провал, $0, «Передано в аутсорс».
- [ ] WorkResult показывает итоги.
- [ ] «Вернуться к работе» → WorkHub.
- [ ] «На рабочий стол» → Desktop.
- [ ] Прогресс-лейбл обновляется («Багов: 4»).
- [ ] Общий метод `_start_work_game()` вынесен, дублирование в `_on_start_sorting` / `_on_start_mail_sorting` убрано.
- [ ] Playtest через MCP: Desktop → WorkHub → Фиксы → сопоставить 3 бага → WorkResult → WorkHub.

## Out of scope (НЕ делать в этом слайсе)
- Не добавлять апгрейд `stackoverflow_premium`.
- Не добавлять агента `bugdav`.
- Не делать drag-drop (только клик-клик).
- Не добавлять анимации.
- Не менять баланс других мини-игр.
- Не добавлять новые сигналы в GameEvents.
- Не трогать Run 3 мини-игры.
