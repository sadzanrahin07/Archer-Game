extends Control

const SPLASH_VIDEO_PATH := "res://assets/splash/splash_screen.ogv"
const INTRO_VIDEO_PATH := "res://assets/splash/sadzan_rahin_intro.ogv"
const LOBBY_SCENE_PATH := "res://campaign/main.tscn"

@onready var background: ColorRect = $Background
@onready var video_player: VideoStreamPlayer = $VideoPlayer
@onready var skip_button: Button = $SkipButton
@onready var fade_rect: ColorRect = $FadeRect

var current_index := 0
var is_transitioning := false
var video_watchdog_timer := 0.0
const VIDEO_TIMEOUTS: Array[float] = [10.0, 6.0]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Configure layout
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if background:
		background.set_anchors_preset(Control.PRESET_FULL_RECT)
		background.color = Color.BLACK
	
	if fade_rect:
		fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		fade_rect.color = Color.BLACK
		fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fade_rect.modulate.a = 0.0
		
	if video_player:
		video_player.set_anchors_preset(Control.PRESET_FULL_RECT)
		video_player.expand = true
		video_player.loop = false
		video_player.buffering_msec = 500
		video_player.finished.connect(_on_video_finished)
	
	if skip_button:
		skip_button.pressed.connect(_on_skip_pressed)
		# Style the skip button nicely
		skip_button.focus_mode = Control.FOCUS_NONE
	
	# Start sequence
	_play_video(0)

func _play_video(index: int) -> void:
	current_index = index
	video_watchdog_timer = 0.0
	
	var video_path := ""
	if index == 0:
		video_path = SPLASH_VIDEO_PATH
	elif index == 1:
		video_path = INTRO_VIDEO_PATH
	else:
		_go_to_lobby()
		return
	
	if not ResourceLoader.exists(video_path):
		push_warning("Splash video missing at: %s" % video_path)
		_next_step()
		return
		
	var stream := load(video_path) as VideoStream
	if stream:
		video_player.stream = stream
		video_player.play()
	else:
		push_warning("Failed to load stream: %s" % video_path)
		_next_step()

func _process(delta: float) -> void:
	if is_transitioning:
		return
	
	video_watchdog_timer += delta
	var max_time := 12.0
	if current_index >= 0 and current_index < VIDEO_TIMEOUTS.size():
		max_time = VIDEO_TIMEOUTS[current_index]
	
	# Watchdog: ensure video does not stall indefinitely
	if video_watchdog_timer >= max_time:
		_on_video_finished()

func _unhandled_input(event: InputEvent) -> void:
	if is_transitioning:
		return
	
	# Advance on tap / click / key press
	if event is InputEventScreenTouch and event.pressed:
		_next_step()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_next_step()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
			_next_step()

func _on_video_finished() -> void:
	if is_transitioning:
		return
	_next_step()

func _next_step() -> void:
	if is_transitioning:
		return
	
	if current_index == 0:
		# Move from Splash Screen video to Sadzan Rahin intro
		_play_video(1)
	else:
		# Sequence finished, go to Lobby
		_go_to_lobby()

func _on_skip_pressed() -> void:
	# Clicking skip button immediately proceeds to lobby
	_go_to_lobby()

func _go_to_lobby() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	
	if video_player and video_player.is_playing():
		video_player.stop()
	
	# Smooth fade out before loading lobby
	if fade_rect:
		var tween := create_tween()
		tween.tween_property(fade_rect, "modulate:a", 1.0, 0.25)
		tween.tween_callback(_change_to_lobby_scene)
	else:
		_change_to_lobby_scene()

func _change_to_lobby_scene() -> void:
	var err := get_tree().change_scene_to_file(LOBBY_SCENE_PATH)
	if err != OK:
		push_error("Failed to switch to lobby scene: %d" % err)
