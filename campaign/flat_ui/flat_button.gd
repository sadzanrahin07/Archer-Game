class_name FlatUiButton
extends Button
## Botao do UI kit "Flat UI Kit" com as transicoes do CSS de referencia.
##
## O tema entrega o fill de repouso e o de hover; aqui os dois sao
## interpolados em 0.12s linear (transition:background-color .12s linear) em um
## unico StyleBoxFlat proprio da instancia, porque o Godot troca stylebox de
## estado sem interpolar.
##
## :active nao troca o fill — cai para opacity .78 sobre o botao inteiro
## (texto incluido), o que corresponde a modulate.a no Godot.
##
## O anel de foco vem do stylebox "focus" do tema. Para imitar :focus-visible,
## o foco conquistado por clique de mouse e liberado ao soltar o botao; o foco
## por teclado (Tab) permanece.

enum Estado {NENHUM, HOVER, ATIVO}

## Congela o botao em um estado para a tabela de estados da prancha.
@export var estado_forcado: Estado = Estado.NENHUM

var _caixa: StyleBoxFlat
var _cor_repouso: Color
var _cor_hover: Color
var _tween_fill: Tween
var _tween_opacidade: Tween
var _pressionado_por_mouse := false


func _ready() -> void:
	recarregar_estilo()
	if estado_forcado == Estado.NENHUM:
		mouse_entered.connect(_ao_entrar_mouse)
		mouse_exited.connect(_ao_sair_mouse)
		button_down.connect(_ao_pressionar)
		button_up.connect(_ao_soltar)


## Rele o tema — necessario depois de trocar theme_type_variation (abas).
func recarregar_estilo() -> void:
	for estado in ["normal", "hover", "pressed", "hover_pressed"]:
		remove_theme_stylebox_override(estado)

	var repouso := get_theme_stylebox("normal") as StyleBoxFlat
	var hover := get_theme_stylebox("hover") as StyleBoxFlat
	if repouso == null:
		return

	_cor_repouso = repouso.bg_color
	_cor_hover = hover.bg_color if hover != null else repouso.bg_color

	_caixa = repouso.duplicate()
	for estado in ["normal", "hover", "pressed", "hover_pressed"]:
		add_theme_stylebox_override(estado, _caixa)

	match estado_forcado:
		Estado.HOVER:
			_caixa.bg_color = _cor_hover
			_congelar()
		Estado.ATIVO:
			modulate.a = FlatUiTokens.OPACIDADE_ATIVO
			_congelar()


func _congelar() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE


func _ao_entrar_mouse() -> void:
	_animar_fill(_cor_hover)


func _ao_sair_mouse() -> void:
	_animar_fill(_cor_repouso)


func _ao_pressionar() -> void:
	_pressionado_por_mouse = get_viewport().gui_get_focus_owner() == self \
			and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	_animar_opacidade(FlatUiTokens.OPACIDADE_ATIVO)


func _ao_soltar() -> void:
	_animar_opacidade(1.0)
	if _pressionado_por_mouse:
		release_focus()
	_pressionado_por_mouse = false


func _animar_fill(cor: Color) -> void:
	if _caixa == null:
		return
	if _tween_fill and _tween_fill.is_valid():
		_tween_fill.kill()
	_tween_fill = create_tween()
	_tween_fill.set_trans(Tween.TRANS_LINEAR)
	_tween_fill.tween_property(_caixa, "bg_color", cor, FlatUiTokens.DUR_ESTADO)


func _animar_opacidade(alvo: float) -> void:
	if _tween_opacidade and _tween_opacidade.is_valid():
		_tween_opacidade.kill()
	_tween_opacidade = create_tween()
	_tween_opacidade.set_trans(Tween.TRANS_LINEAR)
	_tween_opacidade.tween_property(self, "modulate:a", alvo, FlatUiTokens.DUR_ESTADO)
