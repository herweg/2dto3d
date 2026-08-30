class_name TalentTreeDef
extends Resource

## Árbol de talentos (Fase 3, fase3-alcance-v1.md sección 3) — formato de
## datos para el "frame" pedido por el usuario (10-ago): mecánica de
## desbloqueo funcionando, sin depender de qué nodos existan. Ver
## docs/fase3-talentos-motor.md para el estado del contenido y qué sigue
## sin calibrar (costos/economía, conexión real a combate).
##
## Arreglos paralelos, mismo criterio SoA que EnemyStore/TowerStore/
## ProjectileStore — evita sub-recursos anidados en el .tres (frágiles de
## escribir a mano sin el editor). Cada índice es un nodo del árbol.

enum EffectScope { GLOBAL, TOWER_TYPE }

@export var ids: PackedStringArray = PackedStringArray()
@export var display_names: PackedStringArray = PackedStringArray()
@export var positions: PackedVector2Array = PackedVector2Array()

## "" = nodo raíz, sin prerequisito. Árbol simple (un padre por nodo), no
## grafo general — alcanza para el frame; si las notas de la próxima
## interacción piden nodos con más de un prerequisito, este campo pasa a
## PackedStringArray por nodo, cambio acotado.
@export var parent_ids: PackedStringArray = PackedStringArray()
@export var costs: PackedInt32Array = PackedInt32Array()

## Qué stat toca cada nodo y a quién — plumbing de datos, todavía sin
## conectar a combate (eso es la próxima interacción, con las notas
## reales). GLOBAL = afecta a todas las torres/jugador; TOWER_TYPE = solo
## target_tower_types[i] (índice de TowerStore.TOWER_TYPE_STATS).
@export var effect_scopes: PackedInt32Array = PackedInt32Array()
@export var target_tower_types: PackedInt32Array = PackedInt32Array()  # -1 si GLOBAL
@export var stat_ids: PackedStringArray = PackedStringArray()
@export var modifier_values: PackedFloat32Array = PackedFloat32Array()

func index_of(id: String) -> int:
	return ids.find(id)

func is_root(i: int) -> bool:
	return parent_ids[i] == ""
