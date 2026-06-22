extends RefCounted

signal changed(balance: int)

var _balance: int = 0


func _init(starting_balance: int = 0) -> void:
	_balance = max(0, starting_balance)


func get_balance() -> int:
	return _balance


func add_currency(amount: int) -> Dictionary:
	if amount < 0:
		return _fail("currency_invalid", "Cannot add a negative amount.")
	_balance += amount
	changed.emit(_balance)
	return {"ok": true, "balance": _balance}


func spend_currency(amount: int) -> Dictionary:
	if amount < 0:
		return _fail("currency_invalid", "Cannot spend a negative amount.")
	if _balance < amount:
		return _fail("insufficient_currency", "Not enough currency.")
	_balance -= amount
	changed.emit(_balance)
	return {"ok": true, "balance": _balance}


func snapshot() -> int:
	return _balance


func restore(balance: int) -> void:
	_balance = max(0, balance)
	changed.emit(_balance)


func _fail(code: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"error": code,
		"message": message,
	}
