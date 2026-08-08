class_name EnemySystem
extends RefCounted

## Steering simple hacia un ancla fija (jugador sintético), deteniéndose en
## `stand_off` (radio de "melee") en vez de converger todos al mismo punto —
## si no, se apilan sobre el spawn de proyectiles y los matan al instante,
## invalidando la medición. Sin push-out de paredes: el caso de prueba del
## spike no tiene paredes — eso se conserva del POC recién en Fase 2 (ver
## sprint-02.md, "Qué NO es este sprint").

var store: EnemyStore
var anchor: Vector2 = Vector2.ZERO

func _init(p_store: EnemyStore) -> void:
	store = p_store

func tick(delta: float) -> void:
	var i := 0
	while i < store.active_count:
		if store.health[i] <= 0.0:
			store.release(i)
			continue
		var to_anchor := anchor - store.positions[i]
		var dist := to_anchor.length()
		if dist > store.stand_off[i]:
			store.positions[i] += (to_anchor / dist) * store.speed[i] * delta
		i += 1
