class_name ProjectileSystem
extends RefCounted

## Movimiento + colisión + daño en un solo batch por tick, sin señales.
## Ver directorsuggestions.md 2.2 y 2.4.

const HIT_RADIUS := 10.0
const HIT_RADIUS_SQ := HIT_RADIUS * HIT_RADIUS

## Los 4 comportamientos de proyectil (Fase 2 — "al menos 4 proyectiles
## diferentes"). Reutilizan el mismo array plano de ProjectileStore, tal
## como preveía projectile-variety-v1.md: la diferencia es lógica de
## movimiento/resolución de impacto por type_id, no una estructura de datos
## distinta. Cada tipo de torre (tower_store.gd) dispara uno de estos.
const PROJ_STRAIGHT := 0  # dirección fija al disparar — el de siempre desde Sprint 2
const PROJ_HOMING := 1    # corrige rumbo hacia el enemigo objetivo en cada tick
const PROJ_PIERCE := 2    # sigue de largo tras cada impacto hasta agotar hits_remaining
const PROJ_SPLASH := 3    # al impactar, daña también a los enemigos dentro de splash_radius

var proj_store: ProjectileStore
var enemy_store: EnemyStore
var hash: SpatialHash

var hits_last_tick: int = 0

## Diagnóstico del spike: aísla el costo de movimiento+render del costo de
## colisión (consulta al hash espacial), para saber si el hot path a mover
## a GDExtension (Paso 4) es realmente la colisión o si el cuello de botella
## está en otro lado. No es parte del diseño final — solo instrumentación.
var skip_collision: bool = false

## Ruta B (Paso 4): instancia de SimHotPath (game/rust/), o null si el
## GDExtension no está cargado. Cuando está seteada, tick_native() reemplaza
## la búsqueda de colisión por-proyectil de tick() por una sola llamada al
## batch nativo, por frame.
var native: Object = null

var _dead_marks: PackedByteArray

func _init(p_proj: ProjectileStore, p_enemy: EnemyStore, p_hash: SpatialHash) -> void:
	proj_store = p_proj
	enemy_store = p_enemy
	hash = p_hash
	_dead_marks.resize(p_proj.capacity)

func tick(delta: float) -> void:
	hits_last_tick = 0
	var i := 0
	while i < proj_store.active_count:
		if proj_store.type_id[i] == PROJ_HOMING:
			_steer_homing(i)

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

## Splash: además del enemigo golpeado, daña a los que caen dentro de
## splash_radius del punto de impacto — reusa hash.query_nearby() (el mismo
## radio de celdas que ya visita find_hit()) en vez de una consulta nueva.
func _apply_hit(i: int, e_idx: int) -> void:
	enemy_store.health[e_idx] -= proj_store.damage[i]

	if proj_store.type_id[i] != PROJ_SPLASH or proj_store.splash_radius[i] <= 0.0:
		return

	var pos := proj_store.positions[i]
	var radius_sq := proj_store.splash_radius[i] * proj_store.splash_radius[i]
	for other in hash.query_nearby(pos):
		if other == e_idx:
			continue
		if enemy_store.positions[other].distance_squared_to(pos) <= radius_sq:
			enemy_store.health[other] -= proj_store.damage[i]

## Ruta B: movimiento en GDScript (igual que tick()), colisión en un solo
## batch nativo (SimHotPath.find_collisions — game/rust/src/lib.rs), y el
## swap-remove se resuelve acá con los resultados. Índices estables entre el
## batch de movimiento y la llamada nativa: nada se remueve hasta el final.
##
## NOTA (Fase 2): no soporta todavía homing/perforante/splash — SimHotPath
## solo devuelve pares de impacto simples. Solo lo usa el benchmark del
## spike (backend=native); la pantalla 1 corre en tick() (GDScript), que sí
## tiene los 4 comportamientos. Extender esto es trabajo futuro si una
## pantalla necesita la escala de Ruta B con variedad de proyectiles.
func tick_native(delta: float) -> void:
	hits_last_tick = 0
	var count := proj_store.active_count

	for i in count:
		proj_store.positions[i] += proj_store.velocities[i] * delta
		proj_store.ttl[i] -= delta
		_dead_marks[i] = 1 if proj_store.ttl[i] <= 0.0 else 0

	if not skip_collision:
		var pairs: PackedInt32Array = native.find_collisions(
			proj_store.positions, count,
			enemy_store.positions, enemy_store.active_count,
			HIT_RADIUS, hash.cell_size
		)
		var j := 0
		while j < pairs.size():
			var p_idx := pairs[j]
			var e_idx := pairs[j + 1]
			if _dead_marks[p_idx] == 0:
				enemy_store.health[e_idx] -= proj_store.damage[p_idx]
				hits_last_tick += 1
				_dead_marks[p_idx] = 1
			j += 2

	var i := 0
	while i < proj_store.active_count:
		if _dead_marks[i] == 1:
			var last := proj_store.active_count - 1
			if i != last:
				_dead_marks[i] = _dead_marks[last]
			proj_store.release(i)
		else:
			i += 1
