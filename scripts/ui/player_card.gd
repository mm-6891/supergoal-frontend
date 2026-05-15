## PlayerCard
## Renders a player card matching the Super Gol physical card template.
## Call populate(card_dict, profile_dict) to fill with data from the API.
## card_dict   -> response from GET /cards/{id}
## profile_dict -> response from GET /cards/{id}/profile

extends Control

const W = 260
const H = 400

# Card palette
const C_BG         = Color(0.97, 0.95, 0.88)   # cream paper
const C_HEADER     = Color(0.08, 0.15, 0.48)   # dark blue header band
const C_LEFT_BG    = Color(0.91, 0.89, 0.82)   # slightly darker cream for left panel
const C_PHOTO      = Color(0.72, 0.72, 0.72)   # gray skeleton photo
const C_BORDER     = Color(0.20, 0.20, 0.20)   # outer border
const C_DIVIDER    = Color(0.52, 0.52, 0.52)
const C_TEXT       = Color(0.08, 0.08, 0.08)
const C_TEXT_MID   = Color(0.38, 0.38, 0.38)
const C_TEXT_LIGHT = Color(0.62, 0.62, 0.62)
const C_WHITE      = Color.WHITE
const C_FOREIGN    = Color(0.85, 0.10, 0.10)   # red for foreign players

var _card:    Dictionary = {}
var _profile: Dictionary = {}
var display_scale: float = 1.0


func _ready() -> void:
	custom_minimum_size = Vector2(W * display_scale, H * display_scale)


func set_display_scale(s: float) -> void:
	display_scale = s
	custom_minimum_size = Vector2(W * s, H * s)
	queue_redraw()


func populate(card_data: Dictionary, profile_data: Dictionary) -> void:
	_card = card_data
	_profile = profile_data
	queue_redraw()


func _draw() -> void:
	if display_scale != 1.0:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(display_scale, display_scale))
	var font = ThemeDB.fallback_font

	# ------------------------------------------------------------------ #
	# Background
	# ------------------------------------------------------------------ #
	draw_rect(Rect2(0, 0, W, H), C_BG)

	# ------------------------------------------------------------------ #
	# Header band  (tiny labels: "Nombre" / "Escudo del club")
	# ------------------------------------------------------------------ #
	const HDR_H := 18
	draw_rect(Rect2(0, 0, W, HDR_H), C_HEADER)
	draw_string(font, Vector2(5, 13),      "Nombre",         HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.65, 0.75, 1.0))
	draw_string(font, Vector2(W - 90, 13), "Escudo del club",HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.65, 0.75, 1.0))

	# ------------------------------------------------------------------ #
	# Name row  (surname box + club shield placeholder)
	# ------------------------------------------------------------------ #
	const NAME_TOP := HDR_H
	const NAME_H   := 34

	# Club shield placeholder (top-right corner)
	const SHIELD_SZ := 30
	var shield_x := W - SHIELD_SZ - 4
	var shield_y := NAME_TOP + 2
	draw_rect(Rect2(shield_x, shield_y, SHIELD_SZ, SHIELD_SZ), Color(0.58, 0.58, 0.58))
	draw_rect(Rect2(shield_x, shield_y, SHIELD_SZ, SHIELD_SZ), C_DIVIDER, false, 1.0)
	var club: String = _profile.get("club", "---")
	var abbr := club.substr(0, 3).to_upper()
	draw_string(font, Vector2(shield_x + 3, shield_y + 20), abbr, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, C_WHITE)

	# Surname (large, inside a tinted box)
	var surname := _get_surname()
	draw_rect(Rect2(2, NAME_TOP + 2, shield_x - 6, NAME_H - 4), Color(0, 0, 0, 0.07))
	draw_string(font, Vector2(6, NAME_TOP + NAME_H - 7), surname,
			HORIZONTAL_ALIGNMENT_LEFT, shield_x - 10, 22, C_TEXT)

	# ------------------------------------------------------------------ #
	# Body  (left panel: datos + ficha | right: photo skeleton)
	# ------------------------------------------------------------------ #
	const BODY_TOP := NAME_TOP + NAME_H + 1
	const LEFT_W   := 72
	const BODY_H   := 170

	draw_rect(Rect2(0, BODY_TOP, LEFT_W, BODY_H), C_LEFT_BG)

	# -- "Datos" section --
	draw_string(font, Vector2(3, BODY_TOP + 12), "Datos", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_TEXT_MID)
	draw_line(Vector2(2, BODY_TOP + 14), Vector2(LEFT_W - 2, BODY_TOP + 14), C_DIVIDER, 0.7)

	var full_name:  String = _profile.get("full_name",  _card.get("name", ""))
	var birthplace: String = _profile.get("birthplace", "")
	var birth_date: String = _profile.get("birth_date", "")
	var h_cm = _profile.get("height_cm", null)
	var w_kg = _profile.get("weight_kg", null)
	var hw_str := ""
	if h_cm != null:
		var h_int: int = int(h_cm)
		hw_str = "%d,%02d" % [h_int / 100, h_int % 100]
		if w_kg != null:
			hw_str += " - %.0f kg" % [float(w_kg)]

	var dato_y := BODY_TOP + 27
	for line: String in [full_name, birthplace, birth_date, hw_str]:
		if line:
			draw_string(font, Vector2(3, dato_y), line,
					HORIZONTAL_ALIGNMENT_LEFT, LEFT_W - 4, 8, C_TEXT)
			dato_y += 11

	# -- "Ficha" section (bottom of left panel) --
	var ficha_sep_y := BODY_TOP + BODY_H - 62
	draw_line(Vector2(2, ficha_sep_y), Vector2(LEFT_W - 2, ficha_sep_y), C_DIVIDER, 0.7)
	draw_string(font, Vector2(3, ficha_sep_y + 12), "Ficha",         HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_TEXT_MID)
	draw_string(font, Vector2(3, ficha_sep_y + 22), "(Ext. en rojo)",HORIZONTAL_ALIGNMENT_LEFT, LEFT_W - 4, 7, C_TEXT_LIGHT)

	var ficha_num = _profile.get("ficha_num", null)
	var is_foreign: bool = _profile.get("is_foreign", false)
	var ficha_col := C_FOREIGN if is_foreign else C_TEXT
	var ficha_str := str(ficha_num) if ficha_num != null else "?"
	draw_string(font, Vector2(8, ficha_sep_y + 50), ficha_str,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 28, ficha_col)

	# -- Photo skeleton (right of body) --
	var photo_x := LEFT_W + 2
	var photo_w := W - photo_x - 2
	draw_rect(Rect2(photo_x, BODY_TOP, photo_w, BODY_H), C_PHOTO)
	draw_line(Vector2(photo_x,           BODY_TOP),
			  Vector2(photo_x + photo_w, BODY_TOP + BODY_H), Color(0.58, 0.58, 0.58), 1.5)
	draw_line(Vector2(photo_x + photo_w, BODY_TOP),
			  Vector2(photo_x,           BODY_TOP + BODY_H), Color(0.58, 0.58, 0.58), 1.5)
	draw_string(font, Vector2(photo_x + photo_w / 2 - 24, BODY_TOP + BODY_H / 2 + 6),
			"[ foto ]", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.42, 0.42, 0.42))

	# ------------------------------------------------------------------ #
	# Footer divider
	# ------------------------------------------------------------------ #
	var ftr_top := BODY_TOP + BODY_H + 2
	draw_line(Vector2(2, ftr_top), Vector2(W - 2, ftr_top), C_DIVIDER, 1.5)

	# ------------------------------------------------------------------ #
	# Footer left: Factores (stats)
	# ------------------------------------------------------------------ #
	var half := W / 2
	draw_string(font, Vector2(4, ftr_top + 12), "Factores",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_TEXT_MID)

	var stats := _build_stats()
	var stat_y := ftr_top + 23
	for line: String in stats:
		if stat_y > H - 6:
			break
		draw_string(font, Vector2(6, stat_y), line,
				HORIZONTAL_ALIGNMENT_LEFT, half - 8, 9, C_TEXT)
		stat_y += 10

	# ------------------------------------------------------------------ #
	# Footer right: Demarcacion (position)
	# ------------------------------------------------------------------ #
	draw_line(Vector2(half, ftr_top + 4), Vector2(half, H - 4), C_DIVIDER, 0.8)
	draw_string(font, Vector2(half + 4, ftr_top + 12), "Demarcacion",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_TEXT_MID)
	var dem: String = _profile.get("demarcacion", "---")
	draw_string(font, Vector2(half + 4, ftr_top + 38), dem,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 26, C_TEXT)

	# ------------------------------------------------------------------ #
	# Outer border
	# ------------------------------------------------------------------ #
	draw_rect(Rect2(0, 0, W, H), C_BORDER, false, 2.0)
	if display_scale != 1.0:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _get_surname() -> String:
	var n: String = _card.get("name", "---")
	return n.split(" ")[-1].to_upper()


func _build_stats() -> Array:
	var lines: Array = []
	var pairs := [
		["PC", "pc"], ["PL", "pl"], ["RG", "rg"], ["A", "a"], ["RB", "rb"],
		["RM", "rm"], ["DL", "dl"], ["LF", "lf"],
		["CO", "co"], ["RF", "rf"],
		["V",  "v"],  ["PA", "pa"], ["F",  "f"],  ["D",  "d"], ["RC", "rc"],
	]
	for pair: Array in pairs:
		var val = _card.get(pair[1], null)
		if val != null and int(val) != 0:
			lines.append("%s: %d" % [pair[0], int(val)])
	return lines
