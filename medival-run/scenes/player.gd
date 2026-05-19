extends CharacterBody2D

enum AttackKind { NONE, STANDARD, DASH }

const SPEED = 200.0
const JUMP_VELOCITY = -400.0
const STAIRS_SPEED = 120.0
const STAIRS_TILE_TYPE = "stairs"
const SPIKES_TILE_TYPE = "spikes"
const STANDARD_HITBOX_OFFSET_X = 10.0
const DASH_HITBOX_OFFSET_X = 14.0

@export var standard_attack_damage := 2
@export var dash_attack_damage := 1
@export var standard_attack_damage_delay: float = 0.5
@export var dash_attack_damage_delay: float = 1.0
@export_range(0.0, 1.0, 0.05) var dash_attack_move_mult: float = 0.5
@export var hurt_knockback_speed: float = 220.0
@export var hurt_knockback_decel: float = 1200.0
@export var hurt_recoil_duration: float = 0.14
@export var hurt_flash_duration: float = 0.08
@export var hurt_flash_modulate: Color = Color(1, 0.82, 0.82)

@onready var sprite = $AnimatedSprite2D
@onready var attack_area = $AttackArea
@onready var health_bar = get_tree().current_scene.get_node("UI/HealthBar")
@onready var tile_map_layer: TileMapLayer = get_tree().current_scene.get_node_or_null("TileMapLayer")

var attack_kind := AttackKind.NONE
var facing_direction := 1
var attack_facing := 1

var max_health := 6
var health := 6
var is_dead := false

var _hurt_recoil_remaining: float = 0.0


func _ready():
	attack_area.monitoring = false
	health_bar.max_value = max_health
	health_bar.value = health
	_update_facing(facing_direction)


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

	if Input.is_action_just_pressed("attack") and attack_kind == AttackKind.NONE:
		if direction != 0:
			dash_attack(direction)
		else:
			standard_attack()

	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and attack_kind == AttackKind.NONE and not on_stairs:
		velocity.y = JUMP_VELOCITY

	if on_stairs and attack_kind == AttackKind.NONE:
		velocity.y = climb_direction * STAIRS_SPEED
		if direction != 0:
			velocity.x = direction * SPEED
			_update_facing(direction)
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

	if attack_kind == AttackKind.STANDARD:
		velocity.x = 0
	elif attack_kind == AttackKind.DASH:
		var dash_speed := SPEED * dash_attack_move_mult
		if direction != 0:
			velocity.x = direction * dash_speed
		else:
			velocity.x = move_toward(velocity.x, 0, dash_speed)
	else:
		if direction != 0:
			velocity.x = direction * SPEED
			_update_facing(direction)
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


func _update_facing(dir: int) -> void:
	facing_direction = dir
	sprite.flip_h = dir < 0
	if attack_kind == AttackKind.NONE:
		attack_area.position.x = STANDARD_HITBOX_OFFSET_X * facing_direction


func _lock_attack_facing(dir: int, hitbox_offset_x: float) -> void:
	attack_facing = dir
	facing_direction = dir
	sprite.flip_h = dir < 0
	attack_area.position.x = hitbox_offset_x * attack_facing


func _cancel_attack() -> void:
	attack_kind = AttackKind.NONE
	attack_area.monitoring = false


func standard_attack() -> void:
	_run_attack(
		&"attack",
		standard_attack_damage,
		AttackKind.STANDARD,
		STANDARD_HITBOX_OFFSET_X,
		facing_direction,
		standard_attack_damage_delay
	)


func dash_attack(dir: int) -> void:
	_run_attack(
		&"dash attack",
		dash_attack_damage,
		AttackKind.DASH,
		DASH_HITBOX_OFFSET_X,
		dir,
		dash_attack_damage_delay
	)


func _run_attack(
	animation: StringName,
	damage: int,
	kind: AttackKind,
	hitbox_offset_x: float,
	lock_dir: int,
	damage_delay: float
) -> void:
	attack_kind = kind
	_lock_attack_facing(lock_dir, hitbox_offset_x)
	attack_area.monitoring = false
	sprite.play(animation)

	if damage_delay > 0.0:
		await get_tree().create_timer(damage_delay).timeout

	if attack_kind != kind:
		return

	if sprite.animation != animation or not sprite.is_playing():
		attack_kind = AttackKind.NONE
		return

	attack_area.monitoring = true

	var hit_targets: Array = []
	while attack_kind == kind:
		await get_tree().physics_frame
		for body in attack_area.get_overlapping_bodies():
			if body in hit_targets:
				continue
			if body.has_method("take_damage"):
				body.take_damage(damage, self)
				hit_targets.append(body)
		if sprite.animation != animation:
			break
		if not sprite.is_playing():
			break

	if attack_kind == kind:
		attack_area.monitoring = false
		attack_kind = AttackKind.NONE


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
		_cancel_attack()
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
	_cancel_attack()
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
