extends Node2D

## Pantalla 1 (Fase 2) — geometría pura, sin arte. Ver el plan de esta
## pantalla y docs/referencia-orc-problem.md. Enemigos caminan por el carril
## verde de spawn_point a goal_point esquivando árboles (LaneEnemySystem);
## el jugador coloca torres en la zona gris (buildable_zones); las torres
## reutilizan ProjectileStore/ProjectileSystem tal como los dejó Sprint 2.

const LEVEL_DEF := preload("res://data/level_01.tres")

const MAX_ENEMIES := 360  # margen sobre el objetivo de estrés de 300
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

## Un color por tipo (0=recta, 1=homing, 2=perforante, 3=splash) — mismo
## índice para la torre y el proyectil que dispara, así se ve a simple
## vista cuál tiró cuál. Evita los colores ya usados en la pantalla (rojo
## de enemigos/meta, verde del carril, gris construible, marrón de árboles,
## amarillo del spawn).
const TYPE_COLORS := [
	Color(0.30, 0.55, 0.95),  # 0 recta — azul
	Color(0.95, 0.55, 0.15),  # 1 homing — naranja
	Color(0.65, 0.35, 0.85),  # 2 perforante — violeta
	Color(0.15, 0.75, 0.70),  # 3 splash — verde azulado
]

var _level: LevelDef

var _enemy_store: EnemyStore
var _proj_store: ProjectileStore
var _tower_store: TowerStore

var _hash: SpatialHash
var _proj_system: ProjectileSystem
var _lane_system: LaneEnemySystem
var _tower_system: TowerSystem

var _enemy_render: EntityRenderSync
var _proj_render: EntityRenderSync
var _tower_render: EntityRenderSync

var _spawn_timer: float = 0.0
var _selected_tower_type: int = 0  # teclas 1-4 lo cambian — ver _unhandled_input

## Soporte de verificación (Fase 2, primera pasada) — mismo espíritu que
## benchmark_main.gd del spike: capturas + auto-quit para poder revisar la
## pantalla sin depender de mirar la ventana en vivo.
var _quit_after: float = -1.0
var _elapsed: float = 0.0
var _shots_taken: Dictionary = {}
var _shot_times: Array = [6.0, 14.0]

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
	_level = LEVEL_DEF

	_enemy_store = EnemyStore.new(MAX_ENEMIES)
	_proj_store = ProjectileStore.new(MAX_PROJ)
	_tower_store = TowerStore.new(MAX_TOWERS)

	_hash = SpatialHash.new(SPATIAL_CELL_SIZE)
	_proj_system = ProjectileSystem.new(_proj_store, _enemy_store, _hash)
	_lane_system = LaneEnemySystem.new(_enemy_store, _level.waypoints, _level.obstacles, _level.obstacle_radius)
	_tower_system = TowerSystem.new(_tower_store, _enemy_store, _proj_store)

	_enemy_render = EntityRenderSync.new(MAX_ENEMIES, 18.0, Color(0.75, 0.15, 0.15))
	_proj_render = EntityRenderSync.new(MAX_PROJ, 7.0, Color(1.0, 0.9, 0.3))
	_tower_render = EntityRenderSync.new(MAX_TOWERS, 26.0, Color(0.25, 0.35, 0.55))
	_proj_render.set_type_colors(TYPE_COLORS)
	_tower_render.set_type_colors(TYPE_COLORS)
	add_child(_enemy_render.get_node2d())
	add_child(_proj_render.get_node2d())
	add_child(_tower_render.get_node2d())

	_parse_cli_args()
	queue_redraw()

func _parse_cli_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "place-test-towers":
			_place_test_towers()
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

	if _stress_test:
		_setup_stress_test()

## Coloca las torres en grilla dentro de la primera buildable_zone (alcanza
## para 30 con espaciado de sobra) y arranca el logger — el spawner de
## enemigos se resuelve en _process() vía _stress_top_up_enemies().
func _setup_stress_test() -> void:
	var zone: Rect2 = _level.buildable_zones[0]
	var placed := 0
	var y := zone.position.y + 40.0
	while y < zone.position.y + zone.size.y - 20.0 and placed < _stress_towers:
		var x := zone.position.x + 40.0
		while x < zone.position.x + zone.size.x - 20.0 and placed < _stress_towers:
			if _place_tower(Vector2(x, y), placed % 4):
				placed += 1
			x += STRESS_TOWER_SPACING
		y += STRESS_TOWER_SPACING

	var out_path := "res://benchmark_results/level1_stress_%d.csv" % Time.get_unix_time_from_system()
	_stress_logger = BenchmarkLogger.new(out_path)
	print("[level1] stress test: %d torres colocadas (objetivo %d), rampa a %d enemigos. Log: %s" % [placed, _stress_towers, _stress_enemies, out_path])

## Prueba de verificación: una torre de cada uno de los 4 tipos, a lo largo
## del carril, para que un solo run muestre los 4 comportamientos.
func _place_test_towers() -> void:
	var spots := [Vector2(60.0, -320.0), Vector2(60.0, -60.0), Vector2(60.0, 120.0), Vector2(60.0, 300.0)]
	for t in 4:
		_place_tower(spots[t], t)

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

	_enemy_render.sync(_enemy_store.positions, _enemy_store.active_count)
	_proj_render.sync(_proj_store.positions, _proj_store.active_count, _proj_store.type_id)
	_tower_render.sync(_tower_store.positions, _tower_store.active_count, _tower_store.type_id)

	if _stress_logger:
		_stress_logger.tick(delta, _proj_store.active_count, _enemy_store.active_count)

	_maybe_screenshot()
	if _quit_after > 0.0 and _elapsed >= _quit_after:
		if _stress_logger:
			_stress_logger.close()
		print("[level1] listo — torres: %d, proyectiles activos: %d, enemigos activos: %d, leaks: %d" % [_tower_store.active_count, _proj_store.active_count, _enemy_store.active_count, _lane_system.leaked_count])
		get_tree().quit()

## Sostiene ~_stress_enemies activos (fuente estilo BenchmarkSpawner —
## repone lo que muere/llega a la meta) en vez del spawner de a uno de la
## pantalla normal — para poder mantener el pico el tiempo suficiente para
## medir, no solo tocarlo un instante.
func _stress_top_up_enemies() -> void:
	var spawned := 0
	while _enemy_store.active_count < _stress_enemies and spawned < STRESS_SPAWN_PER_FRAME:
		var jitter := Vector2(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0))
		var idx := _enemy_store.spawn(_level.spawn_point + jitter, ENEMY_SPEED, STRESS_ENEMY_HEALTH, 0.0, ENEMY_VARIANT)
		if idx == -1:
			break
		_enemy_store.waypoint_index[idx] = 0
		spawned += 1

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
	for r in _level.buildable_zones:
		draw_rect(r, Color(0.35, 0.35, 0.37, 1.0))
		draw_rect(r, Color(0.55, 0.55, 0.58, 1.0), false, 3.0)
	for r in _level.path_rects:
		draw_rect(r, Color(0.29, 0.42, 0.22, 1.0))
	for o in _level.obstacles:
		draw_circle(o, _level.obstacle_radius, Color(0.35, 0.24, 0.14, 1.0))
	draw_circle(_level.spawn_point, 14.0, Color(0.9, 0.8, 0.2, 1.0))
	draw_circle(_level.goal_point, 14.0, Color(0.9, 0.2, 0.2, 1.0))
