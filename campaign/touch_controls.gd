extends Control
const Catalog = preload("res://campaign/catalog.gd")
# Independent touch IDs allow movement, looking and drawing at the same time.
var game: Node
var roles: Dictionary = {}
var move_vector := Vector2.ZERO
var sprint := false
var aim := false
var look_last: Dictionary = {}
var stick_offset := Vector2.ZERO
var active := false

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	process_mode=Node.PROCESS_MODE_ALWAYS
	z_index=10

func geometry() -> Dictionary:
	# Leave the same bottom information bar visible on every platform.
	var factor:float=clampf(0.85/maxf(game.ui_scale,0.6),1.0,1.3)
	var bottom:float=game.safe_margins.w+117
	var draw_position:=Vector2(size.x-game.safe_margins.z-76*factor,size.y-bottom-66*factor)
	return {"factor":factor,"stick":Vector2(game.safe_margins.x+82*factor,size.y-bottom-70*factor),
		"draw":draw_position,"aim":draw_position+Vector2(0,-116*factor),
		"power":draw_position+Vector2(-132*factor,0),
		"burst":draw_position+Vector2(-132*factor,-105*factor),
		"run":Vector2(game.safe_margins.x+82*factor,size.y-bottom-192*factor)}

func _process(_delta:float) -> void:
	var next:bool=game.touch_enabled() and game.state in ["playing","ready"]
	if active and not next:reset()
	active=next;visible=next
	if not active:return
	if is_instance_valid(game.hero):
		game.hero.touch_move=move_vector if active else Vector2.ZERO
		game.hero.touch_sprint=sprint and active
		game.hero.touch_aim=aim and active
	queue_redraw()

func reset() -> void:
	roles.clear();look_last.clear();move_vector=Vector2.ZERO;stick_offset=Vector2.ZERO;sprint=false;aim=false
	if is_instance_valid(game.hero):
		game.hero.touch_move=Vector2.ZERO;game.hero.touch_sprint=false;game.hero.touch_aim=false
		game.hero.cancel_draw()

func _input(event:InputEvent) -> void:
	if not active:return
	if event is InputEventScreenTouch:
		contact(event.index,event.position/game.ui_scale,event.pressed,event.canceled)
	elif event is InputEventScreenDrag:
		motion(event.index,event.position/game.ui_scale,event.relative/game.ui_scale)
	elif event is InputEventMouseButton and event.device!=-1 and event.button_index==MOUSE_BUTTON_LEFT:
		# Desktop preview of the touch controller; genuine devices use ScreenTouch.
		contact(-100,event.position/game.ui_scale,event.pressed,false)
	elif event is InputEventMouseMotion and event.device!=-1 and roles.has(-100):
		motion(-100,event.position/game.ui_scale,event.relative/game.ui_scale)

func _has_burst() -> bool:
	return is_instance_valid(game) and (game.practice or game.profile.power_is_unlocked("burst"))

func _super_power_key() -> String:
	if not is_instance_valid(game): return ""
	var cur: String = game.selected_power
	if cur != "normal" and cur != "burst" and game.profile.power_is_unlocked(cur):
		return cur
	for i in range(Catalog.POWERS.size() - 1, 0, -1):
		var k := str(Catalog.POWERS[i].key)
		if k != "normal" and k != "burst" and game.profile.power_is_unlocked(k):
			return k
	return ""

func _has_super() -> bool:
	if not is_instance_valid(game): return false
	if game.practice: return true
	return not _super_power_key().is_empty()

func contact(id:int,pos:Vector2,pressed:bool,canceled:bool=false) -> void:
	if pressed:
		var geo:=geometry()
		var role:=""
		if pos.distance_to(geo.stick)<88*geo.factor and not roles.values().has("move"):role="move"
		elif pos.distance_to(geo.draw)<60*geo.factor and not roles.values().has("shoot"):role="shoot"
		elif pos.distance_to(geo.aim)<43*geo.factor:role="aim";aim=not aim
		elif pos.distance_to(geo.run)<43*geo.factor:role="run";sprint=not sprint
		elif _has_super() and pos.distance_to(geo.burst)<42*geo.factor:role="burst";game.shoot_burst()
		elif _has_super() and pos.distance_to(geo.power)<48*geo.factor:role="power";game.trigger_power()
		elif _has_burst() and (pos.distance_to(geo.power)<48*geo.factor or pos.distance_to(geo.burst)<42*geo.factor):role="burst";game.shoot_burst()
		elif pos.y>game.safe_margins.y+60 and pos.y<size.y-(game.safe_margins.w+117):role="look";look_last[id]=pos
		if role.is_empty():return
		roles[id]=role
		if role=="shoot" and game.is_playing():
			if game.power_armed or game.arrows > 0: game.hero.instant_shoot()
		if role=="move":_move(pos)
	else:
		if not roles.has(id):return
		var role:String=roles[id]
		if role=="move":move_vector=Vector2.ZERO;stick_offset=Vector2.ZERO
		roles.erase(id);look_last.erase(id)
	get_viewport().set_input_as_handled()
	queue_redraw()

func motion(id:int,pos:Vector2,relative:Vector2) -> void:
	if not roles.has(id):return
	if roles[id]=="move":_move(pos)
	elif roles[id]=="look":game.hero.apply_touch_look(relative)
	get_viewport().set_input_as_handled()

func _move(pos:Vector2) -> void:
	var geo:=geometry();var radius:float=62.0*geo.factor
	stick_offset=(pos-geo.stick).limit_length(radius)
	move_vector=stick_offset/radius
	if move_vector.length()<0.12:move_vector=Vector2.ZERO

func _draw() -> void:
	if not active:return
	var geo:=geometry();var factor:float=geo.factor
	var ink:=Color(1,1,1,0.92)
	var glass:=Color(0.015,0.055,0.045,0.78)
	draw_circle(geo.stick,74*factor,glass);draw_arc(geo.stick,74*factor,0,TAU,64,ink,2,true)
	draw_circle(geo.stick+stick_offset,29*factor,Color(0.85,1,0.93,0.35))
	_circle(geo.draw,57*factor,"SHOOT",game.hero.drawing)
	_circle(geo.aim,39*factor,"AIM",aim)
	_circle(geo.run,39*factor,"RUN",sprint)
	if _has_super():
		var burst_used: bool = (game.burst_used and not game.practice)
		_circle(geo.burst, 37 * factor, "USED" if burst_used else "BURST", false, burst_used)

		var is_super_used: bool = (game.super_used and not game.practice)
		var title: String = "USED" if is_super_used else ("ARMED" if game.power_armed else ("WAIT" if game.power_cooldown > 0 else "POWER"))
		_circle(geo.power, 45 * factor, title, game.power_armed, is_super_used)

		var cooldown: float = game.power_cooldown
		if cooldown > 0 and not is_super_used:
			var font: Font = game.ui.theme.default_font; var text: String = "%.1f s" % cooldown
			draw_string(font, geo.power + Vector2(-font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x * 0.5, 69 * factor), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
	elif _has_burst():
		var burst_used: bool = (game.burst_used and not game.practice)
		_circle(geo.power, 45 * factor, "USED" if burst_used else "BURST", false, burst_used)
	var font:Font=game.ui.theme.default_font
	draw_string(font,geo.stick+Vector2(-24,94*factor),"MOVE",HORIZONTAL_ALIGNMENT_LEFT,-1,16,ink)

func _circle(center:Vector2,radius:float,title:String,selected:bool,used:bool=false) -> void:
	var fill_color := Color(0.12,0.3,0.23,0.88) if selected else (Color(0.04,0.05,0.05,0.55) if used else Color(0.015,0.055,0.045,0.78))
	var border_color := Color(0.5,0.55,0.52,0.45) if used else Color(1,1,1,0.94)
	var text_color := Color(0.65,0.7,0.68,0.6) if used else Color.WHITE
	draw_circle(center,radius,fill_color)
	draw_arc(center,radius,0,TAU,64,border_color,2,true)
	var font:Font=game.ui.theme.default_font
	var font_size:=17 if title=="RELEASE" else 19
	var width:=font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	draw_string(font,center+Vector2(-width*0.5,font_size*0.34),title,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,text_color)
