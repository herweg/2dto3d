extends Node2D

var weapon_id: String = "base"
var damage: float = 1.0
var fire_cooldown: float = 0.5

var _proj_pool: Node = null
var _enemy_pool_ref: Node = null

func _ready() -> void:
	call_deferred("_find_pools")

func _find_pools() -> void:
	_proj_pool = get_tree().get_first_node_in_group("projectile_pool")
	_enemy_pool_ref = get_tree().get_first_node_in_group("enemy_pool")

# --- Helpers de stats globales ---

func _effective_damage() -> float:
	var p := GameManager.player_ref
	return damage * (1.0 + p.damage_bonus) if p else damage

func _effective_cooldown() -> float:
	var p := GameManager.player_ref
	if p == null:
		return fire_cooldown
	return maxf(0.03, fire_cooldown * (1.0 - p.attack_speed))

func _effective_proj_speed(base_speed: float) -> float:
	var p := GameManager.player_ref
	return base_speed * (1.0 + p.proj_speed_bonus) if p else base_speed

func _effective_range_sq(base_radius_sq: float) -> float:
	var p := GameManager.player_ref
	if p == null:
		return base_radius_sq
	var r: float = 1.0 + p.range_bonus
	return base_radius_sq * r * r

# --- Búsqueda de enemigos ---

func _get_nearest_enemy(from: Vector2, radius_sq: float) -> Node2D:
	if _enemy_pool_ref == null:
		return null
	var best_dist_sq := INF
	var best: Node2D = null
	for e in _enemy_pool_ref._pool:
		if not e.active:
			continue
		var d: float = from.distance_squared_to(e.global_position)
		if d < radius_sq and d < best_dist_sq:
			best_dist_sq = d
			best = e
	return best
