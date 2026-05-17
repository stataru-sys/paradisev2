# История закрытых слайсов

Каждый завершённый слайс пишется сверху коротким блоком. История идёт от свежего к старому.

---

## Slice A — Run 1 как первый день + RunService + MainScene-роутер ✓

**Коммит:** см. `git log` (последний после "Run 1: общий план...").

**Что добавлено:**

| Файл | Что |
|---|---|
| `scripts/core/RunService.gd` *(новый autoload)* | `current_day`, `energy`, `max_energy`, `money_earned_today`, `work_errors/correct_today`, `matches`, `sympathies`, `purchased_upgrades`, `active_agents` + методы `spend_energy()`, `next_day()`, `reset()`, `register_money_earned()`, `register_work_correct/error()`, `register_program_opened()`, `register_reply_sent()`, `register_match_added()`, `get_goals_view()`. Цели Run 1 (`DAY1_GOALS`): «Заработать 30$», «Проверить дейтинг», «Ответить на сообщение», «Дожить до вечера». Вердикт: <30$ — «Ты почти функционировал. Почти.»; 30–49$ — «День прожит без позора.»; ≥50$ — «Подозрительно продуктивно. Тревожно.». |
| `scripts/core/GameEvents.gd` *(расширен)* | Сигналы `day_changed(day)`, `day_finished(summary)`, `goal_completed(goal_id)`, `event_log_added(message)`. `energy_changed` теперь `(current, max)`. |
| `scripts/ui/MainScene.gd` + `scenes/MainScene.tscn` *(новые)* | Корневой роутер. В `_ready` читает `RunService.current_day`, печатает `[MainScene] routing day N → ...` и `change_scene_to_file` на нужный run. В A — всегда Run1. В B — добавится switch на Run2. |
| `scripts/run1/DaySummary.gd` + `scenes/run1/DaySummary.tscn` *(новые)* | Overlay-итог дня: затемнение + Panel в центре, разделы Итог/Цели/Вердикт + кнопка «Начать следующий день» → `RunService.next_day()` + `change_scene_to_file("MainScene.tscn")`. |
| `scripts/ui/MainMenu.gd` *(изменён)* | Кнопка «Начать Run 1» теперь грузит `MainScene.tscn`, не `Run1.tscn` напрямую. |
| `scenes/Run1.tscn` *(расширен)* | В NavBar: `DayLabel`, `EnergyLabel` (плюс к существующему `EarnedLabel`). В RoomOverview: `GoalsPanel` справа сверху с заголовком «Цели дня» и `GoalsBox` (4 строки `[ ] / [x] текст`). |
| `scripts/run1/Run1.gd` *(переписан)* | Убран локальный `Run1State` (заменён обращением к `RunService`). Подписки на `day_changed`/`energy_changed`/`goal_completed`/`day_finished`. По `day_finished` — instantiate `DaySummary.tscn` поверх Run1 root. `_rebuild_goals()` перерисовывает чек-боксы при изменении состояния целей. |
| `scripts/run1/WorkProgram.gd` *(дополнен)* | Подключен `_run = /root/RunService`. На правильный drop — `_run.register_work_correct()` + (при полной категории) `_run.register_money_earned(10)`. На ошибку — `_run.register_work_error()`. После каждого drop'а — `_run.spend_energy(1)`. |
| `scripts/run1/DatingProgram.gd` *(переписан)* | `attach_state` теперь noop, state читает из `_run`. На лайк — `_run.register_match_added(profile)` + `_run.spend_energy(1)`. На диз — только `spend_energy(1)`. При `energy <= 0` кнопки disabled. |
| `scripts/run1/MailProgram.gd` *(переписан)* | `attach_state` noop. Список матчей читается из `_run.matches`, симпатии — из `_run.sympathies`. На ответ — `_run.register_reply_sent()` + `_run.spend_energy(1)` + обновление `_run.sympathies[id]`. При `energy <= 0` кнопки ответов не показываются. |
| `project.godot` *(через MCP add_autoload)* | `RunService="*res://scripts/core/RunService.gd"`. |

**Smoke через MCP (8/8 зелёных):**
1. `play_scene` → MainMenu → клик «Начать Run 1» → Output: `[MainScene] routing day 1 → res://scenes/Run1.tscn` ✓
2. Шапка Run 1: `$0 | День 1 | Энергия 8/8` ✓
3. Виджет «Цели дня» справа в overview, 4 строки `[ ]` ✓
4. `register_money_earned(40)` → цель `earn_30` авто-mark, виджет обновился `[x] Заработать 30$` ✓
5. `register_program_opened("dating")` → `[x] Проверить дейтинг` ✓
6. `register_reply_sent()` → `[x] Ответить на сообщение` ✓
7. 8 × `spend_energy(1)` → энергия 8→0, `day_finished` эмитнут, DaySummary поверх Run1: «День 1 закрыт / Заработано 40$ / Цели [x][x][x][x] / Вердикт: День прожит без позора.» ✓
8. Клик «Начать следующий день» → Output: `[MainScene] routing day 2 → res://scenes/Run1.tscn`, шапка `День 2 | Энергия 8/8`, цели сброшены ✓

**Что keeper'у проверить вручную:**
- Тон вердиктов и текстов целей.
- Не «жжётся» ли цикл `_rebuild_goals()` (он перестраивает 4 Label на каждый goal_completed; для 4 целей это копейки, но если будет 10+ — нужен diff).
- Логика «дожить до вечера» — авто-mark в `_finish_day`. Прям сейчас «доживание» = достичь energy=0. Может стоит триггерить только если все 3 другие цели выполнены, иначе цель тривиальная.

**Компромиссы / known issues:**
- `Run1State.gd` фактически не используется, но файл остался в `scripts/run1/`. `attach_state` в программах = noop. Удалить в B.
- DaySummary `Verdict` — вердикт строится в RunService, в `done.md` Run 2 потребуется расширить (Slice F).
- Если игрок открыл DaySummary и кликнул «Назад» через `← Встать` Computer-вью — overlay остался поверх. Сейчас невозможно (energy=0 блокирует ввод программ), но в B/C/D/E надо аккуратнее.
- При `day=2` загружается тот же `Run1.tscn` — это плейсхолдер до Slice B. Игроку визуально кажется что день повторяется без новых иконок (но `current_day` реально = 2). Slice B переключит на `Run2.tscn`.

**Следующий слайс (Slice B):** см. `next.md`.
