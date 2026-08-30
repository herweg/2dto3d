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

## Misil (fase2-plan-proyectiles.md 1.3): trayectoria fija precalculada al
## spawnear, no re-apuntado en vuelo. `positions` se recalcula cada tick a
## partir de estos 3 campos (Bézier cuadrático origen→control→destino,
## control derivado, no almacenado) en vez de integrarse por velocidad —
## ver projectile_system.gd::_tick_missile(). `traj_duration` es el valor
## de `ttl` al spawnear (`ttl` ya cuenta regresivo, así que el progreso
## t = 1 - ttl/traj_duration).
var traj_origin: PackedVector2Array
var traj_target: PackedVector2Array
var traj_duration: PackedFloat32Array

func _init(p_capacity: int) -> void:
	super._init(p_capacity)
	velocities.resize(p_capacity)
	ttl.resize(p_capacity)
	damage.resize(p_capacity)
	hits_remaining.resize(p_capacity)
	target_enemy.resize(p_capacity)
	splash_radius.resize(p_capacity)
	last_hit_enemy.resize(p_capacity)
	traj_origin.resize(p_capacity)
	traj_target.resize(p_capacity)
	traj_duration.resize(p_capacity)

func _swap_extra(idx: int, last: int) -> void:
	velocities[idx] = velocities[last]
	ttl[idx] = ttl[last]
	damage[idx] = damage[last]
	hits_remaining[idx] = hits_remaining[last]
	target_enemy[idx] = target_enemy[last]
	splash_radius[idx] = splash_radius[last]
	last_hit_enemy[idx] = last_hit_enemy[last]
	traj_origin[idx] = traj_origin[last]
	traj_target[idx] = traj_target[last]
	traj_duration[idx] = traj_duration[last]

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

## Solo para PROJ_MISSILE — llamar justo después de spawn() con el mismo
## `idx`. `duration` normalmente es la misma `life` que se pasó a spawn().
func set_trajectory(idx: int, origin: Vector2, target: Vector2, duration: float) -> void:
	traj_origin[idx] = origin
	traj_target[idx] = target
	traj_duration[idx] = maxf(duration, 0.001)
