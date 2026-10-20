extends AnimationTree

var playback: AnimationNodeStateMachinePlayback

func _ready() -> void:
	active = true
	playback = get("parameters/playback")

func state_transition(state_name: String) -> void:
	if not playback:
		playback = get("parameters/playback")
	if playback:
		playback.travel(state_name)

func direct_sub_state_transition(sub_machine_name: String, anim_name: String) -> void:
	var sub_playback: AnimationNodeStateMachinePlayback = get("parameters/" + sub_machine_name + "/playback")
	if sub_playback:
		sub_playback.travel(anim_name)

func inactive_movement(value: float) -> void:
	set("parameters/Inactive/movement/blend_position", value)

func active_movement(value: Vector2) -> void:
	set("parameters/Active/movement/blend_position", value)

func aim_draw() -> void:
	set("parameters/Active/aim os/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	var sm: AnimationNodeStateMachinePlayback = get("parameters/Active/aim sm/playback")
	if sm:
		sm.travel("draw")

func aim_release() -> void:
	var sm: AnimationNodeStateMachinePlayback = get("parameters/Active/aim sm/playback")
	if sm:
		sm.travel("release")

func aim_abort() -> void:
	set("parameters/Active/aim os/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
