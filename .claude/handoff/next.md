# Fix-слайс — Экономика и баланс мини-игр

## Goal
Закрыть 2 находки из ревью Slice J (см. `done.md`, блок «Ревью вскрыло 2 проблемы»):
1. **🔴 Деньги Почты и Фиксов не зачисляются в `Economy`** — игрок видит «+20$», но баланс не растёт.
2. **🟡 В «Фиксах» ошибки прибыльны** — каскадный баг даёт +5$, ошибка −1$, нетто +4$ → бесконечный гринд.

Маленький хирургический слайс перед Slice K (Meeting Simulator). 3 файла, без новых сцен/сигналов/ресурсов.

## Context

Сейчас:
- `WorkProgram` (сортировка) зачисляет деньги **live** через `_economy.add()` per-category — **работает корректно, НЕ трогать.**
- `MailSortGame` (Slice I) и `BugfixGame` (Slice J) считают `_earned` локально, показывают в `WorkResult` и эмитят `work_day_finished` — но `Economy.money` не меняют. `Run1/Run2._on_work_day_finished` = `pass` (пустой).
- `BugfixGame`: правильный фикс +5$ за **любой** баг, включая рождённые ошибкой.

Решения keeper'а:
- **Зачисление — каждая игра сама.** Mail и Bugfix вызывают `Economy.add()` сами, по образцу `WorkProgram`. Центральный обработчик в Run-контроллерах НЕ вводим (иначе сортировка задвоится).
- **Баланс — не платить за каскад.** +5$ только за первые 3 закрытия (= стартовые баги). Баги, рождённые ошибкой, при закрытии денег не дают. `ERROR_PENALTY` остаётся 1.

## Файлы

| Файл | Что |
|---|---|
| `scripts/run2/BugfixGame.gd` | Зачисление денег + «не платить за каскад» |
| `scripts/run2/MailSortGame.gd` | Зачисление денег |
| `scenes/run2/WorkHub.tscn` | Косметика: диапазон награды в карточке Фиксов |

---

## Часть 1 — Зачисление денег (Bugfix + Mail)

В обеих мини-играх в методе, который показывает `WorkResult`, перед `work_day_finished.emit()` зачислить заработок в `Economy` и `RunService`.

В `BugfixGame.gd._show_result()`:
```gdscript
var economy: Node = get_node_or_null("/root/Economy")
if economy != null and _earned != 0:
    economy.add(_earned)
var run: Node = get_node_or_null("/root/RunService")
if run != null:
    run.register_money_earned(_earned)
GameEvents.work_day_finished.emit(_earned)
```

В `MailSortGame.gd` — то же самое в его методе показа результата (`_show_work_result()` или как он назван).

Замечания:
- `Economy.add()` сам игнорирует 0 — но `_earned != 0` не повредит.
- `register_money_earned()` принимает только положительное (внутри `if amount > 0`) — отрицательный заработок Почты в `money_earned_today` просто не зачтётся. Это нормально.
- `WorkProgram` (сортировку) **НЕ трогать** — она зачисляет live, центрального обработчика нет, задвоения не будет.

## Часть 2 — Баланс Фиксов (не платить за каскад)

В `BugfixGame.gd`:
- Добавить поле `var _paid_closures_remaining: int = INITIAL_BUGS` (= 3).
- В `_on_fix_clicked()`, ветка правильного фикса — платить только пока остались «оплачиваемые» закрытия:

```gdscript
if fix_text == String(bug["fix"]):
    _active_bugs.remove_at(_selected_bug_index)
    if _paid_closures_remaining > 0:
        _earned += FIX_REWARD
        _paid_closures_remaining -= 1
        _show_feedback("Баг закрыт. +%d$" % FIX_REWARD, FEEDBACK_GOOD)
    else:
        _show_feedback("Баг закрыт. Этот — твой косяк, чинишь бесплатно.", FEEDBACK_WARN)
    _update_earned_label()
    _rebuild_columns()
    _update_progress()
    if _active_bugs.is_empty():
        _finish_game()
```

- Ветка ошибки — **без изменений** (−1$, `_spawn_new_bug()`, каскад, проверка `> FAIL_THRESHOLD`).
- Flawless-бонус (`_errors == 0` в `_finish_game()`) — **без изменений**.

Новый баланс: 0 ошибок → 3×5 + 5 = **20$**; 1 ошибка → 3×5 − 1 = **14$**; каждая ошибка строго −1$, монотонно вниз. Гринд бессмыслен.

## Часть 3 — Карточка WorkHub (косметика)

`scenes/run2/WorkHub.tscn` — нода `Card_Bugfix/Margin/Row/Info/StatsBox/RewardLabel`: текст «8–25$» → «8–20$» (новый реальный диапазон).

---

## Acceptance
- [ ] Run 2: пройти Почту с положительным итогом → `Economy.money` вырос на сумму из `WorkResult`, шапка обновилась.
- [ ] Run 2: пройти Фиксы с победой → `Economy.money` вырос ровно на показанное в `WorkResult`.
- [ ] Фиксы, идеальный прогон (0 ошибок) → итог **+20$**.
- [ ] Фиксы с 1 ошибкой → закрытие 4-го (каскадного) бага даёт фидбек «чинишь бесплатно», `_earned` не растёт; итог **+14$**.
- [ ] Сортировка (`WorkProgram`) по-прежнему зачисляет деньги корректно, **без задвоения**.
- [ ] Провал Фиксов → +0$, `Economy.money` не изменился.
- [ ] Цель «Заработать 30$» и DaySummary «Заработано» учитывают доход от Почты и Фиксов.
- [ ] Playtest через MCP: Desktop → WorkHub → Фиксы (победа, считать деньги до/после) → Почта (считать деньги до/после).
- [ ] `get_editor_errors` — чисто.

## Out of scope (НЕ делать)
- НЕ вводить центральный `_on_work_day_finished`-обработчик в Run-контроллерах.
- НЕ трогать `WorkProgram` (сортировку) — она зачисляет корректно.
- НЕ добавлять глобальный clamp денег на 0 — отрицательный баланс после провальной Почты пока допустим, money-floor решим отдельным слайсом.
- НЕ чинить хардкод «−1$/ошибка» в `WorkResult.errors_label` (косметика; для Фиксов он и так верный, врёт только для Почты — отдельно).
- НЕ менять `ERROR_PENALTY`, `FAIL_THRESHOLD`, контент багов.
- НЕ добавлять новые сигналы, ресурсы, агенты, апгрейды.
- НЕ начинать Slice K (Meeting Simulator) — он следующий после этого фикс-слайса.
