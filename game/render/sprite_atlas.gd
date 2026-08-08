class_name SpriteAtlas
extends RefCounted

## Recorta frames individuales de un atlas en grilla — mismo patrón que
## POC/scripts/enemy_renderer.gd::_crop_frame(), portado tal cual (ver nota
## del director sobre gráficos y animación: el problema ya está resuelto
## una vez, no reinventarlo). Pensado para game/assets/characters.png
## (1024×1024, grilla 5×5: fila 0 jugador, filas 1-4 tipos de enemigo del
## POC; columnas idle/caminar/atacar/ranged/muerto).

var _image: Image
var _cols: int
var _rows: int
var _frame_w: float
var _frame_h: float

func _init(path: String, cols: int = 5, rows: int = 5) -> void:
	_image = load(path).get_image()
	_cols = cols
	_rows = rows
	_frame_w = _image.get_width() / float(cols)
	_frame_h = _image.get_height() / float(rows)

func crop_frame(col: int, row: int) -> ImageTexture:
	var x := int(col * _frame_w)
	var y := int(row * _frame_h)
	return ImageTexture.create_from_image(_image.get_region(Rect2i(x, y, int(_frame_w), int(_frame_h))))
