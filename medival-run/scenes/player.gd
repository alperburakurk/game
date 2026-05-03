extends CharacterBody2D

const SPEED = 200.0
const JUMP_VELOCITY = -400.0
const STAIRS_SPEED = 120.0
const STAIRS_TILE_TYPE = "stairs"
const SPIKES_TILE_TYPE = "spikes"
# Movement speed multiplier while attacking. 1.0 = full speed, 0.0 = locked in place.
# Slightly reduced gives the swing a little weight without feeling sluggish.
const ATTACK_MOVE_MULT = 0.75

@export var hurt_knockback_speed: float = 220.0
@export var hurt_knockback_decel: float = 1200.0
@export var hurt_recoil_duration: float = 0.14
@export var hurt_flash_duration: float = 0.08
@export var hurt_flash_modulate: Color = Color(1, 0.82, 0.82)

@onready var sprite = $AnimatedSprite2D
@onready var attack_area = $AttackArea
@onready var health_bar = get_tree().current_scene.get_node("UI/HealthBar")
@onready var tile_map_layer: TileMapLayer = get_tree().current_scene.get_node_or_null("TileMapLayer")

var is_attacking := false
var facing_direction := 1

var max_health := 6
var health := 6
var is_dead := false

var _hurt_recoil_remaining: float = 0.0


func _ready():
	attack_area.monitoring = false
	health_bar.max_value = max_health
	health_bar.value = health


func _physics_process(delta):
	if is_dead:
		return

	if _is_on_spikes_tile():
		die()
		return

	var on_stairs := _is_on_stairs_tile()

	if _hurt_recoil_remaining > 0:
		if not is_on_floor() and not on_stairs:
			velocity += get_gravity() * delta
		velocity.x = move_toward(velocity.x, 0, hurt_knockback_decel * delta)
		move_and_slide()
		_hurt_recoil_remaining = maxf(0.0, _hurt_recoil_remaining - delta)
		return

	if not is_on_floor() and not on_stairs:
		velocity += get_gravity() * delta

	var direction = Input.get_axis("ui_left", "ui_right")
	var climb_direction = Input.get_axis("ui_up", "ui_down")

	if Input.is_action_just_pressed("attack") and not is_attacking:
		attack()

	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not is_attacking and not on_stairs:
		velocity.y = JUMP_VELOCITY

	if on_stairs and not is_attacking:
		velocity.y = climb_direction * STAIRS_SPEED
		if direction != 0:
			velocity.x = direction * SPEED
			facing_direction = direction
			sprite.flip_h = direction < 0
			attack_area.position.x = abs(attack_area.position.x) * facing_direction
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)

		if climb_direction != 0:
			sprite.play("ladder_grab")
		elif direction != 0:
			sprite.play("run")
		else:
			sprite.play("idle")

		move_and_slide()
		return

	if is_attacking:
		# Keep momentum and allow steering during the swing, but don't flip
		# facing so the attack hitbox stays aimed where the swing started.
		if direction != 0:
			velocity.x = direction * SPEED * ATTACK_MOVE_MULT
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED * ATTACK_MOVE_MULT)
	else:
		if direction != 0:
			velocity.x = direction * SPEED
			facing_direction = direction
			sprite.flip_h = direction < 0
			attack_area.position.x = abs(attack_area.position.x) * facing_direction
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)

		if not is_on_floor():
			if velocity.y < 0:
				sprite.play("jump")
			else:
				sprite.play("fall")
		elif direction != 0:
			sprite.play("run")
		else:
			sprite.play("idle")

	move_and_slide()


func attack():
	is_attacking = true

	attack_area.monitoring = true
	sprite.play("attack")

	await get_tree().physics_frame

	for body in attack_area.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(1, self)

	await sprite.animation_finished

	attack_area.monitoring = false
	is_attacking = false


func take_damage(amount: int = 1, attacker: Node2D = null):
	if is_dead:
		return

	health -= amount
	health = max(health, 0)
	health_bar.value = health

	velocity.x = _knockback_sign_from_attacker(attacker) * hurt_knockback_speed
	_hurt_recoil_remaining = hurt_recoil_duration
	_flash_hurt()

	if health <= 0:
		die()
	else:
		is_attacking = false
		attack_area.monitoring = false
		sprite.play("hurt_effect")


func _knockback_sign_from_attacker(attacker: Node2D) -> float:
	if attacker == null:
		return signf(float(-facing_direction))
	var s := signf(global_position.x - attacker.global_position.x)
	if s == 0.0:
		s = signf(attacker.scale.x)
	if s == 0.0:
		s = 1.0
	return s


func _flash_hurt() -> void:
	sprite.modulate = hurt_flash_modulate
	await get_tree().create_timer(hurt_flash_duration).timeout
	if is_instance_valid(sprite):
		sprite.modulate = Color.WHITE


func die():
	is_dead = true
	health = 0
	if health_bar != null:
		health_bar.value = 0
	_hurt_recoil_remaining = 0.0
	velocity = Vector2.ZERO
	attack_area.monitoring = false
	sprite.modulate = Color.WHITE
	sprite.play("death")
	await sprite.animation_finished


func is_player_dead():
	return is_dead


func _is_on_stairs_tile() -> bool:
	if tile_map_layer == null:
		return false

	# Sample near the player's feet so floor stairs are detected reliably.
	var sample_pos := global_position + Vector2(0, 8)
	var local_pos := tile_map_layer.to_local(sample_pos)
	var cell := tile_map_layer.local_to_map(local_pos)
	var tile_data := tile_map_layer.get_cell_tile_data(cell)

	if tile_data == null:
		return false

	var tile_type = tile_data.get_custom_data("tile_type")
	return tile_type != null and String(tile_type).to_lower() == STAIRS_TILE_TYPE


func _is_on_spikes_tile() -> bool:
	if tile_map_layer == null:
		return false

	# Sample centre, left edge, and right edge near the player's feet so
	# detection is reliable even when only partially overlapping a spike tile.
	var offsets: Array[Vector2] = [Vector2(0, 8), Vector2(-6, 8), Vector2(6, 8)]
	for offset in offsets:
		var sample_pos: Vector2 = global_position + offset
		var cell := tile_map_layer.local_to_map(tile_map_layer.to_local(sample_pos))
		var tile_data := tile_map_layer.get_cell_tile_data(cell)
		if tile_data == null:
			continue
		var tile_type = tile_data.get_custom_data("tile_type")
		if tile_type != null and String(tile_type).to_lower() == SPIKES_TILE_TYPE:
			return true
	return false
