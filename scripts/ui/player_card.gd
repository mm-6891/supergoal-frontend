## PlayerCard
## Renders a player card matching the Super Gol physical card template.
## Call populate(card_dict, profile_dict) to fill with data from the API.
## card_dict   -> response from GET /cards/{id}
## profile_dict -> response from GET /cards/{id}/profile

extends Control

const W = 260
const H = 400

# FIFA-365 style palette
const C_GOLD     = Color(1.00, 0.82, 0.10)   # gold accent / title
const C_STAT_BAR = Color(0.18, 0.65, 1.00)   # cyan-blue stat bar
const C_WHITE    = Color.WHITE
const C_SUBTLE   = Color(0.60, 0.60, 0.72)   # secondary text

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
	# Normalize null stat values to 0 so numeric reads never get Nil
	for key in _card:
		if _card[key] == null:
			_card[key] = 0
	queue_redraw()


func _draw() -> void:
	if display_scale != 1.0:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(display_scale, display_scale))
	var font := ThemeDB.fallback_font

	var overall  : int    = _compute_overall()
	var title    : String = _compute_title()
	var surname  : String = _get_surname()
	var full_name: String = _card.get("name", "---")

	# --- 1. GRADIENT BACKGROUNDS ---
	const PHOTO_H := 220
	# Upper photo area: dark navy gradient
	draw_polygon(
		PackedVector2Array([Vector2(0,0), Vector2(W,0), Vector2(W,PHOTO_H), Vector2(0,PHOTO_H)]),
		PackedColorArray([
			Color(0.04,0.07,0.14), Color(0.04,0.07,0.14),
			Color(0.10,0.14,0.24), Color(0.08,0.11,0.20),
		])
	)
	# Lower content area: near-black
	draw_polygon(
		PackedVector2Array([Vector2(0,PHOTO_H), Vector2(W,PHOTO_H), Vector2(W,H), Vector2(0,H)]),
		PackedColorArray([
			Color(0.04,0.04,0.10), Color(0.04,0.04,0.10),
			Color(0.08,0.08,0.16), Color(0.08,0.08,0.16),
		])
	)

	# --- 2. DECORATIVE CIRCUIT LINES ---
	draw_line(Vector2(0,0),   Vector2(W, PHOTO_H*0.7), Color(1,1,1,0.04), 18)
	draw_line(Vector2(W,0),   Vector2(0, PHOTO_H*0.7), Color(1,1,1,0.04), 18)
	draw_line(Vector2(0,PHOTO_H*0.3), Vector2(W*0.65,0), Color(1,1,1,0.03), 10)

	# --- 3. TEAM BADGE (top-left) ---
	var badge := Rect2(8, 8, 38, 38)
	draw_rect(badge, Color(0.06,0.08,0.18))
	draw_rect(badge, Color(0.28,0.30,0.50), false, 1.0)
	var club: String = _profile.get("club", "?")
	var abbr: String = club.substr(0, 3).to_upper() if club.length() >= 3 else club.to_upper()
	draw_string(font, Vector2(12, 33), abbr, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_GOLD)

	# --- 4. OVERALL RATING (top-right) ---
	var ov_str := str(overall)
	draw_string(font, Vector2(W - 50, 14), "OVR",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, C_SUBTLE)
	draw_string(font, Vector2(W - 56, 54), ov_str,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 42, C_WHITE)

	# --- 5. LARGE INITIAL (silhouette placeholder) ---
	var init: String = surname.substr(0, 1) if surname.length() > 0 else "?"
	var init_sz := 108
	var init_w  := font.get_string_size(init, HORIZONTAL_ALIGNMENT_LEFT, -1, init_sz).x
	draw_string(font, Vector2(W / 2.0 - init_w / 2.0 + 22, PHOTO_H - 14), init,
			HORIZONTAL_ALIGNMENT_LEFT, -1, init_sz, Color(1,1,1,0.10))

	# --- 6. KEY STATS (left column, lower photo area: PC, RM, RB) ---
	var stat_triples := [["PC","pc"],["RM","rm"],["RB","rb"]]
	var sy := PHOTO_H - 104
	const BAR_X := 54
	const BAR_W := 72
	const BAR_MAX := 15
	for sk: Array in stat_triples:
		var val: int = _card.get(sk[1] as String, 0)
		draw_string(font, Vector2(10, sy + 4),   sk[0] as String, HORIZONTAL_ALIGNMENT_LEFT, -1, 9,  C_GOLD)
		draw_string(font, Vector2(10, sy + 24),  str(val),  HORIZONTAL_ALIGNMENT_LEFT, -1, 22, C_WHITE)
		draw_rect(Rect2(BAR_X, sy + 12, BAR_W, 5), Color(0.12,0.14,0.28))
		var fill := int(BAR_W * clampf(float(val) / BAR_MAX, 0.0, 1.0))
		if fill > 0:
			draw_rect(Rect2(BAR_X, sy + 12, fill, 5), C_STAT_BAR)
		sy += 34

	# --- 7. GOLD SEPARATOR ---
	draw_line(Vector2(0, PHOTO_H), Vector2(W, PHOTO_H), C_GOLD, 2.0)
	draw_rect(Rect2(0, PHOTO_H, W, 3), Color(1.0, 0.82, 0.10, 0.30))

	# --- 8. BOTTOM CONTENT ---
	const BOT := PHOTO_H
	# Category / title
	var title_w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(font, Vector2(W / 2.0 - title_w / 2.0, BOT + 20), title,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, C_GOLD)
	# Surname (large white)
	var sn_w := font.get_string_size(surname, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	draw_string(font, Vector2(W / 2.0 - sn_w / 2.0, BOT + 44), surname,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 26, C_WHITE)
	# Full name (small)
	draw_string(font, Vector2(8, BOT + 58), full_name,
			HORIZONTAL_ALIGNMENT_LEFT, W - 16, 9, C_SUBTLE)
	# Divider
	draw_line(Vector2(8, BOT + 66), Vector2(W - 8, BOT + 66), Color(0.28,0.30,0.46), 0.7)

	# Secondary stats (2-column grid: PL, RG, A, V, DL, PA)
	var extra_pairs := [["PL","pl"],["RG","rg"],["A","a"],["V","v"],["DL","dl"],["PA","pa"]]
	var ex_y := BOT + 78
	var col  := 0
	for pair: Array in extra_pairs:
		var v: int = _card.get(pair[1] as String, 0)
		if v == 0:
			continue
		draw_string(font, Vector2(10 + col * 120, ex_y), "%s: %d" % [pair[0], v],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9, C_SUBTLE)
		col = (col + 1) % 2
		if col == 0:
			ex_y += 12

	# Ficha num (bottom-left)
	var ficha_num = _profile.get("ficha_num", null)
	if ficha_num != null:
		var is_foreign: bool = _profile.get("is_foreign", false)
		var fc: Color = Color(0.85, 0.15, 0.15) if is_foreign else C_SUBTLE
		draw_string(font, Vector2(6, H - 6), str(ficha_num),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9, fc)
	# Demarcacion (bottom-right)
	var dem: String = _profile.get("demarcacion", "")
	if dem != "":
		var dem_w := font.get_string_size(dem, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		draw_string(font, Vector2(W - dem_w - 6, H - 6), dem,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9, C_SUBTLE)

	# --- 9. GOLDEN FRAME ---
	draw_rect(Rect2(0, 0, W, H), C_GOLD, false, 2.5)
	draw_rect(Rect2(3, 3, W - 6, H - 6), Color(1.0, 0.82, 0.10, 0.22), false, 1.0)

	if display_scale != 1.0:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)



func _get_surname() -> String:
	var n: String = _card.get("name", "---")
	return n.split(" ")[-1].to_upper()


func _compute_overall() -> int:
	var keys := ["pc", "pl", "rg", "a", "rb", "rm", "dl", "v"]
	var total := 0
	var count := 0
	for k: String in keys:
		var v: int = _card.get(k, 0)
		if v > 0:
			total += v
			count += 1
	return (total / count) if count > 0 else 0


func _compute_title() -> String:
	var pc: int = _card.get("pc", 0)
	var pl: int = _card.get("pl", 0)
	var rm: int = _card.get("rm", 0)
	var dl: int = _card.get("dl", 0)
	var rb: int = _card.get("rb", 0)
	var rg: int = _card.get("rg", 0)
	var v:  int = _card.get("v",  0)
	var candidates: Array = [
		[pc + pl, "PLAYMAKER"],
		[rm + dl, "STRIKER"],
		[rb,      "HUNTER"],
		[rg,      "DRIBBLER"],
		[v,       "SPEEDSTER"],
	]
	var best_name := "COMPLETE"
	var best_val  := 0
	for c: Array in candidates:
		if (c[0] as int) > best_val:
			best_val  = c[0] as int
			best_name = c[1] as String
	return best_name
