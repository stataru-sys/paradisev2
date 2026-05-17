# Slice 0 — ЗАКРЫТ ✓

Godot 4.6.2 открывает проект, MCP-плагин коннектится, `MainMenu.tscn` запускается по F5, выводит `[MainMenu] ready — Paradise 2033 boot OK`. Архитектурный паттерн — чистый Godot-way (autoload-сервисы, без ServiceLocator-обёртки). Скиллы Godot MCP Pro доступны в `.claude/skills/godot-mcp.md`.

---

# Slice 1 — Core autoload-сервисы (Economy, Run, Save)

## Goal
Завести три autoload-сервиса со стартовым state, минимальными методами и `reset()`. Сейв загружается при старте, money/energy переживают рестарт. Один тестовый вызов из MainMenu для smoke-проверки.

## Files to touch
- `scripts/core/Economy.gd` — energy/money/exp, методы `add_money(int)`, `spend_energy(int)`, `regen_tick(float)`, `reset()`. Эмитит `GameEvents.money_changed`/`energy_changed`/`energy_depleted`.
- `scripts/core/Run.gd` — enum `Phase { RUN1, RUN2, PRESTIGED }`, `current_phase`, `advance()`, `reset()`. Эмитит `GameEvents.run_ended(phase)`.
- `scripts/core/Save.gd` — `load_game()`/`save_game()`, файл `user://save.json`, поле `save_version: int` со switch-миграцией. Подписан на `GameEvents.task_completed` для авто-сейва. Также сохраняет на `GameEvents.run_ended`.
- `project.godot` — добавить три autoload через **MCP `add_autoload`** (НЕ Write/Edit напрямую).
- `scripts/ui/MainMenu.gd` — в `_ready()` дёрнуть `Save.load_game()`, вывести в Output текущее `Economy.money` для smoke-теста.

## Acceptance
- [ ] `Economy`, `Run`, `Save` зарегистрированы в `[autoload]` и видны через MCP `get_project_info`.
- [ ] `validate_script` чист на всех трёх.
- [ ] F5 → MainMenu выводит: `[MainMenu] ready — Paradise 2033 boot OK` и `[Save] loaded (money=0, energy=100)` при первом запуске.
- [ ] Тест-сценарий через MCP: `play_scene` → дёрнуть `execute_game_script` с `Economy.add_money(123); Save.save_game()` → `stop_scene` → перезапуск → в Output `money=123`.
- [ ] `save_version` = 1, switch в `migrate_if_needed()` уже на месте (с пустой веткой) на день написания.

## Out of scope (НЕ делать в этом слайсе)
- TaskCloud, агенты, импланты, диалоги. Это Slice 2.
- Реальное меню с кнопками — MainMenu остаётся техническим выводом в Output.
- Telemetry CSV — Slice 3.
- UI с энергией/деньгами — Slice 2 (вместе с первой задачей).

## Подсказки
- Перед стартом — прочитать `.claude/skills/godot-mcp.md`, секции «Изучение проекта», «Написание и редактирование скриптов», «Тестирование и отладка».
- `add_autoload` принимает `name`, `path`, `singleton` (=true) — это безопасный способ править `[autoload]`.
- На каждом сервисе обязателен `reset()` — даже если в Slice 1 он не вызывается (нужен для Slice 4 при Prestige-перезапуске).
