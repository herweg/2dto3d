class_name DotSystem
extends RefCounted

## Aplica daño en el tiempo (combat-design-v1.md, slot único sin stackeo) —
## la pieza de lógica genuinamente nueva de fase2-plan-proyectiles.md 1.1.
## Quien alimenta dot_dps/dot_time_left no le importa a este sistema: puede
## ser PROJ_ZONE (projectile_system.gd) o el láser (tower_system.gd),
## ambos refrescan el mismo timer por diseño — "el que refresca último gana"
## es el comportamiento esperado, no un bug.

var enemy_store: EnemyStore

func _init(p_enemy: EnemyStore) -> void:
	enemy_store = p_enemy

func tick(delta: float) -> void:
	for i in enemy_store.active_count:
		if enemy_store.dot_time_left[i] <= 0.0:
			continue
		enemy_store.dot_time_left[i] -= delta
		enemy_store.health[i] -= enemy_store.dot_dps[i] * delta
