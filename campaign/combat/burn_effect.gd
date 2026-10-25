extends Node
var game:Node
var target:Node3D
var encounter:Node3D
var damage:=0.0
var event_id:=0
var clock:=0.5
var ticks:=0

func _ready() -> void:
	game.pending_damage_count+=1

func _physics_process(delta:float) -> void:
	if not is_instance_valid(target) or target.completed or not is_instance_valid(encounter) or game.stage!=encounter:
		queue_free();return
	if not game.is_playing():
		if game.state!="paused":queue_free()
		return
	clock-=delta
	if clock>0:return
	clock+=.5;ticks+=1
	game.secondary_damage=true
	target.campaign_secondary_hit(damage,event_id+ticks)
	game.secondary_damage=false
	if ticks==4:queue_free()

func _exit_tree() -> void:
	if is_instance_valid(game) and game.stage==encounter:game.pending_damage_count=maxi(0,game.pending_damage_count-1)
