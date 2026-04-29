extends Area2D

const ARC_TIME := 0.5
const APEX_OFFSET := Vector2(0, -18)
const REST_OFFSET := Vector2(0, -10)

var _picked_up := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_play_pop_arc()

func _play_pop_arc() -> void:
	var start_pos := position
	var apex := start_pos + APEX_OFFSET
	var land := start_pos + REST_OFFSET
	var t := create_tween().set_trans(Tween.TRANS_QUAD)
	t.tween_property(self, "position", apex, ARC_TIME * 0.5).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position", land, ARC_TIME * 0.5).set_ease(Tween.EASE_IN)
	t.finished.connect(_start_bob)

func _start_bob() -> void:
	if _picked_up:
		return
	var rest_y := position.y
	var bob := create_tween().set_loops()
	bob.tween_property(self, "position:y", rest_y - 2, 0.6).set_trans(Tween.TRANS_SINE)
	bob.tween_property(self, "position:y", rest_y, 0.6).set_trans(Tween.TRANS_SINE)

func _on_body_entered(body: Node) -> void:
	if _picked_up:
		return
	if body.name == "Player":
		_picked_up = true
		var level := get_tree().current_scene
		if level != null and level.has_method("add_key"):
			level.add_key()
		queue_free()
