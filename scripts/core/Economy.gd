extends Node
## Глобальный счёт денег. Слайс 1: только money, regen и сейв — позже.

var money: int = 0

func add(amount: int) -> void:
	if amount == 0:
		return
	money += amount
	GameEvents.money_changed.emit(money)

func spend(amount: int, allow_negative: bool = false) -> bool:
	if not allow_negative and money - amount < 0:
		return false
	money -= amount
	GameEvents.money_changed.emit(money)
	return true

func reset() -> void:
	money = 0
	GameEvents.money_changed.emit(money)
