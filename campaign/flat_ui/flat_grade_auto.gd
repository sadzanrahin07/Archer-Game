class_name FlatUiGradeAuto
extends GridContainer
## Grade equivalente a grid-template-columns:repeat(auto-fill,minmax(N,1fr)).
##
## O Godot nao tem auto-fill: a contagem de colunas e recalculada a cada
## redimensionamento pela mesma formula do CSS — cabe uma coluna a mais
## enquanto (largura + gap) suportar (minimo + gap).

@export var largura_minima := 150
@export var espaco := FlatUiTokens.S3


func _ready() -> void:
	add_theme_constant_override("h_separation", espaco)
	add_theme_constant_override("v_separation", espaco)
	resized.connect(_recalcular)
	_recalcular()


func _recalcular() -> void:
	var cabem := int((size.x + espaco) / float(largura_minima + espaco))
	columns = maxi(1, mini(cabem, get_child_count()))
