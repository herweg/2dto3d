extends Node2D

## Arnés de benchmark de ingeniería sobre los sistemas REALES de la pantalla 1
## (LaneEnemySystem, ProjectileSystem con los 4 tipos, TowerSystem) — no
## pretende ser jugable, es para encontrar el techo de 60fps de esta pantalla
## concreta y separar el costo de cada pieza (enemigos, proyectiles, tipo de
## proyectil, cantidad de torres). Mismo método que benchmark_main.gd del
## spike de Sprint 2, aplicado ahora al contenido real en vez del caso
## sintético.
##
## Modos (CLI, vía --):
##   mode=enemies      barre ENEMY_LEVELS, sin proyectiles ni torres
##   mode=projectiles  barre PROJ_LEVELS (spawn sintético, sin torres),
##                      enemigos fijos como blanco de colisión
##   mode=towers       barre TOWER_LEVELS con torres reales disparando
##                      (TowerSystem), enemigos fijos como blanco
## Parámetros comunes: proj-type=mixed|0|1|2|3, tower-type=0|1|2|3,
## level-duration=<seg>, hold-at-peak=<seg>

const LEVEL_DEF := preload("res://data/level_01.tres")

const MAX_ENEMIES := 7500
const MAX_PROJ := 7000
const MAX_TOWERS := 1500

const ENEMY_LEVELS := [300, 400, 500, 600, 700, 800, 1200, 1800, 2500, 3500, 5000, 7000]
const PROJ_LEVELS := [500, 800, 1100, 1400, 1700, 2000, 3000, 4500, 6000]
const TOWER_LEVELS := [50, 100, 200, 300, 500, 800, 1200]

const DEFAULT_LEVEL_DURATION := 4.0
const DEFAULT_HOLD_AT_PEAK := 6.0
const SPATIAL_CELL_SIZE := 48.0

const ENEMY_SPEED := 70.0
const FIXED_ENEMY_POP := 400   # población fija usada como blanco en mode=projectiles/towers
const FIXED_ENEMY_HEALTH := 900.0  # tanky — no se filtra por muertes durante la medición
const MAX_SPAWN_PER_FRAME := 300

var _mode := "enemies"
var _proj_type_arg := "mixed"
var _tower_type_arg := 3  # splash ("las explosivas") por default para mode=towers
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

	_enemy_render = EntityRenderSync.new(MAX_ENEMIES, 14.0, Color(0.75, 0.15, 0.15))
	_proj_render = EntityRenderSync.new(MAX_PROJ, 6.0, Color(1.0, 0.9, 0.3))
	_tower_render = EntityRenderSync.new(MAX_TOWERS, 16.0, Color(0.25, 0.35, 0.55))
	var type_colors := [Color(0.30, 0.55, 0.95), Color(0.95, 0.55, 0.15), Color(0.65, 0.35, 0.85), Color(0.15, 0.75, 0.70)]
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
		_:
			_mode = "enemies"
			_levels = ENEMY_LEVELS

	var total_time: float = _level_duration * _levels.size() + _hold_at_peak
	_shot_times = [total_time * 0.5, total_time * 0.95]

	var tag := (_mode + "_sprite") if (_sprite_arg and _mode == "enemies") else _mode
	var out_path := "res://benchmark_results/stress_%s_%d.csv" % [tag, Time.get_unix_time_from_system()]
	_logger = BenchmarkLogger.new(out_path)
	print("[stress] modo=%s sprite=%s niveles=%s tipo_proy=%s tipo_torre=%d log=%s" % [_mode, _sprite_arg, str(_levels), _proj_type_arg, _tower_type_arg, out_path])

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
			"level-duration":
				_level_duration = parts[1].to_float()
			"hold-at-peak":
				_hold_at_peak = parts[1].to_float()
			"sprite":
				_sprite_arg = parts[1] == "1"

func _current_target() -> int:
	return _levels[_level_idx]

func _at_final_level() -> bool:
	return _level_idx >= _levels.size() - 1

func _random_point_in_path() -> Vector2:
	var r: Rect2 = _level.path_rects[randi() % _level.path_rects.size()]
	return Vector2(randf_range(r.position.x, r.end.x), randf_range(r.position.y, r.end.y))

func _resolve_proj_type() -> int:
	if _proj_type_arg == "mixed":
		return randi() % 4
	return _proj_type_arg.to_int()

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
		var splash := 42.0 if ptype == ProjectileSystem.PROJ_SPLASH else 0.0
		if _proj_store.spawn(pos, dir * speed, 2.0, 5.0, ptype, hits, homing_target, splash) == -1:
			break
		spawned += 1

func _ensure_towers(target: int) -> void:
	var spawned := 0
	while _tower_store.active_count < target and spawned < MAX_SPAWN_PER_FRAME:
		var idx := _tower_store.active_count
		var col := idx % 40
		var row := idx / 40
		var pos := Vector2(-620.0 + col * 26.0, -350.0 + row * 26.0)
		if _tower_store.spawn_typed(pos, _tower_type_arg) == -1:
			break
		spawned += 1

func _process(delta: float) -> void:
	if _quitting:
		return
	_elapsed += delta
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
	_proj_system.tick(delta)
	if _mode == "towers":
		_tower_system.tick(delta)

	if _sprite_arg and _mode == "enemies":
		_enemy_render.advance_animation(delta)
	_enemy_render.sync(_enemy_store.positions, _enemy_store.active_count)
	_proj_render.sync(_proj_store.positions, _proj_store.active_count, _proj_store.type_id)
	_tower_render.sync(_tower_store.positions, _tower_store.active_count, _tower_store.type_id)

	_logger.tick(delta, _proj_store.active_count, _enemy_store.active_count)
	_maybe_screenshot()

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
	print("[stress] listo — modo=%s nivel_final=%d proy=%d enem=%d torres=%d" % [_mode, _levels[_level_idx], _proj_store.active_count, _enemy_store.active_count, _tower_store.active_count])
	get_tree().quit()

func _draw() -> void:
	for r in _level.path_rects:
		draw_rect(r, Color(0.29, 0.42, 0.22, 1.0))
	for r in _level.buildable_zones:
		draw_rect(r, Color(0.35, 0.35, 0.37, 1.0))
