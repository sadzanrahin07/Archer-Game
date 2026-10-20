extends RefCounted

# Preview access is separate from saved purchases and campaign gates.
const TEST_UNLOCK_CHARACTERS := false
const STARTER_COSTUME := 2
const CHARACTER_CAP := 100
const CAMPAIGN_STAGES := 100
const CHARACTERS := [
	{"name":"Enola","unlock_level":4,"unlock_chapter":3,"price":3000,"base_power":1.05,"base_sway":0.97,"max_level":100,"model":"archer"},
	{"name":"Erin","unlock_level":1,"unlock_chapter":0,"price":0,"base_power":1.0,"base_sway":1.0,"max_level":100,"model":"5351321668046832234"},
	{"name":"Maki","unlock_level":6,"unlock_chapter":5,"price":4000,"base_power":1.08,"base_sway":0.95,"max_level":100,"model":"7714687722943833987"},
	{"name":"Jacky","unlock_level":8,"unlock_chapter":7,"price":5000,"base_power":1.10,"base_sway":0.93,"max_level":100,"model":"7403294174270702488"}
]
# IDs stay stable for existing saves. The dark kimono is the free starter.
const COSTUMES := [
	{"name":"Crimson","price":18000,"unlock_chapter":8,"mastery":50,"base_power":1.18,"base_sway":0.88,"max_level":100,"model":"3675109917025159411"},
	{"name":"Academy","price":900,"unlock_chapter":2,"mastery":1,"base_power":1.03,"base_sway":0.98,"max_level":100,"model":"6370431923836766206"},
	{"name":"Erin · Base","price":0,"unlock_chapter":0,"mastery":1,"base_power":1.0,"base_sway":1.0,"max_level":100,"model":"7643054104406740418"},
	{"name":"Ceremonial","price":4200,"unlock_chapter":6,"mastery":1,"base_power":1.09,"base_sway":0.94,"max_level":100,"model":"7185862033116711190"},
	{"name":"Midnight","price":2200,"unlock_chapter":4,"mastery":1,"base_power":1.06,"base_sway":0.96,"max_level":100,"model":"1292382841793082181"},
	{"name":"Ash Hoodie","price":7500,"unlock_chapter":7,"mastery":1,"base_power":1.12,"base_sway":0.92,"max_level":100,"model":"5351321668046832234"}
]
const BOWS := [
	{"name":"Training Bow","tier":"Basic","tier_index":0,"max_level":20,"unlock_chapter":0,"price":0,"upgrade_rate":10,"multiplier":1.0,"speed":1.0,"draw":1.0,"mesh":"res://models/bow_frame_mesh.res","geometry":"standard"},
	{"name":"Elven Bow","tier":"Premium","tier_index":1,"max_level":40,"unlock_chapter":3,"price":1200,"upgrade_rate":12,"multiplier":1.30,"speed":1.08,"draw":0.98,"mesh":"res://campaign/equipment/elven.res","geometry":"elven"},
	{"name":"Marble Bow","tier":"Epic","tier_index":2,"max_level":70,"unlock_chapter":8,"price":6000,"upgrade_rate":16,"multiplier":1.60,"speed":1.15,"draw":0.95,"mesh":"res://campaign/equipment/marble.res","geometry":"marble"},
	{"name":"Tempest Bow","tier":"Legendary","tier_index":3,"max_level":100,"unlock_chapter":14,"price":24000,"upgrade_rate":20,"multiplier":2.0,"speed":1.25,"draw":0.90,"mesh":"res://campaign/equipment/fantasy.res","geometry":"fantasy"}
]
const ARROWS := [
	{"name":"Standard Arrow","tier":"Basic","tier_index":0,"max_level":20,"unlock_chapter":0,"price":0,"upgrade_rate":6,"power":10.0,"mesh":"res://models/arrow_mesh.res","tint":"basic"},
	{"name":"Runestone Arrow","tier":"Epic","tier_index":2,"max_level":70,"unlock_chapter":8,"price":4000,"upgrade_rate":10,"power":30.0,"mesh":"res://campaign/equipment/marble_arrow.res","tint":"rune"},
	{"name":"Hunter Arrow","tier":"Premium","tier_index":1,"max_level":40,"unlock_chapter":3,"price":800,"upgrade_rate":8,"power":18.0,"mesh":"res://models/arrow_mesh.res","tint":"hunter"},
	{"name":"Aurora Arrow","tier":"Legendary","tier_index":3,"max_level":100,"unlock_chapter":14,"price":18000,"upgrade_rate":12,"power":50.0,"mesh":"res://campaign/equipment/marble_arrow.res","tint":"aurora"}
]
const POWERS := [
	{"key":"normal","name":"Normal Arrow","level":1,"focus":0,"cooldown":0.0,"ammo":1,"damage":1.0,"speed":1.0,"secondary":0.0,"chains":0},
	{"key":"burst","name":"Burst Shot","level":20,"focus":25,"cooldown":8.0,"ammo":3,"damage":1.0,"speed":1.0,"secondary":0.0,"chains":0},
	{"key":"gale","name":"Gale Shot","level":50,"focus":35,"cooldown":10.0,"ammo":1,"damage":5.0,"speed":1.35,"secondary":0.0,"chains":0},
	{"key":"pressure","name":"Pressure Wave","level":60,"focus":45,"cooldown":12.0,"ammo":1,"damage":10.0,"speed":1.35,"secondary":0.30,"chains":0},
	{"key":"fire","name":"Ember Trail","level":70,"focus":45,"cooldown":12.0,"ammo":1,"damage":15.0,"speed":1.25,"secondary":0.20,"chains":0},
	{"key":"lightning","name":"Lightning Arrow","level":80,"focus":55,"cooldown":14.0,"ammo":1,"damage":20.0,"speed":1.60,"secondary":0.25,"chains":1},
	{"key":"super_lightning","name":"Super Lightning","level":90,"focus":65,"cooldown":16.0,"ammo":1,"damage":30.0,"speed":1.75,"secondary":0.30,"chains":2},
	{"key":"ultimate","name":"Aurora Tempest","level":100,"focus":100,"cooldown":0.0,"ammo":1,"damage":50.0,"speed":2.0,"secondary":0.40,"chains":0,"once":true}
]

# Shared by the inventory, nocked arrow and projectile so equipped finishes agree.
static func apply_arrow_finish(node:MeshInstance3D,id:int) -> void:
	if id==0 or not node.mesh:return
	var tint:Color={1:Color("8ed8df"),2:Color("bdcc97"),3:Color("c7afff")}.get(id,Color.WHITE)
	for index in range(node.mesh.get_surface_count()):
		var original:Material=node.mesh.surface_get_material(index)
		var material:StandardMaterial3D=original.duplicate() if original is StandardMaterial3D else StandardMaterial3D.new()
		material.albedo_color*=tint
		if id in [1,3]:
			material.emission_enabled=true;material.emission=tint;material.emission_energy_multiplier=.12 if id==1 else .42
		node.set_surface_override_material(index,material)

# One source of truth for the campaign economy, UI roadmap and upgrade transactions.
const CHAPTER_GEAR_GOALS := [5,12,20,25,30,35,40,45,50,55,60,65,70,75,80,85,90,95,99,100]
static func tier_start(tier:int) -> int:
	return [1,20,40,70][clampi(tier,0,3)]
static func chapter_tier(chapter:int) -> int:
	return 0 if chapter<=3 else (1 if chapter<=7 else (2 if chapter<=13 else 3))
static func chapter_power(chapter:int) -> String:
	if chapter>=20:return "ultimate"
	if chapter>=17:return "super_lightning"
	if chapter>=15:return "lightning"
	if chapter>=13:return "fire"
	if chapter>=11:return "pressure"
	if chapter>=9:return "gale"
	return "burst" if chapter>=3 else "normal"
static func stage_gear_goal(id:int) -> int:
	var chapter:int=id/5+1
	var finish:int=CHAPTER_GEAR_GOALS[chapter-1]
	var start:int=1 if chapter==1 else CHAPTER_GEAR_GOALS[chapter-2]
	var value:int=ceili(lerpf(start,finish,float(id%5+1)/5.0))
	for power in POWERS:
		if str(power.key)==chapter_power(chapter) and chapter in [9,11,13,15,17,20]:value=maxi(value,int(power.level))
	return value
static func upgrade_price(kind:String,level:int,tier:int=0) -> int:
	if kind=="character":return ceili(30+4*level+.20*level*level)
	if kind=="bow":return ceili([30,45,70,100][tier]+7*level+.40*level*level)
	return ceili([20,30,45,65][tier]+5*level+.28*level*level)
static func stage_coin_base(chapter:int) -> int:
	var n:int=maxi(0,chapter-1)
	return 350+150*n+32*n*n
