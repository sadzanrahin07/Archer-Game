extends Control
# Combat information stays near the action without covering the movement field.
var game:Node
var displayed_hp:=1.0
var damage_trail:=1.0
var font:Font
var watched_boss:Node3D
var hit_text:=""
var hit_left:=0.0
var hit_color:=Color.WHITE
var damage_popups: Array[Dictionary] = []
func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 font=ThemeDB.fallback_font
func _process(delta:float) -> void:
 if not is_instance_valid(game) or not is_instance_valid(game.hero):return
 if game.is_playing():hit_left=maxf(0,hit_left-delta)
 if game.is_combat() and is_instance_valid(game.stage.combat_manager.boss):
  var boss:Node3D=game.stage.combat_manager.boss
  if boss!=watched_boss:
   watched_boss=boss;boss.hit_resolved.connect(_on_boss_hit)
 var ratio:float=clampf(game.hero.current_hp/maxf(1,game.hero.max_hp),0,1)
 displayed_hp=move_toward(displayed_hp,ratio,delta*3)
 damage_trail=move_toward(damage_trail,displayed_hp,delta*.45)
 if damage_trail<displayed_hp:damage_trail=displayed_hp
 for i in range(damage_popups.size() - 1, -1, -1):
  damage_popups[i].time -= delta
  if damage_popups[i].time <= 0:
   damage_popups.remove_at(i)
 queue_redraw()
func popup_damage(world_pos: Vector3, damage: float, is_vital: bool, power_key: String) -> void:
 var color := Color("eff8ef")
 if power_key == "super_lightning": color = Color("d9b0ff")
 elif power_key == "lightning": color = Color("9ef5ff")
 elif power_key == "fire": color = Color("ff9b57")
 elif power_key == "pressure": color = Color("a6e3e9")
 elif power_key in ["ultimate", "aurora"]: color = Color("ffe599")
 elif is_vital: color = Color("ffe066")

 var text := ("CRIT " if is_vital else "") + "−%d" % roundi(damage)
 damage_popups.append({
  "world_pos": world_pos + Vector3(randf_range(-0.25, 0.25), randf_range(0.3, 0.6), randf_range(-0.25, 0.25)),
  "text": text,
  "color": color,
  "time": 0.95,
  "vital": is_vital,
  "power": power_key != "normal"
 })

func text_at(text:String,pos:Vector2,font_size:int,color:Color=Color("eff8ef"),center:bool=false) -> void:
 var width:float=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
 var anchor:Vector2=pos-Vector2(width*.5,0) if center else pos
 draw_string_outline(font,anchor,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,3,Color(0,0,0,.85))
 draw_string(font,anchor,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
func gauge(rect:Rect2,ratio:float,color:Color,trail:float=-1) -> void:
 draw_style_box(rounded(Color(.02,.05,.045,.84),5),rect.grow(3))
 if trail>=0:draw_style_box(rounded(Color("d88958"),3),Rect2(rect.position,Vector2(rect.size.x*trail,rect.size.y)))
 draw_style_box(rounded(color,3),Rect2(rect.position,Vector2(rect.size.x*clampf(ratio,0,1),rect.size.y)))
func rounded(color:Color,radius:int) -> StyleBoxFlat:
 var style:=StyleBoxFlat.new();style.bg_color=color;style.set_corner_radius_all(radius);return style
func _draw() -> void:
 if not is_instance_valid(game) or not game.is_combat() or not is_instance_valid(game.hero):return
 # A newly attached canvas may be zero-sized until the first layout pass.
 if size.x<240 or size.y<200:return
 var hero:Node3D=game.hero
 var width:float=minf(340,size.x*.30)
 var bar_h:float=14.0
 var origin:=Vector2((size.x-width)*.5,size.y-game.safe_margins.w-42)
 gauge(Rect2(origin,Vector2(width,bar_h)),displayed_hp,Color("8ed46a") if displayed_hp>.3 else Color("f09a6e"),damage_trail)
 text_at("%d / %d"%[ceili(hero.current_hp),ceili(hero.max_hp)],origin+Vector2(width*.5,11),11,Color.WHITE,true)
 gauge(Rect2(origin+Vector2(0,bar_h+4),Vector2(width,4)),game.focus_meter/100,Color("92ded1"))
 text_at("%d arrows   ·   %d focus"%[game.arrows,int(game.focus_meter)],origin+Vector2(width*.5,-14),13,Color("e3ecd9"),true)
 if not game.touch_enabled():text_at("Space · Jump   Q · Dodge   LMB · Shoot   Hold F/R · Power",Vector2(game.safe_margins.x,size.y-game.safe_margins.w-18),13,Color("d7e3d3"))
 if not is_instance_valid(game.stage.combat_manager):return
 var manager:Node3D=game.stage.combat_manager
 if is_instance_valid(manager.boss):
  var boss:Node3D=manager.boss
  var boss_width:float=minf(460,size.x*.42);var start:=Vector2((size.x-boss_width)*.5,104)
  text_at("THE HOLLOW CROWN",start+Vector2(boss_width*.5,-10),17,Color("f1dfac"),true)
  gauge(Rect2(start,Vector2(boss_width,9)),boss.hp/boss.max_hp,Color("d49476"))
  var status:Dictionary=boss.combat_status()
  var objective:String="CYAN CORE · Full damage" if boss.is_core_exposed else "ARMORED · Body hits deal 25% damage"
  if status.finisher_phase:
   if boss.is_core_exposed:objective="CORE OPEN %.1fs · Hold POWER/F · Release at READY"%status.exposure_remaining
   elif status.rearm_required:objective="FINAL SEAL · Refill at the Aurora Well"
   else:objective="FINAL SEAL · Wait for gold core · Fully charged Aurora"
  text_at(objective,start+Vector2(boss_width*.5,30),14,Color("a6f0dc") if boss.is_core_exposed else Color("f3d4a6"),true)
  if is_instance_valid(boss.intent_label) and boss.intent_label.visible and not boss.is_core_exposed:
   text_at(boss.intent_label.text,start+Vector2(boss_width*.5,51),13,Color("f3d4a6"),true)
   if not hero.camera.is_position_in_frustum(boss.global_position+Vector3(0,2.2,0)):_incoming_marker(hero.camera,boss.global_position+Vector3(0,2.2,0))
  if hit_left>0 and not hero.camera.is_position_behind(boss.core_col.global_position):
   var impact:Vector2=hero.camera.unproject_position(boss.core_col.global_position)/game.ui_scale
   text_at(hit_text,impact+Vector2(0,-34-(1.25-hit_left)*14),21,hit_color,true)
 else:
  var camera:Camera3D=hero.camera
  for enemy in manager.enemies_alive:
   if not is_instance_valid(enemy) or enemy.completed:continue
   if is_instance_valid(enemy.hp_label):enemy.hp_label.visible=false
   var point:Vector3=enemy.global_position+Vector3(0,enemy.vital_shape.position.y+1.0,0)
   var incoming:bool=enemy.current_state in [enemy.State.TELEGRAPH,enemy.State.ATTACK]
   if camera.is_position_behind(point):
    if incoming:_incoming_marker(camera,enemy.global_position)
    continue
   var pos:Vector2=camera.unproject_position(point)/game.ui_scale
   if not Rect2(Vector2(52,85),size-Vector2(104,160)).has_point(pos):
    if incoming:_incoming_marker(camera,enemy.global_position)
    continue
   var ratio:float=enemy.hp/maxf(1,enemy.max_hp)
   var warning:bool=enemy.current_state==enemy.State.TELEGRAPH
   var color:=Color("f4bc66") if warning else Color("d88c75")
   gauge(Rect2(pos-Vector2(46,0),Vector2(92,5)),ratio,color)
   text_at(enemy.family.replace("_"," ").capitalize(),pos+Vector2(0,-7),14,Color("f1dfac") if warning else Color("f0f4e9"),true)
  var wave_rect:=Rect2(Vector2(size.x*.5-125,74),Vector2(250,22))
  draw_style_box(rounded(Color(0.02,0.05,0.04,0.78),6),wave_rect)
  text_at("Wave %d / %d · %d / %d cleared"%[manager.wave_index,manager.total_waves,manager.enemies_killed,manager.total_enemies_expected],Vector2(size.x*.5,89),13,Color("e0e9d8"),true)
  for popup in damage_popups:
   if camera.is_position_behind(popup.world_pos): continue
   var screen_pos: Vector2 = camera.unproject_position(popup.world_pos) / game.ui_scale
   var t: float = 0.95 - popup.time
   var rise: float = t * 42.0
   var alpha: float = clampf(popup.time / 0.30, 0.0, 1.0)
   var col: Color = popup.color; col.a = alpha
   var font_sz: int = 24 if popup.power else (18 if popup.vital else 14)
   text_at(popup.text, screen_pos + Vector2(0, -rise), font_sz, col, true)
 if hero.drawing:
  var center:Vector2=size*.5
  var ready:bool=game.draw_amount>=.95
  text_at("READY · RELEASE" if ready else "CHARGING %d%%"%roundi(game.draw_amount*100),center+Vector2(0,42),13,Color("a5f0d5") if ready else Color("e4d8ab"),true)
  var bw:float=48.0;var bh:float=3.0;var bpos:=center+Vector2(-bw*.5,54)
  draw_rect(Rect2(bpos,Vector2(bw,bh)),Color(0.02,0.06,0.04,0.70))
  var bar_col:=Color("a5f0d5") if ready else Color("e4d8ab")
  draw_rect(Rect2(bpos,Vector2(bw*game.draw_amount,bh)),bar_col)

func _incoming_marker(camera:Camera3D,world_point:Vector3) -> void:
 var local:Vector3=camera.to_local(world_point)
 var direction:=Vector2(local.x,-local.y)
 if direction.length()<.01:direction=Vector2(0,1)
 direction=direction.normalized()
 var center:Vector2=size*.5
 var extent:=Vector2(size.x*.5-70,size.y*.5-115)
 var distance:float=minf(extent.x/maxf(.001,absf(direction.x)),extent.y/maxf(.001,absf(direction.y)))
 var at:Vector2=center+direction*distance
 var side:=direction.orthogonal()
 draw_colored_polygon(PackedVector2Array([at+direction*11,at-direction*8+side*8,at-direction*8-side*8]),Color("f2b568"))
 text_at("INCOMING",at+Vector2(0,25),12,Color("f4d6a5"),true)

func _on_boss_hit(result:Dictionary) -> void:
 if result.reason=="duplicate":return
 hit_left=1.25
 if float(result.damage)>0:
  hit_text="−%.1f"%float(result.damage)
  hit_color=Color("baf9ed") if result.core_hit else Color("e9bc87")
 else:
  hit_text="SEALED" if result.reason in ["core_closed","aurora_required"] else ("CHARGE TO READY" if result.reason=="full_draw_required" else "CORE MISSED")
  hit_color=Color("efc374")
