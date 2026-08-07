extends Node2D

const MAX_ENEMIES := 1000
const FRAME_W     := 1024.0 / 5.0
const FRAME_H     := 1024.0 / 5.0

# Tamaño de quad por tipo (goblin, bruto, chaman, guardian)
const QUAD_SIZES := [40.0, 54.0, 38.0, 62.0]

var _pool_ref: Array = []

var _idle_textures: Array[ImageTexture] = []
var _walk_textures: Array[ImageTexture] = []
var _multimeshes:   Array[MultiMesh]          = []
var _mmis:          Array[MultiMeshInstance2D] = []

var _anim_timer: float = 0.0
var _anim_frame: int   = 0

func _ready() -> void:
	add_to_group("enemy_renderer")
	_build_multimeshes()

func _build_multimeshes() -> void:
	var img: Image = load("res://assets/characters.png").get_image()

	for type_idx in 4:
		var sprite_row := type_idx + 1  # spritesheet fila 1‑4
		_idle_textures.append(_crop_frame(img, 0, sprite_row))
		_walk_textures.append(_crop_frame(img, 1, sprite_row))

		var quad := QuadMesh.new()
		quad.size = Vector2(QUAD_SIZES[type_idx], QUAD_SIZES[type_idx])

		var mm := MultiMesh.new()
		mm.transform_format  = MultiMesh.TRANSFORM_2D
		mm.use_colors        = true
		mm.mesh              = quad
		mm.instance_count    = MAX_ENEMIES
		mm.visible_instance_count = 0
		_multimeshes.append(mm)

		var mmi := MultiMeshInstance2D.new()
		mmi.multimesh = mm
		mmi.texture   = _idle_textures[type_idx]
		add_child(mmi)
		_mmis.append(mmi)

func _crop_frame(img: Image, col: int, row: int) -> ImageTexture:
	var x := int(col * FRAME_W)
	var y := int(row * FRAME_H)
	return ImageTexture.create_from_image(img.get_region(Rect2i(x, y, int(FRAME_W), int(FRAME_H))))

func set_pool(pool_array: Array) -> void:
	_pool_ref = pool_array

func _process(delta: float) -> void:
	if _pool_ref.is_empty():
		return

	# Animación sincronizada para todos los tipos
	_anim_timer += delta
	if _anim_timer >= 0.2:
		_anim_timer = 0.0
		_anim_frame = (_anim_frame + 1) % 2
		for i in 4:
			_mmis[i].texture = _walk_textures[i] if _anim_frame == 1 else _idle_textures[i]

	# Contadores por tipo
	var counts := [0, 0, 0, 0]

	for e in _pool_ref:
		if not e.active and not e.dying:
			continue
		var s: float = e.scale.x
		if s <= 0.001:
			continue
		var t: int = e.enemy_type
		var c: int = counts[t]
		if c >= MAX_ENEMIES:
			continue

		var flip_x: float = 1.0
		if GameManager.player_ref and GameManager.player_ref.global_position.x < e.global_position.x:
			flip_x = -1.0

		_multimeshes[t].set_instance_transform_2d(
			c,
			Transform2D(0.0, Vector2(s * flip_x, -s), 0.0, e.global_position)
		)
		var f: float = e.hit_flash
		_multimeshes[t].set_instance_color(c, Color(
			1.0,
			lerpf(1.0, 0.3, f),
			lerpf(1.0, 0.3, f),
			1.0
		))
		counts[t] += 1

	for i in 4:
		_multimeshes[i].visible_instance_count = counts[i]
