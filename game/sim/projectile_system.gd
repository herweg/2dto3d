class_name ProjectileSystem
extends RefCounted

## Movimiento + colisión + daño en un solo batch por tick, sin señales.
## Ver directorsuggestions.md 2.2 y 2.4.

const HIT_RADIUS := 10.0
const HIT_RADIUS_SQ := HIT_RADIUS * HIT_RADIUS

## Los 6 comportamientos de proyectil que pasan por ProjectileStore (Fase 2
## — congelamiento de 7 tipos de fase2-plan-proyectiles.md; el 7º, láser, no
## está acá porque no spawnea proyectil — ver tower_system.gd). Reutilizan
## el mismo array plano, tal como preveía projectile-variety-v1.md: la
## diferencia es lógica de movimiento/resolución de impacto por type_id, no
## una estructura de datos distinta.
const PROJ_STRAIGHT := 0  # dirección fija al disparar — el de siempre desde Sprint 2
const PROJ_HOMING := 1    # corrige rumbo hacia el enemigo objetivo en cada tick
const PROJ_PIERCE := 2    # sigue de largo tras cada impacto hasta agotar hits_remaining
const PROJ_SPLASH := 3    # al impactar, daña también a los enemigos dentro de splash_radius
const PROJ_MISSILE := 4   # trayectoria fija precalculada al spawnear (Bézier), splash al llegar
const PROJ_ZONE := 5      # no viaja (vel=0); cada tick refresca DoT de los enemigos en splash_radius

const ZONE_DOT_REFRESH := 0.4  # ver dot_system.gd — mismo margen que usa el láser
const MISSILE_ARC_HEIGHT := 60.0

var proj_store: ProjectileStore
var enemy_store: EnemyStore
var hash: SpatialHash

var hits_last_tick: int = 0

## VFX (fase3-vfx-exploracion-v1.md, Fase 0) — arrays de eventos, no
## señales (ver nota de arriba, "sin señales"): el llamador (level_
## controller.gd) drena esto después de tick()/tick_native() y alimenta
## el pool de partículas. Vacío y sin costo salvo el chequeo del booleano
## cuando el flag correspondiente está apagado — la corrida "sin VFX" de
## las Fases 2/3 no debe pagar nada por esta instrumentación.
var vfx_spark_enabled := false
var vfx_explosion_enabled := false
var spark_events: PackedVector2Array = PackedVector2Array()
var explosion_events: PackedVector2Array = PackedVector2Array()

## Diagnóstico del spike: aísla el costo de movimiento+render del costo de
## colisión (consulta al hash espacial), para saber si el hot path a mover
## a GDExtension (Paso 4) es realmente la colisión o si el cuello de botella
## está en otro lado. No es parte del diseño final — solo instrumentación.
var skip_collision: bool = false

## Ruta B (Paso 4 de Sprint 2 / Paso 3 de fase2-plan-proyectiles.md):
## instancia de SimHotPath (game/rust/), o null si el GDExtension no está
## cargado. Cuando está seteada, tick_native() reemplaza el batch de
## movimiento+colisión por-proyectil de tick() por una sola llamada nativa
## por frame, para los tipos que SimHotPath sabe resolver (ver su nota).
var native: Object = null

var _dead_marks: PackedByteArray

func _init(p_proj: ProjectileStore, p_enemy: EnemyStore, p_hash: SpatialHash) -> void:
	proj_store = p_proj
	enemy_store = p_enemy
	hash = p_hash
	_dead_marks.resize(p_proj.capacity)

func tick(delta: float) -> void:
	hits_last_tick = 0
	spark_events.clear()
	explosion_events.clear()
	var i := 0
	while i < proj_store.active_count:
		var dead: bool

		match proj_store.type_id[i]:
			PROJ_ZONE:
				dead = _tick_zone(i, delta)
			PROJ_MISSILE:
				dead = _tick_missile(i, delta)
			_:
				dead = _tick_traveling(i, delta)

		if dead:
			proj_store.release(i)
			# no incrementar i: el swap-remove trajo una entidad nueva a este índice
		else:
			i += 1

## Recto/homing/perforante/splash: el batch de siempre desde Sprint 2 —
## integra por velocidad y resuelve colisión contra el hash.
func _tick_traveling(i: int, delta: float) -> bool:
	if proj_store.type_id[i] == PROJ_HOMING:
		_steer_homing(i)

	proj_store.positions[i] += proj_store.velocities[i] * delta
	proj_store.ttl[i] -= delta

	var dead := proj_store.ttl[i] <= 0.0
	if not dead and not skip_collision:
		dead = _check_collision(i)
	return dead

## Homing (Ruta A GDScript únicamente — ver nota de tick_native() más abajo):
## re-apunta la velocidad hacia target_enemy cada tick, conservando la
## velocidad escalar. target_enemy es un índice a EnemyStore fijado al
## disparar — puede quedar obsoleto si ese enemigo murió y el swap-remove
## reasignó su slot a otro enemigo (no hay id estable todavía). No es un
## crash: en el peor caso el proyectil homing "cambia" de objetivo antes de
## lo esperado. Aceptable para esta primera pasada; un id estable por
## enemigo es el fix correcto si esto se vuelve un problema real de balance.
func _steer_homing(i: int) -> void:
	var target := proj_store.target_enemy[i]
	if target < 0 or target >= enemy_store.active_count:
		return
	var speed := proj_store.velocities[i].length()
	if speed <= 0.0:
		return
	var to_target := enemy_store.positions[target] - proj_store.positions[i]
	if to_target.length_squared() > 0.0001:
		proj_store.velocities[i] = to_target.normalized() * speed

## Una sola llamada a SpatialHash.find_hit() por proyectil — ver nota ahí.
## Perforante: excluye el último enemigo golpeado para no vaciar
## hits_remaining contra el mismo blanco en un frame; resta un impacto y
## sigue vivo hasta agotarlos. Los demás tipos nacen con hits_remaining=1
## (mueren en el primer golpe, igual que siempre).
func _check_collision(i: int) -> bool:
	var e_idx := hash.find_hit(proj_store.positions[i], HIT_RADIUS_SQ, enemy_store.positions, proj_store.last_hit_enemy[i])
	if e_idx == -1:
		return false

	_apply_hit(i, e_idx)
	proj_store.last_hit_enemy[i] = e_idx
	hits_last_tick += 1
	proj_store.hits_remaining[i] -= 1
	return proj_store.hits_remaining[i] <= 0

## Splash (y misil, que reusa esto al llegar): además del enemigo golpeado,
## daña a los que caen dentro de splash_radius del punto de impacto. El
## gate es splash_radius > 0, no el type_id — así misil no necesita
## duplicar esta lógica.
func _apply_hit(i: int, e_idx: int) -> void:
	enemy_store.health[e_idx] -= proj_store.damage[i]
	if vfx_spark_enabled:
		spark_events.append(proj_store.positions[i])
	if proj_store.splash_radius[i] <= 0.0:
		return
	_apply_area_damage(proj_store.positions[i], proj_store.damage[i], proj_store.splash_radius[i], e_idx)

## Un solo evento de explosión por acá, no por enemigo alcanzado — cubre
## los dos llamadores (impacto directo con splash_radius>0 arriba, y
## _tick_missile() al llegar) con un único hook.
func _apply_area_damage(pos: Vector2, dmg: float, radius: float, exclude: int = -1) -> void:
	if vfx_explosion_enabled:
		explosion_events.append(pos)
	var radius_sq := radius * radius
	for other in hash.query_nearby(pos):
		if other == exclude:
			continue
		if enemy_store.positions[other].distance_squared_to(pos) <= radius_sq:
			enemy_store.health[other] -= dmg

## Lanzallamas (fase2-plan-proyectiles.md 1.1): no viaja (vel=0 al
## spawnear), vive por ttl, y cada tick refresca dot_dps/dot_time_left de
## los enemigos dentro de splash_radius en vez de aplicar daño directo —
## dot_system.gd es quien realmente descuenta vida.
func _tick_zone(i: int, delta: float) -> bool:
	proj_store.ttl[i] -= delta
	if not skip_collision:
		var pos := proj_store.positions[i]
		var radius_sq := proj_store.splash_radius[i] * proj_store.splash_radius[i]
		var dps := proj_store.damage[i]
		for e in hash.query_nearby(pos):
			if enemy_store.positions[e].distance_squared_to(pos) <= radius_sq:
				enemy_store.dot_dps[e] = dps
				enemy_store.dot_time_left[e] = ZONE_DOT_REFRESH
	return proj_store.ttl[i] <= 0.0

## Misil (fase2-plan-proyectiles.md 1.3): posición recalculada cada tick
## sobre un Bézier cuadrático origen→control→destino (control derivado del
## punto medio, no almacenado — es el "firulete" visual), no integrada por
## velocidad. Al llegar, resuelve como splash en el punto de impacto —
## reusa _apply_area_damage(), no _check_collision() (no persigue nada en
## vuelo, así que no tiene sentido buscar "el enemigo debajo" primero).
func _tick_missile(i: int, delta: float) -> bool:
	proj_store.ttl[i] -= delta

	var duration := proj_store.traj_duration[i]
	var t := 1.0 - clampf(proj_store.ttl[i] / duration, 0.0, 1.0)
	var origin := proj_store.traj_origin[i]
	var target := proj_store.traj_target[i]
	var to_target := target - origin
	var control := (origin + target) * 0.5
	if to_target.length_squared() > 1.0:
		control += to_target.orthogonal().normalized() * MISSILE_ARC_HEIGHT
	var a := origin.lerp(control, t)
	var b := control.lerp(target, t)
	proj_store.positions[i] = a.lerp(b, t)

	if proj_store.ttl[i] > 0.0:
		return false

	if not skip_collision:
		_apply_area_damage(proj_store.positions[i], proj_store.damage[i], proj_store.splash_radius[i])
		hits_last_tick += 1
	return true

## Ruta B: movimiento en GDScript — incluye el steer de homing y el Bézier
## de misil, exactamente igual que tick() — colisión en un solo batch
## nativo para los tipos que viajan (recto/homing/perforante/splash).
## SimHotPath no mueve nada ni toca stores: recibe posiciones ya
## actualizadas y devuelve qué pegó con qué — GDScript sigue siendo dueño
## de todo el estado (mismo criterio que el contrato de Racimo en
## fase2-plan-proyectiles.md: la llamada nativa reporta, no muta).
##
## NOTA (Fase 2): PROJ_ZONE y PROJ_MISSILE no pasan por el batch nativo —
## se resuelven siempre en GDScript (_tick_zone/_tick_missile), incluso con
## backend nativo. Zona porque en volumen esperado (unas pocas activas, no
## miles) no es el costo que importa medir. Misil porque solo resuelve
## impacto una vez, al llegar (ttl<=0) — no hace una consulta de colisión
## por tick como los demás, así que no hay nada que ganar metiéndolo en el
## batch. Ver docs/fase2-plan-proyectiles.md, "Qué no entró a SimHotPath".
func tick_native(delta: float) -> void:
	hits_last_tick = 0
	spark_events.clear()
	explosion_events.clear()

	# _dead_marks se relee más abajo por índice después de que este loop ya
	# hizo swap-remove sobre el store. El clear de acá solo cubre basura
	# INTER-frame (el slot no se tocó desde el frame anterior); dentro de
	# ESTE mismo frame, un slot puede cambiar de ocupante más de una vez por
	# swap-remove, así que cada ocupante tiene que escribir su propio
	# _dead_marks[i] sin importar la rama — ver el fix de abajo (antes solo
	# lo escribía la rama "viajero", dejando basura intra-frame cuando una
	# zona/misil vivo heredaba el slot de un viajero que acababa de morir en
	# el mismo tick, y la limpieza de más abajo lo liberaba por error).
	for idx in proj_store.active_count:
		_dead_marks[idx] = 0

	var i := 0
	while i < proj_store.active_count:
		var t := proj_store.type_id[i]
		var dead := false
		if t == PROJ_ZONE:
			dead = _tick_zone(i, delta)
		elif t == PROJ_MISSILE:
			dead = _tick_missile(i, delta)
		else:
			if t == PROJ_HOMING:
				_steer_homing(i)
			proj_store.positions[i] += proj_store.velocities[i] * delta
			proj_store.ttl[i] -= delta
			dead = proj_store.ttl[i] <= 0.0
		_dead_marks[i] = 1 if dead else 0

		if dead:
			proj_store.release(i)
			# el swap-remove trajo una entidad nueva a este índice — pero
			# ya procesamos zona/misil arriba, así que es seguro reprocesar
			# lo que cayó acá en la misma vuelta (no incrementamos i).
		else:
			i += 1

	if skip_collision:
		return

	var count := proj_store.active_count
	var result: Dictionary = native.find_collisions(
		proj_store.positions, proj_store.type_id, proj_store.last_hit_enemy, proj_store.splash_radius,
		count,
		enemy_store.positions, enemy_store.active_count,
		HIT_RADIUS, hash.cell_size
	)

	var primary: PackedInt32Array = result.get("primary", PackedInt32Array())
	var splash: PackedInt32Array = result.get("splash", PackedInt32Array())

	var j := 0
	while j < primary.size():
		var p_idx := primary[j]
		var e_idx := primary[j + 1]
		# PROJ_ZONE/PROJ_MISSILE ya se removieron del store más arriba en
		# este mismo tick, así que p_idx acá siempre es un tipo "viajero"
		# todavía vivo — no hace falta filtrarlos de nuevo.
		enemy_store.health[e_idx] -= proj_store.damage[p_idx]
		if vfx_spark_enabled:
			spark_events.append(proj_store.positions[p_idx])
		hits_last_tick += 1
		proj_store.last_hit_enemy[p_idx] = e_idx
		proj_store.hits_remaining[p_idx] -= 1
		if proj_store.hits_remaining[p_idx] <= 0:
			_dead_marks[p_idx] = 1
		j += 2

	# Un evento de explosión por proyectil (p_idx), no por enemigo
	# salpicado — mismo criterio que _apply_area_damage() del lado
	# GDScript. `splash` viene agrupado por p_idx desde SimHotPath (cada
	# proyectil aporta un bloque contiguo de pares), así que alcanza con
	# comparar contra el p_idx anterior en vez de un set.
	var last_explosion_p_idx := -1
	j = 0
	while j < splash.size():
		var p_idx := splash[j]
		var e_idx := splash[j + 1]
		enemy_store.health[e_idx] -= proj_store.damage[p_idx]
		if vfx_explosion_enabled and p_idx != last_explosion_p_idx:
			explosion_events.append(proj_store.positions[p_idx])
			last_explosion_p_idx = p_idx
		j += 2

	var k := 0
	while k < proj_store.active_count:
		if k < count and _dead_marks[k] == 1:
			var last := proj_store.active_count - 1
			if k != last and last < count:
				_dead_marks[k] = _dead_marks[last]
			proj_store.release(k)
		else:
			k += 1
