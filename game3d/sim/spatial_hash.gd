class_name SpatialHash
extends RefCounted

## Grilla uniforme reconstruida cada tick sobre las posiciones de los
## enemigos (el lado barato de la asimetría — ver directorsuggestions.md 2.2).
## Nada de Area2D/body_entered: cada proyectil consulta solo su celda + las
## 8 vecinas contra los pocos enemigos que caen ahí.

var cell_size: float
var _cells: Dictionary = {}

func _init(p_cell_size: float) -> void:
	cell_size = p_cell_size

func _key(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / cell_size), floori(pos.y / cell_size))

func build(store: EnemyStore) -> void:
	_cells.clear()
	for i in store.active_count:
		var k := _key(store.positions[i])
		var bucket: PackedInt32Array = _cells.get(k, PackedInt32Array())
		bucket.append(i)
		_cells[k] = bucket

## Índices (en EnemyStore) de la celda de `pos` y las 8 vecinas.
## Usado por herramientas/debug — el hot path (projectile_system.gd) itera
## las celdas directamente con key_for()/has_cell()/get_cell() para no pagar
## la asignación + copia de un array nuevo por proyectil por frame.
func query_nearby(pos: Vector2) -> PackedInt32Array:
	var result := PackedInt32Array()
	var base := _key(pos)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var k := Vector2i(base.x + dx, base.y + dy)
			if _cells.has(k):
				result.append_array(_cells[k])
	return result

## Igual que query_nearby() pero para radios mayores a una celda (torres de
## área — fase2-benchmark-conjunto.md sección 7: el chequeo de rectángulo
## de _tick_beam() tiene que acotarse por hash, no barrer active_count
## completo). Devuelve candidatos de un cuadrado de lado 2*radius, sin
## filtrar por distancia real — eso queda a cargo de quien llama, esto solo
## acota cuántos candidatos hay que revisar.
func query_radius(pos: Vector2, radius: float) -> PackedInt32Array:
	var result := PackedInt32Array()
	var base := _key(pos)
	var span := ceili(radius / cell_size)
	for dx in range(-span, span + 1):
		for dy in range(-span, span + 1):
			var k := Vector2i(base.x + dx, base.y + dy)
			if _cells.has(k):
				result.append_array(_cells[k])
	return result

func key_for(pos: Vector2) -> Vector2i:
	return _key(pos)

func has_cell(key: Vector2i) -> bool:
	return _cells.has(key)

func get_cell(key: Vector2i) -> PackedInt32Array:
	return _cells[key]

## Hot path real: barre las 9 celdas vecinas de `pos` y devuelve el primer
## índice de EnemyStore a distancia <= sqrt(radius_sq), o -1. Todo en una
## sola llamada (sin round-trips de método por celda) — es lo que
## projectile_system.gd usa en el batch de colisión.
## `exclude_idx` (Fase 2, proyectiles perforantes): salta ese índice en la
## búsqueda, para que un proyectil que ya pegó en un enemigo no vuelva a
## pegarle en el frame siguiente solo por seguir superpuesto — sin esto, un
## perforante gastaría todos sus impactos contra el mismo enemigo antes de
## alejarse lo suficiente.
func find_hit(pos: Vector2, radius_sq: float, enemy_positions: PackedVector2Array, exclude_idx: int = -1) -> int:
	var base := _key(pos)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var k := Vector2i(base.x + dx, base.y + dy)
			if not _cells.has(k):
				continue
			for e_idx in _cells[k]:
				if e_idx == exclude_idx:
					continue
				if enemy_positions[e_idx].distance_squared_to(pos) <= radius_sq:
					return e_idx
	return -1
