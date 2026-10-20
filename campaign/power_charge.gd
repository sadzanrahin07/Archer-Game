extends Sprite3D
var player:Node3D
var last_key:=""
var charge_time:=0.0
var release_time:=0.0
var was_charging:=false
func _ready() -> void:
 billboard=BaseMaterial3D.BILLBOARD_ENABLED;shaded=false;pixel_size=.0035
 cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;top_level=true;visible=false
func _process(delta:float) -> void:
 if not is_instance_valid(player) or not is_instance_valid(player.game):return
 var game:Node=player.game
 # Menu previews always display the equipped physical arrow, never an armed power.
 if player.showcase or not game.is_playing():
  visible=false;was_charging=false;charge_time=0;release_time=0
  return
 var key:String=game.selected_power
 var charging:bool=player.drawing and game.power_armed and key!="normal" and game.profile.power_is_unlocked(key)
 if charging and key!="normal":
  if key!=last_key:
   last_key=key;texture=load("res://campaign/vfx/"+key+"-charge.png");charge_time=0
  charge_time+=delta;release_time=0
  visible=true;modulate.a=.8;scale=Vector3.ONE*lerpf(.4,1.0,minf(1,charge_time/.25))
 elif was_charging and not player.drawing:
  release_time=.12;texture=load("res://campaign/vfx/"+last_key+"-release.png")
 elif release_time>0:
  release_time-=delta;modulate.a=maxf(0,release_time/.12);scale=Vector3.ONE*1.1
 else:visible=false;charge_time=0
 was_charging=charging
 if visible:global_position=player.nock_world
