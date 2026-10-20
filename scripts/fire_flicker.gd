extends OmniLight3D

@export var base_energy: float = 2.4
@export var flicker_speed: float = 14.0
@export var noise_amplitude: float = 0.6

var time_passed: float = 0.0

func _process(delta: float) -> void:
	time_passed += delta * flicker_speed
	var noise = sin(time_passed) * 0.5 + sin(time_passed * 1.7) * 0.3 + sin(time_passed * 2.9) * 0.2
	light_energy = base_energy + noise * noise_amplitude
