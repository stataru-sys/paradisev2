extends Node
## Глобальный event-bus через autoload-синглтон.
## Никаких прямых ссылок между несвязанными системами. Только подписка на сигналы.
##
## Правила:
## - Подписываемся: GameEvents.task_completed.connect(_on_task_completed)
## - Отписываемся не обязательно — autoload живёт всю сессию.
## - Названия сигналов — past tense (task_completed, не complete_task).
## - Эмитят сигналы только сервисы из scripts/core/. UI/View — только подписываются.

signal task_completed(task: Resource)
signal task_failed(task: Resource, fail_dialogue_id: String)
signal energy_depleted
signal run_ended(phase: int)
signal agent_assigned(agent: Resource, task_cloud: Node)
signal implant_applied(implant: Resource)
signal money_changed(new_value: int)
signal energy_changed(new_value: int)
signal dialogue_shown(dialogue_id: String)
