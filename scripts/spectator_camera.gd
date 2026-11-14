extends Camera3D
## Free observer camera; intentionally independent of simulation time.

const Forest = preload("res://scripts/forest.gd")

var follow_target: Node3D = null
var fly_speed: float = 15.0
var _yaw: float = 0.0
var _pitch: float = -0.30
var _follow_offset := Vector3(0, 5, 10)

func _ready() -> void:
	position = Vector3(9, 12, 26)
	look_at(Vector3(0, 1, 0))
	_yaw = rotation.y
	_pitch = rotation.x
	far = 350.0
	near = 0.1
	fov = 65.0

func focus_position(point: Vector3) -> void:
	position = point + _follow_offset
	look_at(point + Vector3.UP)
	_yaw = rotation.y
	_pitch = rotation.x

func restore_pose(point: Vector3, orientation: Vector3) -> void:
	position = point
	rotation = orientation
	_yaw = rotation.y
	_pitch = rotation.x

func restore_follow(target: Node3D) -> void:
	follow_target = target
	_follow_offset = position - target.global_position

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * 0.003
		_pitch = clampf(_pitch - event.relative.y * 0.003, -1.45, 1.45)
		rotation = Vector3(_pitch, _yaw, 0)
		if is_instance_valid(follow_target):
			_follow_offset = basis.z * 10.0 + Vector3.UP * 3.0

func _process(delta: float) -> void:
	if is_instance_valid(follow_target):
		position = position.lerp(follow_target.global_position + _follow_offset, 1.0 - exp(-delta * 6.0))
		look_at(follow_target.global_position + Vector3.UP)
		_yaw = rotation.y
		_pitch = rotation.x
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var direction := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): direction -= basis.z
	if Input.is_physical_key_pressed(KEY_S): direction += basis.z
	if Input.is_physical_key_pressed(KEY_A): direction -= basis.x
	if Input.is_physical_key_pressed(KEY_D): direction += basis.x
	if Input.is_physical_key_pressed(KEY_Q): direction -= Vector3.UP
	if Input.is_physical_key_pressed(KEY_E): direction += Vector3.UP
	if direction.length_squared() > 0:
		follow_target = null
		var boost: float = 3.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0
		position += direction.normalized() * fly_speed * boost * delta
		position.x = clampf(position.x, -85, 85)
		position.z = clampf(position.z, -85, 85)
		position.y = clampf(position.y, Forest.height_at(position.x, position.z) + 1.5, 90)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
