class_name ProjectileSystem
extends RefCounted

## Movimiento + colisión + daño en un solo batch por tick, sin señales.
## Ver directorsuggestions.md 2.2 y 2.4.

const HIT_RADIUS := 10.0
const HIT_RADIUS_SQ := HIT_RADIUS * HIT_RADIUS

var proj_store: ProjectileStore
var enemy_store: EnemyStore
var hash: SpatialHash

var hits_last_tick: int = 0

## Diagnóstico del spike: aísla el costo de movimiento+render del costo de
## colisión (consulta al hash espacial), para saber si el hot path a mover
## a GDExtension (Paso 4) es realmente la colisión o si el cuello de botella
## está en otro lado. No es parte del diseño final — solo instrumentación.
var skip_collision: bool = false

func _init(p_proj: ProjectileStore, p_enemy: EnemyStore, p_hash: SpatialHash) -> void:
	proj_store = p_proj
	enemy_store = p_enemy
	hash = p_hash

func tick(delta: float) -> void:
	hits_last_tick = 0
	var i := 0
	while i < proj_store.active_count:
		proj_store.positions[i] += proj_store.velocities[i] * delta
		proj_store.ttl[i] -= delta

		var dead := proj_store.ttl[i] <= 0.0

		if not dead and not skip_collision:
			dead = _check_collision(i)

		if dead:
			proj_store.release(i)
			# no incrementar i: el swap-remove trajo una entidad nueva a este índice
		else:
			i += 1

## Una sola llamada a SpatialHash.find_hit() por proyectil — ver nota ahí.
func _check_collision(i: int) -> bool:
	var e_idx := hash.find_hit(proj_store.positions[i], HIT_RADIUS_SQ, enemy_store.positions)
	if e_idx == -1:
		return false
	enemy_store.health[e_idx] -= proj_store.damage[i]
	hits_last_tick += 1
	return true
