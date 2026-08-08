class_name ProjectileStore
extends EntityStore

var velocities: PackedVector2Array
var ttl: PackedFloat32Array
var damage: PackedFloat32Array

## Campos para variedad de comportamiento (Fase 2 — ver projectile_system.gd
## para los 4 tipos: recto/homing/perforante/splash). `type_id` (heredado de
## EntityStore) selecciona el comportamiento — estos campos son sus
## parámetros. Defaults seguros: cualquier spawn() que no los pase se
## comporta exactamente como el tipo "recto" de siempre (Sprint 2).
var hits_remaining: PackedInt32Array   # perforante: impactos antes de morir
var target_enemy: PackedInt32Array     # homing: índice en EnemyStore, -1 = sin objetivo
var splash_radius: PackedFloat32Array  # splash: radio de daño en área, 0 = sin splash
var last_hit_enemy: PackedInt32Array   # evita que perforante re-pegue al mismo enemigo en el frame siguiente

func _init(p_capacity: int) -> void:
	super._init(p_capacity)
	velocities.resize(p_capacity)
	ttl.resize(p_capacity)
	damage.resize(p_capacity)
	hits_remaining.resize(p_capacity)
	target_enemy.resize(p_capacity)
	splash_radius.resize(p_capacity)
	last_hit_enemy.resize(p_capacity)

func _swap_extra(idx: int, last: int) -> void:
	velocities[idx] = velocities[last]
	ttl[idx] = ttl[last]
	damage[idx] = damage[last]
	hits_remaining[idx] = hits_remaining[last]
	target_enemy[idx] = target_enemy[last]
	splash_radius[idx] = splash_radius[last]
	last_hit_enemy[idx] = last_hit_enemy[last]

func spawn(pos: Vector2, vel: Vector2, life: float, dmg: float, variant: int, p_hits: int = 1, p_target: int = -1, p_splash_radius: float = 0.0) -> int:
	var idx := acquire()
	if idx == -1:
		return -1
	positions[idx] = pos
	type_id[idx] = variant
	velocities[idx] = vel
	ttl[idx] = life
	damage[idx] = dmg
	hits_remaining[idx] = p_hits
	target_enemy[idx] = p_target
	splash_radius[idx] = p_splash_radius
	last_hit_enemy[idx] = -1
	return idx
