# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Paradise 2033 (Godot edition)

Idle/tap-кликер тайкун с сатирой на эпоху AI-агентов 2033 года. Соло-разработка пользователем + друг-сооснователь (дизайн/идеи). **Идея игры портирована** из Unity-прототипа `D:\UnityProjects\Paradise2033` — там лежат расширенные docs концепта и истории решений. В этом репозитории — реализация с нуля на Godot.

## Quick context

- **Жанр:** idle-кликер с престижем; геймплейный референс — корейский *Don't Get Fired!* (облачки-задания, тап тратит энергию, % шанс провала, делегирование агентам).
- **Платформа:** Steam (PC) на релиз; Standalone Windows для playtest'ов; mobile-адаптация — после Steam.
- **Стек:** Godot 4.x, GDScript, 2D, GL Compatibility renderer (для широкой совместимости PC). Пиксель-арт — AI-генерация (Midjourney/SDXL) + Aseprite, импорт через стандартный Godot importer (CompressedTexture2D с Nearest filter).
- **MCP-стек:** Godot MCP Pro v1.13.0. Сервер живёт **вне** проекта в `C:\Users\stas1\Downloads\godot-mcp-pro-v1.13.0\server\`, addon-плагин лежит **внутри** проекта в `addons/godot_mcp/`.
- **Язык общения:** русский. Тон в нарративе игры — сухая ирония + бытовой мат (авторская стилистика).

## Где что лежит

| Путь | Что внутри |
|---|---|
| `.claude/docs/concept.md` | Сюжет, лор, тон, нарратив, каталог контента MVP, что не входит |
| `.claude/docs/workflow.md` | Описание keeper/coder two-chat workflow + шаблоны `next.md`/`done.md` |
| `.claude/handoff/next.md` | **Что делать в текущей coder-сессии** (живой документ от keeper'а) |
| `.claude/handoff/done.md` | Отчёт coder'а после слайса (живой) |
| `scripts/core/` | GameEvents, ServiceLocator (autoload), Bootstrap, будущие сервисы (Economy/Run/Save) |
| `scenes/Bootstrap.tscn` | main_scene проекта, единственная точка инициализации сервисов |
| `resources/{tasks,agents,implants,dialogues,fails}/` | `.tres`-ресурсы — единственный способ хранить контент |
| `addons/godot_mcp/` | Godot-плагин MCP Pro, включён в `project.godot` |

## Two-chat workflow

Проект ведётся **в две параллельные роли в разных чатах Claude Code**, чтобы не засорять контекст. Подробности и шаблоны — в `.claude/docs/workflow.md`.

- **Keeper-чат** (постоянный): дизайн, нарратив, баланс, ревью кода, обновление `docs/`. Формулирует `next.md` для coder'а. **Не пишет код.**
- **Coder-чат** (свежий каждый слайс): открывается командой `claude` в этой папке, **первое действие** — прочитать `.claude/handoff/next.md`. Делает один слайс, коммитит, заполняет `done.md`, закрывается.
- Auto-memory (`~/.claude/projects/D--ClaudeProjects-paradise/memory/`) — общий сейф фактов, авто-загружается обоими чатами.

## Архитектурные правила (5 штук, переносим из Unity-версии)

Те же принципы что в Unity-прототипе, но с заменой механизмов под Godot 4.

1. **Event-bus с дня 1 — через signals.** `GameEvents` — autoload-синглтон со списком `signal task_completed(...)` и т.п. Никаких прямых ссылок между несвязанными системами. Подписка — `GameEvents.task_completed.connect(_on_task_completed)`. Названия сигналов — past tense.
2. **Три сервиса, не один GameManager.** `EconomyService` / `RunService` / `SaveService` — обычные `RefCounted`/`Node`, **не autoload**, регистрируются через `ServiceLocator` (тоже autoload) в `Bootstrap._ready()`. Это позволяет пересоздавать сервисы между ранами и легко мокать в тестах.
3. **Resource-driven контент.** Всё перечислимое (задачи, агенты, импланты, диалоги, fail'ы) — кастомный `Resource` (`class_name TaskRes extends Resource` и т.п.), хранится как `.tres` в `resources/`. Это аналог Unity ScriptableObject в Godot.
4. **Save с версионированием.** Файл — `user://save.json`, формат — `Dictionary` через `JSON.stringify` + поле `save_version: int` + `migrate_if_needed()` switch по версии. Стоит 30 минут на старте, спасает первый playtest.
5. **Имплант = swap дочерней `Sprite2D`-ноды**, НЕ AnimationTree/AnimatedSprite2D. Каждая часть тела — отдельная child-нода под `Player` со своим `texture`. На каждый имплант — отдельный `Texture2D` ссылкой в `ImplantRes`. Артист добавляет вариант независимо, не трогая остальные части.

## Конвенции кода (GDScript)

- **Type hints обязательны** на параметрах функций, возвращаемых типах, `@export`-полях. `func add_money(amount: int) -> void:` — норма, нетипизированное — bad smell.
- **Для-циклы — типизированные:** `for item: String in array:` вместо `for item in array:` (Godot MCP Pro явно это рекомендует).
- **`@onready var` для child-нод**, не `get_node()` в `_ready`. UID-стабильность сцены важнее «явности».
- **Без комментариев «что делает»** — имена идентификаторов должны говорить сами. Комментарий пишется только для непредсказуемого «почему» (хидден инвариант, обходной путь, баг которого нет в коде).
- **Сигналы только из `scripts/core/`** — UI/View ноды только подписываются, не эмитят. Это держит data-flow однонаправленным.
- **`class_name`** — для всех Resource-классов и сервисов, чтобы они подхватились в Inspector и `preload()` без полного пути.
- **UI-тексты, имена ресурсов, идентификаторы контента** — на русском в пользовательском слое; внутренние tech-id (имена нод, ключи словарей, autoload-имена) — на латинице.

## Ассеты

- **Pixel art:** AI-генерация (Midjourney/SDXL) → пост-обработка в Aseprite → импорт `.png` стандартным Godot-importer. **Обязательно:** в Import-вкладке выставить `Filter: Nearest` и `Mipmaps: off`, иначе пиксели мылятся.
- **Звук:** freesound.org placeholder для MVP.
- **Шрифты:** TTF/OTF положить в `resources/fonts/`, использовать через `Theme`-ресурс (а не в каждом `Label` руками).

## MCP setup status

- ✅ **Godot MCP Pro v1.13.0** установлен. Сервер собран в `C:\Users\stas1\Downloads\godot-mcp-pro-v1.13.0\server\build\index.js`, проверен через `node build/setup.js doctor` — All good.
- ✅ **Addon** `addons/godot_mcp/` лежит в проекте, включён в `project.godot` (секция `[editor_plugins]`).
- ✅ **`.mcp.json`** в корне проекта с абсолютным путём к `build/index.js`. Коммитится в git (project scope).
- ⚠️ **Editor vs Runtime tools.** В MCP Pro разделение: editor-tools работают всегда, runtime-tools (симуляция кликов, чтение state запущенной игры, скриншоты) требуют сначала вызова `play_scene`. Без `play_scene` — `runtime_*` всегда падают.
- ⚠️ **Никогда не редактируй `project.godot` напрямую** через Write/Edit — Godot Editor перезаписывает файл при сохранении. Используй MCP `set_project_setting` или редактируй через UI Godot и пересохраняй.
- ⚠️ **Stale `node.exe`** — если MCP «Waiting for connection», в Task Manager убить все `node.exe` и перезапустить Claude Code.

### Первый запуск Godot

1. Godot 4.x → Import → выбрать `D:\ClaudeProjects\paradise\project.godot`.
2. Project → Project Settings → Plugins → `Godot MCP Pro` → **Enable**.
3. Нижняя панель → вкладка `MCP Pro` → должна показать **зелёный** коннект-дот после старта Claude Code в этой папке.
4. F5 → запуск Bootstrap-сцены → в Output: `[Bootstrap] Paradise 2033 — boot OK`.

### Ключевые MCP-инструменты

Полный список — в `C:\Users\stas1\Downloads\godot-mcp-pro-v1.13.0\instructions\CLAUDE.md`. Чаще всего нужны:

| Тул | Когда |
|---|---|
| `create_script`, `edit_script`, `read_script`, `validate_script` | Создать/обновить .gd, проверить синтаксис |
| `attach_script` | Прицепить .gd к существующей ноде в сцене |
| `add_node`, `batch_add_nodes`, `update_property` | Построить/изменить сцену |
| `create_resource`, `edit_resource`, `read_resource` | Работа с `.tres`-ресурсами (TaskRes, AgentRes и т.п.) |
| `set_project_setting`, `get_project_settings` | Безопасное редактирование project.godot |
| `get_editor_errors`, `get_output_log` | Узнать что сломалось после изменений |
| `play_scene` → `simulate_mouse_click` → `get_game_screenshot` → `stop_scene` | Тест геймплея без открытия рук |

## CLI fallback (если MCP-тулы недоступны)

```bash
node C:/Users/stas1/Downloads/godot-mcp-pro-v1.13.0/server/build/cli.js --help
node C:/Users/stas1/Downloads/godot-mcp-pro-v1.13.0/server/build/cli.js project info
node C:/Users/stas1/Downloads/godot-mcp-pro-v1.13.0/server/build/cli.js scene tree
node C:/Users/stas1/Downloads/godot-mcp-pro-v1.13.0/server/build/cli.js script read --path res://scripts/core/Bootstrap.gd
```

## Текущий статус

- **Phase:** Bootstrap. Структура папок и autoload-скелет созданы. MCP-плагин в проекте, сервер собран. `Bootstrap.tscn` — main scene, печатает boot-маркер.
- **Slice 0** активен — см. `.claude/handoff/next.md`. Цель: убедиться что Godot открывает проект, MCP-плагин коннектится, Bootstrap запускается.
- **Сцены:** только `scenes/Bootstrap.tscn`. MainMenu/MainScene/EndScreen — Slice 1+.
- **Сервисы:** Economy/Run/Save — ещё не написаны, заготовки в `Bootstrap._ready()` закомментированы. Slice 1.
- **Сейв:** не реализован. Формат — `user://save.json`, версионирование с дня реализации.
- **Telemetry:** не реализована. План — CSV в `user://playtest_log.csv`, append-mode, формат как в Unity-версии.
- **Git:** инициализирован, первый коммит — bootstrap.
