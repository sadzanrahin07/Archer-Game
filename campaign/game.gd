extends Node3D

const Profile = preload("res://campaign/profile.gd")
const Catalog = preload("res://campaign/catalog.gd")
const Player = preload("res://campaign/player.gd")
const MenuUI = preload("res://campaign/menu_ui.gd")
const FinalShotDirector = preload("res://campaign/final_shot_director.gd")
const TouchControls = preload("res://campaign/touch_controls.gd")
var profile = Profile.new()
var definitions: Array = []
var backdrop: Node3D
var menu_course: Node3D
var hero: CharacterBody3D
var menu_camera: Camera3D
var stage: Node3D
var current_definition: Dictionary = {}
var ui: Control
var layer: CanvasLayer
var page := "home"
var state := "menu"
var current_chapter := 1
var selected_chapter := 0
var selected_stage := 0
var time_left := 0.0
var ready_left := 3.0
var arrows := 0
var shots := 0
var hits := 0
var centers := 0
var best_zone := 0
var completed := 0
var airborne := 0
var precision_sum := 0.0
var minimum_arrows := 1
var max_thread_chain:=0
var focus_meter := 100.0
var power_timers:Dictionary={}
var power_global_lock:=0.0
var secondary_damage:=false
var current_hit_actor_id:=0
var focus_targets:Dictionary={}
var pending_damage_count:=0
var selected_power := "normal"
var power_cooldown := 0.0
var power_armed := false
var power_charge_source := ""
var ultimate_used := false
var burst_used := false
var super_used := false
var shop_mode := "store"
var preview_item := -1
var shot_serial := 0
var current_shot_id := ""
var credited_shots:Dictionary = {}
var focus_volley:Dictionary = {}
var last_hit_position := Vector3.ZERO
var final_director:Node
var pending_result:Dictionary = {}
var result_sequence:=0
var run_transaction := ""
var prior_pause_state := "playing"
var impact_sound_count := 0
var draw_amount := 0.0
var practice := false
var message := ""
var message_time := 0.0
var dragging := false
var drag_distance := 0.0
var hud_timer: Label
var hud_objective: Label
var hud_ammo: Label
var hud_message: Label
var hud_draw: ProgressBar
var last_tick := -1
var focus_material: ShaderMaterial
var hud_ready: Label
var combat_hud: Control
var music: AudioStreamPlayer
var ambience: AudioStreamPlayer
var inventory_tab := "bow"
var gear_preview: Node3D
var test_mode := false
var menu_builder:RefCounted
var ui_scale:=1.0
var safe_margins:=Vector4(18,18,18,18)
var touch_layer:CanvasLayer
var touch_controller:Control
var last_result:Dictionary={}
var hud_cross:Label
var layout_queued:=false
const GOLD := Color("f5f8f6")
const IVORY := Color("f1f6f3")
const MUTED := Color("ccd8d1")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("Arrowglade ",ProjectSettings.get_setting("application/config/version","development")," · Combat revision 4")
	process_physics_priority = 100
	test_mode = test_mode or "--campaign-test" in OS.get_cmdline_user_args()
	if not test_mode: profile.load_profile()
	else:profile.save_path="/tmp/arrowglade-runtime-qa.json"
	definitions = JSON.parse_string(FileAccess.get_file_as_string("res://campaign/stages.json"))
	selected_stage = int(profile.data.selected)
	selected_chapter = selected_stage / 5
	if selected_power == "normal" or not profile.power_is_unlocked(selected_power):
		var best_pwr: String = profile.selected_power()
		if best_pwr != "normal": selected_power = best_pwr
	backdrop = load("res://campaign/forest_backdrop.tscn").instantiate()
	backdrop.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(backdrop)
	backdrop.get_node("Props/Campfire").position.x = -4.5
	var old_range := backdrop.get_node_or_null("ArcheryShootingRanges")
	if old_range: backdrop.remove_child(old_range); old_range.free()
	var podium := MeshInstance3D.new()
	var podium_mesh := CylinderMesh.new()
	podium_mesh.top_radius = 1.15
	podium_mesh.bottom_radius = 1.35
	podium_mesh.height = 0.25
	podium.mesh = podium_mesh
	var podium_mat := StandardMaterial3D.new()
	podium_mat.albedo_color = Color("757d65")
	podium_mat.roughness = 0.95
	podium.material_override = podium_mat
	podium.position = Vector3(0, 5.625, 16.5)
	podium.name = "ShowcasePodium"
	add_child(podium)
	var environment := backdrop.get_node("WorldEnvironment") as WorldEnvironment
	environment.environment = environment.environment.duplicate()
	environment.environment.tonemap_exposure = 0.65
	environment.environment.ambient_light_energy = 0.65
	environment.environment.glow_bloom = 0.0
	menu_camera = Camera3D.new()
	menu_camera.fov = 38
	menu_camera.near = 0.05
	add_child(menu_camera)
	menu_camera.position = Vector3(0, 7.0, 20.5)
	menu_camera.look_at(Vector3(0, 6.55, 16.5))
	layer = CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	ui.theme = _theme()
	_update_layout_metrics()
	get_viewport().size_changed.connect(_queue_layout)
	touch_layer=CanvasLayer.new();touch_layer.layer=30;add_child(touch_layer)
	touch_controller=TouchControls.new();touch_controller.game=self;touch_layer.add_child(touch_controller)
	_layout_touch_controller()
	_setup_music()
	for node in backdrop.find_children("*","AudioStreamPlayer3D",true,false):node.bus="Ambience"
	for node in backdrop.find_children("*","AudioStreamPlayer",true,false):node.bus="Ambience"
	ambience = AudioStreamPlayer.new()
	ambience.stream = load("res://campaign/audio/soul_serenity_sounds-field_softgrassandgentlebreeze-337196.mp3")
	ambience.volume_db = -20
	ambience.bus="Ambience"
	add_child(ambience)
	ambience.finished.connect(ambience.play)
	ambience.play()
	var wind_audio := AudioStreamPlayer.new()
	wind_audio.stream = load("res://campaign/audio/soul_serenity_sounds-distant-breeze-241047.mp3")
	wind_audio.volume_db = -24
	wind_audio.bus="Ambience"
	add_child(wind_audio)
	wind_audio.finished.connect(wind_audio.play)
	wind_audio.play()
	_apply_settings()
	_spawn_hero()
	final_director=FinalShotDirector.new();final_director.game=self;add_child(final_director)
	show_home()
	if "--capture-home" in OS.get_cmdline_user_args(): _capture_later()
	if "--campaign-test" in OS.get_cmdline_user_args(): _run_smoke.call_deferred()

func _theme() -> Theme:
	var theme := Theme.new()
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = 0.35
	theme.default_font = font
	theme.default_font_size = 22
	theme.set_color("font_color", "Label", IVORY)
	theme.set_color("font_color", "Button", IVORY)
	theme.set_color("font_hover_color", "Button", GOLD)
	theme.set_color("font_disabled_color","Button",Color("bfccc4"))
	theme.set_color("font_outline_color","Button",Color(0.01,0.025,0.02,0.6))
	theme.set_constant("outline_size","Button",1)
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := _box(Color(0.025,0.10,0.075,0.88), Color(0.8,1,0.9,0.48))
		if style_name in ["hover", "focus", "pressed"]: box.border_color = GOLD; box.bg_color = Color(0.14,0.29,0.22,0.95)
		if style_name == "disabled": box.bg_color = Color(0.065,0.12,0.095,0.72)
		theme.set_stylebox(style_name, "Button", box)
	return theme

func _box(color: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box

func _rect(control: Control, x: float, y: float, w: float, h: float) -> void:
	control.position = Vector2(x, y)
	control.size = Vector2(w, h)

func _label(text: String, x: float, y: float, w: float, h: float, size_value: int = 18, color: Color = IVORY) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.01,0.025,0.02,0.70))
	label.add_theme_constant_override("outline_size", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect(label, x, y, w, h)
	ui.add_child(label)
	return label

func _button(text: String, x: float, y: float, w: float, h: float, action: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	_rect(button, x, y, w, h)
	if primary:
		button.add_theme_stylebox_override("normal", _box(Color(0.8,0.9,0.85,0.18), GOLD))
		button.add_theme_color_override("font_color", IVORY)
	button.pressed.connect(func(): play_sound("res://campaign/audio/click.mp3"); action.call_deferred())
	ui.add_child(button)
	return button

func _panel(x: float, y: float, w: float, h: float) -> Panel:
	var panel := Panel.new()
	_rect(panel, x, y, w, h)
	panel.add_theme_stylebox_override("panel", _box(Color(0.06,0.19,0.15,0.28), Color(0.9,1,0.95,0.15)))
	var frost:=ShaderMaterial.new()
	frost.shader=load("res://campaign/glass.gdshader")
	panel.material=frost
	ui.add_child(panel)
	return panel

func _clear_ui() -> void:
	if is_instance_valid(gear_preview):
		remove_child(gear_preview); gear_preview.queue_free(); gear_preview = null
	if is_instance_valid(hero): hero.visible = true
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	hud_timer = null
	hud_ready = null
	combat_hud = null
	hud_draw = null
	focus_material = null
	dragging = false

func _header(title: String, back_action: Callable = show_home) -> void:
	_button("‹  Back", 32, 28, 110, 44, back_action)
	_label(title, 162, 28, 660, 50, 30)
	_label("%d coins   ·   %s Lv. %d" % [profile.data.coins, _character_name(), profile.level()], 950, 30, 300, 40, 17, GOLD)

var preview_character := -1
var preview_costume := -1

func _spawn_hero() -> void:
	if is_instance_valid(hero): remove_child(hero); hero.queue_free()
	var id := preview_character if preview_character>=0 else int(profile.data.character)
	var model_id: String = Catalog.CHARACTERS[id].model
	if id == 1: model_id = Catalog.COSTUMES[preview_costume if preview_costume>=0 else int(profile.data.costume)].model
	hero = Player.new()
	var user_scenes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://campaign/characters/user-scenes.json"))
	hero.model_path = "res://"+str(user_scenes[model_id]) if user_scenes.has(model_id) else "res://campaign/characters/"+model_id+".scn"
	hero.character_id = id
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://campaign/characters/manifest.json"))
	hero.bone_names = manifest["3675109917025159411" if id == 0 else model_id].bones
	hero.game = self
	hero.position = Vector3(0,5.75,16.5)
	hero.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(hero)
	hero.visuals.rotation.y = PI
	hero.set_showcase(true)
	menu_camera.current = true

func _cycle_character(direction:int=1) -> void:
	var owned: Array = profile.data.owned_characters
	if owned.size() <= 1: return
	_choose_character(int(owned[posmod(owned.find(int(profile.data.character))+direction,owned.size())]))

func show_home() -> void:
	if preview_character>=0 or preview_costume>=0:
		preview_character=-1;preview_costume=-1;_spawn_hero()
	if is_instance_valid(final_director):final_director.cancel()
	pending_result.clear()
	power_armed=false;power_charge_source=""
	if not test_mode:selected_stage=profile.run_selected_stage();selected_chapter=selected_stage/5
	_set_backdrop_playing(false)
	get_node("ShowcasePodium").visible = true
	get_tree().paused = false
	state = "menu"
	page = "home"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(stage): remove_child(stage); stage.queue_free(); stage = null
	hero.position = Vector3(0, 5.75, 16.5)
	hero.set_showcase(true)
	hero.visuals.rotation.y = PI
	menu_camera.position = Vector3(0, 7, 20.5)
	menu_camera.look_at(Vector3(0, 6.55, 16.5))
	menu_camera.current = true
	_set_environment(0)
	_clear_ui()
	menu_builder=MenuUI.new(self);menu_builder.home()

func _character_name() -> String:
	return Catalog.CHARACTERS[int(profile.data.character)].name

func _choose_character(id: int) -> void:
	if not profile.data.owned_characters.has(id):
		if not profile.buy_character(id): return
	if not profile.equip_character(id):return
	selected_power=profile.selected_power()
	if not test_mode: profile.save_profile()
	_spawn_hero()
	if page == "characters": show_characters()
	else: show_home()

func show_characters(keep_preview: bool = false) -> void:
	selected_power=profile.selected_power()
	if not keep_preview and page != "characters":
		if preview_character>=0 or preview_costume>=0:
			preview_character=-1;preview_costume=-1;_spawn_hero()
	page="characters"
	menu_builder=MenuUI.new(self);menu_builder.characters()

func show_levels() -> void:
	page="levels"
	menu_builder=MenuUI.new(self);menu_builder.levels()

func _objective_text(def: Dictionary) -> String:
	if def.has("objective_text"):return str(def.objective_text)
	if def.has("encounter_hint"):return str(def.encounter_hint)
	if def.mode == "precision": return "Hit the target from %d meters in 10 seconds." % def.distance
	if bool(def.get("roaming",false)):return "Roam the trail · Clear targets in order · Reach and break the final rune stone"
	if def.mode == "ordered": return "Follow the numbered route. Clear %d targets in order." % def.materials.size()
	if def.mode == "destruction": return "Break every target. Aim for the center to deal more damage."
	return "Clear every mark%s." % (" · Moving targets" if def.moving else "")

func show_collection() -> void:
	shop_mode="collection";preview_item=-1;show_inventory()

func show_store() -> void:
	shop_mode="store";preview_item=-1;show_inventory()

func show_inventory() -> void:
	selected_power=profile.selected_power()
	page="inventory"
	menu_builder=MenuUI.new(self);menu_builder.inventory()

func _select_equipment(kind: String,id:int)->void:
	if not profile.buy_equipment(kind,id):return
	if kind=="bow":profile.equip_bow(id)
	else:profile.equip_arrow(id)
	_spawn_hero();show_inventory()

func _show_gear() -> void:
	hero.visible=false
	if is_instance_valid(gear_preview):remove_child(gear_preview);gear_preview.queue_free()
	var id:int=preview_item if preview_item>=0 else int(profile.data["equipped_"+inventory_tab])
	gear_preview=preload("res://campaign/equipment_visual.gd").build(inventory_tab,id)
	gear_preview.position=Vector3(0,6.6,16.5);gear_preview.rotation.z=-.3
	gear_preview.scale=Vector3.ONE*1.15;add_child(gear_preview)
	var fill_light:=OmniLight3D.new()
	fill_light.name="GearFillLight"
	fill_light.position=Vector3(0,0.5,1.8)
	fill_light.light_color=Color("fffbf0")
	fill_light.light_energy=2.0
	fill_light.omni_range=5.0
	gear_preview.add_child(fill_light)
	menu_camera.position=Vector3(0,7,20.5);menu_camera.look_at(Vector3(0,6.6,16.5))

var equipment_cards:Dictionary={}
func equipment_thumbnail(kind:String,id:int) -> Texture2D:
	var key:String=kind+str(id)
	if not equipment_cards.has(key):equipment_cards[key]=preload("res://campaign/equipment_visual.gd").thumbnail(self,kind,id)
	return equipment_cards[key].get_texture()

func open_upgrade(kind:String) -> void:
	if kind=="character":show_characters();return
	inventory_tab=kind;shop_mode="collection";preview_item=int(profile.data["equipped_"+kind]);show_inventory()

func readiness_rows(definition:Dictionary) -> Array:
	var tier:int=int(definition.get("required_tier",0));var gear:int=int(definition.get("required_gear_level",1))
	var needed:int=int(definition.get("required_character_level",1))
	var rows:Array=[]
	var higher:bool=mini(int(Catalog.BOWS[int(profile.data.equipped_bow)].tier_index),int(Catalog.ARROWS[int(profile.data.equipped_arrow)].tier_index))>tier
	rows.append({"kind":"character","name":"Archer","current":profile.level(),"required":needed,"ready":higher or profile.level()>=needed,"tier_ok":true})
	for kind in ["bow","arrow"]:
		var entry:Dictionary=(Catalog.BOWS if kind=="bow" else Catalog.ARROWS)[int(profile.data["equipped_"+kind])]
		var actual:int=int(profile.data[kind+"_level"]);var actual_tier:int=entry.tier_index
		rows.append({"kind":kind,"name":kind.capitalize(),"current":actual,"required":gear,"ready":actual_tier>tier or actual_tier==tier and actual>=gear,"tier_ok":actual_tier>=tier})
	return rows

func show_settings() -> void:
	page="settings"
	menu_builder=MenuUI.new(self);menu_builder.settings()

func _apply_settings() -> void:
	AudioServer.set_bus_volume_db(0,0)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"),not bool(profile.data.settings.get("bg_sound",true)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"),not bool(profile.data.settings.get("game_sound",true)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Ambience"),not bool(profile.data.settings.get("game_sound",true)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"),linear_to_db(float(profile.data.settings.get("bg_volume",0.5))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"),linear_to_db(float(profile.data.settings.get("game_volume",0.7))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambience"),linear_to_db(float(profile.data.settings.get("game_volume",0.7))))
	if not OS.has_feature("android") and not OS.has_feature("ios"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if profile.data.settings.get("fullscreen", false) else DisplayServer.WINDOW_MODE_WINDOWED)

func start_stage(id: int, is_practice: bool = false) -> void:
	if preview_character>=0 or preview_costume>=0:
		preview_character=-1;preview_costume=-1;_spawn_hero()
	if not is_practice and not test_mode:
		var reason:String=profile.get_stage_lock_reason(id)
		if not reason.is_empty():show_levels();feedback(reason);return
		if id==99 and profile.data.power!="ultimate":profile.equip_power("ultimate")
	get_node("ShowcasePodium").visible = false
	if not test_mode and id > int(profile.data.unlocked):
		id = mini(id, int(profile.data.unlocked))
	get_tree().paused = false
	if is_instance_valid(touch_controller):touch_controller.reset()
	if is_instance_valid(final_director):final_director.cancel()
	pending_result.clear()
	id=clampi(id,0,definitions.size()-1)
	if not is_practice and not test_mode:
		profile.start_run(id)
		var requirement:Dictionary=definitions[id]
		var gate:String=loadout_requirement(requirement)
		if not gate.is_empty():
			feedback(gate)
		elif profile.power()<float(requirement.get("required_power",0)):
			feedback("Notice: Recommended power %.1f"%float(requirement.required_power))
		run_transaction=profile.current_run_transaction()+":stage:"+str(id)
		if id%5==0 and not bool(profile.data.get("power_chosen",false)) and profile.data.get("power","normal")=="normal" and profile.power_is_unlocked(str(definitions[id].get("chapter_power","normal"))):profile.equip_power(str(definitions[id].get("chapter_power","normal")))

	selected_stage = id
	if not is_practice:
		profile.data.selected = id
		if not test_mode:profile.save_profile()
	current_definition = definitions[id]
	practice = is_practice
	if is_instance_valid(stage): remove_child(stage); stage.queue_free()
	stage = load(current_definition.scene).instantiate()
	stage.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(stage)
	stage.build(self, current_definition)
	_set_backdrop_playing(true)
	hero.position = stage.spawn
	hero.spawn_point = stage.spawn
	var chapter: int = (id / 5) + 1
	current_chapter = chapter
	hero.stationary = bool(current_definition.get("stationary", false)) or (chapter >= 18 and bool(current_definition.get("sniper", false)))
	hero.set_showcase(false)
	hero.max_hp=profile.max_hp();hero.current_hp=hero.max_hp;hero.is_dodging=false;hero.is_invulnerable=false;hero.dodge_cooldown=0
	_set_environment(id)
	time_left = float(current_definition.get("seconds", 30))
	arrows = 999 if practice else int(current_definition.arrows)
	shots = 0; hits = 0; centers = 0; best_zone = 0; completed = 0; airborne = 0;max_thread_chain=0
	precision_sum=0;credited_shots.clear();focus_volley.clear();focus_meter=100;power_cooldown=0;power_armed=false;ultimate_used=false;burst_used=false;super_used=false
	selected_power=profile.selected_power();minimum_arrows=_minimum_arrow_count()
	power_timers.clear();power_global_lock=0;focus_targets.clear();pending_damage_count=0;power_charge_source=""
	draw_amount = 0
	ready_left = 1.0 if is_practice else 4.0
	last_tick = -1
	state = "ready"
	page = "hud"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if touch_enabled() else Input.MOUSE_MODE_CAPTURED
	_show_hud()

func _set_environment(id:int) -> void:
	var environment:Environment=backdrop.get_node("WorldEnvironment").environment
	var biome:String=str(definitions[id].get("biome","meadow")) if id<definitions.size() else "meadow"
	var cool:bool=biome in ["moonlit","storm","lightning","tempest"]
	var warm:bool=biome in ["ember","golden","crown"]
	environment.fog_density=.008 if cool else (.0022 if biome in ["coast","river","highland"] else .0035)
	environment.fog_light_color=Color("738baf") if cool else (Color("e6d7b4") if warm else Color("bacfd8"))
	environment.glow_enabled=true;environment.glow_intensity=.35;environment.glow_bloom=.04
	environment.ambient_light_energy=.45 if cool else .85
	environment.tonemap_exposure=.7 if cool else .85
	var sky_material:ProceduralSkyMaterial=environment.sky.sky_material
	sky_material.sky_top_color=Color("14213e") if cool else (Color("6e9bad") if warm else Color("529efa"))
	sky_material.sky_horizon_color=Color("526d91") if cool else (Color("e7cda0") if warm else Color("b8dbf5"))
	var sun:DirectionalLight3D=backdrop.get_node("SunLight")
	sun.light_color=Color("a8bce3") if cool else (Color("ffcc8e") if warm else Color("fff2d9"))
	sun.light_energy=.45 if cool else .65;sun.rotation_degrees.x=-45-(id%5)*4

func _show_hud() -> void:
	menu_builder=MenuUI.new(self);menu_builder.hud()
	_layout_touch_controller()

func is_playing() -> bool:
	return state == "playing"

func consume_arrow() -> bool:
	if not is_playing() or arrows <= 0: return false
	arrows -= 1
	shots += 1
	airborne += 1
	return true

func has_available_power() -> bool:
	return arrows>0 and profile.selected_power()!="normal"

func _check_quiver_empty() -> void:
	if not is_playing():return
	if arrows<=0 and is_instance_valid(hero):hero.clear_empty_aim()
	if practice:return
	if is_combat():return
	if arrows<=0 and airborne==0 and pending_damage_count==0 and completed<current_definition.materials.size():finish(false,"Quiver empty")

func arrow_resolved() -> void:
	airborne = maxi(0, airborne - 1)
	_check_quiver_empty()

func target_scored(zone:int,damage:float,_destructible:bool) -> void:
	if secondary_damage:return
	var release:String=current_shot_id.get_slice(":arrow:",0)
	if credited_shots.has(release):return
	credited_shots[release]=true;hits+=1;precision_sum+=[.3,.6,.8,1.0][zone]
	if not focus_targets.has(current_hit_actor_id):
		focus_targets[current_hit_actor_id]=true;focus_meter=minf(100,focus_meter+(8 if zone==3 else 4))
	if zone==3:centers+=1
	feedback("%s · %.1f damage"%[("Weak spot" if zone==3 else "Creature hit") if is_combat() else ["WHITE","BLUE","RED","CENTER"][zone],damage])

func target_completed(index: int) -> void:
	completed += 1
	if str(current_definition.get("mode", "precision")) == "ordered" and index + 1 < stage.targets.size(): stage.targets[index + 1].set_active(true)
	if is_instance_valid(stage) and is_instance_valid(stage.combat_manager):
		stage.combat_manager.on_target_completed(index)
		return
	if completed >= current_definition.get("materials", []).size() and not current_definition.get("materials", []).is_empty(): finish(true, "Challenge complete")

func feedback(text: String) -> void:
	message = text
	message_time = 2.0

func play_sound(path: String, pitch: float = 1.0, volume: float = -7.0) -> void:
	if not is_inside_tree() or not ResourceLoader.exists(path): return
	var sound := AudioStreamPlayer.new()
	sound.stream = load(path)
	sound.pitch_scale = pitch
	sound.volume_db = volume
	sound.bus = "SFX"
	add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()

func play_stream(path: String, pitch: float = 1.0, volume: float = -7.0) -> void:
	play_sound(path, pitch, volume)

func _power_audio() -> Node:
	var node:Node=get_node_or_null("PowerAudio")
	if not is_instance_valid(node):
		node=preload("res://campaign/power_audio.gd").new();node.game=self;add_child(node)
	return node

func play_power_sound(key:String) -> void:
	_power_audio().play_release(key)

func play_power_impact_sound(key:String) -> void:
	_power_audio().play_impact(key)

func power_coin_cost(_power_key: String = "") -> int:
	return 0

func _physics_process(delta: float) -> void:
	_update_music()
	if state=="playing":
		power_global_lock=maxf(0,power_global_lock-delta)
		for key in power_timers:power_timers[key]=maxf(0,float(power_timers[key])-delta)
		power_cooldown=float(power_timers.get(selected_power,0))
	if state == "ready":
		ready_left -= delta
		if ready_left <= 0: state = "playing"; feedback(_objective_text(current_definition))
	if state == "playing" and not practice:
		var tick := ceili(time_left)
		if tick <= 5 and tick != last_tick:
			last_tick = tick
			play_sound("res://campaign/countdown.wav")
		time_left = maxf(0, time_left - delta)
		if time_left <= 0 and not is_combat(): finish(false, "Time expired")
		_check_quiver_empty()
	if page == "hud" and is_instance_valid(hud_timer):
		hud_timer.text = "PRACTICE" if practice else "%02d:%02d" % [ceili(time_left) / 60, ceili(time_left) % 60]
		hud_timer.add_theme_color_override("font_color", Color("e9a17b") if time_left < 5 else GOLD)
		if is_instance_valid(hud_ammo): hud_ammo.text = "%s arrows · %d focus\n%d / %d targets" % ["∞" if practice else str(arrows),int(focus_meter), completed, current_definition.materials.size()]
		if is_combat():hud_ammo.text = "%s arrows · %d focus\nHP %d/%d · %s"%["∞" if practice else str(arrows),int(focus_meter),ceili(hero.current_hp),ceili(hero.max_hp),stage.combat_manager.status_text()]
		if is_instance_valid(hud_cross): hud_cross.visible = state != "ready"
		if is_instance_valid(hud_ready):
			if state == "ready":
				var prompt: String = ("Tap screen or SHOOT to begin · %d" % ceili(ready_left)) if touch_enabled() else ("Press SHOOT or Space to begin · %d" % ceili(ready_left))
				hud_ready.text = "%s\n%s\n%s" % [current_definition.name, current_definition.get("story", ""), prompt]
			else:
				hud_ready.text = ""
			if hud_ready.get_parent() is PanelContainer:
				hud_ready.get_parent().visible = not hud_ready.text.is_empty()
		if is_instance_valid(hud_draw): hud_draw.value = draw_amount
		if focus_material: focus_material.set_shader_parameter("strength",hero.focus_blend if state in ["playing","paused"] else 0.0)
		message_time -= delta
		if is_instance_valid(hud_message): hud_message.text = message if message_time > 0 else ""

func finish(success: bool, reason: String) -> void:
	if state != "playing": return
	result_sequence+=1
	hero.cancel_draw();hero.velocity=Vector3.ZERO
	power_armed=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var performance:Dictionary=Profile.calculate_performance(success,hits,shots,precision_sum,time_left,float(current_definition.get("seconds", 30)),minimum_arrows)
	var reward:Dictionary={"xp":0,"coins":0,"saved":true}
	performance.badges=[]
	if success:
		if hits==shots and shots>0:performance.badges.append("No missed arrows")
		if max_thread_chain>=3:performance.badges.append("One-arrow chain")
		if is_instance_valid(stage.encounter) and stage.encounter.found_perch:performance.badges.append("Hidden perch")
	if is_combat():
		performance.stars=(1+int(hero.current_hp>=hero.max_hp*.5)+int(time_left>0)) if success else 0
	if not practice and not test_mode:
		if success:reward=profile.reward(selected_stage,int(performance.stars),float(performance.accuracy),time_left,run_transaction,performance)
		else:profile.fail_run()
	pending_result={"success":success,"reason":reason,"stars":int(performance.stars),"reward":reward,"accuracy":float(performance.accuracy),"performance":performance,"chapter_restart":(selected_stage/5)*5}
	if is_instance_valid(touch_controller):touch_controller.reset()
	if success:
		state="finishing"
		var target_position:Vector3=last_hit_position
		if target_position==Vector3.ZERO and not stage.targets.is_empty():target_position=stage.targets.back().global_position
		if not test_mode:
			_play_restoration_event(target_position)
		final_director.final_impact(target_position)
	else:
		state="finishing"
		var sequence:=result_sequence
		get_tree().create_timer(0.65,false).timeout.connect(func():
			if sequence==result_sequence:complete_pending_result())

func complete_pending_result() -> void:
	if state!="finishing" or pending_result.is_empty():return
	last_result=pending_result.duplicate(true);pending_result.clear()
	state="results";page="results"
	play_sound("res://campaign/complete.wav" if bool(last_result.success) else "res://campaign/failed.wav")
	menu_builder=MenuUI.new(self);menu_builder.results()

func show_pause() -> void:
	if state!="paused":prior_pause_state=state
	state = "paused"
	page = "pause"
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hero.cancel_draw()
	hero.drawing = false
	hero.aim_held = false
	hero.controller_drawing = false
	hero.draw_elapsed = 0.0
	draw_amount = 0.0
	if is_instance_valid(touch_controller):touch_controller.reset()
	hero.reset_jump_input();power_charge_source="";power_armed=false
	menu_builder=MenuUI.new(self);menu_builder.pause()

func resume_game() -> void:
	get_tree().paused = false
	state = "finishing" if prior_pause_state=="finishing" else ("ready" if ready_left > 0 else "playing")
	page = "hud"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if touch_enabled() else Input.MOUSE_MODE_CAPTURED
	_show_hud()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_B and is_playing():shoot_burst();get_viewport().set_input_as_handled()
	if event is InputEventKey and not event.echo and event.keycode in [KEY_F,KEY_E,KEY_R]:
		var source:String="key:"+str(event.keycode)
		if event.pressed and is_playing():begin_power_charge(profile.secondary_power() if event.keycode==KEY_R else profile.selected_power(),source)
		elif not event.pressed:end_power_charge(source)
		get_viewport().set_input_as_handled()
	if event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_A and is_playing():hero.request_jump()
	if event is InputEventJoypadButton and event.button_index in [JOY_BUTTON_X,JOY_BUTTON_Y]:
		var source:String="pad:"+str(event.button_index)
		if event.pressed and is_playing():begin_power_charge(profile.secondary_power() if event.button_index==JOY_BUTTON_Y else profile.selected_power(),source)
		elif not event.pressed:end_power_charge(source)
		get_viewport().set_input_as_handled()
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		if state in ["playing", "ready", "finishing"]: show_pause()
		elif state == "paused": resume_game()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if state in ["playing", "ready", "finishing"]: show_pause()
		elif state == "paused": resume_game()
		elif page != "home": show_home()
		get_viewport().set_input_as_handled()
func _capture_later() -> void:
	await get_tree().create_timer(4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://campaign/home-preview.png")
	_quit_game()

func _run_smoke() -> void:
	# Runs without touching the user's campaign profile.
	for character in range(4):
		profile.data.character = character
		_spawn_hero()
		hero.interact()
		await get_tree().physics_frame
	for id in range(definitions.size()):
		start_stage(id)
		assert(stage.targets.size() == definitions[id].materials.size())
		state = "playing"
		for target in stage.targets:
			target.set_active(true)
			target.required_range = 0
			if target.final_stone:hero.global_position=target.global_position+Vector3(0,-1.3,4)
			while not target.completed:
				target.campaign_hit(target.global_position + Vector3(0, 0, 0.13), 10)
		assert(state == "finishing")
		complete_pending_result()
		await get_tree().process_frame
	show_home()
	print("CAMPAIGN SMOKE PASS: 100 stages, four characters, target completion and results")
	_quit_game()

func current_wind() -> float:
	var base: float = current_definition.get("wind", 0.0)
	if bool(current_definition.get("wind_cycle",false)):return base*sin(stage.encounter.elapsed*.6) if is_instance_valid(stage) and is_instance_valid(stage.encounter) else 0.0
	return base

func _show_costumes() -> void:
	inventory_tab="costumes"
	show_inventory()

func _select_costume(id: int) -> void:
	if not profile.data.owned_characters.has(1) or not profile.buy_costume(id): return
	if not profile.equip_costume(id):return
	profile.data.character = 1
	profile.save_profile()
	_spawn_hero()
	_show_costumes()

func _setup_music()->void:
	for name_value in ["Music","SFX","Ambience"]:
		if AudioServer.get_bus_index(name_value)<0:
			AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,name_value)
	music=AudioStreamPlayer.new();music.bus="Music";music.volume_db=-10
	music.stream=load("res://campaign/audio/music.mp3")
	add_child(music)
	music.finished.connect(_music_finished)
	music.play(28.0)

func _update_music()->void:
	if not is_instance_valid(music):return
	if state in ["menu","paused","results"]:
		if not music.playing:music.play(28.0)
	elif music.playing:music.stop()

func _music_finished()->void:
	if state in ["menu","paused","results"]:music.play(28.0)

func _coin_badge()->void:
	_panel(1035,25,210,52)
	_label("%d coins"%profile.data.coins,1055,33,170,35,20)

func stop_audio() -> void:
	for node in find_children("*", "AudioStreamPlayer", true, false):
		node.stop()
		node.stream = null
	for node in find_children("*", "AudioStreamPlayer3D", true, false):
		node.stop()
		node.stream = null

func _quit_game() -> void:
	stop_audio()
	await get_tree().create_timer(0.25).timeout
	get_tree().quit()

func _exit_tree() -> void:
	stop_audio()

func touch_enabled() -> bool:
	return bool(profile.data.settings.get("touch_controls",OS.has_feature("android") or OS.has_feature("ios")))

func _update_layout_metrics() -> void:
	var viewport_size:Vector2=get_viewport().get_visible_rect().size
	# Both platforms use the same landscape composition and logical canvas.
	ui_scale=clampf(minf(viewport_size.x/1280.0,viewport_size.y/600.0),0.5,1.6)
	ui.scale=Vector2.ONE*ui_scale
	ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	ui.size=viewport_size/ui_scale
	safe_margins=Vector4(18,18,18,18)
	if OS.has_feature("android") or OS.has_feature("ios"):
		var safe:Rect2i=DisplayServer.get_display_safe_area()
		var screen:Vector2i=DisplayServer.screen_get_size()
		if safe.size.x>0 and screen.x>0:
			var ratio:Vector2=viewport_size/Vector2(screen)/ui_scale
			safe_margins.x=maxf(18,float(safe.position.x)*ratio.x+12)
			safe_margins.y=maxf(18,float(safe.position.y)*ratio.y+12)
			safe_margins.z=maxf(18,float(screen.x-safe.end.x)*ratio.x+12)
			safe_margins.w=maxf(18,float(screen.y-safe.end.y)*ratio.y+12)

func _layout_touch_controller() -> void:
	if not is_instance_valid(touch_controller):return
	touch_controller.scale=Vector2.ONE*ui_scale
	touch_controller.size=ui.size

func _queue_layout() -> void:
	if layout_queued:return
	layout_queued=true
	_refresh_layout.call_deferred()

func _refresh_layout() -> void:
	layout_queued=false
	if not is_instance_valid(ui) or not is_instance_valid(hero):return
	_update_layout_metrics();_layout_touch_controller()
	if is_instance_valid(touch_controller):touch_controller.reset()
	menu_builder=MenuUI.new(self)
	match page:
		"home":menu_builder.home()
		"characters":menu_builder.characters()
		"levels":menu_builder.levels()
		"inventory":menu_builder.inventory()
		"settings":menu_builder.settings()
		"hud":menu_builder.hud()
		"pause":menu_builder.pause()
		"results":menu_builder.results()

func _notification(what:int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and not test_mode and state in ["playing","ready"] and is_instance_valid(ui):
		show_pause()


func _minimum_arrow_count() -> int:
	var count:=0
	var thread_cost:=0
	for target in stage.targets:
		var health:float=target.max_hp;var hits_needed:=0
		while health>0.001 and hits_needed<10000:
			health-=maxf(.01,profile.power())*(1+mini(hits_needed,2)*.1 if target.material_kind in ["stone","rune","master"] else 1)
			hits_needed+=1
		if target.is_pierceable:thread_cost=maxi(thread_cost,hits_needed)
		else:count+=hits_needed+(3 if target.is_armor_petals else 0)
	return maxi(1,count+thread_cost)

func available_powers() -> Array:
	var result:Array=[]
	for info in profile.power_unlocks():
		if str(info.key)=="normal":continue
		var item:Dictionary=info.duplicate(true);item.id=item.key;item.unlock=item.level;result.append(item)
	return result

func select_power(id:String) -> void:
	if profile.equip_power(id):selected_power=id;power_armed=false
	else:feedback("Power unlocks at a higher bow and arrow level")

func power_status_text() -> String:
	return "%s · %s"%[profile.ability_stats(selected_power).name,"ARMED" if power_armed else power_block_reason(selected_power)]

func trigger_power() -> void:
	if not is_playing():return
	if power_armed:power_armed=false;feedback("Power canceled");return
	if selected_power=="normal" or not profile.power_is_unlocked(selected_power):selected_power=profile.selected_power()
	var reason:String=power_block_reason(selected_power)
	if reason!="Ready":feedback(reason);return
	power_armed=true;play_sound("res://campaign/audio/cue_rise.wav",1,-12)
	feedback("%s armed · Draw and release"%profile.ability_stats(selected_power).name)

func clear_power_hold() -> void:
	power_charge_source=""

func begin_power_charge(key:String,source:String) -> bool:
	if not is_playing() or not is_instance_valid(hero) or hero.current_hp<=0 or hero.is_dodging:return false
	if not power_charge_source.is_empty() or hero.drawing:return false
	if hero.shot_cooldown>0:return false
	if key.is_empty() or key=="normal":feedback("Choose an unlocked power in your loadout");return false
	var reason:String=power_block_reason(key)
	if reason!="Ready":feedback(reason);return false
	selected_power=key;power_armed=true
	hero._start_draw()
	if not hero.drawing:power_armed=false;return false
	power_charge_source=source
	feedback("%s · Hold to charge · Release to fire"%profile.ability_stats(key).name)
	return true

func end_power_charge(source:String,canceled:bool=false) -> void:
	if source!=power_charge_source or source.is_empty():return
	power_charge_source=""
	if not is_instance_valid(hero):return
	if canceled or not is_playing() or not hero.drawing:
		hero.cancel_draw();power_armed=false;return
	# A short tap retains the existing arm-next-shot option. Holding fires on release.
	if hero.draw_elapsed<.12:
		hero.cancel_draw();power_armed=true
		feedback("%s armed · Hold POWER to charge, or aim and draw"%profile.ability_stats(selected_power).name)
	else:hero._fire()

func begin_volley() -> Dictionary:
	if not is_playing() or arrows<=0:return {}
	var key:String=selected_power if power_armed else "normal"
	if key!="normal" and power_block_reason(key)!="Ready":return {}
	var info:Dictionary=profile.ability_stats(key)
	arrows-=1;shots+=1;shot_serial+=1;airborne+=int(info.ammo)
	info.volley_id="volley:"+str(shot_serial)
	if key!="normal":
		focus_meter-=float(info.focus);power_timers[key]=float(info.cooldown);power_global_lock=2.0
		if key=="ultimate":ultimate_used=true
	power_armed=false
	return info

func maybe_follow_final(projectile:Node3D,target:Node3D,point:Vector3) -> void:
	if is_combat() or not is_playing() or completed!=stage.targets.size()-1 or final_director.is_active():return
	if target.would_be_destroyed(point,projectile.power):final_director.begin(projectile,target)

func play_impact_sound() -> void:
	impact_sound_count+=1
	play_sound("res://campaign/audio/target-impact-single.wav")

func _set_backdrop_playing(playing:bool) -> void:
	if not is_instance_valid(menu_course):
		# Preserve the original lobby vista in a separate, noninteractive scene.
		menu_course=Node3D.new();menu_course.name="LobbyForest";add_child(menu_course)
		for child in backdrop.get_children():
			if child is Node3D and not child is Light3D:
				child.reparent(menu_course)
		preload("res://campaign/lobby_backdrop.gd").prepare(menu_course)
	menu_course.visible=not playing
	menu_course.process_mode=Node.PROCESS_MODE_DISABLED
	# The lobby contributes no geometry, physics or particles to a shooting stage.
	for particles in menu_course.find_children("*","GPUParticles3D",true,false):particles.emitting=not playing

func loadout_requirement(definition:Dictionary) -> String:
	return profile.get_stage_lock_reason(int(definition.id))

func shoot_burst() -> void:
	if profile.equip_power("burst"):selected_power="burst";trigger_power()

func shoot_power(power_key:String="") -> void:
	if not power_key.is_empty() and profile.power_is_unlocked(power_key):
		if power_key!=selected_power:power_armed=false
		selected_power=power_key
	trigger_power()

func _play_restoration_event(target_pos: Vector3) -> void:
	if is_instance_valid(stage):
		stage.restore_story_landmark()
		if is_instance_valid(stage.encounter):stage.encounter.restore_landmark()
	play_sound("res://campaign/audio/nature_restore.wav", 1.0, -4.0)
	feedback("🌿 %s Restored!" % str(current_definition.get("chapter", "The Grove")))
	if not is_instance_valid(stage): return
	var bloom := CPUParticles3D.new()
	bloom.amount = 120; bloom.lifetime = 2.4; bloom.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; bloom.emission_sphere_radius = 1.8
	bloom.position = target_pos; bloom.direction = Vector3(0, 1, 0); bloom.spread = 25.0; bloom.initial_velocity_min = 3.5; bloom.initial_velocity_max = 6.0
	bloom.gravity = Vector3(0, -0.5, 0)
	var star := PrismMesh.new(); star.size = Vector3.ONE * 0.18
	var smat := StandardMaterial3D.new(); smat.albedo_color = Color("ffe082"); smat.emission_enabled = true; smat.emission = Color("ffca28"); smat.emission_energy_multiplier = 3.0
	star.material = smat; bloom.mesh = star; stage.add_child(bloom)

	var spray := CPUParticles3D.new()
	spray.amount = 80; spray.lifetime = 1.8; spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; spray.emission_box_extents = Vector3(6.0, 0.2, 12.0)
	spray.position = Vector3(0, stage.spawn.y + 0.1, (stage.spawn.z + target_pos.z) * 0.5); spray.direction = Vector3(0, 1, 0); spray.initial_velocity_min = 1.2; spray.initial_velocity_max = 2.5
	spray.gravity = Vector3(0, -3.0, 0)
	var water_drop := SphereMesh.new(); water_drop.radius = 0.08; water_drop.height = 0.16
	var wmat := StandardMaterial3D.new(); wmat.albedo_color = Color(0.4, 0.9, 0.95, 0.8); wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wmat.emission_enabled = true; wmat.emission = Color("4dd0e1"); wmat.emission_energy_multiplier = 1.5
	water_drop.material = wmat; spray.mesh = water_drop; stage.add_child(spray)

	for f in range(24):
		var flower := MeshInstance3D.new()
		var fm := CylinderMesh.new(); fm.top_radius = 0.25; fm.bottom_radius = 0.05; fm.height = 0.15; flower.mesh = fm
		var fmat := StandardMaterial3D.new()
		fmat.albedo_color = [Color("ff6b8b"), Color("ffd166"), Color("06d6a0"), Color("118ab2"), Color("f72585")][f % 5]
		flower.material_override = fmat
		var f_offset := Vector3(randf_range(-10.0, 10.0), 0.08, randf_range(target_pos.z - 4.0, target_pos.z + 8.0))
		flower.position = Vector3(f_offset.x, stage.spawn.y + 0.08, f_offset.z); flower.scale = Vector3.ZERO; stage.add_child(flower)
		var ft := create_tween()
		ft.tween_property(flower, "scale", Vector3.ONE * randf_range(0.8, 1.4), 0.4).set_delay(randf_range(0.1, 0.8))

func shot_budget(definition:Dictionary) -> int:
	var count:int=0
	var thread_cost:int=0
	for i in range(definition.materials.size()):
		var material:String=str(definition.materials[i])
		var hp:float=float(definition.target_hp[i]);var hits:int=0
		while hp>.001 and hits<10000:
			hp-=maxf(.01,profile.power())*(1+mini(hits,2)*.1 if material in ["stone","rune","master"] else 1)
			hits+=1
		if material=="soft_orb":thread_cost=maxi(thread_cost,hits)
		else:count+=hits+(3 if material=="armor_petals" else 0)
	return count+thread_cost

func preparation_hint(definition:Dictionary) -> String:
	if profile.power_level()<int(definition.get("minimum_power_level",1)):
		return "Chapter entry: BOTH weapons Lv. %d required · equipped bow %d / arrow %d. Open UPGRADES."%[int(definition.minimum_power_level),profile.data.bow_level,profile.data.arrow_level]
	var shots:int=shot_budget(definition)
	if shots>int(definition.arrows):
		for kind in ["bow","arrow"]:
			var entries:Array=Catalog.BOWS if kind=="bow" else Catalog.ARROWS
			var current:int=int(profile.data["equipped_"+kind])
			for id in profile.data["owned_"+kind+"s"]:
				if int(entries[int(id)].tier_index)>int(entries[current].tier_index):return "Equip your owned %s in Collection. %d center shots needed / %d arrows."%[entries[int(id)].name,shots,definition.arrows]
		return "Upgrade bow, arrows or archer in Collection: %d center shots needed / %d arrows."%[shots,definition.arrows]
	return "%d center shots / %d arrows · %d spare. Powers optional."%[shots,definition.arrows,int(definition.arrows)-shots]

func is_combat() -> bool:
	return is_instance_valid(stage) and is_instance_valid(stage.combat_manager)

func power_block_reason(key:String) -> String:
	if key=="normal":return "Choose an unlocked power"
	if not profile.power_is_unlocked(key):return profile.get_power_lock_reason(key)
	if arrows<=0:return "No arrows"
	if key=="ultimate" and ultimate_used:return "Aurora spent · Reach the rearm well" if selected_stage==99 else "Aurora used this attempt"
	if power_global_lock>0 or float(power_timers.get(key,0))>0:return "Cooldown %.1fs"%maxf(power_global_lock,float(power_timers.get(key,0)))
	if focus_meter<float(profile.ability_stats(key).focus):return "Need %d focus"%int(profile.ability_stats(key).focus)
	return "Ready"
