class_name FlatUiBarra
extends Control
## Trilho + preenchimento das barras de recurso (.bar .track / .bar .fill).
##
## Trilho de 14px em chip com raio pill; preenchimento reto e chapado, com o
## mesmo raio, cortado na largura proporcional. Desenhado em _draw porque o
## preenchimento precisa de largura fracionaria da propria barra.

const ALTURA := 14

var _caixa_trilho := FlatUiTokens.caixa(FlatUiTokens.CHIP, FlatUiTokens.R_PILL)
var _caixa_fill := FlatUiTokens.caixa(FlatUiTokens.CORAL, FlatUiTokens.R_PILL)

@export_range(0.0, 1.0) var proporcao := 0.0:
	set(valor):
		proporcao = clampf(valor, 0.0, 1.0)
		queue_redraw()

@export var cor_fill: Color = FlatUiTokens.CORAL:
	set(valor):
		cor_fill = valor
		_caixa_fill.bg_color = valor
		queue_redraw()


func _init() -> void:
	custom_minimum_size.y = ALTURA
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _draw() -> void:
	var altura := float(ALTURA)
	draw_style_box(_caixa_trilho, Rect2(0.0, 0.0, size.x, altura))
	if proporcao <= 0.0:
		return
	draw_style_box(_caixa_fill, Rect2(0.0, 0.0, size.x * proporcao, altura))


## Anima o preenchimento de zero ate a proporcao final (entrada da cena).
func animar_entrada(destino: float, duracao: float, atraso: float) -> void:
	proporcao = 0.0
	var tween := create_tween()
	tween.tween_interval(atraso)
	tween.tween_property(self, "proporcao", destino, duracao) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
