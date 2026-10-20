class_name FlatUiEntrada
extends Container
## Envelope de um bloco da prancha para a animacao de entrada.
##
## Anima fade + deslocamento vertical do conteudo. O deslocamento nao pode ser
## feito na propriedade position do filho: quem manda na posicao de um filho de
## Container e o proprio Container, e qualquer re-ordenacao (troca de fonte,
## textura importada, redimensionamento) desfaria o tween. Aqui o
## deslocamento e a propria variavel usada no sort, entao sobrevive a tudo.

const DESLOCAMENTO_INICIAL := 16.0
const DURACAO := 0.34
const ATRASO_POR_BLOCO := 0.06

var deslocamento := 0.0:
	set(valor):
		deslocamento = valor
		queue_sort()


func _notification(qual: int) -> void:
	if qual != NOTIFICATION_SORT_CHILDREN:
		return
	for filho in get_children():
		var controle := filho as Control
		if controle == null or not controle.visible:
			continue
		fit_child_in_rect(controle, Rect2(0.0, deslocamento, size.x, size.y))


func _get_minimum_size() -> Vector2:
	var minimo := Vector2.ZERO
	for filho in get_children():
		var controle := filho as Control
		if controle == null or not controle.visible:
			continue
		minimo = minimo.max(controle.get_combined_minimum_size())
	return minimo


## Prepara o bloco escondido; chame animar() depois, com o atraso do bloco.
func preparar() -> void:
	modulate.a = 0.0
	deslocamento = DESLOCAMENTO_INICIAL


func animar(atraso: float) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, DURACAO) \
			.set_delay(atraso).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(self, "deslocamento", 0.0, DURACAO) \
			.set_delay(atraso).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
