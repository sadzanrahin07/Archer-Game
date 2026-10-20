extends AudioStreamPlayer3D

func _ready() -> void:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	autoplay = true
	if not playing:
		play()

func _process(_delta: float) -> void:
	if not playing:
		play()
