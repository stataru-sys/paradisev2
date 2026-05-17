extends Node
## Глобальный event-bus через autoload-синглтон.
## Никаких прямых ссылок между несвязанными системами. Только подписка на сигналы.
##
## Правила:
## - Подписываемся: GameEvents.task_completed.connect(_on_task_completed)
## - Названия сигналов — past tense (task_completed, не complete_task).
## - Эмитят сигналы только сервисы из scripts/core/ или Run-контроллеры. UI/View — только подписываются.

signal task_completed(task: Resource)
signal task_failed(task: Resource, fail_dialogue_id: String)
signal energy_depleted
signal run_ended(phase: int)
signal agent_assigned(agent: Resource, task_cloud: Node)
signal implant_applied(implant: Resource)
signal money_changed(new_value: int)
signal energy_changed(current_value: int, max_value: int)
signal dialogue_shown(dialogue_id: String)

# Run1 desktop / programs
signal program_open_requested(program_id: String)
signal program_closed
signal work_day_finished(earned: int)
signal dating_match_added(profile_id: String)
signal sympathy_changed(profile_id: String, new_value: float)

# Run-loop (Slice A+)
signal day_changed(new_day: int)
signal day_finished(summary: Dictionary)
signal goal_completed(goal_id: String)
signal event_log_added(message: String)
signal upgrade_purchased(upgrade_id: String)
signal agent_hired(agent_id: String)
