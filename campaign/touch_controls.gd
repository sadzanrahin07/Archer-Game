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
	var bottom:float=game.safe_margins.w+(70 if game.is_combat() else 117)
	var draw_position:=Vector2(size.x-game.safe_margins.z-76*factor,size.y-bottom-66*factor)
	return {"factor":factor,"stick":Vector2(game.safe_margins.x+82*factor,size.y-bottom-70*factor),
		"draw":draw_position,"aim":draw_position+Vector2(0,-116*factor),
		"secondary":draw_position+Vector2(-250*factor,0),
		"power":draw_position+Vector2(-132*factor,0),
		"burst":draw_position+Vector2(-132*factor,-105*factor),
		"dodge":draw_position+Vector2(-132*factor,-105*factor),
		"jump":draw_position+Vector2(-250*factor,-105*factor),
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
	if not game.power_charge_source.is_empty():game.end_power_charge(game.power_charge_source,true)
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

func _active_power_key() -> String:
	if not is_instance_valid(game): return ""
	var pwr: String = game.profile.selected_power()
	if pwr != "normal" and game.profile.power_is_unlocked(pwr):
		return pwr
	return ""

func _power_title() -> String:
	var pwr := _active_power_key()
	if pwr.is_empty(): return ""
	var is_used:bool=game.power_block_reason(pwr)!="Ready" and not game.power_armed
	if is_used: return "WAIT"
	if game.power_armed and game.selected_power==pwr: return "RELEASE" if game.hero.drawing and game.draw_amount>=.95 else ("CHARGE" if game.hero.drawing else "ARMED")
	if game.practice and game.power_cooldown > 0: return "WAIT"
	match pwr:
		"burst": return "BURST"
		"gale": return "GALE"
		"pressure": return "PRESS"
		"fire": return "EMBER"
		"lightning": return "BOLT"
		"super_lightning": return "SUPER"
		"ultimate": return "AURORA"
		_: return "POWER"

func _power_color(key: String) -> Color:
	match key:
		"burst": return Color("45f5a8")
		"gale": return Color("81eeff")
		"pressure": return Color("5ae6ff")
		"fire": return Color("ff7b39")
		"lightning": return Color("9dfbe4")
		"super_lightning": return Color("c59dff")
		"ultimate": return Color("ffedb5")
		_: return Color(1, 1, 1, 0.94)

func _has_active_power() -> bool:
	if not is_instance_valid(game): return false
	if game.practice: return true
	return not _active_power_key().is_empty()

func contact(id:int,pos:Vector2,pressed:bool,canceled:bool=false) -> void:
	if pressed:
		var geo:=geometry()
		var can_move: bool = is_instance_valid(game.hero) and not game.hero.stationary
		var role:=""
		if can_move and pos.distance_to(geo.stick)<88*geo.factor and not roles.values().has("move"):role="move"
		elif pos.distance_to(geo.draw)<60*geo.factor and not roles.values().has("shoot"):role="shoot"
		elif pos.distance_to(geo.aim)<43*geo.factor:role="aim";aim=not aim if game.arrows>0 else false
		elif game.is_combat() and pos.distance_to(geo.dodge)<43*geo.factor:role="dodge";game.hero.start_dodge()
		elif pos.distance_to(geo.jump)<43*geo.factor:role="jump";game.hero.request_jump()
		elif can_move and pos.distance_to(geo.run)<43*geo.factor:role="run";sprint=not sprint
		elif game.profile.secondary_power()!="normal" and pos.distance_to(geo.secondary)<48*geo.factor:role="secondary";game.begin_power_charge(game.profile.secondary_power(),"touch:"+str(id))
		elif _has_active_power() and pos.distance_to(geo.power)<48*geo.factor:role="power";game.begin_power_charge(game.profile.selected_power(),"touch:"+str(id))
		elif pos.y>game.safe_margins.y+60 and pos.y<size.y-(game.safe_margins.w+117):role="look";look_last[id]=pos
		if role.is_empty():return
		roles[id]=role
		if game.state=="ready":game.ready_left=0
		if role=="shoot" and game.is_playing() and game.power_charge_source.is_empty():
			if is_instance_valid(game.hero):
				if aim:game.hero.touch_aim=true;game.hero._start_draw()
				else:game.hero.instant_shoot()
		if role=="move":_move(pos)
	else:
		if not roles.has(id):return
		var role:String=roles[id]
		if role=="move":move_vector=Vector2.ZERO;stick_offset=Vector2.ZERO
		elif role in ["power","secondary"]:game.end_power_charge("touch:"+str(id),canceled)
		elif role=="shoot" and is_instance_valid(game.hero) and game.power_charge_source.is_empty():
			if canceled:
				game.hero.cancel_draw()
			elif game.hero.drawing:
				game.hero._fire()
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
	var can_move: bool = is_instance_valid(game.hero) and not game.hero.stationary
	if can_move:
		draw_circle(geo.stick,74*factor,glass);draw_arc(geo.stick,74*factor,0,TAU,64,ink,2,true)
		draw_circle(geo.stick+stick_offset,29*factor,Color(0.85,1,0.93,0.35))
		_circle(geo.run,39*factor,"RUN",sprint)
		var font_move:Font=game.ui.theme.default_font
		draw_string(font_move,geo.stick+Vector2(-24,94*factor),"MOVE",HORIZONTAL_ALIGNMENT_LEFT,-1,16,ink)

	_circle(geo.draw,57*factor,"SHOOT",game.hero.drawing)
	_circle(geo.aim,39*factor,"AIM",aim)
	_circle(geo.jump,39*factor,"JUMP",game.hero.is_jumping)
	if game.is_combat():_dodge_circle(geo.dodge,39*factor)

	if game.profile.secondary_power()!="normal":
		var second:String=game.profile.secondary_power()
		_circle(geo.secondary,42*factor,game.profile.ability_stats(second).name.get_slice(" ",0).to_upper(),game.power_armed and game.selected_power==second,game.power_block_reason(second)!="Ready",_power_color(second))
	if _has_active_power():
		var pwr_k := _active_power_key()
		var is_used:bool=game.power_block_reason(pwr_k)!="Ready" and not game.power_armed
		var title: String = _power_title()
		var col := _power_color(pwr_k)
		_circle(geo.power, 46 * factor, title, game.power_armed and game.selected_power==pwr_k, is_used, col)

		var cooldown: float = game.power_cooldown
		if cooldown > 0 and not is_used:
			var font: Font = game.ui.theme.default_font; var text: String = "%.1f s" % cooldown
			draw_string(font, geo.power + Vector2(-font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x * 0.5, 70 * factor), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)

func _circle(center:Vector2,radius:float,title:String,selected:bool,used:bool=false,accent:Color=Color.WHITE) -> void:
	var fill_color := Color(accent.r * 0.25, accent.g * 0.25, accent.b * 0.25, 0.88) if selected else (Color(0.04,0.05,0.05,0.55) if used else Color(0.015,0.055,0.045,0.78))
	var border_color := Color(0.5,0.55,0.52,0.45) if used else (accent if accent != Color.WHITE else Color(1,1,1,0.94))
	var text_color := Color(0.65,0.7,0.68,0.6) if used else Color.WHITE
	draw_circle(center,radius,fill_color)
	draw_arc(center,radius,0,TAU,64,border_color,2,true)
	var font:Font=game.ui.theme.default_font
	if title.contains("\n"):
		var parts := title.split("\n")
		var fs1 := 14; var fs2 := 12
		var w1 := font.get_string_size(parts[0],HORIZONTAL_ALIGNMENT_LEFT,-1,fs1).x
		var w2 := font.get_string_size(parts[1],HORIZONTAL_ALIGNMENT_LEFT,-1,fs2).x
		draw_string(font,center+Vector2(-w1*0.5,-3),parts[0],HORIZONTAL_ALIGNMENT_LEFT,-1,fs1,text_color)
		draw_string(font,center+Vector2(-w2*0.5,14),parts[1],HORIZONTAL_ALIGNMENT_LEFT,-1,fs2,Color("f6df88") if not used else text_color)
	else:
		var font_size:=13 if title.length() >= 9 else (15 if title.length() >= 7 else (17 if title=="RELEASE" else 19))
		var width:=font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		draw_string(font,center+Vector2(-width*0.5,font_size*0.34),title,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,text_color)

func _dodge_circle(center:Vector2,radius:float) -> void:
	var ready:bool=game.hero.dodge_cooldown<=0
	var title:String="DODGE" if ready else "%.1f"%game.hero.dodge_cooldown
	_circle(center,radius,title,game.hero.is_dodging)
	if not ready:
		var ratio:float=clampf(1-game.hero.dodge_cooldown/1.2,0,1)
		draw_arc(center,radius+4,-PI*.5,-PI*.5+TAU*maxf(.01,ratio),40,Color("a8e3cf"),3,true)
