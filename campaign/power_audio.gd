extends Node
# Separate, bounded voices: a volley cannot stack three launch/impact sounds.
const KEYS=["burst","gale","pressure","fire","lightning","super_lightning","ultimate"]
var game:Node
var release_voice:AudioStreamPlayer
var impact_voice:AudioStreamPlayer
var charge_voice:AudioStreamPlayer
var impact_gate:=0.0
var ready_latched:=false
var active_key:="normal"
func _voice(label:String) -> AudioStreamPlayer:
 var voice:=AudioStreamPlayer.new();voice.name=label;voice.bus="SFX";add_child(voice);return voice
func _ready() -> void:
 name="PowerAudio"
 release_voice=_voice("Release");impact_voice=_voice("Impact");charge_voice=_voice("Charge")
func _play(voice:AudioStreamPlayer,path:String,volume:float,pitch:float=1) -> void:
 voice.stop();voice.stream=load(path);voice.volume_db=volume;voice.pitch_scale=pitch;voice.play()
func begin_charge(key:String) -> void:
 if key not in KEYS:return
 stop_charge();active_key=key;ready_latched=false
 _play(charge_voice,"res://campaign/audio/power-charge-loop.wav",-27)
 var loop:AudioStreamWAV=charge_voice.stream.duplicate()
 loop.loop_mode=AudioStreamWAV.LOOP_FORWARD;loop.loop_begin=0;loop.loop_end=22050
 charge_voice.stream=loop;charge_voice.play()
func charge_ready(key:String) -> void:
 if ready_latched or key not in KEYS:return
 ready_latched=true
 _play(charge_voice,"res://campaign/audio/power-ready.wav",-23,1.04 if key in ["lightning","super_lightning","ultimate"] else 1)
func stop_charge() -> void:
 if is_instance_valid(charge_voice):charge_voice.stop()
 active_key="normal";ready_latched=false
func play_release(key:String) -> void:
 if key not in KEYS:return
 stop_charge()
 var path:String="res://campaign/audio/power_%s.wav"%key
 if key in ["super_lightning","ultimate"] and ResourceLoader.exists("res://campaign/audio/power_%s.mp3"%key):path="res://campaign/audio/power_%s.mp3"%key
 _play(release_voice,path,-14 if key in ["pressure","super_lightning"] else -12)
func play_impact(key:String) -> void:
 if key not in KEYS or impact_gate>0:return
 impact_gate=.065
 _play(impact_voice,"res://campaign/audio/power-hit-%s.wav"%key,-14)
func _process(delta:float) -> void:
 if not is_instance_valid(game):return
 var paused:bool=game.state=="paused"
 for voice in [release_voice,impact_voice,charge_voice]:voice.stream_paused=paused
 if paused:return
 impact_gate=maxf(0,impact_gate-delta)
 if game.state not in ["playing","finishing"]:
  stop_charge();release_voice.stop();impact_voice.stop()
 elif charge_voice.playing and (not is_instance_valid(game.hero) or not game.hero.drawing or not game.power_armed):stop_charge()
