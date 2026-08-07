extends Node

@warning_ignore("UNUSED_SIGNAL")
signal enemy_killed(position: Vector2)
@warning_ignore("UNUSED_SIGNAL")
signal player_damaged(amount: float)
@warning_ignore("UNUSED_SIGNAL")
signal game_over
signal level_up
signal wave_scaled(new_mult: float)

const DIFF_INTERVAL := 60.0
const DIFF_STEP     := 0.20

var kill_count: int = 0
var elapsed_time: float = 0.0
var player_ref: CharacterBody2D = null
var is_game_over: bool = false

var xp: float = 0.0
var level: int = 1
var xp_to_next: float = 10.0
var first_weapon_chosen: bool = false
var difficulty_mult: float = 1.0

func _process(delta: float) -> void:
	if not is_game_over and not get_tree().paused:
		var old_tier := int(elapsed_time / DIFF_INTERVAL)
		elapsed_time += delta
		var new_tier := int(elapsed_time / DIFF_INTERVAL)
		if new_tier > old_tier:
			difficulty_mult = 1.0 + new_tier * DIFF_STEP
			wave_scaled.emit(difficulty_mult)

func add_xp(amount: float) -> void:
	var effective: float = amount * (1.0 + player_ref.harvest) if player_ref else amount
	xp += effective
	if xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = 10.0 * pow(level, 1.2)
		level_up.emit()

func reset() -> void:
	kill_count = 0
	elapsed_time = 0.0
	is_game_over = false
	player_ref = null
	xp = 0.0
	level = 1
	xp_to_next = 10.0
	first_weapon_chosen = false
	difficulty_mult = 1.0
