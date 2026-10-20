class_name FlatUiRibbon
extends Control
## Fita de nivel (.ribbon) com as pontas recortadas.
##
## O CSS recorta as tres formas com clip-path:
##   corpo:      polygon(0 0, 100% 0, 100% 100%, 0 100%, 7px 50%)
##   cauda esq.: 16x(h-10) em left:-13, mesmo recorte do corpo
##   cauda dir.: 16x(h-10) em right:-13,
##               polygon(0 0, 100% 0, calc(100% - 7px) 50%, 100% 100%, 0 100%)
##
## Nem draw_colored_polygon nem Polygon2D.antialiased dao conta das diagonais:
## o primeiro nao suaviza nada e o segundo amacia cerca de um pixel, o que
## ainda le como serrilhado numa diagonal de 7x17px. Aqui a fita e rasterizada
## em uma Image na resolucao exata em que sera desenhada, com cobertura
## analitica por pixel: para uma aresta reta, a area coberta do pixel e a
## sobreposicao horizontal calculada no centro vertical do pixel — exato, nao
## amostrado. O resultado tem 256 niveis de alpha na diagonal e nao depende de
## MSAA (que fica ligado no projeto, mas como reforco, nao como requisito).
##
## A textura e desenhada 1:1 em _draw (sem escala, para nao reintroduzir
## borrao) e refeita so quando o tamanho ou uma cor muda.

const RECORTE := 7.0
const CAUDA_LARGURA := 16.0
const CAUDA_MARGEM := 13.0
const CAUDA_TOPO := 5.0
const PAD_H := 20
const PAD_V := 5

var _rotulo: Label
var _textura: ImageTexture
var _tamanho_desenhado := Vector2.ZERO

@export var texto := "":
	set(valor):
		texto = valor
		if _rotulo != null:
			_rotulo.text = valor

@export var cor: Color = FlatUiTokens.MOSS:
	set(valor):
		cor = valor
		_invalidar()

@export var cor_cauda: Color = FlatUiTokens.RIBBON_TAIL:
	set(valor):
		cor_cauda = valor
		_invalidar()

@export var com_caudas := true:
	set(valor):
		com_caudas = valor
		_invalidar()


func _ready() -> void:
	var margem := MarginContainer.new()
	margem.add_theme_constant_override("margin_left", PAD_H)
	margem.add_theme_constant_override("margin_right", PAD_H)
	margem.add_theme_constant_override("margin_top", PAD_V)
	margem.add_theme_constant_override("margin_bottom", PAD_V)
	margem.set_anchors_preset(Control.PRESET_FULL_RECT)
	margem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margem)

	_rotulo = Label.new()
	_rotulo.theme_type_variation = "FlatUiRibbon"
	_rotulo.text = texto
	_rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	margem.add_child(_rotulo)

	resized.connect(_invalidar)
	update_minimum_size()
	_invalidar()


func _get_minimum_size() -> Vector2:
	if _rotulo == null:
		return Vector2.ZERO
	return _rotulo.get_combined_minimum_size() + Vector2(PAD_H * 2, PAD_V * 2)


func _invalidar() -> void:
	_tamanho_desenhado = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	if _textura == null or _tamanho_desenhado != size:
		_textura = _rasterizar()
		_tamanho_desenhado = size
	draw_texture(_textura, Vector2(-CAUDA_MARGEM, 0.0))


## Cobertura da fita, em pixels, com as tres formas compostas na ordem do CSS.
func _rasterizar() -> ImageTexture:
	var largura_fita := size.x
	var altura := size.y
	var largura_total := int(ceil(largura_fita + CAUDA_MARGEM * 2.0))
	var alta := int(ceil(altura))
	var imagem := Image.create_empty(largura_total, alta, false, Image.FORMAT_RGBA8)
	imagem.fill(Color(cor.r, cor.g, cor.b, 0.0))

	var cauda_altura := altura - CAUDA_TOPO * 2.0
	var deslocamento := CAUDA_MARGEM  # x=0 da imagem e -13 do controle

	for py in alta:
		var centro := py + 0.5

		# corpo: x de chevron(y) ate a largura da fita
		var cobertura_v := _sobreposicao(py, py + 1.0, 0.0, altura)
		var esquerda_corpo := deslocamento + _chevron(centro, altura)
		var direita_corpo := deslocamento + largura_fita

		# caudas: 16px de largura, recuadas 5px em cima e embaixo
		var v_cauda := _sobreposicao(py, py + 1.0, CAUDA_TOPO, CAUDA_TOPO + cauda_altura)
		var centro_cauda := centro - CAUDA_TOPO
		var esquerda_e := _chevron(centro_cauda, cauda_altura)
		# A borda interna da cauda esquerda precisa alcancar pelo menos onde o
		# corpo comeca (esquerda_corpo) — perto do meio vertical da fita o
		# recorte em V do corpo recua ate deslocamento+RECORTE (13+7=20px),
		# mais fundo que a largura fixa da cauda (16px). Sem este maxf() sobra
		# uma fresta de 4px sem cobertura de corpo nem de cauda ali (o fundo
		# aparecia por tras, visto como um triangulo escuro entre as pecas).
		var direita_e := maxf(CAUDA_LARGURA, esquerda_corpo)
		var base_d := deslocamento + largura_fita + CAUDA_MARGEM - CAUDA_LARGURA
		var esquerda_d := base_d
		var direita_d := base_d + CAUDA_LARGURA - _chevron(centro_cauda, cauda_altura)

		for px in largura_total:
			var alpha_corpo := cobertura_v * _sobreposicao(
					px, px + 1.0, esquerda_corpo, direita_corpo)
			var alpha_cauda := 0.0
			if com_caudas and v_cauda > 0.0:
				alpha_cauda = v_cauda * maxf(
						_sobreposicao(px, px + 1.0, esquerda_e, direita_e),
						_sobreposicao(px, px + 1.0, esquerda_d, direita_d))
			imagem.set_pixel(px, py, _compor(alpha_corpo, alpha_cauda))

	return ImageTexture.create_from_image(imagem)


## Deslocamento horizontal da ponta recortada na altura y (0 nas bordas, 7 no
## meio) — os dois segmentos do clip-path, em forma fechada.
func _chevron(y: float, altura: float) -> float:
	if altura <= 0.0:
		return 0.0
	var t := clampf(y / altura, 0.0, 1.0)
	return RECORTE * (1.0 - absf(2.0 * t - 1.0))


## Area do pixel [inicio,fim] coberta pelo intervalo [a,b]. Para uma aresta
## reta avaliada no centro vertical do pixel, isso e a area exata.
func _sobreposicao(inicio: float, fim: float, a: float, b: float) -> float:
	return maxf(0.0, minf(fim, b) - maxf(inicio, a))


func _compor(alpha_corpo: float, alpha_cauda: float) -> Color:
	# cauda por cima do corpo (::before/::after pintam depois do fundo)
	var resultado := Color(cor.r, cor.g, cor.b, alpha_corpo)
	if alpha_cauda <= 0.0:
		return resultado
	var alpha := alpha_cauda + resultado.a * (1.0 - alpha_cauda)
	if alpha <= 0.0:
		return Color(cor.r, cor.g, cor.b, 0.0)
	var mistura := alpha_cauda / alpha
	return Color(
		lerpf(resultado.r, cor_cauda.r, mistura),
		lerpf(resultado.g, cor_cauda.g, mistura),
		lerpf(resultado.b, cor_cauda.b, mistura),
		alpha)
