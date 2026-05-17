extends Node
## Простой реестр сервисов через autoload. Альтернатива DI-фреймворку.
##
## Регистрируем в Bootstrap, дёргаем из любой системы:
##   ServiceLocator.register("economy", EconomyService.new())
##   var econ = ServiceLocator.get_service("economy") as EconomyService
##
## Сервисы — обычные RefCounted/Node, не autoload — чтобы их можно было пересоздавать
## между ранами и легко мокать в тестах.

var _services: Dictionary = {}

func register(key: String, service: Object) -> void:
	_services[key] = service

func get_service(key: String) -> Object:
	return _services.get(key)

func has_service(key: String) -> bool:
	return _services.has(key)

func clear() -> void:
	_services.clear()
