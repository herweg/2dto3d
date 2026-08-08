class_name TowerSystem
extends RefCounted

## Targeting + disparo de torres (Fase 2, pantalla 1). Reutiliza
## ProjectileStore.spawn() tal como lo dejó el spike de Sprint 2 — no hace
## falta el hash espacial ni el hot path de Rust a la escala de una
## pantalla jugable, así que la búsqueda de objetivo es brute-force sobre
## enemy_store.positions.

const PROJ_SPEED := 520.0
const PROJ_LIFE := 1.5

var tower_store: TowerStore
var enemy_store: EnemyStore
var proj_store: ProjectileStore

func _init(p_tower: TowerStore, p_enemy: EnemyStore, p_proj: ProjectileStore) -> void:
	tower_store = p_tower
	enemy_store = p_enemy
	proj_store = p_proj

func tick(delta: float) -> void:
	for i in tower_store.active_count:
		tower_store.cooldown_left[i] -= delta
		if tower_store.cooldown_left[i] > 0.0:
			continue

		var target := _find_nearest_enemy(tower_store.positions[i], tower_store.range[i])
		if target == -1:
			continue

		var proj_type := tower_store.proj_type_of(i)
		var dir := (enemy_store.positions[target] - tower_store.positions[i]).normalized()

		# hits/objetivo/radio de splash dependen del tipo — el resto de tipos
		# los ignora (defaults seguros de ProjectileStore.spawn()).
		var hits := int(tower_store.proj_extra[i]) if proj_type == ProjectileSystem.PROJ_PIERCE else 1
		var homing_target := target if proj_type == ProjectileSystem.PROJ_HOMING else -1
		var splash := tower_store.proj_extra[i] if proj_type == ProjectileSystem.PROJ_SPLASH else 0.0

		proj_store.spawn(
			tower_store.positions[i], dir * PROJ_SPEED, PROJ_LIFE,
			tower_store.damage[i], proj_type, hits, homing_target, splash
		)
		tower_store.cooldown_left[i] = tower_store.fire_rate[i]

func _find_nearest_enemy(pos: Vector2, range_limit: float) -> int:
	var best := -1
	var best_dist_sq := range_limit * range_limit
	for e in enemy_store.active_count:
		var dist_sq := enemy_store.positions[e].distance_squared_to(pos)
		if dist_sq <= best_dist_sq:
			best_dist_sq = dist_sq
			best = e
	return best
