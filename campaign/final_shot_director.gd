extends Node

# Presentation only: projectile physics, challenge timers and rewards remain in Game.
const APPROACH_SECONDS := 0.35
const IMPACT_HOLD_SECONDS := 0.70
const RETURN_SECONDS := 0.35
const RESULTS_SECONDS := 1.30
const CANCEL_SECONDS := 0.25

var game: Node
var _phase := "idle"
var _camera: Camera3D
var _original_camera: Camera3D
var _stage_ref: WeakRef
var _projectile_ref: WeakRef
var _target_ref: WeakRef
var _original_transform := Transform3D.IDENTITY
var _original_fov := 40.0
var _phase_start := Transform3D.IDENTITY
var _impact_start := Transform3D.IDENTITY
var _impact_frame := Transform3D.IDENTITY
var _impact_position := Vector3.ZERO
var _last_direction := Vector3.FORWARD
var _static_frame := Transform3D.IDENTITY
var _elapsed := 0.0
var _confirmed := false
var _reduced_motion := false

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS

func is_active() -> bool:
	return _phase!="idle"

func _make_camera() -> bool:
	if not is_instance_valid(game) or not is_instance_valid(game.get("hero")):return false
	_original_camera=game.hero.camera
	if not is_instance_valid(_original_camera) or not is_instance_valid(game.get("stage")):return false
	_stage_ref=weakref(game.stage)
	_original_transform=_original_camera.global_transform
	_original_fov=_original_camera.fov
	_reduced_motion=bool(game.profile.data.settings.get("reduced_motion",false))
	if not is_instance_valid(_camera):
		_camera=Camera3D.new();_camera.name="FinalShotCamera";_camera.near=0.05;add_child(_camera)
	_camera.cull_mask=_original_camera.cull_mask
	_camera.far=_original_camera.far
	_camera.keep_aspect=_original_camera.keep_aspect
	_camera.attributes=_original_camera.attributes
	_camera.global_transform=_original_transform
	_camera.fov=_original_fov
	_camera.make_current()
	return true

func begin(projectile: Node3D,target: Node3D) -> void:
	if _confirmed or not is_instance_valid(projectile) or not is_instance_valid(target):return
	# A volley may generate several candidates; keep the first active camera stable.
	if _phase in ["approach","armed"]:return
	_cleanup(false)
	if not _make_camera():return
	_projectile_ref=weakref(projectile);_target_ref=weakref(target)
	_last_direction=_flight_direction(projectile,target.global_position)
	_impact_position=target.global_position
	_static_frame=_frame(_original_transform.origin,_impact_position)
	_phase_start=_original_transform;_elapsed=0.0;_confirmed=false
	_phase="approach"

func final_impact(targetpos: Vector3) -> void:
	if _confirmed:return
	if not is_instance_valid(_camera) or _phase=="idle":
		if not _make_camera():
			# A scene may have been removed by an exit; it must never open stale results.
			return
	_last_direction=_last_direction.normalized() if _last_direction.length_squared()>0.0001 else Vector3.FORWARD
	_impact_position=targetpos
	_impact_start=_camera.global_transform
	var side:=_last_direction.cross(Vector3.UP).normalized()
	if side.length_squared()<0.001:side=Vector3.RIGHT
	var desired:=targetpos-_last_direction*3.3+side*1.2+Vector3.UP*0.7
	if _reduced_motion:desired=_camera.global_position
	_impact_frame=_frame(_safe_position(targetpos,desired),targetpos)
	_confirmed=true;_elapsed=0.0;_phase="impact"
	_camera.make_current()

func cancel() -> void:
	if _phase=="idle":return
	_confirmed=false
	if not _same_stage() or not _gameplay_state() or not is_instance_valid(_camera) or not is_instance_valid(_original_camera):
		_cleanup(false);return
	_phase_start=_camera.global_transform;_elapsed=0.0;_phase="cancel"

func _process(delta: float) -> void:
	if _phase=="idle":return
	if not is_instance_valid(game) or not _same_stage():_cleanup(false);return
	if get_tree().paused or str(game.get("state"))=="paused":return
	if not _gameplay_state():_cleanup(false);return
	_elapsed+=maxf(0.0,delta)
	if _phase=="cancel":
		var blend:=_ease(_elapsed/CANCEL_SECONDS)
		_camera.global_transform=_phase_start.interpolate_with(_return_transform(),blend)
		_camera.fov=lerpf(_camera.fov,_return_fov(),blend)
		if _elapsed>=CANCEL_SECONDS:_cleanup(true)
		return
	if _phase=="impact":
		_update_impact()
		return
	var projectile: Node3D=_projectile_ref.get_ref() if _projectile_ref else null
	var target: Node3D=_target_ref.get_ref() if _target_ref else null
	if not is_instance_valid(projectile) or not is_instance_valid(target) or not bool(projectile.get("flying")):
		cancel();return
	_impact_position=target.global_position
	_last_direction=_flight_direction(projectile,_impact_position)
	var side:=_last_direction.cross(Vector3.UP).normalized()
	if side.length_squared()<0.001:side=Vector3.RIGHT
	var blend:=_ease(_elapsed/APPROACH_SECONDS)
	var desired_frame: Transform3D
	if _reduced_motion:
		# No flying-camera translation in reduced-motion mode.
		desired_frame=_static_frame
	else:
		var desired:=projectile.global_position-_last_direction*2.5+side*1.35+Vector3.UP*0.6
		var look_point:=projectile.global_position+_last_direction*2.0
		desired_frame=_frame(_safe_position(projectile.global_position,desired),look_point)
	_camera.global_transform=_phase_start.interpolate_with(desired_frame,blend)
	_camera.fov=lerpf(_original_fov,32.0 if _reduced_motion else 28.0,blend)
	# Root predicts a finishable collision in the last0.35seconds. A stale prediction
	# cannot capture control indefinitely if the target moved or the arrow missed.
	if _elapsed>1.2:cancel()

func _update_impact() -> void:
	if _elapsed<IMPACT_HOLD_SECONDS:
		_camera.global_transform=_impact_start.interpolate_with(_impact_frame,_ease(_elapsed/0.15))
		_camera.fov=lerpf(_camera.fov,32.0 if _reduced_motion else 28.0,clampf(_elapsed/0.15,0.0,1.0))
	elif _elapsed<IMPACT_HOLD_SECONDS+RETURN_SECONDS:
		var blend:=_ease((_elapsed-IMPACT_HOLD_SECONDS)/RETURN_SECONDS)
		_camera.global_transform=_impact_frame.interpolate_with(_return_transform(),blend)
		_camera.fov=lerpf(32.0 if _reduced_motion else 28.0,_return_fov(),blend)
	else:
		# Keep the final0.25seconds quiet for the impact sound's natural decay.
		if is_instance_valid(_original_camera):_original_camera.make_current()
	if _elapsed>=RESULTS_SECONDS:
		var owner: Node=game
		_cleanup(true)
		if is_instance_valid(owner) and str(owner.get("state"))=="finishing" and owner.has_method("complete_pending_result"):
			owner.complete_pending_result()

func _return_transform() -> Transform3D:
	return _original_camera.global_transform if is_instance_valid(_original_camera) else _original_transform

func _return_fov() -> float:
	return _original_camera.fov if is_instance_valid(_original_camera) else _original_fov

func _flight_direction(projectile: Node3D,targetpos: Vector3) -> Vector3:
	var velocity: Variant=projectile.get("velocity")
	if velocity is Vector3 and velocity.length_squared()>0.0001:return velocity.normalized()
	return (targetpos-projectile.global_position).normalized()

func _frame(position: Vector3,point: Vector3) -> Transform3D:
	var direction:=point-position
	if direction.length_squared()<0.0001:direction=_last_direction
	var up:=Vector3.UP
	if absf(direction.normalized().dot(up))>0.99:up=Vector3.RIGHT
	return Transform3D(Basis.looking_at(direction.normalized(),up),position)

func _safe_position(anchor: Vector3,desired: Vector3) -> Vector3:
	if not is_instance_valid(_camera) or not _camera.is_inside_tree():return desired
	var query:=PhysicsRayQueryParameters3D.create(anchor,desired,1)
	query.hit_from_inside=false
	if is_instance_valid(game.get("hero")):query.exclude=[game.hero.get_rid()]
	var hit: Dictionary=_camera.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position+hit.normal*0.22 if not hit.is_empty() else desired

func _same_stage() -> bool:
	return is_instance_valid(game) and _stage_ref!=null and is_instance_valid(_stage_ref.get_ref()) and _stage_ref.get_ref()==game.get("stage")

func _gameplay_state() -> bool:
	return str(game.get("state")) in ["playing","ready","finishing"]

func _ease(value: float) -> float:
	var t:=clampf(value,0.0,1.0)
	return t*t*(3.0-2.0*t)

func _cleanup(restore: bool) -> void:
	if restore and _same_stage() and _gameplay_state() and is_instance_valid(_original_camera):_original_camera.make_current()
	if is_instance_valid(_camera):
		# Clearing a non-current camera leaves Home's newly selected menu camera alone.
		_camera.queue_free()
	_camera=null;_projectile_ref=null;_target_ref=null;_stage_ref=null;_original_camera=null
	_phase="idle";_elapsed=0.0;_confirmed=false
