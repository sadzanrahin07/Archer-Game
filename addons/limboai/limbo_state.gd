class_name LimboState
extends Node

var agent: Node = null

func _enter() -> void:
	pass

func _exit() -> void:
	pass

func _update(_delta: float) -> void:
	pass

func dispatch(event: StringName) -> bool:
	var hsm = get_hsm()
	if hsm:
		return hsm.dispatch(event)
	return false

func get_hsm() -> LimboHSM:
	var p = get_parent()
	while p:
		if p is LimboHSM:
			return p as LimboHSM
		p = p.get_parent()
	return null
