extends RefCounted
var active_attackers:Array[Node]=[]
var waiting:Array[Node]=[]
var approach_lease:=0.0
const MAX_ATTACKERS:=1
func can_attack(enemy:Node) -> bool:
	return active_attackers.has(enemy)
func reserve_attack(enemy:Node) -> bool:
	active_attackers=active_attackers.filter(func(n):return is_instance_valid(n) and n.get("completed")!=true)
	waiting=waiting.filter(func(n):return is_instance_valid(n) and n.get("completed")!=true)
	if active_attackers.has(enemy):return true
	if not waiting.has(enemy):waiting.append(enemy)
	if active_attackers.is_empty() and waiting.front()==enemy:
		waiting.pop_front();active_attackers.append(enemy);approach_lease=0;return true
	return false
func staging_position(enemy:Node,player:Node3D) -> Vector3:
	var index:int=maxi(0,waiting.find(enemy))
	var angle:float=-PI*.5+float(index)*2.399963
	return player.global_position+Vector3(cos(angle),0,sin(angle))*(4.2+float(index%2)*.6)
func release_attack(enemy:Node) -> void:
	active_attackers.erase(enemy);waiting.erase(enemy)
func clear() -> void:
	active_attackers.clear();waiting.clear()

func advance(delta:float) -> void:
	if active_attackers.is_empty():return
	var enemy:Node=active_attackers[0]
	if not is_instance_valid(enemy):active_attackers.clear();return
	if int(enemy.current_state)==1:
		approach_lease+=delta
		if approach_lease>4:
			release_attack(enemy);waiting.append(enemy);approach_lease=0
	else:approach_lease=0
