## DiceOverlay
## Displays an animated dice roll over the board when an action resolves.
## Call play(result_dict) to trigger; emits animation_finished when done.

extends Control
class_name DiceOverlay

signal animation_finished

# ---------------------------------------------------------------------------
# Palette
# ---------------------------------------------------------------------------
const C_OVERLAY  = Color(0.02, 0.02, 0.10, 0.82)
const C_DIE_BG   = Color(0.96, 0.94, 0.88)
const C_DIE_PIP  = Color(0.06, 0.06, 0.12)
const C_DIE_PIP2 = Color(0.85, 0.10, 0.10)   # pip color for die-2 (red)
const C_GOLD     = Color(1.00, 0.82, 0.10)
const C_SUCCESS  = Color(0.22, 0.88, 0.38)
const C_FAIL     = Color(0.92, 0.20, 0.20)
const C_WHITE    = Color.WHITE
const C_SUBTLE   = Color(0.68, 0.68, 0.78)

# Pip layouts: normalized offsets (-0.35..+0.35) relative to die center
const PIP_LAYOUTS: Array = [
	[],
	[Vector2( 0.00,  0.00)],
	[Vector2(-0.27, -0.27), Vector2( 0.27,  0.27)],
	[Vector2(-0.27, -0.27), Vector2( 0.00,  0.00), Vector2( 0.27,  0.27)],
	[Vector2(-0.27, -0.27), Vector2( 0.27, -0.27), Vector2(-0.27,  0.27), Vector2( 0.27,  0.27)],
	[Vector2(-0.27, -0.27), Vector2( 0.27, -0.27), Vector2( 0.00,  0.00),
	 Vector2(-0.27,  0.27), Vector2( 0.27,  0.27)],
	[Vector2(-0.27, -0.27), Vector2( 0.27, -0.27), Vector2(-0.27,  0.00),
	 Vector2( 0.27,  0.00), Vector2(-0.27,  0.27), Vector2( 0.27,  0.27)],
]

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
const DIE_SIZE     = 100.0
const PIP_RADIUS   = 8.0
const GAP          = 24.0

const DUR_ROLL     = 1.0
const DUR_SETTLE   = 0.38
const DUR_SHOW     = 1.6
const DUR_FADE     = 0.28
const ROLL_TICK    = 0.065   # seconds between value changes while rolling

# Settle ticks: time between each "click" while slowing down
const SETTLE_TICKS: Array = [0.08, 0.13, 0.20, 0.30]

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
enum Phase { IDLE, ROLLING, SETTLING, SHOWING, FADING }

var _phase:          int     = Phase.IDLE
var _time:           float   = 0.0
var _alpha:          float   = 1.0
var _result:         Dictionary = {}
var _num_dice:       int     = 2
var _final:          Array   = [1, 1]   # actual rolled values
var _shown:          Array   = [1, 1]   # currently displayed values
var _settled:        Array   = [false, false]

var _roll_timer:     float   = 0.0
var _settle_idx:     int     = 0
var _settle_timer:   float   = 0.0

# Bounce effect on landing
var _bounce:         Array   = [0.0, 0.0]   # scale offset (0..1 → ease out)
var _bounce_time:    Array   = [0.0, 0.0]
const BOUNCE_DUR             = 0.22


func _ready() -> void:
	visible       = false
	mouse_filter  = Control.MOUSE_FILTER_IGNORE
	set_process(false)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func play(result: Dictionary) -> void:
	_result   = result
	var dice: Array = result.get("dice_roll", [])
	_num_dice = max(1, dice.size())
	_final    = [
		dice[0] if dice.size() > 0 else 1,
		dice[1] if dice.size() > 1 else 1,
	]
	_shown    = [randi() % 6 + 1, randi() % 6 + 1]
	_settled  = [false, false]
	_bounce   = [0.0, 0.0]
	_bounce_time = [0.0, 0.0]

	_phase        = Phase.ROLLING
	_time         = 0.0
	_alpha        = 1.0
	_roll_timer   = 0.0
	_settle_idx   = 0
	_settle_timer = 0.0

	visible = true
	set_process(true)
	queue_redraw()


# ---------------------------------------------------------------------------
# _process
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _phase == Phase.IDLE:
		return

	_time        += delta
	_roll_timer  += delta
	_settle_timer += delta

	# Update bounce damping
	for i in 2:
		if _bounce[i] > 0.0:
			_bounce_time[i] += delta
			var t: float = _bounce_time[i] / BOUNCE_DUR
			_bounce[i] = max(0.0, 1.0 - t * t * t)
			queue_redraw()

	match _phase:
		Phase.ROLLING:
			if _roll_timer >= ROLL_TICK:
				_roll_timer = 0.0
				_shown[0] = randi() % 6 + 1
				if _num_dice > 1:
					_shown[1] = randi() % 6 + 1
				queue_redraw()
			if _time >= DUR_ROLL:
				_phase        = Phase.SETTLING
				_time         = 0.0
				_settle_idx   = 0
				_settle_timer = 0.0

		Phase.SETTLING:
			var tick: float = 9999.0
			if _settle_idx < SETTLE_TICKS.size():
				tick = SETTLE_TICKS[_settle_idx]
			if _settle_timer >= tick:
				_settle_timer = 0.0
				_settle_idx  += 1

				# Land dice progressively
				if _settle_idx == 2 and not _settled[0]:
					_shown[0]   = _final[0]
					_settled[0] = true
					_bounce[0]  = 1.0
					_bounce_time[0] = 0.0
				if _settle_idx >= 3 and not _settled[1]:
					_shown[1]   = _final[1]
					_settled[1] = true
					_bounce[1]  = 1.0
					_bounce_time[1] = 0.0
				if _settle_idx < SETTLE_TICKS.size():
					_shown[0] = _final[0] if _settled[0] else randi() % 6 + 1
					_shown[1] = _final[1] if _settled[1] else randi() % 6 + 1
				queue_redraw()

			if _settle_idx >= SETTLE_TICKS.size():
				_shown    = _final.duplicate()
				_settled  = [true, true]
				_phase    = Phase.SHOWING
				_time     = 0.0
				queue_redraw()

		Phase.SHOWING:
			if _time >= DUR_SHOW:
				_phase = Phase.FADING
				_time  = 0.0

		Phase.FADING:
			_alpha = 1.0 - clampf(_time / DUR_FADE, 0.0, 1.0)
			queue_redraw()
			if _time >= DUR_FADE:
				_phase   = Phase.IDLE
				visible  = false
				set_process(false)
				animation_finished.emit()


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	if _phase == Phase.IDLE:
		return

	var font := ThemeDB.fallback_font
	var W: float = size.x
	var H: float = size.y
	var cx: float = W * 0.38   # center of board area (left 60% of screen)
	var cy: float = H / 2.0
	var a: float  = _alpha

	# Full-screen dim
	draw_rect(Rect2(0, 0, W, H), Color(C_OVERLAY.r, C_OVERLAY.g, C_OVERLAY.b, C_OVERLAY.a * a))

	# Panel background behind dice
	var total_w: float = DIE_SIZE * _num_dice + GAP * (_num_dice - 1)
	var panel_pad      = 32.0
	var panel_w        = total_w + panel_pad * 2
	var panel_h        = 260.0
	var px             = cx - panel_w / 2.0
	var py             = cy - panel_h / 2.0

	# Panel dark card
	draw_rect(Rect2(px, py, panel_w, panel_h), Color(0.04, 0.04, 0.14, 0.92 * a))
	draw_rect(Rect2(px, py, panel_w, panel_h), Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.55 * a), false, 2.0)

	# Dice
	var dice_y = py + panel_pad
	for i in _num_dice:
		var dx: float = cx - total_w / 2.0 + i * (DIE_SIZE + GAP)
		var bounce_scale: float = 1.0 + _bounce[i] * 0.12
		_draw_die(Vector2(dx, dice_y), _shown[i], i, bounce_scale, a)

	# Result area
	if _phase == Phase.SHOWING or _phase == Phase.FADING:
		_draw_result(font, cx, py + DIE_SIZE + panel_pad * 2 + 8, a)
	elif _phase == Phase.SETTLING and _settle_idx >= SETTLE_TICKS.size() - 1:
		_draw_result(font, cx, py + DIE_SIZE + panel_pad * 2 + 8, a)


func _draw_die(pos: Vector2, value: int, die_idx: int, scale_f: float, alpha: float) -> void:
	var s := DIE_SIZE * scale_f
	var offset := Vector2((DIE_SIZE - s) / 2.0, (DIE_SIZE - s) / 2.0)
	var dp := pos + offset
	var pip_col: Color = C_DIE_PIP if die_idx == 0 else C_DIE_PIP2

	# Shadow
	draw_rect(Rect2(dp + Vector2(5, 5), Vector2(s, s)),
			Color(0, 0, 0, 0.38 * alpha))
	# Face
	draw_rect(Rect2(dp, Vector2(s, s)),
			Color(C_DIE_BG.r, C_DIE_BG.g, C_DIE_BG.b, alpha))
	# Gold border
	var b_col: Color = C_GOLD if _settled[die_idx] else Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.45)
	draw_rect(Rect2(dp, Vector2(s, s)), Color(b_col.r, b_col.g, b_col.b, b_col.a * alpha), false, 2.5)

	# Pips
	var v: int = clampi(value, 1, 6)
	var layout: Array = PIP_LAYOUTS[v]
	var center: Vector2 = dp + Vector2(s, s) / 2.0
	var pr: float = PIP_RADIUS * scale_f
	for pip in layout:
		var pip_v: Vector2 = pip
		var pp: Vector2 = center + Vector2(pip_v.x * s, pip_v.y * s)
		draw_circle(pp, pr, Color(pip_col.r, pip_col.g, pip_col.b, alpha))


func _draw_result(font: Font, cx: float, y: float, alpha: float) -> void:
	var success: bool = _result.get("success", false)
	var total: int    = _result.get("total", 0)
	var thresh: int   = _result.get("threshold", 0)
	var attr: int     = _result.get("attribute_value", 0)

	# Formula  e.g.  "5 + 3  +  (8)  =  16  vs  12"
	var d1: int = _final[0]
	var d2: int = _final[1]
	var formula := "%d" % d1
	if _num_dice > 1:
		formula += "  +  %d" % d2
	if attr > 0:
		formula += "  +  (%d)" % attr
	formula += "  =  %d" % total
	if thresh > 0:
		formula += "   vs   %d" % thresh

	var f_w: float = font.get_string_size(formula, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	draw_string(font, Vector2(cx - f_w / 2.0, y + 20),
			formula, HORIZONTAL_ALIGNMENT_LEFT, -1, 17,
			Color(C_WHITE.r, C_WHITE.g, C_WHITE.b, alpha))

	# Success / Fail badge
	var s_col: Color = C_SUCCESS if success else C_FAIL
	var badge := "✓  ÉXITO" if success else "✗  FALLO"
	var b_w: float = font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	var bx := cx - b_w / 2.0 - 16
	var by := y + 30
	draw_rect(Rect2(bx, by, b_w + 32, 42), Color(s_col.r, s_col.g, s_col.b, 0.18 * alpha))
	draw_rect(Rect2(bx, by, b_w + 32, 42), Color(s_col.r, s_col.g, s_col.b, alpha), false, 2.0)
	draw_string(font, Vector2(cx - b_w / 2.0, by + 30),
			badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 28,
			Color(s_col.r, s_col.g, s_col.b, alpha))
