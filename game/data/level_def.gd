class_name LevelDef
extends Resource

## Definición de pantalla — geometría pura, sin arte (Fase 2, pantalla 1).
## Ver docs/referencia-orc-problem.md: gris = zona construible, verde = carril
## por el que avanzan los enemigos de spawn_point a goal_point.

## Rects cuya unión forma el carril (verde). Un punto está "en el carril" si
## cae dentro de alguno de estos rects.
@export var path_rects: Array[Rect2] = []

## Puntos guía de alto nivel que los enemigos persiguen en orden (no incluye
## spawn_point — el primer waypoint es el primer punto al que se dirigen).
@export var waypoints: PackedVector2Array = PackedVector2Array()

## Centros de los obstáculos ("árboles") dentro del carril + su radio de
## repulsión — ver lane_enemy_system.gd.
@export var obstacles: PackedVector2Array = PackedVector2Array()
@export var obstacle_radius: float = 20.0

## Rects (gris) donde el jugador puede colocar torres.
@export var buildable_zones: Array[Rect2] = []

@export var spawn_point: Vector2 = Vector2.ZERO
@export var goal_point: Vector2 = Vector2.ZERO

func is_in_path(pos: Vector2) -> bool:
	for r in path_rects:
		if r.has_point(pos):
			return true
	return false

func is_buildable(pos: Vector2) -> bool:
	for r in buildable_zones:
		if r.has_point(pos):
			return true
	return false
