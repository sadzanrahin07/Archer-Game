extends RefCounted

# Preview access is separate from saved purchases and campaign gates.
const TEST_UNLOCK_CHARACTERS := false
const STARTER_COSTUME := 2
const CHARACTER_CAP := 100
const CAMPAIGN_STAGES := 100
const CHARACTERS := [
	{"name":"Enola","unlock_level":1,"unlock_chapter":6,"price":80000,"base_power":1.0,"base_sway":0.92,"draw_mult":1.04,"max_level":100,"model":"archer","trait":"8% less sway, 4% longer draw"},
	{"name":"Erin","unlock_level":1,"unlock_chapter":1,"price":0,"base_power":1.0,"base_sway":1.0,"draw_mult":1.0,"max_level":100,"model":"5351321668046832234","trait":"Balanced baseline"},
	{"name":"Maki","unlock_level":1,"unlock_chapter":11,"price":250000,"base_power":1.0,"base_sway":1.08,"draw_mult":0.94,"max_level":100,"model":"7714687722943833987","trait":"6% faster draw, 8% more sway"},
	{"name":"Jacky","unlock_level":1,"unlock_chapter":16,"price":900000,"base_power":1.0,"base_sway":0.85,"draw_mult":1.08,"max_level":100,"model":"7403294174270702488","trait":"15% less movement sway, 8% longer draw"}
]
const COSTUMES := [
	{"name":"Crimson","price":300000,"unlock_chapter":15,"mastery":1,"base_power":1.0,"base_sway":1.0,"max_level":100,"model":"3675109917025159411"},
	{"name":"Academy","price":12000,"unlock_chapter":2,"mastery":1,"base_power":1.0,"base_sway":1.0,"max_level":100,"model":"6370431923836766206"},
	{"name":"Erin · Base","price":0,"unlock_chapter":1,"mastery":1,"base_power":1.0,"base_sway":1.0,"max_level":100,"model":"7643054104406740418"},
	{"name":"Ceremonial","price":140000,"unlock_chapter":10,"mastery":1,"base_power":1.0,"base_sway":1.0,"max_level":100,"model":"7185862033116711190"},
	{"name":"Midnight","price":40000,"unlock_chapter":5,"mastery":1,"base_power":1.0,"base_sway":1.0,"max_level":100,"model":"1292382841793082181"},
	{"name":"Ash Hoodie","price":75000,"unlock_chapter":7,"mastery":1,"base_power":1.0,"base_sway":1.0,"max_level":100,"model":"5351321668046832234"}
]
const BOWS := [
	{"name":"Training Bow","tier":"Basic","tier_index":0,"max_level":100,"unlock_chapter":1,"price":0,"upgrade_rate":10,"multiplier":1.0,"speed":1.0,"draw":1.0,"mesh":"res://models/bow_frame_mesh.res","geometry":"standard","trait":"Balanced baseline"},
	{"name":"Elven Bow","tier":"Rare","tier_index":1,"max_level":100,"unlock_chapter":4,"price":35000,"upgrade_rate":12,"multiplier":1.0,"speed":1.08,"draw":1.05,"mesh":"res://campaign/equipment/elven.res","geometry":"elven","trait":"+8% flight speed, +5% draw time"},
	{"name":"Marble Bow","tier":"Epic","tier_index":2,"max_level":100,"unlock_chapter":9,"price":180000,"upgrade_rate":16,"multiplier":1.0,"speed":1.0,"draw":1.06,"sway_mult":0.90,"mesh":"res://campaign/equipment/marble.res","geometry":"marble","trait":"10% less sway, +6% draw time"},
	{"name":"Tempest Bow","tier":"Legendary","tier_index":3,"max_level":100,"unlock_chapter":14,"price":600000,"upgrade_rate":20,"multiplier":1.0,"speed":1.10,"draw":1.07,"mesh":"res://campaign/equipment/fantasy.res","geometry":"fantasy","trait":"+10% flight speed, +7% draw time"}
]
const ARROWS := [
	{"name":"Standard Arrow","tier":"Basic","tier_index":0,"max_level":100,"unlock_chapter":1,"price":0,"upgrade_rate":6,"power":10.0,"mesh":"res://models/arrow_mesh.res","tint":"default","trait":"Baseline"},
	{"name":"Runestone Arrow","tier":"Epic","tier_index":2,"max_level":100,"unlock_chapter":9,"price":120000,"upgrade_rate":10,"power":10.0,"speed":0.95,"damage_mult":1.06,"mesh":"res://campaign/equipment/marble_arrow.res","tint":"runestone","trait":"+6% damage, −5% flight speed"},
	{"name":"Hunter Arrow","tier":"Rare","tier_index":1,"max_level":100,"unlock_chapter":4,"price":25000,"upgrade_rate":8,"power":10.0,"speed":0.97,"damage_mult":1.04,"mesh":"res://models/arrow_mesh.res","tint":"hunter","trait":"+4% damage, −3% flight speed"},
	{"name":"Aurora Arrow","tier":"Legendary","tier_index":3,"max_level":100,"unlock_chapter":14,"price":450000,"upgrade_rate":12,"power":10.0,"speed":0.94,"damage_mult":1.08,"mesh":"res://campaign/equipment/marble_arrow.res","tint":"aurora","trait":"+8% damage, −6% flight speed"}
]
const POWERS := [
	{"key":"normal","name":"Normal Arrow","level":1,"focus":0,"cooldown":0.0,"ammo":1,"damage":1.0,"speed":1.0,"secondary":0.0,"chains":0,"price":0,"trial_id":-1},
	{"key":"burst","name":"3× Burst Shot","level":20,"focus":35,"cooldown":8.0,"ammo":3,"damage":1.4,"speed":1.15,"secondary":0.0,"chains":0,"price":0,"trial_id":-1},
	{"key":"gale","name":"Gale Shot","level":50,"focus":40,"cooldown":9.0,"ammo":1,"damage":3.0,"speed":1.45,"secondary":0.0,"chains":0,"price":0,"trial_id":-1},
	{"key":"pressure","name":"Pressure Wave","level":60,"focus":50,"cooldown":11.0,"ammo":1,"damage":3.8,"speed":1.45,"secondary":0.80,"chains":3,"price":0,"trial_id":55},
	{"key":"fire","name":"Ember Trail","level":70,"focus":50,"cooldown":11.0,"ammo":1,"damage":4.5,"speed":1.35,"secondary":0.90,"chains":0,"price":0,"trial_id":65},
	{"key":"lightning","name":"Lightning Arrow","level":80,"focus":60,"cooldown":12.0,"ammo":1,"damage":6.0,"speed":1.70,"secondary":0.85,"chains":2,"price":0,"trial_id":75},
	{"key":"super_lightning","name":"Super Lightning","level":90,"focus":75,"cooldown":15.0,"ammo":1,"damage":8.5,"speed":1.85,"secondary":0.95,"chains":3,"price":0,"trial_id":85},
	{"key":"ultimate","name":"Aurora Tempest","level":100,"focus":100,"cooldown":0.0,"ammo":1,"damage":16.0,"speed":2.10,"secondary":1.00,"chains":4,"once":true,"price":0,"trial_id":95}
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
const CHAPTER_GEAR_GOALS := [5,10,20,25,30,35,40,45,50,55,60,65,70,75,80,85,90,95,99,100]
static func tier_start(tier:int) -> int:
	return [1,20,40,70][clampi(tier,0,3)]
static func chapter_tier(chapter:int) -> int:
	return 0 if chapter<=3 else (1 if chapter<=7 else (2 if chapter<=13 else 3))
static func chapter_power(chapter:int) -> String:
	if chapter >= 20:return "ultimate"
	if chapter >= 18:return "super_lightning"
	if chapter >= 16:return "lightning"
	if chapter >= 14:return "fire"
	if chapter >= 12:return "pressure"
	if chapter >= 9:return "gale"
	return "burst" if chapter >= 3 else "normal"

static func stage_gear_goal(id:int) -> int:
	var chapter:int=id/5+1
	if chapter == 20:return 100
	var finish:int=CHAPTER_GEAR_GOALS[chapter-1]
	var start:int=1 if chapter==1 else CHAPTER_GEAR_GOALS[chapter-2]
	return start+ceili(float(finish-start)*float(id%5+1)/5.0)

static func upgrade_price(kind: String, level: int, _tier: int = 0) -> int:
	if level < 1 or level >= 100: return 0
	match kind:
		"bow":
			return 5 * int(ceili(float(5000 + 800 * level + 80 * level * level) / 500.0))
		"arrow":
			return 5 * int(ceili(float(3500 + 600 * level + 60 * level * level) / 500.0))
		"character", "archer":
			return 5 * int(ceili(float(3000 + 400 * level + 35 * level * level) / 500.0))
	return 0

static func stage_reward_base(chapter: int) -> int:
	var n: int = maxi(0, chapter - 1)
	return 600 + 180 * n + 36 * n * n

static func stage_coin_base(chapter: int) -> int:
	return stage_reward_base(chapter)

static func stage_clear_reward(chapter: int, stars: int) -> int:
	var r: int = stage_reward_base(chapter)
	match stars:
		1: return int(round(float(r) * 1.00))
		2: return int(round(float(r) * 1.25))
		3: return int(round(float(r) * 1.50))
		_: return int(round(float(r) * 1.00))

static func chapter_clear_bonus(chapter: int) -> int:
	return stage_reward_base(chapter)

static func stage_replay_reward(chapter: int, stars: int) -> int:
	var r: int = stage_reward_base(chapter)
	var mult: float = 0.35 if stars == 1 else (0.45 if stars == 2 else 0.55)
	return int(floor(float(r) * mult / 10.0) * 10.0)
