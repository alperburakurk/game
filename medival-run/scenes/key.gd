extends Area2D

@export var pickup_delay: float = 1.0
@export var arc_time: float = 0.5
@export var apex_offset: Vector2 = Vector2(8, -18)
@export var rest_offset: Vector2 = Vector2(16, 4)

var _picked_up := false
var _popped := false
var _pickup_armed := false

func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)

func pop(direction: int = 1) -> void:
	if _popped or _picked_up:
		return
	_popped = true
	var dir := -1.0 if direction < 0 else 1.0
	var start_pos := position
	var apex := start_pos + Vector2(apex_offset.x * dir, apex_offset.y)
	var land := start_pos + Vector2(rest_offset.x * dir, rest_offset.y)
	var t := create_tween().set_trans(Tween.TRANS_QUAD)
	t.tween_property(self, "position", apex, arc_time * 0.5).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position", land, arc_time * 0.5).set_ease(Tween.EASE_IN)
	t.finished.connect(_on_landed)
	_arm_pickup_after_delay()

func _arm_pickup_after_delay() -> void:
	if pickup_delay <= 0.0:
		_arm_pickup()
		return
	var timer := get_tree().create_timer(pickup_delay)
	timer.timeout.connect(_arm_pickup)

func _arm_pickup() -> void:
	if _pickup_armed or _picked_up:
		return
	_pickup_armed = true
	for body in get_overlapping_bodies():
		if _is_player(body):
			_pickup()
			return

func _on_landed() -> void:
	if _picked_up:
		return
	if _pickup_armed:
		for body in get_overlapping_bodies():
			if _is_player(body):
				_pickup()
				return
	_start_bob()

func _start_bob() -> void:
	if _picked_up:
		return
	var rest_y := position.y
	var bob := create_tween().set_loops()
	bob.tween_property(self, "position:y", rest_y - 2, 0.6).set_trans(Tween.TRANS_SINE)
	bob.tween_property(self, "position:y", rest_y, 0.6).set_trans(Tween.TRANS_SINE)

func _on_body_entered(body: Node) -> void:
	if _picked_up or not _pickup_armed:
		return
	if _is_player(body):
		_pickup()

func _pickup() -> void:
	if _picked_up or not _pickup_armed:
		return
	_picked_up = true
	var level := get_tree().current_scene
	if level != null and level.has_method("add_key"):
		level.add_key()
	queue_free()

func _is_player(body: Node) -> bool:
	return body != null and (body.name == "Player" or body.is_in_group("player"))
