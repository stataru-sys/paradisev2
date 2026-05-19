# Slice I — Corporate Mail Mini-game

## Goal
Мини-игра «Корпоративная почта» — распределение писем по папкам. Вторая работа в WorkHub (после Сортировки).

## Context
Дизайн-документ: `.claude/plans/work-expansion.md` раздел 4.2.

Сейчас:
- WorkHub показывает 1 активную карточку (Сортировка) и 2 заблокированных (Почта, Фиксы).
- WorkResult (Slice H) готов и переиспользуется всеми мини-играми.
- WorkHub хостит мини-игры в `GameHost`, переподключает кнопки.
- `WorkProgram` (сортировка) использует `_show_work_result()` → WorkResult.

Нужно:
- Создать `MailSortGame` — мини-игру с письмами и 4 папками.
- Сделать карточку «Корпоративная почта» активной в WorkHub (Run 2).
- Интегрировать с WorkResult (переиспользовать, не дублировать).
- Энергия: -2 при старте мини-игры (списывается сразу).

## Flow
```
WorkHub → клик «Начать» на Почте
  → MailSortGame (письма по одному, 4 кнопки-папки)
    → все письма разобраны (или игрок нажал «Закончить»)
      → WorkResult (earned, errors, energy_used, quality)
        → «Вернуться к работе» → WorkHub
        → «На рабочий стол» → Desktop
```

## Files to touch

### Новые файлы:
- `scenes/run2/MailSortGame.tscn` — сцена мини-игры
- `scripts/run2/MailSortGame.gd` — логика писем, папок, наград/ошибок

### Изменяемые файлы:
- `scenes/run2/WorkHub.tscn` — Card_Mail: заменить locked-лейаут на активный (stats + кнопка)
- `scripts/run2/WorkHub.gd` — добавить `mail_start_button_path`, `_on_start_mail_sorting()`
- `scripts/core/GameEvents.gd` — если нужны новые сигналы (вероятно нет, `program_closed` + `work_day_finished` уже есть)

## MailSortGame spec

### Сатира:
«Письма от тех, кто тоже не знает, зачем работает. Твой долг — рассортировать их так, чтобы никто ничего не заметил.»

### Механика:
- Игроку показывается 5–7 писем **по одному**.
- Каждое письмо: отправитель + тема + короткий текст (1–2 предложения).
- 4 кнопки-папки: **«Срочно»**, **«Игнорировать»**, **«Делегировать»**, **«Шаблон»**.
- После выбора папки → мгновенный фидбек (правильно/нейтрально/ошибка) → следующее письмо.
- После последнего письма → `_show_work_result()` (как в WorkProgram).

### Награда / штраф:
- Правильная папка: **+$4**
- Нейтральная папка: **+$1**
- Ошибочная папка: **−$2**
- Пропущено важное (ловушка от начальника): **−$5**
- Бонус за все правильные: **+$5** («Идеальный сортировщик»)
- Энергия: **−2** за сессию (списывается при старте)

### Структура сцены MailSortGame:
```
MailSortGame (Control, anchor full_rect)
├── Bg (ColorRect, тёмно-синий/фиолетовый оттенок)
├── Margin (MarginContainer)
│   └── Layout (VBoxContainer)
│       ├── TopBar (HBoxContainer)
│       │   ├── BackBtn (Button: «← Назад»)
│       │   ├── Spacer
│       │   ├── ProgressLabel (Label: «Письмо 1/6»)
│       │   └── EarnedLabel (Label: «+0$»)
│       ├── EmailPanel (PanelContainer, стилизованный)
│       │   └── VBox
│       │       ├── SenderLabel (Label: «От: Михаил, отдел синергии»)
│       │       ├── SubjectLabel (Label: «Синхронизация по созвону», bold)
│       │       └── BodyLabel (Label: «Коллеги, предлагаю...», autowrap)
│       └── FoldersBox (HBoxContainer, 4 кнопки)
│           ├── UrgentBtn (Button: «🚨 Срочно»)
│           ├── IgnoreBtn (Button: «🗑 Игнорировать»)
│           ├── DelegateBtn (Button: «👥 Делегировать»)
│           └── TemplateBtn (Button: «📋 Шаблон»)
```

### Формат пула писем (в скрипте):
```gdscript
const EMAILS: Array[Dictionary] = [
    {
        "sender": "Михаил, отдел синергии",
        "subject": "Синхронизация по созвону",
        "body": "Коллеги, предлагаю синхронизироваться по вчерашнему созвону. Когда всем удобно?",
        "correct": "ignore",       # «Игнорировать»
        "neutral": "template",     # «Шаблон»
        "trap": false,             # не ловушка
    },
    {
        "sender": "Анна, HR",
        "subject": "Срочно: опрос удовлетворённости",
        "body": "Заполните до конца дня. Это обязательно. Да. Прямо сейчас.",
        "correct": "urgent",
        "neutral": "template",
        "trap": true,              # если проигнорировать → -$5
    },
    # ... ещё 16–18 писем
]
```

### Типы писем (разнообразие):
1. **Обычное рабочее** (10 шт) — 1 правильная папка, 1 нейтральная, 2 ошибочные.
2. **Письмо-ловушка от начальника** (3 шт) — выглядит как спам, но `trap: true`. Если «Игнорировать» → −$5.
3. **Письмо от AI-агента** (2 шт) — агент сам себя в копии, отвечать бессмысленно.
4. **Приглашение на митинг** (2 шт) — любое действие кроме «Игнорировать» + «Шаблон» считается ошибкой.
5. **Спам** (3 шт) — правильное = «Игнорировать», нейтральное = «Шаблон».

### Логика `_on_folder_picked(folder: String)`:
```gdscript
var email: Dictionary = _current_email
if folder == email["correct"]:
    _earned += 4
    _show_feedback("Правильно", Color.GREEN)
elif folder == email.get("neutral", ""):
    _earned += 1
    _show_feedback("Сойдёт", Color.YELLOW)
else:
    _earned -= 2
    _errors += 1
    _show_feedback("Ошибка", Color.RED)
    if email.get("trap", false) and folder == "ignore":
        _earned -= 5  # дополнительный штраф за игнор начальника

_next_email()
```

### Интеграция с WorkHub:
- Card_Mail в WorkHub.tscn получает stats (5–25$, -2 энергии, Риск: Средний) и кнопку «Начать».
- WorkHub.gd: новый `@export var mail_start_button_path: NodePath`, новый метод `_on_start_mail_sorting()`.
- `_on_start_mail_sorting()`: списать 2 энергии, загрузить MailSortGame, инстанциировать в GameHost.
- Переподключить `_back_button` в MailSortGame → `_on_game_return`.
- Подписаться на `work_day_finished` → найти WorkResult → подключить `return_to_hub` (как в `_on_start_sorting`).
- **В Run 1 карточка Почты остаётся заблокированной** — условие: `_run.current_day >= 2`.

### Кнопка «Закончить»:
В отличие от сортировки (где нужно разобрать все слова), в Почте игрок может захотеть закончить досрочно. Добавить кнопку «Закончить» в TopBar:
- Если игрок нажал «Закончить» до того как разобрал все письма — оставшиеся письма не учитываются, показывается WorkResult с текущим результатом.
- Если все письма разобраны — авто-показ WorkResult.

## WorkHub.tscn — Card_Mail (активная версия)

Заменить текущий locked-лейаут на:
```
Card_Mail (PanelContainer, theme_override_styles/panel = StyleBoxFlat_sorting)
├── Margin (MarginContainer, margin 12/8/12/8)
│   └── Row (HBoxContainer)
│       ├── Info (VBoxContainer, size_flags_horizontal=3)
│       │   ├── NameLabel (Label: «Корпоративная почта», font_size=20, WHITE)
│       │   ├── DescLabel (Label: «Рассортируй письма по папкам. Игнорировать — тоже ответ.», font_size=14, autowrap)
│       │   └── StatsBox (HBoxContainer)
│       │       ├── RewardLabel (Label: «5–25$», зеленоватый)
│       │       ├── CostLabel (Label: «-2 энергии», серый)
│       │       └── RiskLabel (Label: «Риск: Средний», желтоватый)
│       └── StartBtn (Button: «Начать»)
```

StyleBoxFlat_sorting уже есть в сцене — переиспользовать.

## Acceptance
- [ ] В Run 2 WorkHub показывает «Корпоративную почту» как доступную (зелёная карточка, кнопка «Начать»).
- [ ] В Run 1 Почта остаётся заблокированной.
- [ ] Кнопка «Начать» на Почте → списывается 2 энергии → открывается MailSortGame.
- [ ] Показывается письмо с отправителем, темой, текстом и 4 кнопками папок.
- [ ] Правильный выбор папки → +4$, зелёный фидбек.
- [ ] Нейтральный выбор → +1$, жёлтый фидбек.
- [ ] Ошибочный выбор → −2$, красный фидбек.
- [ ] Письмо-ловушка: если «Игнорировать» → дополнительный −5$.
- [ ] После последнего письма → WorkResult с итогами.
- [ ] Кнопка «Закончить» досрочно → WorkResult с текущим результатом.
- [ ] «Вернуться к работе» в WorkResult → WorkHub.
- [ ] «На рабочий стол» в WorkResult → Desktop.
- [ ] Прогресс-лейбл обновляется («Письмо 3/6»).
- [ ] Playtest через MCP: Desktop → WorkHub → Почта → разобрать письма → WorkResult → WorkHub.

## Out of scope (НЕ делать в этом слайсе)
- Не добавлять апгрейды `reply_templates` и `spam_filter`.
- Не добавлять агента `mail_demon`.
- Не делать анимации перехода между письмами.
- Не менять баланс других мини-игр.
- Не трогать карточку «Фикс багов» (остаётся locked).
- Не добавлять новые сигналы в GameEvents (использовать существующие `work_day_finished`, `program_closed`).
- Не рефакторить `WorkHub._on_start_sorting` и `_on_game_finished` в общий метод (это преждевременная абстракция для 2 игр; на 3-й игре — вынесем).
