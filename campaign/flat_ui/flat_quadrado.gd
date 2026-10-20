class_name FlatUiQuadrado
extends PanelContainer
## Painel que mantem proporcao 1:1 (aspect-ratio:1/1 do CSS).
##
## Usado no art chip dos tiles, nos gems do tabuleiro e nos nos de nivel, que
## no CSS ocupam toda a largura da coluna e derivam a altura dela.


func _ready() -> void:
	resized.connect(_ajustar)
	_ajustar()


func _ajustar() -> void:
	if is_equal_approx(custom_minimum_size.y, size.x):
		return
	custom_minimum_size.y = size.x
