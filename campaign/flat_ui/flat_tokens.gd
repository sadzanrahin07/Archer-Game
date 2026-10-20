class_name FlatUiTokens
extends RefCounted
## Tokens do UI kit "Flat UI Kit" — cores, escala de espacamento e raios.
##
## Valores copiados um a um do bloco :root da prancha de componentes HTML/CSS
## de referencia. Nada aqui e arredondado ou reinterpretado: se um numero
## mudar, a prancha deixa de ser identica.

# ---------------------------------------------------------------- terrenos
const INK := Color("1b1d33")
const SCREEN := Color("21243d")
const PANEL := Color("2f3550")
const CHIP := Color("454d70")
const CHIP_HI := Color("535c85")
const SLATE := Color("8a90b4")
const LINE := Color("151729")

# ---------------------------------------------------------------- modern action style
const ACTION_MINT := Color("2ee89a")
const ACTION_MINT_HI := Color("45f5a8")
const ACTION_MINT_DARK := Color("1dbd7a")
const ACTION_CYAN := Color("38bdf8")
const ACTION_CYAN_HI := Color("7dd3fc")
const ACTION_BG := Color("0c1017")
const ACTION_CARD := Color(0.06, 0.09, 0.15, 0.94)
const ACTION_CARD_BORDER := Color(0.18, 0.28, 0.38, 0.75)
const ACTION_GLOW_MINT := Color(0.18, 0.91, 0.60, 0.9)
const ACTION_GLOW_CYAN := Color(0.22, 0.74, 0.97, 0.85)

# ---------------------------------------------------------------- acentos
const ORANGE := Color("f0a03c")
const BLUE := Color("4a72d8")
const AQUA := Color("4fb0e8")
const MINT := Color("4ec9c0")
const MOSS := Color("2eb195")
const CORAL := Color("e8465e")
const GOLD := Color("ffc94d")
const WHITE := Color("ffffff")
const DIM := Color("b9beda")

# hover de cada acento (fill mais claro, valores literais do CSS)
const ORANGE_HI := Color("ffb256")
const BLUE_HI := Color("5f86ec")
const MINT_HI := Color("67dbd2")
const MOSS_HI := Color("3ac7a9")
const CORAL_HI := Color("fb5a71")
const SLATE_HI := Color("9ba1c4")

# cores pontuais que o CSS declara inline
const ON_MINT := Color("123c39")  # texto sobre mint
const ON_ORANGE := Color("2b1a05")  # glifo sobre laranja (marca, art chip)
const ON_GOLD := Color("4a3400")  # glifo sobre dourado (reward coin)
const RIBBON_TAIL := Color("1f8672")  # cauda da fita, um passo abaixo do moss
const DISABLED_TEXT := Color("767ea6")
const STAR_EMPTY := Color("5b6390")  # estrela vazia em no de nivel concluido
const STAR_EMPTY_NOW := Color("7a4a10")  # estrela vazia sobre o no atual
const LOCK_TEXT := Color("6b7299")
const TILE_HOVER := Color("394060")
const DIM_BACKDROP := Color(0.058824, 0.062745, 0.117647, 0.72)  # rgba(15,16,30,.72)
const TAG_BG := Color(0.180392, 0.694118, 0.584314, 0.14)  # rgba(46,177,149,.14)
const SHADOW := Color(0.0, 0.0, 0.0, 0.18)  # 0 2px 0 rgba(0,0,0,.18)

# ------------------------------------------------------ espacamento e raio
const S1 := 4
const S2 := 8
const S3 := 12
const S4 := 16
const S5 := 24
const S6 := 32
const S7 := 48

const R_SM := 6
const R_MD := 10
const R_LG := 14
const R_PILL := 999

# ------------------------------------------------------------- transicoes
const DUR_ESTADO := 0.12  # transition:... .12s linear
const OPACIDADE_ATIVO := 0.78  # :active{opacity:.78}
const FOCO_LARGURA := 3
const FOCO_OFFSET := 3


static func caixa(cor: Color, raio: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = cor
	sb.set_corner_radius_all(raio)
	# corner_detail padrao (8) deixa o arco de 14px visivelmente facetado
	sb.corner_detail = 16
	sb.anti_aliasing = true
	sb.anti_aliasing_size = 1.0
	return sb
