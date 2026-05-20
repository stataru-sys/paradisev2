# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Paradise 2033 (Godot edition)

Idle/tap-кликер тайкун с сатирой на эпоху AI-агентов 2033 года. Соло-разработка пользователем + друг-сооснователь (дизайн/идеи). **Идея игры портирована** из Unity-прототипа `D:\UnityProjects\Paradise2033` — там лежат расширенные docs концепта и истории решений. В этом репозитории — реализация с нуля на Godot.

## Quick context

- **Жанр:** idle-кликер с престижем; геймплейный референс — корейский *Don't Get Fired!* (облачки-задания, тап тратит энергию, % шанс провала, делегирование агентам).
- **Платформа:** Steam (PC) на релиз; Standalone Windows для playtest'ов; mobile-адаптация — после Steam.
- **Стек:** Godot 4.6.2-stable, GDScript, 2D, GL Compatibility renderer (для широкой совместимости PC). Пиксель-арт — AI-генерация (Midjourney/SDXL) + Aseprite, импорт через стандартный Godot importer (CompressedTexture2D с Nearest filter).
- **MCP-стек:** Godot MCP Pro v1.13.0. Сервер живёт **вне** проекта в `C:\Users\stas1\Downloads\godot-mcp-pro-v1.13.0\server\`, addon-плагин лежит **внутри** проекта в `addons/godot_mcp/`.
- **Язык общения:** русский. Тон в нарративе игры — сухая ирония + бытовой мат (авторская стилистика).

## Где что лежит

| Путь | Что внутри |
|---|---|
| `.claude/docs/concept.md` | Сюжет, лор, тон, нарратив, каталог контента MVP, что не входит |
| `.claude/docs/workflow.md` | Описание keeper/coder two-chat workflow + шаблоны `next.md`/`done.md` |
| `.claude/handoff/next.md` | **Что делать в текущей coder-сессии** (живой документ от keeper'а) |
| `.claude/handoff/done.md` | Отчёт coder'а после слайса (живой) |
| `.claude/plans/` | Дизайн-документы фич (напр. `work-expansion.md` — план Work System Expansion G→J) |
| `.claude/skills/godot-mcp.md` | **Скиллы Godot MCP Pro** — workflow-паттерны и подсказки по 169 MCP-тулам. **Coder читает первым делом перед любой работой через MCP.** |
| `scripts/core/` | Autoload-сервисы: `GameEvents.gd` (event-bus), `Economy.gd`, `RunService.gd` |
| `scripts/ui/` | Общие UI-скрипты: `MainMenu.gd`, `MainScene.gd` (роутер run-ов), `EventLog.gd` |
| `scripts/run1/`, `scripts/run2/` | Скрипты программ и мини-игр конкретного run-а |
| `scenes/` | `MainMenu.tscn` (main_scene), `MainScene.tscn` (роутер), `Run1.tscn`/`Run2.tscn`; программы — в `scenes/run1/`, `scenes/run2/` |
| `resources/{tasks,agents,implants,dialogues,fails}/` | Папки под `.tres`-контент — **пока пусты**, контент зашит в `const`-словари скриптов (см. правило #3) |
| `addons/godot_mcp/` | Godot-плагин MCP Pro, включён в `project.godot` |

## Two-chat workflow

Проект ведётся **в две параллельные роли в разных чатах Claude Code**, чтобы не засорять контекст. Подробности и шаблоны — в `.claude/docs/workflow.md`.

- **Keeper-чат** (постоянный): дизайн, нарратив, баланс, ревью кода, обновление `docs/`. Формулирует `next.md` для coder'а. **Не пишет код.**
- **Coder-чат** (свежий каждый слайс): открывается командой `claude` в этой папке, **первое действие** — прочитать `.claude/handoff/next.md`. Делает один слайс, коммитит, заполняет `done.md`, закрывается.
- Auto-memory (`~/.claude/projects/D--ClaudeProjects-paradise/memory/`) — общий сейф фактов, авто-загружается обоими чатами.

## Архитектурные правила (5 штук, переносим из Unity-версии)

Те же принципы что в Unity-прототипе, но с заменой механизмов под Godot 4.

1. **Event-bus с дня 1 — через signals.** `GameEvents` — autoload-синглтон со списком `signal task_completed(...)` и т.п. Никаких прямых ссылок между несвязанными системами. Подписка — `GameEvents.task_completed.connect(_on_task_completed)`. Названия сигналов — past tense.
2. **Сервисы = autoload-синглтоны, не ServiceLocator.** `Economy`, `RunService` (и будущий `Save`) — каждый отдельный autoload в `[autoload]`-секции `project.godot`. Из любой ноды — `Economy.add(50)`, `RunService.spend_energy(1)`. У каждого сервиса обязателен метод `reset()` — для пересоздания state между ранами (без перегрузки autoload-инстанса). Это идиоматичный Godot-way; ServiceLocator-обёртка не нужна, она была лишним слоем из Unity-привычек.
3. **Resource-driven контент.** Всё перечислимое (задачи, агенты, импланты, диалоги, fail'ы) — кастомный `Resource` (`class_name TaskRes extends Resource` и т.п.), хранится как `.tres` в `resources/`. Это аналог Unity ScriptableObject в Godot. **Текущее состояние:** контент пока зашит как `const Array[Dictionary]` прямо в скриптах программ (`UPGRADES` в `ShopApp.gd`, `AGENTS` в `AgentShopApp.gd`, `OUTCOMES` в `CasinoApp.gd` и т.п.). `.tres`-миграция отложена до момента, когда понадобится Inspector-редактирование или баланс через keeper'а.
4. **Save с версионированием.** Файл — `user://save.json`, формат — `Dictionary` через `JSON.stringify` + поле `save_version: int` + `migrate_if_needed()` switch по версии. Стоит 30 минут на старте, спасает первый playtest.
5. **Имплант = swap дочерней `Sprite2D`-ноды**, НЕ AnimationTree/AnimatedSprite2D. Каждая часть тела — отдельная child-нода под `Player` со своим `texture`. На каждый имплант — отдельный `Texture2D` ссылкой в `ImplantRes`. Артист добавляет вариант независимо, не трогая остальные части.

## Архитектура runtime (сцены и навигация)

Поток сцен — три уровня; каждый загружает следующий через `change_scene_to_file` либо инстансит сцену внутрь host-ноды.

1. **`MainMenu.tscn`** — стартовое меню (`run/main_scene` проекта). Кнопка «Начать» → грузит `MainScene.tscn`.
2. **`MainScene.tscn` (`MainScene.gd`)** — роутер run-ов. Читает `RunService.current_day`: день 1 → `Run1.tscn`, день ≥ 2 → `Run2.tscn`.
3. **`Run1.tscn` / `Run2.tscn` (`Run1.gd` / `Run2.gd`)** — root-контроллер игрового дня. Держит шапку (день/деньги/энергия), виджет целей, два вида комнаты (общий план ↔ крупный план монитора) и **program-host**.

**Program-host паттерн.** Run-контроллер не знает о программах напрямую — он хранит `const SCENE_PATHS` (id → путь `.tscn`) и ноду `_program_host`. Метод `_open_program(id)` чистит host и инстансит туда сцену программы. Открытие — клик иконки на Desktop эмитит `GameEvents.program_open_requested.emit(id)`. Закрытие — программа эмитит `GameEvents.program_closed`, Run-контроллер ловит и грузит обратно Desktop.

**WorkHub — вложенный host.** Программа `work` ведёт не на мини-игру, а на `WorkHub.tscn` — экран выбора работы, который сам хостит мини-игры (`WorkProgram`, `MailSortGame`, будущий `BugfixGame`) в собственной `GameHost`-ноде. Мини-игра завершается, инстансируя `WorkResult.tscn` и эмитя `GameEvents.work_day_finished`. WorkHub переподключает кнопку «Назад» мини-игры на возврат к карточкам выбора.

**Run1 vs Run2.** `Run2.tscn`/`Run2.gd` — почти копия Run1 с расширенным рабочим столом (`Desktop2.tscn` — 6 иконок: 3 рабочие + 3 разблокируемые: Магазин/Казино/Агенты). Программы work/dating/mail переиспользуются из `scenes/run1/`. Дублирование run-сцен — осознанный компромисс (см. `done.md`, Slice B).

**Жизненный цикл дня.** Действия (drop карточки, лайк, ответ, крутка) тратят энергию через `RunService.spend_energy()`. При энергии 0 (или кнопкой «Лечь спать» → `force_finish_day()`) — `day_finished` с `summary`-словарём, Run-контроллер показывает `DaySummary` поверх всего. «Начать следующий день» → `RunService.next_day()` → снова `MainScene.tscn`.

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

## Skills — Godot MCP Pro

**Перед любой работой через MCP-тулы coder обязан прочитать `.claude/skills/godot-mcp.md`.** Это адаптированные авторами плагина workflow-паттерны под 169 MCP-инструментов: с чего начинать (`get_project_info` → `get_filesystem_tree` → `get_scene_tree`), как корректно создавать сцены и скрипты, как делать playtest-цикл (`play_scene` → `simulate_*` → `get_game_screenshot` → `stop_scene`), какие есть batch-операции и анализ-тулы. Файл — копия `addons/godot_mcp/skills.ru.md` (русская локаль из дистрибутива плагина); обновлять можно из `addons/godot_mcp/skills.ru.md` при апдейте MCP Pro до новой версии.

## MCP setup status

- ✅ **Godot MCP Pro v1.13.0** установлен. Сервер собран в `C:\Users\stas1\Downloads\godot-mcp-pro-v1.13.0\server\build\index.js`, проверен через `node build/setup.js doctor` — All good.
- ✅ **Addon** `addons/godot_mcp/` лежит в проекте, включён в `project.godot` (секция `[editor_plugins]`).
- ✅ **`.mcp.json`** в корне проекта с абсолютным путём к `build/index.js`. Коммитится в git (project scope).
- ⚠️ **Editor vs Runtime tools.** В MCP Pro разделение: editor-tools работают всегда, runtime-tools (симуляция кликов, чтение state запущенной игры, скриншоты) требуют сначала вызова `play_scene`. Без `play_scene` — `runtime_*` всегда падают.
- ⚠️ **Никогда не редактируй `project.godot` напрямую** через Write/Edit — Godot Editor перезаписывает файл при сохранении. Используй MCP `set_project_setting` или редактируй через UI Godot и пересохраняй.
- ⚠️ **Autoload-секция содержит MCP-сервисы плагина** (`MCPScreenshot`, `MCPInputService`, `MCPGameInspector`) — это **не наши** autoload-ы, их зарегистрировал плагин при первом enable. Не удалять: без них не работают runtime-тулы (`get_game_screenshot`, `simulate_*`, `find_nodes_by_script`). Наши собственные autoload-ы — `GameEvents`, `Economy`, `RunService`.
- ⚠️ **Stale `node.exe`** — если MCP «Waiting for connection», в Task Manager убить все `node.exe` и перезапустить Claude Code.

### Первый запуск Godot

1. Godot 4.x → Import → выбрать `D:\ClaudeProjects\paradise\project.godot`.
2. Project → Project Settings → Plugins → `Godot MCP Pro` → **Enable**.
3. Нижняя панель → вкладка `MCP Pro` → должна показать **зелёный** коннект-дот после старта Claude Code в этой папке.
4. F5 → запускается main_scene (`MainMenu.tscn`) → в Output: `[MainMenu] ready — Paradise 2033 boot OK`.

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
node C:/Users/stas1/Downloads/godot-mcp-pro-v1.13.0/server/build/cli.js script read --path res://scripts/ui/MainMenu.gd
```

## Текущий статус

- **Phase:** Slice I закрыт, Slice J (Bug Fix Mini-game) — в `next.md`. Пройдены мастер-план A→F (полная idle-петля: Run 1/2, Магазин, Казино, Агенты, EventLog/DaySummary) и Work System Expansion G→I (WorkHub, WorkResult, Corporate Mail).
- **Сцены:** `MainMenu` → `MainScene` (роутер) → `Run1`/`Run2`. Программы Run 1: `Desktop`, `WorkProgram`, `DatingProgram`, `MailProgram`, `DaySummary`. Run 2: `Desktop2`, `ShopApp`, `CasinoApp`, `AgentShopApp`, `WorkHub`, `MailSortGame`, `WorkResult`. (`Bootstrap.tscn` — мёртвый артефакт Slice 0, в графе сцен не участвует.)
- **Autoload-сервисы:** `GameEvents` (event-bus), `Economy` (деньги), `RunService` (state дня: энергия, цели, апгрейды, агенты, матчи, симпатии, разблокировки). У каждого есть `reset()`.
- **Сейв:** `Save` ещё не написан. План — `user://save.json`, `Dictionary` через `JSON.stringify` + `save_version` + `migrate_if_needed()`.
- **Telemetry:** не реализована. План — CSV в `user://playtest_log.csv`, append-mode, формат как в Unity-версии.
- **Git:** ветка `main`. Каждый слайс — отдельный коммит coder'а + коммит keeper'а с обновлением `done.md`/`next.md`.
