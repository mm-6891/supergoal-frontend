## Board
## Draws the board horizontally: HOME goal on the left, AWAY goal on the right.
## Backend coordinates unchanged: row 0 = HOME goal, row 5 = AWAY goal.
## On screen: row maps to the X axis (left→right), col maps to the Y axis (top→bottom).
## Visual grid is therefore COLS_SCREEN=6 columns × ROWS_SCREEN=5 rows.

extends Node2D
class_name Board

const ROWS = 6          # backend rows (0-5)
const COLS = 5          # backend cols (0-4)
const CELL_SIZE = 105
const GK_STRIP_W = 50   # width of goal strip on left/right sides
const GRID_X = GK_STRIP_W  # x-pixel where the 6x5 grid starts

# ---------------------------------------------------------------------------
# Zone definitions per cell [row][col]
# Zones define which special actions are allowed from that cell.
# Matches the physical Super Gol board layout.
# ---------------------------------------------------------------------------
# Zone codes: ""=normal, "PA"=high-pass, "DL"=long-shot,
#             "RM"=close-shot, "PA/DL"=both
const ZONE_MAP: Array = [
	# row 0 (AWAY goal area) - corners PA, center 3 RM
	["PA",    "RM",    "RM",    "RM",    "PA"],
	# row 1
	["PA",    "PA/DL", "DL",    "PA/DL", "PA"],
	# row 2 (center - no zone)
	["",      "",      "",      "",      ""],
	# row 3 (center - no zone)
	["",      "",      "",      "",      ""],
	# row 4
	["PA",    "PA/DL", "DL",    "PA/DL", "PA"],
	# row 5 (HOME goal area) - corners PA, center 3 RM
	["PA",    "RM",    "RM",    "RM",    "PA"],
]

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
const C_FIELD       = Color(0.13, 0.55, 0.13)
const C_FIELD_DARK  = Color(0.10, 0.45, 0.10)   # alternating stripe
const C_GRID        = Color(1.0, 1.0, 1.0, 0.40)
const C_CENTER_LINE = Color(1.0, 1.0, 1.0, 0.75)
const C_AREA_HOME   = Color(0.20, 0.40, 1.0,  0.18)
const C_AREA_AWAY   = Color(1.0,  0.30, 0.30, 0.18)
const C_HOME        = Color(0.18, 0.45, 0.90)
const C_AWAY        = Color(0.90, 0.25, 0.25)
const C_BALL        = Color(1.0,  0.90, 0.0)
const C_SELECTED    = Color(1.0,  1.0,  1.0)
const C_ZONE_PA     = Color(1.0,  1.0,  1.0, 0.10)
const C_ZONE_DL     = Color(1.0,  1.0,  0.3, 0.10)
const C_ZONE_RM     = Color(1.0,  0.4,  0.0, 0.15)
const C_ZONE_TEXT   = Color(1.0,  1.0,  1.0, 0.55)
const C_MARK_MAN    = Color(1.0,  0.60, 0.0)         # naranja: marcaje al hombre
const C_MARK_ZONE   = Color(0.0,  0.85, 0.85, 0.80)  # cian: marcaje en zona
const C_CONTESTED   = Color(1.0,  0.85, 0.0, 0.18)  # tinte casilla disputada

signal player_clicked(player_id: String)
signal goalkeeper_clicked(team: String)

var _state: Dictionary = {}
var _selected_id: String = ""
var _player_draws: Array = []


func update_from_state(state: Dictionary) -> void:
	_state = state
	_rebuild_players()
	queue_redraw()


func set_selected(player_id: String) -> void:
	_selected_id = player_id
	_rebuild_players()
	queue_redraw()


# ---------------------------------------------------------------------------
# Field drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	var font := ThemeDB.fallback_font
	# Screen grid: ROWS columns wide × COLS rows tall
	var grid_w: float = ROWS * CELL_SIZE   # 6 * 105 = 630
	var grid_h: float = COLS * CELL_SIZE   # 5 * 105 = 525

	# -----------------------------------------------------------------------
	# Porteria strips on left (HOME) and right (AWAY)
	# -----------------------------------------------------------------------
	var gk_home: String = _state.get("home", {}).get("goalkeeper_name", "Portero HOME")
	var gk_away: String = _state.get("away", {}).get("goalkeeper_name", "Portero AWAY")
	_draw_porteria(font, 0.0,                grid_h, C_HOME, false, gk_home)  # left strip
	_draw_porteria(font, GRID_X + grid_w,    grid_h, C_AWAY, true,  gk_away)  # right strip

	# -----------------------------------------------------------------------
	# Grid: row=X axis (left→right), col=Y axis (top→bottom)
	# -----------------------------------------------------------------------

	# Alternating stripe background (stripes along rows = vertical bands)
	for r in range(ROWS):
		var c_bg := C_FIELD if r % 2 == 0 else C_FIELD_DARK
		draw_rect(Rect2(GRID_X + r * CELL_SIZE, 0, CELL_SIZE, grid_h), c_bg)

	# Shooting zone tints + zone labels
	for r in range(ROWS):
		for c in range(COLS):
			var zone: String = ZONE_MAP[r][c]
			var cell_rect := Rect2(GRID_X + r * CELL_SIZE, c * CELL_SIZE, CELL_SIZE, CELL_SIZE)

			if zone == "RM":
				draw_rect(cell_rect, C_ZONE_RM)
			elif zone == "DL":
				draw_rect(cell_rect, C_ZONE_DL)
			elif zone == "PA":
				draw_rect(cell_rect, C_ZONE_PA)
			elif zone == "PA/DL":
				draw_rect(cell_rect, C_ZONE_PA)
				draw_rect(cell_rect, C_ZONE_DL)

			if zone != "":
				var label_pos := Vector2(
					GRID_X + r * CELL_SIZE + CELL_SIZE / 2.0,
					c * CELL_SIZE + CELL_SIZE - 6
				)
				draw_string(font, label_pos - Vector2(zone.length() * 3.5, 0),
					zone, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_ZONE_TEXT)

	# Grid lines
	for r in range(ROWS + 1):
		# centre line between row 2 and row 3 (the half-way line)
		var lw := 2.5 if r == 3 else 1.0
		var lc := C_CENTER_LINE if r == 3 else C_GRID
		draw_line(
			Vector2(GRID_X + r * CELL_SIZE, 0),
			Vector2(GRID_X + r * CELL_SIZE, grid_h),
			lc, lw
		)
	for c in range(COLS + 1):
		draw_line(
			Vector2(GRID_X,          c * CELL_SIZE),
			Vector2(GRID_X + grid_w, c * CELL_SIZE),
			C_GRID, 1.0
		)

	# Area overlays (rows 0-1 = HOME area left; rows 4-5 = AWAY area right)
	draw_rect(Rect2(GRID_X,                        0, 2 * CELL_SIZE, grid_h), C_AREA_HOME)
	draw_rect(Rect2(GRID_X + 4 * CELL_SIZE,        0, 2 * CELL_SIZE, grid_h), C_AREA_AWAY)
	draw_rect(Rect2(GRID_X,                        0, 2 * CELL_SIZE, grid_h), C_AREA_HOME, false, 2.0)
	draw_rect(Rect2(GRID_X + 4 * CELL_SIZE,        0, 2 * CELL_SIZE, grid_h), C_AREA_AWAY, false, 2.0)

	# Casillas disputadas: HOME y AWAY comparten celda → tinte + borde amarillo
	if not _state.is_empty():
		var cell_home: Dictionary = {}
		var cell_away: Dictionary = {}
		for p in _state.get("home", {}).get("players", []):
			var k := "%d,%d" % [p["row"], p["col"]]
			cell_home[k] = true
		for p in _state.get("away", {}).get("players", []):
			var k := "%d,%d" % [p["row"], p["col"]]
			cell_away[k] = true
		for key in cell_home:
			if cell_away.has(key):
				var parts: PackedStringArray = (key as String).split(",")
				var cr := int(parts[0])
				var cc := int(parts[1])
				var crect := Rect2(GRID_X + cr * CELL_SIZE, cc * CELL_SIZE, CELL_SIZE, CELL_SIZE)
				draw_rect(crect, C_CONTESTED)
				draw_rect(crect, C_MARK_MAN, false, 2.0)

	# Ball indicator
	if not _state.is_empty():
		var br: int = _state.get("ball_row", 2)
		var bc: int = _state.get("ball_col", 2)
		for p in _state.get("home", {}).get("players", []):
			if p.get("has_ball", false):
				br = p["row"]; bc = p["col"]
		for p in _state.get("away", {}).get("players", []):
			if p.get("has_ball", false):
				br = p["row"]; bc = p["col"]
		_draw_soccer_ball(_cell_center(br, bc), 12.0)

	# Column number labels (top margin)
	for c in range(COLS):
		draw_string(font,
			Vector2(GRID_X - 24, c * CELL_SIZE + CELL_SIZE / 2.0 + 6),
			str(c), HORIZONTAL_ALIGNMENT_RIGHT, -1, 14, Color(1, 1, 1, 0.7))

	# Player names drawn along the direction of play
	# HOME attacks right → text reads left-to-right (no rotation)
	# AWAY attacks left  → text reads right-to-left (180° rotation, or just mirrored)
	for d in _player_draws:
		var ctr: Vector2 = d["center"]
		var surname: String = d["name"]
		var fs := 10
		var tw: float = font.get_string_size(surname, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if d["team"] == "home":
			# rotate 90° CW so text reads top-to-bottom inside the cell
			draw_set_transform(ctr, PI / 2.0, Vector2.ONE)
		else:
			# rotate 90° CCW so text reads bottom-to-top inside the cell
			draw_set_transform(ctr, -PI / 2.0, Vector2.ONE)
		draw_string(font, Vector2(-tw / 2.0, fs / 2.0), surname,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------------------
# Players as buttons - two per cell, split top/bottom (along col axis)
# ---------------------------------------------------------------------------

func _rebuild_players() -> void:
	_player_draws = []
	for child in get_children():
		child.queue_free()

	if _state.is_empty():
		return

	# Goalkeepers: HOME on the left strip, AWAY on the right strip
	var home_gk: String = _state.get("home", {}).get("goalkeeper_name", "")
	if home_gk != "":
		_add_goalkeeper_button(home_gk, "home")
	var away_gk: String = _state.get("away", {}).get("goalkeeper_name", "")
	if away_gk != "":
		_add_goalkeeper_button(away_gk, "away")

	# Count occupants per cell to assign slot (0=top, 1=bottom)
	var cell_counts: Dictionary = {}

	var all_players: Array = []
	for p in _state["home"]["players"]:
		all_players.append({"data": p, "team": "home"})
	for p in _state["away"]["players"]:
		all_players.append({"data": p, "team": "away"})

	for entry in all_players:
		var p: Dictionary = entry["data"]
		var key := "%d,%d" % [p["row"], p["col"]]
		var slot: int = cell_counts.get(key, 0)
		cell_counts[key] = slot + 1
		var color := C_HOME if entry["team"] == "home" else C_AWAY
		_add_player_button(p, color, slot, entry["team"])


func _add_player_button(player: Dictionary, color: Color, slot: int, team: String) -> void:
	# slot 0 = top half of cell, slot 1 = bottom half
	# In horizontal layout: row → X, col → Y
	const MARGIN := 3
	const HALF_H := CELL_SIZE / 2 - MARGIN - 1

	var cell_x: int = GRID_X + player["row"] * CELL_SIZE
	var cell_y: int = player["col"] * CELL_SIZE
	var btn_x: int = cell_x + MARGIN
	var btn_y: int = cell_y + MARGIN + slot * (HALF_H + MARGIN + 1)
	var btn_w: int = CELL_SIZE - MARGIN * 2
	var btn_h: int = HALF_H

	var btn := Button.new()
	btn.position = Vector2(btn_x, btn_y)
	btn.size     = Vector2(btn_w, btn_h)
	btn.flat     = true
	btn.clip_text = true
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER

	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(6)

	var has_ball: bool = player.get("has_ball", false)
	var is_selected: bool = player["id"] == _selected_id

	if has_ball:
		style.set_border_width_all(3)
		style.border_color = C_BALL
	elif is_selected:
		style.set_border_width_all(3)
		style.border_color = C_SELECTED
	else:
		var mtype: String = player.get("marking_type", "free")
		if mtype == "man_to_man":
			# Marcaje al hombre: borde amarillo solido
			style.set_border_width_all(3)
			style.border_color = C_MARK_MAN
		elif mtype == "zone":
			# Marcaje en zona: borde amarillo tenue
			style.set_border_width_all(2)
			style.border_color = C_MARK_ZONE
		else:
			# Direction indicator: HOME attacks right → right border; AWAY attacks left → left border
			if team == "home":
				style.border_width_right = 4
			else:
				style.border_width_left = 4
			style.border_color = color.lightened(0.5)

	btn.add_theme_stylebox_override("normal",   style)
	btn.add_theme_stylebox_override("hover",    style)
	btn.add_theme_stylebox_override("pressed",  style)
	btn.add_theme_stylebox_override("disabled", style)

	btn.text = ""  # name drawn in _draw()
	var parts: Array = player.get("name", player["id"]).split(" ")
	_player_draws.append({
		"center": Vector2(btn_x + btn_w / 2.0, btn_y + btn_h / 2.0),
		"team":   team,
		"name":   parts[-1],
	})

	var pid: String = player["id"]
	btn.pressed.connect(func(): player_clicked.emit(pid))
	add_child(btn)


func _add_goalkeeper_button(gk_name: String, team: String) -> void:
	var grid_h: float = COLS * CELL_SIZE
	var btn := Button.new()
	if team == "home":
		btn.position = Vector2(0, 0)
	else:
		btn.position = Vector2(GRID_X + ROWS * CELL_SIZE, 0)
	btn.size  = Vector2(GK_STRIP_W, grid_h)
	btn.flat  = true
	btn.clip_text = true

	var transparent := StyleBoxFlat.new()
	transparent.bg_color = Color(0, 0, 0, 0)
	transparent.set_border_width_all(0)
	btn.add_theme_stylebox_override("normal",   transparent)
	btn.add_theme_stylebox_override("hover",    transparent)
	btn.add_theme_stylebox_override("pressed",  transparent)
	btn.add_theme_stylebox_override("disabled", transparent)

	btn.pressed.connect(func(): goalkeeper_clicked.emit(team))
	add_child(btn)


func _draw_porteria(font: Font, x: float, h: float, team_color: Color,
		crossbar_right: bool, gk_name: String) -> void:
	var w: float = GK_STRIP_W
	# Goal mouth spans col 2 only (center), cols 0-1 and 3-4 are walls
	var post_y1: float = 2 * CELL_SIZE          # top goal post (col 2)
	var post_y2: float = 3 * CELL_SIZE          # bottom goal post (col 3 top edge)
	var goal_h: float  = post_y2 - post_y1      # 1 * CELL_SIZE
	var crossbar_x: float = x + w if crossbar_right else x

	# 1. Dark background
	var bg := Color(0.08, 0.08, 0.10, 1.0)
	draw_rect(Rect2(x, 0, w, h), bg)

	# 2. Wall panels (cols 0-1 top and cols 3-4 bottom)
	var wall_col := team_color.darkened(0.35)
	wall_col.a = 0.85
	draw_rect(Rect2(x, 0,       w, post_y1),     wall_col)  # top walls (2 cells)
	draw_rect(Rect2(x, post_y2, w, h - post_y2), wall_col)  # bottom walls (2 cells)
	for i in range(0, int(post_y1) + 1, 12):
		var wc := team_color.lightened(0.1)
		wc.a = 0.25
		draw_line(Vector2(x, i),           Vector2(x + w, i + 10),           wc, 1.0)
	for i in range(0, int(h - post_y2) + 1, 12):
		var wc := team_color.lightened(0.1)
		wc.a = 0.25
		draw_line(Vector2(x, post_y2 + i), Vector2(x + w, post_y2 + i + 10), wc, 1.0)

	# 3. Net area
	draw_rect(Rect2(x, post_y1, w, goal_h), Color(0.12, 0.12, 0.14, 1.0))
	var net_col := Color(1.0, 1.0, 1.0, 0.18)
	var net_step := 12.0
	var yi := post_y1
	while yi <= post_y2:
		draw_line(Vector2(x, yi), Vector2(x + w, yi), net_col, 0.8)
		yi += net_step
	var xi := x
	while xi <= x + w:
		draw_line(Vector2(xi, post_y1), Vector2(xi, post_y2), net_col, 0.8)
		xi += net_step

	# 4. Goal posts (horizontal bars)
	var post_col := Color(0.95, 0.95, 0.95)
	draw_rect(Rect2(x, post_y1 - 4, w, 6), post_col)
	draw_rect(Rect2(x, post_y2 - 2, w, 6), post_col)

	# 5. Crossbar (bar at the field-facing edge)
	draw_rect(Rect2(crossbar_x - 3, post_y1 - 4, 6, goal_h + 10), post_col)

	# 6. Team color accent on field-facing edge
	var accent := team_color.lightened(0.15)
	accent.a = 0.9
	if crossbar_right:
		draw_line(Vector2(x, 0), Vector2(x, h), accent, 2.5)       # left edge
	else:
		draw_line(Vector2(x + w, 0), Vector2(x + w, h), accent, 2.5) # right edge

	# 7. GK name (rotated 90° to fit vertical strip)
	var fs := 13
	var surname := gk_name.split(" ")[-1]
	var label := "GK: " + surname
	var tw: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var lx: float = x + w / 2.0
	var ly: float = post_y1 + goal_h / 2.0
	draw_set_transform(Vector2(lx, ly), -PI / 2.0, Vector2.ONE)
	draw_string(font, Vector2(-tw / 2.0 + 1, fs / 2.0 + 1), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.6))
	draw_string(font, Vector2(-tw / 2.0, fs / 2.0), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 8. Side label (HOME / AWAY) on wall areas
	var side_fs := 9
	var side_lbl := "HOME" if not crossbar_right else "AWAY"
	var slw: float = font.get_string_size(side_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, side_fs).x
	draw_set_transform(Vector2(x + w / 2.0, post_y1 / 2.0), -PI / 2.0, Vector2.ONE)
	draw_string(font, Vector2(-slw / 2.0, side_fs / 2.0), side_lbl,
		HORIZONTAL_ALIGNMENT_LEFT, -1, side_fs, team_color.lightened(0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_set_transform(Vector2(x + w / 2.0, post_y2 + (h - post_y2) / 2.0), -PI / 2.0, Vector2.ONE)
	draw_string(font, Vector2(-slw / 2.0, side_fs / 2.0), side_lbl,
		HORIZONTAL_ALIGNMENT_LEFT, -1, side_fs, team_color.lightened(0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_soccer_ball(center: Vector2, radius: float) -> void:
	var n := 5
	# White base
	draw_circle(center, radius, Color.WHITE)
	# Central pentagon patch
	var pts := PackedVector2Array()
	for i in n:
		var a := float(i) * TAU / float(n) - TAU / 4.0
		pts.append(center + Vector2(cos(a), sin(a)) * radius * 0.35)
	draw_polygon(pts, PackedColorArray([Color.BLACK]))
	# 5 outer pentagon patches
	for j in n:
		var base_angle := float(j) * TAU / float(n) - TAU / 4.0
		var pc := center + Vector2(cos(base_angle), sin(base_angle)) * radius * 0.65
		var pp := PackedVector2Array()
		for i in n:
			var a := float(i) * TAU / float(n) + base_angle + PI
			pp.append(pc + Vector2(cos(a), sin(a)) * radius * 0.27)
		draw_polygon(pp, PackedColorArray([Color.BLACK]))
	# Outline
	draw_arc(center, radius, 0, TAU, 32, Color.BLACK, 1.5)


func _cell_center(row: int, col: int) -> Vector2:
	# row → X axis, col → Y axis
	return Vector2(GRID_X + row * CELL_SIZE + CELL_SIZE / 2.0, col * CELL_SIZE + CELL_SIZE / 2.0)


func _cell_to_pixel(row: int, col: int) -> Vector2:
	return Vector2(GRID_X + row * CELL_SIZE, col * CELL_SIZE)
