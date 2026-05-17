# Slice 0 — Project bootstrap

## Goal
Открыть проект в Godot 4.x, убедиться что Bootstrap-сцена запускается без ошибок, MCP-плагин подключился.

## Steps (для coder-чата ИЛИ человека)
1. Открыть Godot 4.x → Import → выбрать `D:\ClaudeProjects\paradise\project.godot`.
2. Project → Project Settings → Plugins → убедиться что `Godot MCP Pro` включён (галочка Enable).
3. В нижней панели должна появиться вкладка `MCP Pro` с зелёной точкой коннекта (после старта Claude Code в этой папке).
4. F5 (Play) → запустится Bootstrap-сцена → в Output: `[Bootstrap] Paradise 2033 — boot OK`.

## Acceptance
- [ ] `project.godot` открывается без ошибок (Output → нет красных строк).
- [ ] Bootstrap.tscn — main scene, запускается по F5.
- [ ] В Output появляется `[Bootstrap] Paradise 2033 — boot OK`.
- [ ] MCP-плагин включён и виден в нижней панели.

## Out of scope
- Никаких сервисов, сцен MainMenu/MainScene, ScriptableObjects-аналогов. Это Slice 1.
- Не трогать `.mcp.json` — он уже корректен.

---

# Slice 1 (предварительно) — Core services + TaskCloud MVP

(Активировать после того как Slice 0 закрыт.)

Реализовать `EconomyService`, `RunService`, `SaveService` (заглушки в `scripts/core/`),
зарегистрировать через `ServiceLocator` в `Bootstrap._ready()`. Один `TaskCloud` на сцене
с тапом-обработчиком, который снимает энергию через `EconomyService` и эмитит `task_completed`.

Подробности добавит keeper после ревью Slice 0.
