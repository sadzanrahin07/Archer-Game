extends Node3D

var game:Node
var kind:="ground"
var damage:=22.0
var warning:=1.1
var age:=0.0
var radius:=1.6
var delivered:=false
var shape:MeshInstance3D

func _ready() -> void:
	shape=MeshInstance3D.new()
	var ring:=TorusMesh.new();ring.inner_radius=radius-.12;ring.outer_radius=radius
	shape.mesh=ring
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color("f5ae52");mat.emission_enabled=true;mat.emission=Color("d99144");shape.material_override=mat
	add_child(shape)

func _physics_process(delta:float) -> void:
	if not is_instance_valid(game) or not game.is_playing():return
	age+=delta
	if age<warning:return
	if kind=="ring":
		var distance:float=(age-warning)*5.0
		shape.scale=Vector3.ONE*maxf(.1,distance/radius)
		if not delivered and is_instance_valid(game.hero):
			var offset:Vector3=game.hero.global_position-global_position;offset.y=0
			if absf(offset.length()-distance)<.5 and game.hero.global_position.y-global_position.y<=.50:game.hero.take_player_damage(damage,self);delivered=true
		if distance>16:queue_free()
	else:
		if not delivered:
			delivered=true
			game.play_sound("res://sounds/step_stone_2.wav",.55,-7)
			if is_instance_valid(game.hero):
				var offset:Vector3=game.hero.global_position-global_position;offset.y=0
				if offset.length()<=radius:game.hero.take_player_damage(damage,self)
		shape.scale.y=.2
		if age>warning+.2:queue_free()
