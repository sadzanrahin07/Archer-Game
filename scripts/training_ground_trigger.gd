extends StaticBody3D

var is_player_inside: bool = false
var is_active: bool = false

@onready var prompt_lbl: Label3D = $PromptLabel
@onready var trigger_area: Area3D = $TriggerArea
var mannequin: Node = null
var snd_gong: AudioStreamPlayer3D = null

func _ready() -> void:
	if trigger_area:
		trigger_area.body_entered.connect(_on_body_entered)
		trigger_area.body_exited.connect(_on_body_exited)
		
	snd_gong = AudioStreamPlayer3D.new()
	snd_gong.name = "SndGong"
	var gong_path = "res://Sound effects/musicholder-sword-sound-260274.mp3"
	snd_gong.stream = load(gong_path) if ResourceLoader.exists(gong_path) else load("res://sounds/target_hit.wav")
	snd_gong.unit_size = 15.0
	snd_gong.max_distance = 80.0
	add_child(snd_gong)
	
	_update_prompt()

func _find_mannequin() -> void:
	if not mannequin:
		mannequin = get_parent().find_child("SparringMannequin", true, false)
		if not mannequin:
			var mann_list = get_tree().get_nodes_in_group("TrainingMannequin")
			if mann_list.size() > 0:
				mannequin = mann_list[0]

func _unhandled_input(event: InputEvent) -> void:
	if not is_player_inside:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			toggle_training()

func toggle_training() -> void:
	_find_mannequin()
	if not mannequin:
		return
		
	is_active = not is_active
	if mannequin.has_method("set_training_active"):
		mannequin.set_training_active(is_active)
		
	if snd_gong and snd_gong.stream:
		snd_gong.pitch_scale = 0.85 if is_active else 1.35
		snd_gong.play()
		
	_update_prompt()

func _update_prompt() -> void:
	if not prompt_lbl:
		return
	if is_active:
		prompt_lbl.text = "[E] END TRAINING SESSION"
		prompt_lbl.modulate = Color(1.0, 0.4, 0.3)
	else:
		prompt_lbl.text = "[E] START TRAINING SESSION"
		prompt_lbl.modulate = Color(1.0, 0.88, 0.25)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player") or "Player" in body.name:
		is_player_inside = true
		if prompt_lbl:
			prompt_lbl.visible = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("Player") or "Player" in body.name:
		is_player_inside = false
