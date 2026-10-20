extends Camera3D

@export var move_speed: float = 14.0
@export var sprint_factor: float = 2.2
@export var mouse_sensitivity: float = 0.003

var is_moving_free: bool = false
var yaw: float = 0.0
var pitch: float = 0.0
var right_mouse_down: bool = false

# Target transforms for smooth camera transitions
var target_pos: Vector3
var target_rot: Vector3
var is_transitioning: bool = false

# Preset Camera Views matching reference images perfectly
var presets = {
	1: { # Campsite View (Tent, Campfire, Benches)
		"pos": Vector3(-0.6, 5.2, 18.5),
		"rot": Vector3(-7.0, 10.0, 0.0)
	},
	2: { # Panoramic Lake & Mountain Vista
		"pos": Vector3(10.0, 5.0, 5.0),
		"rot": Vector3(-7.1, -165.6, 0.0)
	},
	3: { # Wooden Pier & Shoreline
		"pos": Vector3(5.5, 2.2, -3.5),
		"rot": Vector3(-9.0, -145.0, 0.0)
	},
	4: { # High Mountain Overlook
		"pos": Vector3(0.0, 24.0, 32.0),
		"rot": Vector3(-28.0, 0.0, 0.0)
	}
}

func _ready() -> void:
	target_pos = presets[1]["pos"]
	target_rot = presets[1]["rot"]
	global_position = target_pos
	rotation_degrees = target_rot
	yaw = deg_to_rad(target_rot.y)
	pitch = deg_to_rad(target_rot.x)
	create_onscreen_ui()

func apply_preset(index: int) -> void:
	if not presets.has(index):
		return
	is_moving_free = false
	is_transitioning = true
	var p = presets[index]
	target_pos = p["pos"]
	target_rot = p["rot"]
	yaw = deg_to_rad(p["rot"].y)
	pitch = deg_to_rad(p["rot"].x)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			right_mouse_down = event.pressed
			is_moving_free = true
			is_transitioning = false
			if right_mouse_down:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				
	if right_mouse_down and event is InputEventMouseMotion:
		yaw -= event.relative.x * mouse_sensitivity
		pitch = clamp(pitch - event.relative.y * mouse_sensitivity, -deg_to_rad(85), deg_to_rad(85))
		rotation = Vector3(pitch, yaw, 0.0)

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			apply_preset(1)
		elif event.keycode == KEY_2:
			apply_preset(2)
		elif event.keycode == KEY_3:
			apply_preset(3)
		elif event.keycode == KEY_4:
			apply_preset(4)
		elif event.keycode == KEY_ESCAPE:
			right_mouse_down = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	if is_transitioning:
		global_position = global_position.lerp(target_pos, delta * 4.0)
		rotation_degrees = rotation_degrees.lerp(target_rot, delta * 4.0)
		if global_position.distance_to(target_pos) < 0.05:
			global_position = target_pos
			rotation_degrees = target_rot
			is_transitioning = false
			
	var dir = Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		dir -= transform.basis.z
	if Input.is_key_pressed(KEY_S):
		dir += transform.basis.z
	if Input.is_key_pressed(KEY_A):
		dir -= transform.basis.x
	if Input.is_key_pressed(KEY_D):
		dir += transform.basis.x
	if Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_E):
		dir += Vector3.UP
	if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_Q):
		dir -= Vector3.UP
	
	if dir != Vector3.ZERO:
		is_transitioning = false
		var speed = move_speed
		if Input.is_key_pressed(KEY_SHIFT):
			speed *= sprint_factor
		global_position += dir.normalized() * speed * delta

func create_onscreen_ui() -> void:
	var canvas = CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)
	
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 20
	panel.offset_right = -20
	panel.offset_top = 15
	panel.offset_bottom = 65
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.16, 0.75)
	style.set_corner_radius_all(10)
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(panel)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	panel.add_child(hbox)
	
	var title = Label.new()
	title.text = "STYLIZED MAP VIEWER:"
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	hbox.add_child(title)
	
	var btn1 = Button.new()
	btn1.text = "1. Campsite View"
	btn1.pressed.connect(func(): apply_preset(1))
	hbox.add_child(btn1)
	
	var btn2 = Button.new()
	btn2.text = "2. Panoramic Lake & Mountain"
	btn2.pressed.connect(func(): apply_preset(2))
	hbox.add_child(btn2)
	
	var btn3 = Button.new()
	btn3.text = "3. Wooden Pier & Shore"
	btn3.pressed.connect(func(): apply_preset(3))
	hbox.add_child(btn3)
	
	var btn4 = Button.new()
	btn4.text = "4. Mountain Vista Overlook"
	btn4.pressed.connect(func(): apply_preset(4))
	hbox.add_child(btn4)
	
	var help_label = Label.new()
	help_label.text = "Controls: Click buttons above, or press [1]-[4]. Hold [Right Mouse] + [W,A,S,D] to fly around freely! [Shift]=Sprint, [Space]=Up, [Ctrl]=Down"
	help_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	help_label.offset_bottom = -15
	help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	help_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	help_label.add_theme_constant_override("shadow_offset_x", 1)
	help_label.add_theme_constant_override("shadow_offset_y", 1)
	canvas.add_child(help_label)
