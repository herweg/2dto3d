extends Node2D

## Pantalla 1 (Fase 2) — geometría pura, sin arte. Ver el plan de esta
## pantalla y docs/referencia-orc-problem.md. Enemigos caminan por el carril
## verde de spawn_point a goal_point esquivando árboles (LaneEnemySystem);
## el jugador coloca torres en la zona gris (buildable_zones); las torres
## reutilizan ProjectileStore/ProjectileSystem tal como los dejó Sprint 2.

const LEVEL_DEF := preload("res://data/level_01.tres")

## Subido de 360 a 2.500 (09-ago) — el tope viejo (300 + margen) nunca se
## pensó contra el objetivo de escala real de T2/T4 (2.000-2.400), solo
## contra el stress-test original de esta pantalla. Necesario para poder
## correr la población real del pico conjunto por el camino de producción
## (`Level1.tscn`), no el arnés sintético — ver plan-fases.md, punto 4,
## verificación de la Causa 2 de fase2-benchmark-conjunto.md sección 11.
const MAX_ENEMIES := 2500
const MAX_PROJ := 4000
const MAX_TOWERS := 64

const STRESS_SPAWN_PER_FRAME := 40
const STRESS_TOWER_SPACING := 70.0

const ENEMY_SPEED := 70.0
const ENEMY_HEALTH := 20.0
const ENEMY_VARIANT := 0
const SPAWN_INTERVAL := 1.2

const TOWER_MIN_SPACING := 48.0
const SPATIAL_CELL_SIZE := 48.0

## Un color por tipo — mismo índice para la torre y el proyectil que dispara
## (los que spawnean uno), así se ve a simple vista cuál tiró cuál. Evita los
## colores ya usados en la pantalla (rojo de enemigos/meta, verde del
## carril, gris construible, marrón de árboles, amarillo del spawn). Mismo
## set que TYPE_COLORS de stress_main.gd, para que un tipo se vea igual en
## las dos pantallas.
const TYPE_COLORS := [
	Color(0.30, 0.55, 0.95),  # 0 recta — azul
	Color(0.95, 0.55, 0.15),  # 1 homing — naranja
	Color(0.65, 0.35, 0.85),  # 2 perforante — violeta
	Color(0.15, 0.75, 0.70),  # 3 splash — verde azulado
	Color(0.85, 0.25, 0.25),  # 4 misil ("Mortero") — rojo
	Color(0.90, 0.55, 0.20),  # 5 lanzallamas ("Fuego") — ámbar
	Color(0.95, 0.95, 0.30),  # 6 láser — amarillo
	Color(0.60, 0.60, 0.65),  # 7 riel — gris acero
]

var _level: LevelDef

var _enemy_store: EnemyStore
var _proj_store: ProjectileStore
var _tower_store: TowerStore

var _hash: SpatialHash
var _proj_system: ProjectileSystem
var _lane_system: LaneEnemySystem
var _tower_system: TowerSystem
var _dot_system: DotSystem

var _enemy_render: EntityRenderSync
var _proj_render: EntityRenderSync
var _tower_render: TypedRenderGroup

var _spawn_timer: float = 0.0
var _selected_tower_type: int = 0  # teclas 1-4 lo cambian — ver _unhandled_input

## Soporte de verificación (Fase 2, primera pasada) — mismo espíritu que
## benchmark_main.gd del spike: capturas + auto-quit para poder revisar la
## pantalla sin depender de mirar la ventana en vivo.
var _quit_after: float = -1.0
var _elapsed: float = 0.0
var _shots_taken: Dictionary = {}
var _shot_times: Array = [6.0, 14.0, 30.0]

## Simulación de estrés — 30 torres disparando rápido (DEV_FIRE_RATE_OVERRIDE)
## contra un objetivo sostenido de 300 enemigos, midiendo frame time con la
## misma herramienta del spike (BenchmarkLogger, game/sim/benchmark_logger.gd).
var _stress_test := false
var _stress_towers := 30
var _stress_enemies := 300
var _stress_logger: BenchmarkLogger = null

## Vida alta (no infinita) solo para el modo de estrés: con 30 torres a
## cadencia de DEV_FIRE_RATE_OVERRIDE, la vida normal (ENEMY_HEALTH=20) hace
## que mueran más rápido de lo que se pueden acumular — nunca se llega a
## sostener el pico de 300 simultáneos, que es justamente lo que este modo
## quiere medir. Mismo criterio que usó BenchmarkSpawner en el spike para
## aislar la medición de población del balance de combate.
const STRESS_ENEMY_HEALTH := 600.0

func _ready() -> void:
	# Mismo fix que stress_main.gd (fase2-vfx-benchmark.md sección 3) — sin
	# esto, a población baja/moderada el frame time mide el refresco del
	# monitor (120Hz acá, confirmado con el fps redondo de la corrida de
	# stress-test de hoy: 120.0/110.0/100.0 exactos), no el motor. Esta
	# pantalla nunca lo tuvo — no se había corrido a población real antes de
	# hoy. No aplica en --headless.
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_level = LEVEL_DEF

	_enemy_store = EnemyStore.new(MAX_ENEMIES)
	_proj_store = ProjectileStore.new(MAX_PROJ)
	_tower_store = TowerStore.new(MAX_TOWERS)

	_hash = SpatialHash.new(SPATIAL_CELL_SIZE)
	_proj_system = ProjectileSystem.new(_proj_store, _enemy_store, _hash)
	_lane_system = LaneEnemySystem.new(_enemy_store, _level.waypoints, _level.obstacles, _level.obstacle_radius)
	_tower_system = TowerSystem.new(_tower_store, _enemy_store, _proj_store, _hash)
	_dot_system = DotSystem.new(_enemy_store)

	_enemy_render = EntityRenderSync.new(MAX_ENEMIES, 18.0, Color(0.75, 0.15, 0.15))
	_proj_render = EntityRenderSync.new(MAX_PROJ, 7.0, Color(1.0, 0.9, 0.3))
	_tower_render = TypedRenderGroup.new(TowerStore.TOWER_TYPE_STATS.size(), MAX_TOWERS, 26.0, TYPE_COLORS)
	_proj_render.set_type_colors(TYPE_COLORS)
	add_child(_enemy_render.get_node2d())
	add_child(_proj_render.get_node2d())
	_tower_render.add_all_to(self)

	_parse_cli_args()
	queue_redraw()

func _parse_cli_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "place-test-towers":
			_place_test_towers()
		if arg == "place-all-towers":
			_place_all_types_test()
		if arg == "real-stats":
			# Sin esto, DEV_RANGE_OVERRIDE/DEV_FIRE_RATE_OVERRIDE (activas por
			# default desde la verificación de los 4 tipos originales) hacen
			# que cualquier torre alcance cualquier punto del nivel — útil
			# para "¿dispara o no?" pero no para verificar que el rango/DPS
			# real de cada fila de TOWER_TYPE_STATS alcanza el carril desde
			# la zona construible. Ver docs/fase2-benchmark-conjunto.md.
			TowerStore.DEV_RANGE_OVERRIDE = 0.0
			TowerStore.DEV_FIRE_RATE_OVERRIDE = 0.0
		if arg == "stress-test":
			_stress_test = true
		var parts := arg.split("=")
		if parts.size() == 2:
			match parts[0]:
				"quit-after":
					_quit_after = parts[1].to_float()
				"stress-towers":
					_stress_towers = parts[1].to_int()
				"stress-enemies":
					_stress_enemies = parts[1].to_int()
				"place-types":
					# Subconjunto de _place_all_types_test() — para aislar un
					# tipo (o familia, ej. "5,6" = BEAM) sin el resto
					# compitiendo por los mismos enemigos, mismo criterio que
					# el aislamiento por variable de fase2-benchmark-conjunto.md.
					_place_types_test(parts[1])
				"sprite-test":
					# Smoke test de integración (docs/smoke-test-motor-arte-v1.md):
					# asigna la textura real al tipo 0 (Torreta Recta) en el
					# TypedRenderGroup real de esta pantalla — mismo quad de
					# 26px que usa el juego, no el de 16px del arnés sintético.
					# Coloca una torre tipo 0 (con sprite) y una tipo 1 (sigue
					# en color plano) juntas, como piso de comparación de tamaño.
					_run_sprite_test(parts[1])
				"sprite-test-mipmap-filter":
					# Igual que sprite-test, pero fuerza texture_filter a
					# LINEAR_WITH_MIPMAPS en el tipo 0 — diagnóstico puntual
					# para aislar si el default del proyecto (Linear, sin
					# mipmaps) es lo que neutraliza mipmaps/generate=true del
					# .import, no el contenido del asset. Ver
					# EntityRenderSync.set_texture_filter().
					_run_sprite_test(parts[1])
					_tower_render.set_texture_filter_for_type(0, CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
				"orientation-test":
					# Diagnóstico puntual (09-ago): ¿el MultiMesh de
					# EntityRenderSync orienta distinto que un Sprite2D común?
					# Sprite2D es la referencia de verdad — 2D nativo, sin el
					# QuadMesh que usa TypedRenderGroup por debajo. Mismo
					# tamaño grande para los dos, para poder comparar a ojo
					# sin depender de una captura de 26px.
					_run_orientation_test(parts[1])

	if _stress_test:
		_setup_stress_test()

## Coloca las torres pegadas al borde del carril (mismo x=30 que ya probó
## `_place_all_types_test()` con muertes reales, no el x=60+ de la grilla
## vieja) — corregido 09-ago: la grilla original barría toda la zona
## construible hacia la derecha (hasta x=410+), muy lejos del carril real
## (los enemigos caminan pegados a `waypoints`, no por todo `path_rects`) —
## con `real-stats` activo eso daba 24 torres colocadas pero 0 proyectiles
## y 0 muertes en 15s, el rango real (170-260px) nunca llegaba. Dos
## columnas cerca del borde (x=30/100, 70px de separación, mismo
## STRESS_TOWER_SPACING) en vez de una sola fila — a una sola columna no
## entran 24 torres con `TOWER_MIN_SPACING=48` en los 640px de alto del
## carril (640/23≈28px < 48). Arranca el logger — el spawner de enemigos
## se resuelve en _process() vía _stress_top_up_enemies().
func _setup_stress_test() -> void:
	var col_count := 2
	var per_col := ceili(float(_stress_towers) / float(col_count))
	var y_step := 640.0 / maxf(1.0, float(per_col - 1))
	var placed := 0
	for col in col_count:
		var x := 30.0 + col * STRESS_TOWER_SPACING
		for i in per_col:
			if placed >= _stress_towers:
				break
			if _place_tower(Vector2(x, -320.0 + i * y_step), placed % 4):
				placed += 1

	var out_path := "res://benchmark_results/level1_stress_%d.csv" % Time.get_unix_time_from_system()
	_stress_logger = BenchmarkLogger.new(out_path)
	print("[level1] stress test: %d torres colocadas (objetivo %d), rampa a %d enemigos. Log: %s" % [placed, _stress_towers, _stress_enemies, out_path])

## Prueba de verificación: una torre de cada uno de los 4 tipos originales,
## a lo largo del carril, para que un solo run muestre los 4 comportamientos.
func _place_test_towers() -> void:
	var spots := [Vector2(60.0, -320.0), Vector2(60.0, -60.0), Vector2(60.0, 120.0), Vector2(60.0, 300.0)]
	for t in 4:
		_place_tower(spots[t], t)

## Prueba de verificación de los 8 tipos reales de TOWER_TYPE_STATS,
## incluidos los dos que `_place_test_towers()` no cubre (BEAM — láser y
## lanzallamas migrados 08-ago — y riel), en la pantalla jugable real, no
## en el arnés sintético de stress_main.gd. x=30 (borde izquierdo de
## buildable_zones[0], a 60px del borde del carril) para que hasta
## lanzallamas (el rango más corto, 90px) alcance con `real-stats` activo.
func _place_all_types_test() -> void:
	var types: Array = []
	for t in TowerStore.TOWER_TYPE_STATS.size():
		types.append(t)
	_place_types(types)

func _place_types_test(csv: String) -> void:
	var types: Array = []
	for s in csv.split(","):
		types.append(s.to_int())
	_place_types(types)

func _place_types(types: Array) -> void:
	var y_start := -320.0
	var y_step := 640.0 / maxf(1.0, float(types.size() - 1))
	for i in types.size():
		_place_tower(Vector2(30.0, y_start + i * y_step), types[i])

func _run_orientation_test(tex_path: String) -> void:
	var tex: Texture2D = load(tex_path)
	if tex == null:
		push_error("[level1] orientation-test: no se pudo cargar " + tex_path)
		return
	var target_w := 190.0  # ancho visible aprox., para poder juzgar a ojo

	var sprite := Sprite2D.new()
	sprite.texture = tex
	var s := target_w / tex.get_width()
	sprite.scale = Vector2(s, s)
	sprite.position = Vector2(-140.0, 0.0)
	add_child(sprite)

	var diag := EntityRenderSync.new(1, target_w, Color.WHITE)
	diag.set_sprite(tex, tex)
	add_child(diag.get_node2d())
	diag.sync(PackedVector2Array([Vector2(140.0, 0.0)]), 1)

	var diag_flip := EntityRenderSync.new(1, target_w, Color.WHITE)
	diag_flip.set_sprite(tex, tex)
	diag_flip.set_flip_h(true)
	add_child(diag_flip.get_node2d())
	diag_flip.sync(PackedVector2Array([Vector2(380.0, 0.0)]), 1)

func _run_sprite_test(tex_path: String) -> void:
	var tex := load(tex_path)
	if tex == null:
		push_error("[level1] sprite-test: no se pudo cargar " + tex_path)
		return
	_tower_render.set_sprite_for_type(0, tex, tex)  # sin frame de caminar — mismo tex en los dos, cero animación
	_place_tower(Vector2(120.0, 0.0), 0)  # con sprite
	_place_tower(Vector2(200.0, 0.0), 1)  # color plano, piso de comparación de tamaño

func _place_tower(pos: Vector2, tower_type: int = -1) -> bool:
	if tower_type == -1:
		tower_type = _selected_tower_type
	if not _level.is_buildable(pos):
		return false
	for i in _tower_store.active_count:
		if _tower_store.positions[i].distance_to(pos) < TOWER_MIN_SPACING:
			return false
	if _tower_store.is_full():
		return false
	_tower_store.spawn_typed(pos, tower_type)
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_place_tower(get_global_mouse_position())
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: _selected_tower_type = 0
			KEY_2: _selected_tower_type = 1
			KEY_3: _selected_tower_type = 2
			KEY_4: _selected_tower_type = 3

func _process(delta: float) -> void:
	_elapsed += delta

	if _stress_test:
		_stress_top_up_enemies()
	else:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0 and _enemy_store.active_count < MAX_ENEMIES:
			_spawn_timer = SPAWN_INTERVAL
			var idx := _enemy_store.spawn(_level.spawn_point, ENEMY_SPEED, ENEMY_HEALTH, 0.0, ENEMY_VARIANT)
			if idx != -1:
				_enemy_store.waypoint_index[idx] = 0

	_lane_system.tick(delta)
	_hash.build(_enemy_store)
	_proj_system.tick(delta)
	_tower_system.tick(delta)
	_dot_system.tick(delta)

	_enemy_render.sync(_enemy_store.positions, _enemy_store.active_count)
	_proj_render.sync(_proj_store.positions, _proj_store.active_count, _proj_store.type_id)
	_tower_render.sync(_tower_store.positions, _tower_store.type_id, _tower_store.active_count)

	if _stress_logger:
		_stress_logger.tick(delta, _proj_store.active_count, _enemy_store.active_count)

	_maybe_screenshot()
	if _quit_after > 0.0 and _elapsed >= _quit_after:
		if _stress_logger:
			_stress_logger.close()
		print("[level1] listo — torres: %d, proyectiles activos: %d, enemigos activos: %d, muertes: %d, leaks: %d" % [_tower_store.active_count, _proj_store.active_count, _enemy_store.active_count, _lane_system.killed_count, _lane_system.leaked_count])
		get_tree().quit()

## Sostiene ~_stress_enemies activos (fuente estilo BenchmarkSpawner —
## repone lo que muere/llega a la meta) en vez del spawner de a uno de la
## pantalla normal — para poder mantener el pico el tiempo suficiente para
## medir, no solo tocarlo un instante.
## Corregido 09-ago: spawneaba todo en spawn_point (+jitter chico) — con
## salud alta (no se filtra por muertes) y sin más spawns una vez llegado
## al objetivo, eso arma una sola "ola" densa que avanza en bloque en vez
## de una población distribuida en régimen — nunca cruza más que un par de
## torres a la vez, no es comparable a la población sostenida de
## mode=joint (que sí reparte cada spawn en un punto aleatorio de
## path_rects, ver stress_main.gd::_random_point_in_path()). Mismo patrón
## acá para que la comparación sea real.
func _stress_top_up_enemies() -> void:
	var spawned := 0
	while _enemy_store.active_count < _stress_enemies and spawned < STRESS_SPAWN_PER_FRAME:
		var idx := _enemy_store.spawn(_random_point_in_path(), ENEMY_SPEED, STRESS_ENEMY_HEALTH, 0.0, ENEMY_VARIANT)
		if idx == -1:
			break
		_enemy_store.waypoint_index[idx] = 0
		spawned += 1

func _random_point_in_path() -> Vector2:
	var r: Rect2 = _level.path_rects[randi() % _level.path_rects.size()]
	return Vector2(randf_range(r.position.x, r.end.x), randf_range(r.position.y, r.end.y))

func _maybe_screenshot() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for t in _shot_times:
		if _elapsed >= t and not _shots_taken.has(t):
			_shots_taken[t] = true
			var img := get_viewport().get_texture().get_image()
			var path := "res://benchmark_results/level1_screenshot_t%d.png" % int(t)
			img.save_png(path)
			print("[level1] screenshot guardado: ", path)

func _draw() -> void:
	if _level.background_texture:
		draw_texture_rect(_level.background_texture, _level.background_rect, false)
	else:
		draw_rect(_level.background_rect, _level.background_color)
	for r in _level.buildable_zones:
		draw_rect(r, Color(0.35, 0.35, 0.37, 1.0))
		draw_rect(r, Color(0.55, 0.55, 0.58, 1.0), false, 3.0)
	for r in _level.path_rects:
		draw_rect(r, Color(0.29, 0.42, 0.22, 1.0))
	for o in _level.obstacles:
		draw_circle(o, _level.obstacle_radius, Color(0.35, 0.24, 0.14, 1.0))
	draw_circle(_level.spawn_point, 14.0, Color(0.9, 0.8, 0.2, 1.0))
	draw_circle(_level.goal_point, 14.0, Color(0.9, 0.2, 0.2, 1.0))
