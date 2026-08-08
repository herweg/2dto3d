extends Node2D

## Arnés de benchmark de ingeniería sobre los sistemas REALES de la pantalla 1
## (LaneEnemySystem, ProjectileSystem con los tipos implementados, TowerSystem,
## DotSystem) — no pretende ser jugable, es para encontrar el techo de 60fps
## de esta pantalla concreta y separar el costo de cada pieza. Mismo método
## que benchmark_main.gd del spike de Sprint 2, aplicado al contenido real.
##
## Modos (CLI, vía --):
##   mode=enemies      barre ENEMY_LEVELS, sin proyectiles ni torres
##   mode=projectiles  barre PROJ_LEVELS (spawn sintético, sin torres),
##                      enemigos fijos como blanco de colisión
##   mode=towers       barre TOWER_LEVELS con torres reales disparando
##                      (TowerSystem), enemigos fijos como blanco
##   mode=joint        "verificación de pico conjunto" (director, 08-ago):
##                      2.000 enemigos, 3.000 proyectiles (mezcla realista de
##                      los 6 tipos), 20 torres reales — todo ×1.2 (condición
##                      del 20% de T4) — TOWER_TYPE_STATS real (sin overrides
##                      de desarrollo), backend nativo por default.
## Parámetros comunes: proj-type=mixed|0-5, tower-type=0-7, backend=gdscript|native,
## level-duration=<seg>, hold-at-peak=<seg>

const LEVEL_DEF := preload("res://data/level_01.tres")

const MAX_ENEMIES := 7500
const MAX_PROJ := 8000
const MAX_TOWERS := 1500

const ENEMY_LEVELS := [300, 400, 500, 600, 700, 800, 1200, 1800, 2500, 3500, 5000, 7000]
const PROJ_LEVELS := [500, 800, 1100, 1400, 1700, 2000, 3000, 4500, 6000]
const TOWER_LEVELS := [50, 100, 200, 300, 500, 800, 1200]

## "Verificación de pico conjunto" — número real de diseño (director,
## fase2-motor-cristalizado.md) × 1.2 (condición del 20%, definicion-escala-v1.md).
const JOINT_MARGIN := 1.2
const JOINT_ENEMY_TARGET := 2000
const JOINT_PROJ_TARGET := 3000
const JOINT_TOWER_TARGET := 20

const DEFAULT_LEVEL_DURATION := 4.0
const DEFAULT_HOLD_AT_PEAK := 6.0
const SPATIAL_CELL_SIZE := 48.0

const ENEMY_SPEED := 70.0
const FIXED_ENEMY_POP := 400   # población fija usada como blanco en mode=projectiles/towers
const FIXED_ENEMY_HEALTH := 900.0  # tanky — no se filtra por muertes durante la medición
const MAX_SPAWN_PER_FRAME := 300

## Mezcla realista de los proyectiles que "viajan" (recto, homing,
## perforante, splash, misil) — pesos aproximados a cuántas de las ~20-24
## torres de una composición real serían de cada familia. PROJ_ZONE queda
## AFUERA de esta mezcla a propósito — ver ZONE_FIXED_COUNT: una zona no es
## "un proyectil más" en volumen, es un emisor de larga vida que en juego
## real nunca hay más que un puñado activas a la vez (torres con cooldown
## de segundos, no un inyector sintético manteniendo cientos). Meterla en
## esta mezcla infló el benchmark con ~300 zonas simultáneas, cada una
## haciendo hash.query_nearby() por tick — un artefacto de metodología del
## benchmark, no un costo real del juego. Diagnosticado 08-ago: aislada,
## zona sola corre a 7.5-13fps a esta escala; recto/homing solos, 75-80fps.
const REALISTIC_PROJ_WEIGHTS := [32, 22, 14, 22, 10]  # suma 100, índice = proj_type (0-4, sin zona)
const ZONE_FIXED_COUNT := 10  # cuántas zonas se sostienen en paralelo, fijo — no escala con proj_target

var _mode := "enemies"
var _proj_type_arg := "mixed"
var _tower_type_arg := 3  # splash ("las explosivas") por default para mode=towers
var _backend_arg := "gdscript"
var _tower_cycle_modulo := 8  # diagnóstico: 6 = excluir láser/riel (idx 6,7) de la mezcla de mode=joint
var _joint_enemy_override := -1  # diagnóstico: pisa _joint_enemy_target (-1 = usar ×1.2 normal)
var _joint_tower_override := -1  # diagnóstico: pisa _joint_tower_target (-1 = usar ×1.2 normal)
var _level_duration := DEFAULT_LEVEL_DURATION
var _hold_at_peak := DEFAULT_HOLD_AT_PEAK

## A/B de gráficos y animación (ver docs/) — sprite=1 activa sprite animado
## en mode=enemies en vez de color plano, mismo ENEMY_LEVELS, para medir el
## costo real contra el ~5.730 ya conocido del color plano.
var _sprite_arg := false
const SPRITE_SHEET := "res://assets/characters.png"
const SPRITE_ROW := 1  # fila 1 del atlas = goblin (tipo 0)
const SPRITE_ANIM_INTERVAL := 0.2

var _level: LevelDef
var _enemy_store: EnemyStore
var _proj_store: ProjectileStore
var _tower_store: TowerStore
var _hash: SpatialHash
var _lane_system: LaneEnemySystem
var _proj_system: ProjectileSystem
var _tower_system: TowerSystem
var _dot_system: DotSystem
var _enemy_render: EntityRenderSync
var _proj_render: EntityRenderSync
var _tower_render: EntityRenderSync
var _logger: BenchmarkLogger

var _levels: Array = []
var _level_idx := 0
var _level_timer := 0.0
var _elapsed := 0.0
var _hold_timer := 0.0
var _quitting := false
var _shots_taken := {}
var _shot_times: Array = []

var _joint_enemy_target := 0
var _joint_proj_target := 0
var _joint_tower_target := 0
var _joint_ramped := false

func _ready() -> void:
	_parse_cli_args()
	_level = LEVEL_DEF

	_enemy_store = EnemyStore.new(MAX_ENEMIES)
	_proj_store = ProjectileStore.new(MAX_PROJ)
	_tower_store = TowerStore.new(MAX_TOWERS)
	_hash = SpatialHash.new(SPATIAL_CELL_SIZE)
	_lane_system = LaneEnemySystem.new(_enemy_store, _level.waypoints, _level.obstacles, _level.obstacle_radius)
	_proj_system = ProjectileSystem.new(_proj_store, _enemy_store, _hash)
	_tower_system = TowerSystem.new(_tower_store, _enemy_store, _proj_store)
	_dot_system = DotSystem.new(_enemy_store)

	if _mode == "joint" or _backend_arg == "native":
		if ClassDB.class_exists("SimHotPath"):
			_proj_system.native = ClassDB.instantiate("SimHotPath")
			_backend_arg = "native"
		else:
			push_error("[stress] backend=native pedido pero SimHotPath no está registrado — ¿falta compilar game/rust/?")
			get_tree().quit(1)
			return

	_enemy_render = EntityRenderSync.new(MAX_ENEMIES, 14.0, Color(0.75, 0.15, 0.15))
	_proj_render = EntityRenderSync.new(MAX_PROJ, 6.0, Color(1.0, 0.9, 0.3))
	_tower_render = EntityRenderSync.new(MAX_TOWERS, 16.0, Color(0.25, 0.35, 0.55))
	var type_colors := [
		Color(0.30, 0.55, 0.95), Color(0.95, 0.55, 0.15), Color(0.65, 0.35, 0.85), Color(0.15, 0.75, 0.70),
		Color(0.85, 0.25, 0.25), Color(0.90, 0.55, 0.20), Color(0.95, 0.95, 0.30), Color(0.60, 0.60, 0.65),
	]
	_proj_render.set_type_colors(type_colors)
	_tower_render.set_type_colors(type_colors)
	add_child(_enemy_render.get_node2d())
	add_child(_proj_render.get_node2d())
	add_child(_tower_render.get_node2d())

	if _sprite_arg and _mode == "enemies":
		var atlas := SpriteAtlas.new(SPRITE_SHEET)
		var idle := atlas.crop_frame(0, SPRITE_ROW)
		var walk := atlas.crop_frame(1, SPRITE_ROW)
		_enemy_render.set_sprite(idle, walk, SPRITE_ANIM_INTERVAL)

	match _mode:
		"projectiles":
			_levels = PROJ_LEVELS
		"towers":
			_levels = TOWER_LEVELS
		"joint":
			_setup_joint()
		_:
			_mode = "enemies"
			_levels = ENEMY_LEVELS

	var total_time: float
	if _mode == "joint":
		total_time = 4.0 + _hold_at_peak  # la rampa a población fija tarda unos pocos segundos, no 30
	else:
		total_time = _level_duration * _levels.size() + _hold_at_peak
	_shot_times = [total_time * 0.5, total_time * 0.95]

	var tag := (_mode + "_sprite") if (_sprite_arg and _mode == "enemies") else _mode
	var out_path := "res://benchmark_results/stress_%s_%d.csv" % [tag, Time.get_unix_time_from_system()]
	_logger = BenchmarkLogger.new(out_path)
	print("[stress] modo=%s backend=%s sprite=%s niveles=%s tipo_proy=%s tipo_torre=%d log=%s" % [_mode, _backend_arg, _sprite_arg, str(_levels), _proj_type_arg, _tower_type_arg, out_path])

## TOWER_TYPE_STATS real (sin overrides de desarrollo) y objetivos ×1.2 —
## ver docs/fase2-plan-proyectiles.md y fase2-motor-cristalizado.md.
func _setup_joint() -> void:
	TowerStore.DEV_RANGE_OVERRIDE = 0.0
	TowerStore.DEV_FIRE_RATE_OVERRIDE = 0.0
	_joint_enemy_target = _joint_enemy_override if _joint_enemy_override >= 0 else int(round(JOINT_ENEMY_TARGET * JOINT_MARGIN))
	_joint_proj_target = int(round(JOINT_PROJ_TARGET * JOINT_MARGIN))
	_joint_tower_target = _joint_tower_override if _joint_tower_override >= 0 else int(round(JOINT_TOWER_TARGET * JOINT_MARGIN))
	_levels = [_joint_proj_target]  # solo para que _current_target()/_at_final_level() no rompan

func _parse_cli_args() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=")
		if parts.size() != 2:
			continue
		match parts[0]:
			"mode":
				_mode = parts[1]
			"proj-type":
				_proj_type_arg = parts[1]
			"tower-type":
				_tower_type_arg = parts[1].to_int()
			"backend":
				_backend_arg = parts[1]
			"level-duration":
				_level_duration = parts[1].to_float()
			"hold-at-peak":
				_hold_at_peak = parts[1].to_float()
			"sprite":
				_sprite_arg = parts[1] == "1"
			"tower-cycle":
				_tower_cycle_modulo = parts[1].to_int()
			"joint-enemies":
				_joint_enemy_override = parts[1].to_int()
			"joint-towers":
				_joint_tower_override = parts[1].to_int()

func _current_target() -> int:
	return _levels[_level_idx]

func _at_final_level() -> bool:
	return _level_idx >= _levels.size() - 1

func _random_point_in_path() -> Vector2:
	var r: Rect2 = _level.path_rects[randi() % _level.path_rects.size()]
	return Vector2(randf_range(r.position.x, r.end.x), randf_range(r.position.y, r.end.y))

func _resolve_proj_type() -> int:
	if _proj_type_arg == "realistic":
		return _weighted_proj_type()
	if _proj_type_arg == "mixed":
		return randi() % 4
	return _proj_type_arg.to_int()

func _weighted_proj_type() -> int:
	var total := 0
	for w in REALISTIC_PROJ_WEIGHTS:
		total += w
	var roll := randi() % total
	var acc := 0
	for t in REALISTIC_PROJ_WEIGHTS.size():
		acc += REALISTIC_PROJ_WEIGHTS[t]
		if roll < acc:
			return t
	return 0

func _top_up_enemies(target: int, health: float) -> void:
	var spawned := 0
	while _enemy_store.active_count < target and spawned < MAX_SPAWN_PER_FRAME:
		var idx := _enemy_store.spawn(_random_point_in_path(), ENEMY_SPEED, health, 0.0, 0)
		if idx == -1:
			break
		_enemy_store.waypoint_index[idx] = 0
		spawned += 1

func _top_up_projectiles(target: int) -> void:
	var spawned := 0
	while _proj_store.active_count < target and spawned < MAX_SPAWN_PER_FRAME:
		var pos := _random_point_in_path()
		var dir := Vector2.from_angle(randf() * TAU)
		var speed := randf_range(250.0, 450.0)
		var ptype := _resolve_proj_type()
		var hits := 3 if ptype == ProjectileSystem.PROJ_PIERCE else 1
		var homing_target := -1
		if ptype == ProjectileSystem.PROJ_HOMING and _enemy_store.active_count > 0:
			homing_target = randi() % _enemy_store.active_count
		var radius := 0.0
		if ptype == ProjectileSystem.PROJ_SPLASH:
			radius = 42.0
		elif ptype == ProjectileSystem.PROJ_ZONE:
			radius = 60.0
		var life := 2.0 if ptype != ProjectileSystem.PROJ_ZONE else 3.0
		var idx := _proj_store.spawn(pos, dir * speed, life, 5.0, ptype, hits, homing_target, radius)
		if idx == -1:
			break
		if ptype == ProjectileSystem.PROJ_MISSILE:
			_proj_store.set_trajectory(idx, pos, pos + dir * randf_range(150.0, 400.0), life)
		spawned += 1

## Sostiene un puñado fijo de zonas activas (no escala con el objetivo de
## proyectiles) — ver nota en ZONE_FIXED_COUNT.
func _top_up_zones() -> void:
	var active := 0
	for i in _proj_store.active_count:
		if _proj_store.type_id[i] == ProjectileSystem.PROJ_ZONE:
			active += 1
	var spawned := 0
	while active + spawned < ZONE_FIXED_COUNT and spawned < 5:
		var pos := _random_point_in_path()
		if _proj_store.spawn(pos, Vector2.ZERO, 3.0, 5.0, ProjectileSystem.PROJ_ZONE, 1, -1, 60.0) == -1:
			break
		spawned += 1

func _ensure_towers(target: int, cycle_types: bool = false) -> void:
	var spawned := 0
	while _tower_store.active_count < target and spawned < MAX_SPAWN_PER_FRAME:
		var idx := _tower_store.active_count
		var col := idx % 40
		var row := idx / 40
		var pos := Vector2(-620.0 + col * 26.0, -350.0 + row * 26.0)
		var t := (idx % _tower_cycle_modulo) if cycle_types else _tower_type_arg
		if _tower_store.spawn_typed(pos, t) == -1:
			break
		spawned += 1

func _process(delta: float) -> void:
	if _quitting:
		return
	_elapsed += delta

	if _mode == "joint":
		_top_up_enemies(_joint_enemy_target, FIXED_ENEMY_HEALTH)
		_top_up_projectiles(_joint_proj_target)
		_top_up_zones()
		_ensure_towers(_joint_tower_target, true)
	else:
		_level_timer += delta
		if _level_timer >= _level_duration and not _at_final_level():
			_level_idx += 1
			_level_timer = 0.0

		match _mode:
			"enemies":
				_top_up_enemies(_current_target(), FIXED_ENEMY_HEALTH)
			"projectiles":
				_top_up_enemies(FIXED_ENEMY_POP, FIXED_ENEMY_HEALTH)
				_top_up_projectiles(_current_target())
			"towers":
				_top_up_enemies(FIXED_ENEMY_POP, FIXED_ENEMY_HEALTH)
				_ensure_towers(_current_target())

	_lane_system.tick(delta)
	_hash.build(_enemy_store)
	if _backend_arg == "native":
		_proj_system.tick_native(delta)
	else:
		_proj_system.tick(delta)
	if _mode == "towers" or _mode == "joint":
		_tower_system.tick(delta)
	_dot_system.tick(delta)

	if _sprite_arg and _mode == "enemies":
		_enemy_render.advance_animation(delta)
	_enemy_render.sync(_enemy_store.positions, _enemy_store.active_count)
	_proj_render.sync(_proj_store.positions, _proj_store.active_count, _proj_store.type_id)
	_tower_render.sync(_tower_store.positions, _tower_store.active_count, _tower_store.type_id)

	_logger.tick(delta, _proj_store.active_count, _enemy_store.active_count)
	_maybe_screenshot()

	if _mode == "joint":
		if not _joint_ramped:
			if _enemy_store.active_count >= int(_joint_enemy_target * 0.95) and _proj_store.active_count >= int(_joint_proj_target * 0.9) and _tower_store.active_count >= _joint_tower_target:
				_joint_ramped = true
		if _joint_ramped:
			_hold_timer += delta
			if _hold_timer >= _hold_at_peak:
				_finish()
		return

	if _at_final_level():
		_hold_timer += delta
		if _hold_timer >= _hold_at_peak:
			_finish()

func _maybe_screenshot() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for t in _shot_times:
		if _elapsed >= t and not _shots_taken.has(t):
			_shots_taken[t] = true
			var img := get_viewport().get_texture().get_image()
			var path := "res://benchmark_results/stress_%s_t%d.png" % [_mode, int(t)]
			img.save_png(path)
			print("[stress] screenshot: ", path)

func _finish() -> void:
	_quitting = true
	_logger.close()
	var final_target = _joint_proj_target if _mode == "joint" else _levels[_level_idx]
	print("[stress] listo — modo=%s backend=%s nivel_final=%d proy=%d enem=%d torres=%d" % [_mode, _backend_arg, final_target, _proj_store.active_count, _enemy_store.active_count, _tower_store.active_count])
	get_tree().quit()

func _draw() -> void:
	for r in _level.path_rects:
		draw_rect(r, Color(0.29, 0.42, 0.22, 1.0))
	for r in _level.buildable_zones:
		draw_rect(r, Color(0.35, 0.35, 0.37, 1.0))
