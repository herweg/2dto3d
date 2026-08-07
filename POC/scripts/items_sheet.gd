class_name ItemsSheet
extends RefCounted

# Asset: res://assets/items.png  (1402 × 814) — fondo transparente
# Row 0 — buff icons   (y=0..230):    speed|life|damage|defense|crit
# Row 1 — weapons top  (y=230..525):  sword|axe|mace|bow|staff
# Row 2 — weapons bot  (y=525..814):  dagger|spear|crossbow|pistol|rifle
# 5 columnas iguales ≈ 280px (1402 / 5)

const REGIONS: Dictionary = {
	# Fila 0 — buff icons
	"speed":    Rect2i(0,    0,   280, 230),
	"life":     Rect2i(280,  0,   280, 230),
	"damage":   Rect2i(560,  0,   281, 230),
	"defense":  Rect2i(841,  0,   280, 230),
	"crit":     Rect2i(1121, 0,   281, 230),
	# Fila 1 — armas top
	"sword":    Rect2i(0,    230, 280, 295),
	"axe":      Rect2i(280,  230, 280, 295),
	"mace":     Rect2i(560,  230, 281, 295),
	"bow":      Rect2i(841,  230, 280, 295),
	"staff":    Rect2i(1121, 230, 281, 295),
	# Fila 2 — armas bot
	"dagger":   Rect2i(0,    525, 280, 289),
	"spear":    Rect2i(280,  525, 280, 289),
	"crossbow": Rect2i(560,  525, 281, 289),
	"pistol":   Rect2i(841,  525, 280, 289),
	"rifle":    Rect2i(1121, 525, 281, 289),
}

const ITEM_ICON: Dictionary = {
	# Weapons
	"pistola":       "pistol",
	"baculo":        "staff",
	"orbe":          "mace",
	"arco":          "bow",
	# Generic stats
	"hp":            "life",
	"regen":         "life",
	"armor":         "defense",
	"dodge":         "defense",
	"speed":         "speed",
	"damage":        "damage",
	"atk_speed":     "damage",
	"proj_speed":    "crit",
	"range":         "crit",
	"life_steal":    "life",
	"harvest":       "life",
	# Weapon-specific upgrades
	"orbe_orb":      "mace",
	"orbe_cooldown": "mace",
	"orbe_orbit":    "mace",
	"pistola_damage":"pistol",
	"pistola_cd":    "pistol",
	"baculo_damage": "staff",
	"baculo_cd":     "staff",
	"arco_damage":   "bow",
	"arco_cd":       "bow",
}

static func get_icon(item_id: String, img: Image) -> ImageTexture:
	if img == null:
		return null
	var key: String = ITEM_ICON.get(item_id, "")
	if key.is_empty() or not REGIONS.has(key):
		return null
	return ImageTexture.create_from_image(img.get_region(REGIONS[key]))
