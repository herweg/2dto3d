class_name BenchmarkLogger
extends RefCounted

## Paso 0 de sprint-02.md — logger reproducible de frame time vs. conteo de
## entidades, a CSV, para poder graficar "entidades vs. frame time" al final
## y ubicar con precisión dónde cae de 60fps.

var _file: FileAccess
var _frame_count: int = 0
var _elapsed: float = 0.0

var _log_every_n_frames: int
var _window_time_sum: float = 0.0
var _window_frames: int = 0

func _init(path: String, log_every_n_frames: int = 15) -> void:
	_log_every_n_frames = log_every_n_frames
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	_file = FileAccess.open(path, FileAccess.WRITE)
	_file.store_csv_line(["elapsed_s", "frame", "proj_count", "enemy_count", "avg_frame_time_ms", "avg_fps"])

## Acumula `delta` en una ventana de N frames y escribe el promedio — una
## sola muestra por frame sería demasiado ruidosa para leer la curva.
func tick(delta: float, proj_count: int, enemy_count: int) -> void:
	_elapsed += delta
	_frame_count += 1
	_window_time_sum += delta
	_window_frames += 1

	if _window_frames < _log_every_n_frames:
		return

	var avg_frame_time_ms := (_window_time_sum / _window_frames) * 1000.0
	var avg_fps := _window_frames / _window_time_sum if _window_time_sum > 0.0 else 0.0

	_file.store_csv_line([
		"%.3f" % _elapsed,
		str(_frame_count),
		str(proj_count),
		str(enemy_count),
		"%.3f" % avg_frame_time_ms,
		"%.1f" % avg_fps,
	])

	_window_time_sum = 0.0
	_window_frames = 0

func close() -> void:
	if _file:
		_file.flush()
		_file.close()
