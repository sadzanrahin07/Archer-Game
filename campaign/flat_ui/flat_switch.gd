class_name FlatUiSwitch
extends BaseButton
## Switch chapado (.sw-in + .sw-lbl).
##
## Trilho 56x30 com raio pill; botao de 22px em top:4 left:4 que desliza 26px
## com transform:translateX(26px) em 0.12s linear. Desligado: trilho chip
## (hover chip-hi) e botao na cor screen. Ligado: trilho moss (hover #3ac7a9)
## e botao branco. O anel de foco repete outline:3px gold / offset 3px.

const LARGURA := 56
const ALTURA := 30
const BOTAO := 22
const BORDA := 4
const CURSO := 26

var _caixa_trilho := FlatUiTokens.caixa(FlatUiTokens.CHIP, FlatUiTokens.R_PILL)
var _caixa_botao := FlatUiTokens.caixa(FlatUiTokens.SCREEN, FlatUiTokens.R_PILL)
var _caixa_foco: StyleBoxFlat
var _deslocamento := 0.0:
	set(valor):
		_deslocamento = valor
		queue_redraw()
var _sob_mouse := false
var _tween: Tween


func _init() -> void:
	toggle_mode = true
	custom_minimum_size = Vector2(LARGURA, ALTURA)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	_caixa_foco = StyleBoxFlat.new()
	_caixa_foco.draw_center = false
	_caixa_foco.border_color = FlatUiTokens.GOLD
	_caixa_foco.set_border_width_all(FlatUiTokens.FOCO_LARGURA)
	_caixa_foco.set_corner_radius_all(FlatUiTokens.R_PILL)
	_caixa_foco.corner_detail = 16
	_caixa_foco.anti_aliasing = true
	_caixa_foco.anti_aliasing_size = 1.0


func _ready() -> void:
	_deslocamento = CURSO if button_pressed else 0.0
	_aplicar_cores(false)
	toggled.connect(_ao_alternar)
	mouse_entered.connect(_ao_entrar_mouse)
	mouse_exited.connect(_ao_sair_mouse)


func _draw() -> void:
	draw_style_box(_caixa_trilho, Rect2(0.0, 0.0, LARGURA, ALTURA))
	draw_style_box(_caixa_botao, Rect2(BORDA + _deslocamento, BORDA, BOTAO, BOTAO))
	if has_focus():
		var margem := float(FlatUiTokens.FOCO_OFFSET + FlatUiTokens.FOCO_LARGURA)
		draw_style_box(_caixa_foco, Rect2(
			-margem, -margem, LARGURA + margem * 2.0, ALTURA + margem * 2.0))


func _ao_alternar(ligado: bool) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_LINEAR)
	_tween.set_parallel(true)
	_tween.tween_property(self, "_deslocamento", CURSO if ligado else 0.0,
			FlatUiTokens.DUR_ESTADO)
	_tween.tween_property(_caixa_trilho, "bg_color", _cor_trilho(), FlatUiTokens.DUR_ESTADO)
	_tween.tween_property(_caixa_botao, "bg_color",
			FlatUiTokens.WHITE if ligado else FlatUiTokens.SCREEN, FlatUiTokens.DUR_ESTADO)


func _ao_entrar_mouse() -> void:
	_sob_mouse = true
	_aplicar_cores(true)


func _ao_sair_mouse() -> void:
	_sob_mouse = false
	_aplicar_cores(true)


func _aplicar_cores(animado: bool) -> void:
	_caixa_botao.bg_color = FlatUiTokens.WHITE if button_pressed else FlatUiTokens.SCREEN
	if not animado:
		_caixa_trilho.bg_color = _cor_trilho()
		queue_redraw()
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_LINEAR)
	_tween.tween_property(_caixa_trilho, "bg_color", _cor_trilho(), FlatUiTokens.DUR_ESTADO)


func _cor_trilho() -> Color:
	if button_pressed:
		return FlatUiTokens.MOSS_HI if _sob_mouse else FlatUiTokens.MOSS
	return FlatUiTokens.CHIP_HI if _sob_mouse else FlatUiTokens.CHIP


func _notification(qual: int) -> void:
	if qual == NOTIFICATION_FOCUS_ENTER or qual == NOTIFICATION_FOCUS_EXIT:
		queue_redraw()
