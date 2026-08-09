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

## Fondo/tema de la pantalla (tarjeta de motor confirmada por el director,
## docs/diseno-grafico.md sección 2, 08-ago): hasta ahora LevelDef era
## geometría pura, sin dónde enganchar arte de ambiente. `background_texture`
## es opcional — null significa "Arte todavía no entregó nada para esta
## pantalla", y se ve `background_color` plano en su lugar (no negro/default
## del viewport). `background_rect` son coordenadas de mundo, las mismas que
## path_rects/buildable_zones — no se infiere del resto de la geometría
## porque el fondo (ambientación) puede exceder el carril y la zona
## construible.
@export var background_texture: Texture2D = null
@export var background_color: Color = Color(0.09, 0.10, 0.08, 1.0)
@export var background_rect: Rect2 = Rect2(-680, -400, 1400, 840)

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

## Punto más cercano de `path_rects` a `pos` — clampea `pos` a cada rect por
## separado (barato, sin raíz cuadrada) y se queda con el más cercano de los
## candidatos. Usado para la dirección fija de disparo de las torres sin
## targeting real (tower_system.gd, plan-fases.md 09-ago) — se llama una
## sola vez al colocar la torre, no por tick.
func nearest_point_on_path(pos: Vector2) -> Vector2:
	var best := Vector2.ZERO
	var best_dist_sq := INF
	for r in path_rects:
		var clamped := Vector2(
			clampf(pos.x, r.position.x, r.end.x),
			clampf(pos.y, r.position.y, r.end.y)
		)
		var dist_sq := pos.distance_squared_to(clamped)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best = clamped
	return best
