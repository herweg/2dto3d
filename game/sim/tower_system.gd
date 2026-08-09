class_name TowerSystem
extends RefCounted

## Targeting + disparo de torres (Fase 2, pantalla 1 + fase2-plan-proyectiles.md).
## Reutiliza ProjectileStore.spawn() tal como lo dejó el spike de Sprint 2 —
## los tipos que spawnean proyectil siguen con búsqueda brute-force sobre
## enemy_store.positions (pocas torres, dispara poco seguido, no hace falta
## más). La familia BEAM (láser + lanzallamas, TOWER_MODE_BEAM) sí filtra por
## SpatialHash — corre cada tick sin cooldown de disparo, así que a escala de
## benchmark conjunto (2.400 enemigos) el brute-force sí importaba: ver
## fase2-benchmark-conjunto.md sección 7. Riel (TOWER_MODE_RAIL) tampoco
## spawnea proyectil pero sigue en brute-force — dispara cada RAIL_CHARGE,
## no cada tick.

const PROJ_SPEED := 520.0
const PROJ_LIFE := 1.5
const MISSILE_SPEED := 260.0  # para derivar el tiempo de vuelo según distancia

const RAIL_CHARGE := 1.2
const RAIL_HIT_WIDTH := 14.0

## Cadencia de reselección de objetivo/candidatos para la familia BEAM
## (fase2-benchmark-conjunto.md sección 7, pedido del director 08-ago): el
## rectángulo se re-evalúa 8 veces/seg, no las 60 del tick — el DoT que deja
## (dot_linger) ya tiene margen de sobra para que se sienta continuo entre
## una reselección y la siguiente. Reusa cooldown_left como timer, igual que
## el resto de las torres (para BEAM antes no se usaba para nada).
const BEAM_RETARGET_INTERVAL := 1.0 / 8.0

var tower_store: TowerStore
var enemy_store: EnemyStore
var proj_store: ProjectileStore
var hash: SpatialHash

func _init(p_tower: TowerStore, p_enemy: EnemyStore, p_proj: ProjectileStore, p_hash: SpatialHash) -> void:
	tower_store = p_tower
	enemy_store = p_enemy
	proj_store = p_proj
	hash = p_hash

func tick(delta: float) -> void:
	for i in tower_store.active_count:
		var proj_type := tower_store.proj_type_of(i)

		if proj_type == TowerStore.TOWER_MODE_BEAM:
			_tick_beam(i, delta)
			continue
		if proj_type == TowerStore.TOWER_MODE_RAIL:
			_tick_rail(i, delta)
			continue

		tower_store.cooldown_left[i] -= delta
		# while, no if — a cadencia real (fire_rate ≥ 0.6s, muy por encima de
		# delta ~0.016s) esto itera una sola vez siempre, cero cambio de
		# comportamiento. Con DEV_FIRE_RATE_OVERRIDE forzado por debajo de
		# delta (fase2-benchmark-conjunto.md, prueba de textura+población
		# real, 09-ago) un `if` tapaba la torre a un disparo por frame sin
		# importar cuánto se bajara el cooldown.
		#
		# Ojo con esto (bug real, encontrado y corregido en el mismo pase):
		# si no hay blanco, cooldown_left sigue restando `delta` cada frame
		# sin techo — cuando por fin reaparece un blanco, un `break` sin más
		# dejaría el déficit acumulado y el while lo descargaría entero de
		# una ("ráfaga" al reenganchar, no cadencia normal). Por eso el
		# clamp a 0.0 antes del break: sin blanco, no se banca déficit más
		# allá de "lista para disparar ya" — un salto de 6→120 proyectiles
		# en la regresión de place-all-towers real-stats fue lo que lo
		# expuso (torres con huecos reales de blanco entre spawns).
		while tower_store.cooldown_left[i] <= 0.0:
			var target := _find_nearest_enemy(tower_store.positions[i], tower_store.range[i])
			if target == -1:
				tower_store.cooldown_left[i] = 0.0
				break
			_fire(i, proj_type, target)
			tower_store.cooldown_left[i] += tower_store.fire_rate[i]

func _fire(i: int, proj_type: int, target: int) -> void:
	var origin := tower_store.positions[i]
	var target_pos := enemy_store.positions[target]

	if proj_type == ProjectileSystem.PROJ_MISSILE:
		_fire_missile(i, origin, target_pos)
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

## Familia BEAM (láser + lanzallamas desde la migración de fase2-benchmark-
## conjunto.md sección 7): rectángulo de largo `range` y ancho `proj_extra`
## que parte de la torre hacia el candidato más cercano — refresca el DoT
## (dot_dps/dot_time_left, mismo slot que consume dot_system.gd) de todo
## enemigo dentro del rectángulo, no solo el que fija la dirección. Reusa
## exactamente la geometría de corredor de _tick_rail() (dot-product +
## distancia perpendicular), la diferencia es DoT continuo vs hit único y
## que los candidatos salen de SpatialHash.query_radius() en vez de barrer
## enemy_store.active_count completo — a 2.400 enemigos ese barrido es lo
## que causaba la caída diagnosticada en esa misma sección.
func _tick_beam(i: int, delta: float) -> void:
	tower_store.cooldown_left[i] -= delta
	if tower_store.cooldown_left[i] > 0.0:
		return
	tower_store.cooldown_left[i] = BEAM_RETARGET_INTERVAL

	var origin := tower_store.positions[i]
	var length := tower_store.range[i]
	var half_width := tower_store.proj_extra[i] * 0.5
	var candidates := hash.query_radius(origin, length + half_width)
	if candidates.is_empty():
		return

	var target := _nearest_in(origin, length, candidates)
	if target == -1:
		return
	var dir := (enemy_store.positions[target] - origin).normalized()

	var dps := tower_store.damage[i]
	var linger := tower_store.dot_linger[i]
	var half_width_sq := half_width * half_width
	for e in candidates:
		var to_e := enemy_store.positions[e] - origin
		var along := to_e.dot(dir)
		if along < 0.0 or along > length:
			continue
		var perp := to_e - dir * along
		if perp.length_squared() <= half_width_sq:
			enemy_store.dot_dps[e] = dps
			enemy_store.dot_time_left[e] = linger

## Más cercano dentro de `range_limit`, restringido a `candidates` (ya
## acotados por hash) en vez de enemy_store.active_count — mismo contrato
## que _find_nearest_enemy() de abajo, que sigue usando barrido completo
## porque riel dispara cada RAIL_CHARGE=1.2s, no cada tick (no vale la pena
## acotarlo todavía, ver fase2-benchmark-conjunto.md sección 7).
func _nearest_in(origin: Vector2, range_limit: float, candidates: PackedInt32Array) -> int:
	var best := -1
	var best_dist_sq := range_limit * range_limit
	for e in candidates:
		var dist_sq := enemy_store.positions[e].distance_squared_to(origin)
		if dist_sq <= best_dist_sq:
			best_dist_sq = dist_sq
			best = e
	return best

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
