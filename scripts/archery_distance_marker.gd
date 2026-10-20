@tool
extends StaticBody3D

@export var distance_text: String = "10":
	set(v):
		distance_text = v
		_update_label()

func _ready() -> void:
	_update_label()

func _update_label() -> void:
	var lbl = get_node_or_null("FrontBoard/NumberLabel") as Label3D
	if lbl:
		lbl.text = distance_text
