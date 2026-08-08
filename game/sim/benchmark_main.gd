extends Node2D

## Escena principal del spike (sprint-02.md, Pasos 1-3). Orquesta stores,
## spatial hash, sistemas y render sync sobre el caso de prueba sintético,
## barriendo de 0 hasta el pico objetivo de definicion-escala-v1.md y
## registrando frame time con BenchmarkLogger.
##
## Objetivo de T2: ~6.000-8.000 proyectiles (pico 10.000-12.000),
## ~1.500-2.000 enemigos (pico 3.000).

const PROJ_LEVELS := [0, 1000, 2000, 4000, 6000, 8000, 10000, 12000]
const ENEMY_LEVELS := [0, 300, 600, 1000, 1500, 2000, 2500, 3000]
const MAX_PROJ := 13000
const MAX_ENEMY := 3200

const DEFAULT_LEVEL_DURATION := 4.0
const DEFAULT_HOLD_AT_PEAK := 6.0
const SPATIAL_CELL_SIZE := 24.0  # ~2x HIT_RADIUS de projectile_system.gd — ver nota en sprint-02.md

var _level_duration := DEFAULT_LEVEL_DURATION
var _hold_at_peak := DEFAULT_HOLD_AT_PEAK
var _skip_collision := false

var _proj_store: ProjectileStore
var _enemy_store: EnemyStore
var _hash: SpatialHash
var _proj_system: ProjectileSystem
var _enemy_system: EnemySystem
var _spawner: BenchmarkSpawner
var _logger: BenchmarkLogger
var _proj_render: EntityRenderSync
var _enemy_render: EntityRenderSync

var _elapsed_total: float = 0.0
var _hold_timer: float = 0.0
var _quitting := false
var _shots_taken: Dictionary = {}
var _shot_times: Array = [8.0, 30.0]

func _ready() -> void:
	_parse_cli_args()

	_proj_store = ProjectileStore.new(MAX_PROJ)
	_enemy_store = EnemyStore.new(MAX_ENEMY)
	_hash = SpatialHash.new(SPATIAL_CELL_SIZE)
	_proj_system = ProjectileSystem.new(_proj_store, _enemy_store, _hash)
	_proj_system.skip_collision = _skip_collision
	_enemy_system = EnemySystem.new(_enemy_store)
	_spawner = BenchmarkSpawner.new(_proj_store, _enemy_store, PROJ_LEVELS.duplicate(), ENEMY_LEVELS.duplicate(), _level_duration)

	_proj_render = EntityRenderSync.new(MAX_PROJ, 8.0, Color(1.0, 0.85, 0.2))
	_enemy_render = EntityRenderSync.new(MAX_ENEMY, 16.0, Color(0.85, 0.2, 0.25))
	add_child(_proj_render.get_node2d())
	add_child(_enemy_render.get_node2d())

	var tag := "nocollision" if _skip_collision else "route_a"
	var out_path := "res://benchmark_results/%s_%d.csv" % [tag, Time.get_unix_time_from_system()]
	_logger = BenchmarkLogger.new(out_path)
	print("[benchmark] Ruta A — GDScript puro (skip_collision=%s). Log: %s" % [_skip_collision, out_path])
	print("[benchmark] niveles proyectiles: ", PROJ_LEVELS, " | niveles enemigos: ", ENEMY_LEVELS)

func _parse_cli_args() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=")
		if parts.size() != 2:
			continue
		match parts[0]:
			"level-duration":
				_level_duration = parts[1].to_float()
			"hold-at-peak":
				_hold_at_peak = parts[1].to_float()
			"skip-collision":
				_skip_collision = parts[1] == "1"

func _process(delta: float) -> void:
	if _quitting:
		return

	_elapsed_total += delta

	_spawner.tick(delta)
	_enemy_system.tick(delta)
	_hash.build(_enemy_store)
	_proj_system.tick(delta)

	_proj_render.sync(_proj_store.positions, _proj_store.active_count)
	_enemy_render.sync(_enemy_store.positions, _enemy_store.active_count)

	_logger.tick(delta, _proj_store.active_count, _enemy_store.active_count)
	_maybe_screenshot()

	if _spawner.at_final_level():
		_hold_timer += delta
		if _hold_timer >= _hold_at_peak:
			_finish()

func _maybe_screenshot() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for t in _shot_times:
		if _elapsed_total >= t and not _shots_taken.has(t):
			_shots_taken[t] = true
			var img := get_viewport().get_texture().get_image()
			var path := "res://benchmark_results/screenshot_t%d.png" % int(t)
			img.save_png(path)
			print("[benchmark] screenshot guardado: ", path)

func _finish() -> void:
	_quitting = true
	_logger.close()
	print("[benchmark] listo — proyectiles activos: %d, enemigos activos: %d" % [_proj_store.active_count, _enemy_store.active_count])
	get_tree().quit()
