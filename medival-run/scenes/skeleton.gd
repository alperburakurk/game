extends CharacterBody2D

@export var patrol_distance: float = 200.0
@export var speed: float = 60.0
@export var hit_knockback_speed: float = 180.0
@export var hit_knockback_decel: float = 1200.0
@export var hit_recoil_duration: float = 0.12
@export var hit_invulnerability_duration: float = 0.15
@export var hit_flash_duration: float = 0.06
@export var hit_flash_modulate: Color = Color(1, 0.82, 0.82)

const GRAVITY = 980.0

@onready var sprite = $AnimatedSprite2D
@onready var attack_range = $AttackRange

var direction := 1
var start_x: float
var turn_cooldown := 0.0

var health := 5
var is_dead := false
var player_in_range := false
var is_attacking := false

var _hit_invuln_remaining: float = 0.0
var _hit_recoil_remaining: float = 0.0


func _ready():
	start_x = global_position.x
	sprite.play("walk")


func _physics_process(delta):
	if is_dead:
		return

	_hit_invuln_remaining = maxf(0.0, _hit_invuln_remaining - delta)

	if _hit_recoil_remaining > 0:
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		velocity.x = move_toward(velocity.x, 0, hit_knockback_decel * delta)
		move_and_slide()
		_hit_recoil_remaining = maxf(0.0, _hit_recoil_remaining - delta)
		return

	if is_attacking:
		return

	if player_in_range:
		var player = get_player_in_range()
		if player != null and player.has_method("is_player_dead") and not player.is_player_dead():
			attack()
		else:
			player_in_range = false
		return

	if turn_cooldown > 0:
		turn_cooldown -= delta

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	velocity.x = direction * speed
	sprite.flip_h = direction < 0

	move_and_slide()

	if turn_cooldown <= 0:
		if is_on_wall():
			turn_around()
		elif is_on_floor() and not has_ground_ahead():
			turn_around()
		elif global_position.x > start_x + patrol_distance:
			direction = -1
			turn_cooldown = 0.2
		elif global_position.x < start_x - patrol_distance:
			direction = 1
			turn_cooldown = 0.2


func get_player_in_range():
	for body in attack_range.get_overlapping_bodies():
		if body.name == "Player":
			return body
	return null


func turn_around():
	direction *= -1
	turn_cooldown = 0.2


func has_ground_ahead() -> bool:
	var space_state = get_world_2d().direct_space_state

	var ray_origin = global_position + Vector2(direction * 30, 10)
	var ray_target = ray_origin + Vector2(0, 80)

	var query = PhysicsRayQueryParameters2D.create(ray_origin, ray_target)
	query.exclude = [self]

	var result = space_state.intersect_ray(query)
	return result.size() > 0


func attack():
	is_attacking = true
	velocity = Vector2.ZERO
	sprite.play("attack")

	await get_tree().create_timer(0.75).timeout

	for body in attack_range.get_overlapping_bodies():
		if body.name == "Player" and body.has_method("take_damage"):
			if body.has_method("is_player_dead") and not body.is_player_dead():
				body.take_damage(1, self)

	await sprite.animation_finished
	is_attacking = false


func take_damage(_amount: int = 1, attacker: Node2D = null):
	if is_dead or _hit_invuln_remaining > 0:
		return

	health -= 1
	velocity.x = _knockback_sign_from_attacker(attacker) * hit_knockback_speed
	_hit_invuln_remaining = hit_invulnerability_duration
	_hit_recoil_remaining = hit_recoil_duration
	_flash_hit()

	if health <= 0:
		die()


func _knockback_sign_from_attacker(attacker: Node2D) -> float:
	if attacker == null:
		return 1.0
	var s := signf(global_position.x - attacker.global_position.x)
	if s == 0.0:
		s = signf(attacker.scale.x)
	if s == 0.0:
		s = 1.0
	return s


func _flash_hit() -> void:
	sprite.modulate = hit_flash_modulate
	await get_tree().create_timer(hit_flash_duration).timeout
	if is_instance_valid(sprite):
		sprite.modulate = Color.WHITE


func die():
	is_dead = true
	is_attacking = false
	player_in_range = false
	velocity = Vector2.ZERO
	_hit_recoil_remaining = 0.0
	sprite.modulate = Color.WHITE
	sprite.play("death")
	await sprite.animation_finished
	queue_free()


func _on_attack_range_body_entered(body):
	if body.name == "Player":
		if body.has_method("is_player_dead") and not body.is_player_dead():
			player_in_range = true


func _on_attack_range_body_exited(body):
	if body.name == "Player":
		player_in_range = false
