extends Node2D

const COLOR_PLAYER_BODY := Color(0.2, 0.6, 1.0, 0.35)
const COLOR_PLAYER_ATTACK := Color(1.0, 0.45, 0.1, 0.55)
const COLOR_ENEMY_BODY := Color(1.0, 0.25, 0.25, 0.35)
const COLOR_ENEMY_ATTACK := Color(1.0, 0.1, 0.55, 0.55)
const COLOR_INTERACT := Color(0.2, 1.0, 0.45, 0.45)
const COLOR_PICKUP := Color(1.0, 0.95, 0.2, 0.4)
const COLOR_PROP := Color(0.65, 0.4, 0.15, 0.35)
const COLOR_OTHER := Color(0.75, 0.75, 0.75, 0.3)

var level: Node2D
var player: CharacterBody2D

var _info_label: Label
var _shape_count := 0


func setup(level_node: Node2D, player_node: CharacterBody2D) -> void:
	level = level_node
	player = player_node
	z_index = 100

	var canvas := CanvasLayer.new()
	canvas.layer = 100
	level.add_child(canvas)

	_info_label = Label.new()
	_info_label.position = Vector2(8, 8)
	_info_label.add_theme_font_size_override("font_size", 13)
	_info_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_info_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_info_label.add_theme_constant_override("shadow_offset_x", 1)
	_info_label.add_theme_constant_override("shadow_offset_y", 1)
	canvas.add_child(_info_label)


func _process(_delta: float) -> void:
	queue_redraw()
	_update_info_label()


func _draw() -> void:
	if level == null:
		return
	_shape_count = 0
	_draw_shapes_in(level)


func _draw_shapes_in(node: Node) -> void:
	if node is CollisionShape2D:
		_draw_collision_shape(node as CollisionShape2D)
	for child in node.get_children():
		_draw_shapes_in(child)


func _draw_collision_shape(collision: CollisionShape2D) -> void:
	var shape := collision.shape
	if shape == null:
		return

	var color := _color_for_collision(collision)
	var outline := Color(color.r, color.g, color.b, minf(color.a + 0.35, 1.0))
	var xf := collision.global_transform

	if shape is RectangleShape2D:
		var rect_shape := shape as RectangleShape2D
		var half := rect_shape.size * 0.5
		var corners := PackedVector2Array([
			Vector2(-half.x, -half.y),
			Vector2(half.x, -half.y),
			Vector2(half.x, half.y),
			Vector2(-half.x, half.y),
		])
		_draw_global_polygon(corners, xf, color, outline)
	elif shape is CircleShape2D:
		var circle := shape as CircleShape2D
		var center := to_local(xf * Vector2.ZERO)
		var radius := circle.radius * maxf(absf(xf.x.x), absf(xf.y.y))
		draw_circle(center, radius, color)
		draw_arc(center, radius, 0.0, TAU, 32, outline, 1.0)
		_shape_count += 1
	elif shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		var half_height := maxf((capsule.height - capsule.radius * 2.0) * 0.5, 0.0)
		var r := capsule.radius
		var points := PackedVector2Array([
			Vector2(-r, -half_height),
			Vector2(r, -half_height),
			Vector2(r, half_height),
			Vector2(-r, half_height),
		])
		_draw_global_polygon(points, xf, color, outline)


func _draw_global_polygon(local_points: PackedVector2Array, xf: Transform2D, fill: Color, outline: Color) -> void:
	var global_points := PackedVector2Array()
	for point in local_points:
		global_points.append(to_local(xf * point))
	if global_points.size() < 3:
		return
	draw_colored_polygon(global_points, fill)
	global_points.append(global_points[0])
	draw_polyline(global_points, outline, 1.0)
	_shape_count += 1


func _color_for_collision(collision: CollisionShape2D) -> Color:
	var parent := collision.get_parent()
	if parent == null:
		return COLOR_OTHER

	if parent.name == "AttackArea":
		var color := COLOR_PLAYER_ATTACK
		if parent is Area2D and not (parent as Area2D).monitoring:
			color.a *= 0.35
		return color
	if parent.name == "AttackRange":
		return COLOR_ENEMY_ATTACK
	if parent.name == "InteractArea":
		return COLOR_INTERACT

	var current: Node = parent
	while current != null:
		if current.name == "Player":
			return COLOR_PLAYER_BODY
		if current.name == "Skeleton":
			return COLOR_ENEMY_BODY
		if current is Area2D:
			return COLOR_PICKUP
		if current is RigidBody2D:
			return COLOR_PROP
		current = current.get_parent()

	return COLOR_OTHER


func _update_info_label() -> void:
	if _info_label == null:
		return

	var lines: PackedStringArray = ["=== DEBUG MODE ===", ""]

	lines.append("Hitboxes: %d shapes" % _shape_count)
	lines.append("Legend: blue=player  orange=player atk  red=enemy  pink=enemy atk")
	lines.append("        green=interact  yellow=pickup  brown=prop")
	lines.append("")

	if player != null:
		lines.append("--- Player ---")
		lines.append("HP: %d / %d" % [player.health, player.max_health])
		lines.append("Velocity: (%.0f, %.0f)" % [player.velocity.x, player.velocity.y])
		lines.append("Facing: %d   AttackFacing: %d" % [player.facing_direction, player.attack_facing])
		lines.append("Attack: %s" % _attack_kind_name(player.attack_kind))
		if player.has_node("AttackArea"):
			var attack_area: Area2D = player.get_node("AttackArea")
			lines.append("AttackArea monitoring: %s" % str(attack_area.monitoring))
			lines.append("AttackArea pos: (%.1f, %.1f)" % [attack_area.position.x, attack_area.position.y])
		lines.append("On floor: %s" % str(player.is_on_floor()))
		lines.append("Damage delays: std=%.2fs dash=%.2fs" % [player.standard_attack_damage_delay, player.dash_attack_damage_delay])
		lines.append("")

	var skeleton := level.get_node_or_null("Floor/Skeleton") if level != null else null
	if skeleton != null:
		lines.append("--- Skeleton ---")
		lines.append("HP: %d" % skeleton.health)
		lines.append("Dead: %s" % str(skeleton.is_dead))
		lines.append("Player in range: %s" % str(skeleton.player_in_range))
		lines.append("Attacking: %s" % str(skeleton.is_attacking))
		lines.append("Velocity: (%.0f, %.0f)" % [skeleton.velocity.x, skeleton.velocity.y])
		lines.append("")

	var chest := level.get_node_or_null("Chest") if level != null else null
	if chest != null and chest.has_method("_open"):
		lines.append("--- Chest ---")
		lines.append("State: %s" % _chest_state_name(chest.state))
		lines.append("Player in range: %s" % str(chest.player_in_range))
		lines.append("")

	lines.append("--- Level ---")
	lines.append("Keys: %d   Coins: %d" % [level.key_count, level.coin_count])
	lines.append("Game over: %s" % str(level.game_over))

	_info_label.text = "\n".join(lines)


func _attack_kind_name(kind: int) -> String:
	match kind:
		0:
			return "NONE"
		1:
			return "STANDARD"
		2:
			return "DASH"
		_:
			return "UNKNOWN"


func _chest_state_name(state: int) -> String:
	match state:
		0:
			return "CLOSED"
		1:
			return "OPENING"
		2:
			return "OPEN"
		_:
			return "UNKNOWN"
