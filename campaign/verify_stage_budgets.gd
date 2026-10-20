extends SceneTree
const Target=preload("res://campaign/target.gd")
func _initialize():run.call_deferred()
func run():
 var definitions:Array=JSON.parse_string(FileAccess.get_file_as_string("res://campaign/stages.json"))
 var target=Target.new();var worst:=0.0;var worst_stage:=0
 for row in definitions:
  var power:float=maxf(10.0,float(row.required_power));var needed:=0
  for i in range(row.materials.size()):
   target.material_kind=row.materials[i]
   needed+=int(row.hits_required) if target.material_kind=="ring" else ceili(float(row.target_hp[i])/(power*target.damage_multiplier(2)))
  assert(needed<=int(row.arrows),"Every stage needs a feasible full-draw centre-hit ammo budget")
  var ratio:=float(needed)/float(row.arrows)
  if ratio>worst:worst=ratio;worst_stage=int(row.id)+1
 target.free();print("100 STAGE AMMO BUDGET PASS: minimum gate or starter10; worst ",snappedf(worst*100,.1),"% at stage ",worst_stage);quit()
