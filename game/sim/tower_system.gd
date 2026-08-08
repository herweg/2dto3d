class_name TowerSystem
extends RefCounted

## Targeting + disparo de torres (Fase 2, pantalla 1 + fase2-plan-proyectiles.md).
## Reutiliza ProjectileStore.spawn() tal como lo dejó el spike de Sprint 2 —
## no hace falta el hash espacial ni el hot path de Rust a la escala de una
## pantalla jugable, así que la búsqueda de objetivo es brute-force sobre
## enemy_store.positions. Láser y riel (TOWER_MODE_BEAM/RAIL) no pasan por
## acá — no spawnean proyectil, ver _tick_laser()/_tick_rail().

const PROJ_SPEED := 520.0
const PROJ_LIFE := 1.5
const ZONE_LIFE := 3.0    # cuánto dura plantada una zona de lanzallamas
const MISSILE_SPEED := 260.0  # para derivar el tiempo de vuelo según distancia

const LASER_GRACE := 0.4  # dot_time_left que refresca cada tick de contacto — fase2-plan-proyectiles.md 1.2
const RAIL_CHARGE := 1.2
const RAIL_HIT_WIDTH := 14.0

var tower_store: TowerStore
var enemy_store: EnemyStore
var proj_store: ProjectileStore

func _init(p_tower: TowerStore, p_enemy: EnemyStore, p_proj: ProjectileStore) -> void:
	tower_store = p_tower
	enemy_store = p_enemy
	proj_store = p_proj

func tick(delta: float) -> void:
	for i in tower_store.active_count:
		var proj_type := tower_store.proj_type_of(i)

		if proj_type == TowerStore.TOWER_MODE_BEAM:
			_tick_laser(i)
			continue
		if proj_type == TowerStore.TOWER_MODE_RAIL:
			_tick_rail(i, delta)
			continue

		tower_store.cooldown_left[i] -= delta
		if tower_store.cooldown_left[i] > 0.0:
			continue

		var target := _find_nearest_enemy(tower_store.positions[i], tower_store.range[i])
		if target == -1:
			continue

		_fire(i, proj_type, target)
		tower_store.cooldown_left[i] = tower_store.fire_rate[i]

func _fire(i: int, proj_type: int, target: int) -> void:
	var origin := tower_store.positions[i]
	var target_pos := enemy_store.positions[target]

	if proj_type == ProjectileSystem.PROJ_MISSILE:
		_fire_missile(i, origin, target_pos)
		return

	if proj_type == ProjectileSystem.PROJ_ZONE:
		# Se planta en el punto del enemigo objetivo, no en la torre.
		proj_store.spawn(target_pos, Vector2.ZERO, ZONE_LIFE, tower_store.damage[i], proj_type, 1, -1, tower_store.proj_extra[i])
		return

	var dir := (target_pos - origin).normalized()
	# hits/objetivo/radio de splash dependen del tipo — el resto los ignora
	# (defaults seguros de ProjectileStore.spawn()).
	var hits := int(tower_store.proj_extra[i]) if proj_type == ProjectileSystem.PROJ_PIERCE else 1
	var homing_target := target if proj_type == ProjectileSystem.PROJ_HOMING else -1
	var splash := tower_store.proj_extra[i] if proj_type == ProjectileSystem.PROJ_SPLASH else 0.0

	proj_store.spawn(origin, dir * PROJ_SPEED, PROJ_LIFE, tower_store.damage[i], proj_type, hits, homing_target, splash)

## Misil (fase2-plan-proyectiles.md 1.3): trayectoria fija calculada una
## sola vez acá — no re-apunta en vuelo. Impacta donde *hubo* el enemigo al
## momento del disparo, no lo persigue.
func _fire_missile(i: int, origin: Vector2, target_pos: Vector2) -> void:
	var duration := maxf(0.3, origin.distance_to(target_pos) / MISSILE_SPEED)
	var idx := proj_store.spawn(origin, Vector2.ZERO, duration, tower_store.damage[i], ProjectileSystem.PROJ_MISSILE, 1, -1, tower_store.proj_extra[i])
	if idx != -1:
		proj_store.set_trajectory(idx, origin, target_pos, duration)

## Láser (fase2-plan-proyectiles.md 1.2): sin cooldown real — cada tick que
## hay un enemigo en rango, refresca su DoT (mismo slot que lanzallamas,
## dot_system.gd lo consume). Sin contacto, el timer decae solo — es el
## margen corto "sigo recibiendo daño un rato" del catálogo, gratis por
## construcción del esquema de DoT, no lógica nueva.
func _tick_laser(i: int) -> void:
	var target := _find_nearest_enemy(tower_store.positions[i], tower_store.range[i])
	if target == -1:
		return
	enemy_store.dot_dps[target] = tower_store.damage[i]
	enemy_store.dot_time_left[target] = LASER_GRACE

## Riel (fase2-plan-proyectiles.md 3, "misma familia que láser"): carga
## RAIL_CHARGE segundos (reusa cooldown_left como timer de carga) y then
## dispara un hitscan instantáneo que pega a todo enemigo dentro de un
## corredor angosto entre la torre y el objetivo más cercano — sin spawnear
## proyectil, así que no compite por presupuesto de ProjectileStore. Barato
## de sobra: dispara poco seguido y no hay muchas torres de este tipo.
func _tick_rail(i: int, delta: float) -> void:
	tower_store.cooldown_left[i] -= delta
	if tower_store.cooldown_left[i] > 0.0:
		return

	var target := _find_nearest_enemy(tower_store.positions[i], tower_store.range[i])
	if target == -1:
		return

	var origin := tower_store.positions[i]
	var dir := (enemy_store.positions[target] - origin).normalized()
	var max_dist := tower_store.range[i]
	var hit_width_sq := RAIL_HIT_WIDTH * RAIL_HIT_WIDTH

	for e in enemy_store.active_count:
		var to_e := enemy_store.positions[e] - origin
		var along := to_e.dot(dir)
		if along < 0.0 or along > max_dist:
			continue
		var perp := to_e - dir * along
		if perp.length_squared() <= hit_width_sq:
			enemy_store.health[e] -= tower_store.damage[i]

	tower_store.cooldown_left[i] = RAIL_CHARGE

func _find_nearest_enemy(pos: Vector2, range_limit: float) -> int:
	var best := -1
	var best_dist_sq := range_limit * range_limit
	for e in enemy_store.active_count:
		var dist_sq := enemy_store.positions[e].distance_squared_to(pos)
		if dist_sq <= best_dist_sq:
			best_dist_sq = dist_sq
			best = e
	return best
