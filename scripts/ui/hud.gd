## HUD
## Muestra marcador, turno activo, resultado de la ultima accion
## y la card del jugador seleccionado (sin popup, integrada en el panel).

extends PanelContainer
class_name HUD

## Emitida cuando el usuario pulsa "Actuar" en la card de un jugador accionable.
signal card_actuar_pressed(player_id: String)

@onready var _turn:   Label = $VBox/TurnLabel
@onready var _result: Label = $VBox/ResultLabel

const C_HOME := Color(0.18, 0.45, 0.90)
const C_AWAY := Color(0.90, 0.25, 0.25)

var _home_label := "HOME"
var _away_label := "AWAY"

var _home_lbl_node: Label  = null
var _score_mid:     Label  = null
var _away_lbl_node: Label  = null

var _card_node             = null   # PlayerCard instance
var _actuar_btn: Button    = null
var _pending_player_id: String = ""
var _history: Array = []
var _history_label: Label = null


func _ready() -> void:
	var vbox := $VBox
	var old_score: Label = $VBox/ScoreLabel

	# --- Score HBox ---
	var hbox := HBoxContainer.new()
	hbox.name = "ScoreHBox"
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_home_lbl_node = Label.new()
	_home_lbl_node.add_theme_color_override("font_color", C_HOME)
	_home_lbl_node.add_theme_font_size_override("font_size", 22)
	_home_lbl_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_home_lbl_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_score_mid = Label.new()
	_score_mid.text = "  0  -  0  "
	_score_mid.add_theme_font_size_override("font_size", 22)

	_away_lbl_node = Label.new()
	_away_lbl_node.add_theme_color_override("font_color", C_AWAY)
	_away_lbl_node.add_theme_font_size_override("font_size", 22)
	_away_lbl_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	hbox.add_child(_home_lbl_node)
	hbox.add_child(_score_mid)
	hbox.add_child(_away_lbl_node)

	var idx: int = old_score.get_index()
	vbox.remove_child(old_score)
	old_score.queue_free()
	vbox.add_child(hbox)
	vbox.move_child(hbox, idx)

	_home_lbl_node.text = _home_label
	_away_lbl_node.text = _away_label

	# --- Player card section (below result label) ---
	var sep := HSeparator.new()
	vbox.add_child(sep)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(center)

	var PlayerCardScene = load("res://scenes/ui/PlayerCard.tscn")
	_card_node = PlayerCardScene.instantiate()
	_card_node.display_scale = 0.72
	_card_node.visible = false
	center.add_child(_card_node)

	_actuar_btn = Button.new()
	_actuar_btn.text = "▶  Actuar"
	_actuar_btn.visible = false
	_actuar_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actuar_btn.add_theme_font_size_override("font_size", 16)
	_actuar_btn.pressed.connect(_on_actuar_pressed)
	vbox.add_child(_actuar_btn)

	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	var hist_title := Label.new()
	hist_title.text = "Historial"
	hist_title.add_theme_font_size_override("font_size", 11)
	hist_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(hist_title)

	_history_label = Label.new()
	_history_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_history_label.add_theme_font_size_override("font_size", 10)
	_history_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	_history_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_history_label)


func setup(home_lbl: String, away_lbl: String) -> void:
	_home_label = home_lbl
	_away_label = away_lbl
	if _home_lbl_node != null:
		_home_lbl_node.text = home_lbl
	if _away_lbl_node != null:
		_away_lbl_node.text = away_lbl


## Muestra la card del jugador en el panel lateral.
## player_id: ID del jugador (vacío para GK u observación). can_act: muestra botón Actuar.
func show_card(card_data: Dictionary, profile_data: Dictionary,
		player_id: String, can_act: bool) -> void:
	_pending_player_id  = player_id
	_card_node.populate(card_data, profile_data)
	_card_node.visible  = true
	_actuar_btn.visible = can_act


func hide_card() -> void:
	_card_node.visible  = false
	_actuar_btn.visible = false
	_pending_player_id  = ""


func _on_actuar_pressed() -> void:
	var pid := _pending_player_id
	hide_card()
	card_actuar_pressed.emit(pid)


func update_from_state(state: Dictionary) -> void:
	var home_score: int = state.get("home", {}).get("score", state.get("home_score", 0))
	var away_score: int = state.get("away", {}).get("score", state.get("away_score", 0))
	_score_mid.text = "  %d  -  %d  " % [home_score, away_score]

	if state.get("finished", false):
		var winner = str(state.get("winner", "empate")).to_upper()
		_turn.text = "FIN - GANADOR: %s" % winner
	else:
		var raw_turn: String = state.get("turn", "home")
		var lbl: String = _home_label if raw_turn == "home" else _away_label
		_turn.text = "Turno: %s" % lbl


func show_result(result: Dictionary, prefix: String = "") -> void:
	if result == null or result.is_empty():
		return
	var line := "%s%s" % [prefix, result.get("description", "")]
	_result.text = line
	_add_to_history(line)


func append_cpu_result(result: Dictionary) -> void:
	if result == null or result.is_empty():
		return
	var line: String = "CPU: %s" % result.get("description", "")
	if _result.text == "":
		_result.text = line
	else:
		_result.text = _result.text + "\n" + line
	_add_to_history(line)


func clear_result() -> void:
	_result.text = ""


func _add_to_history(line: String) -> void:
	_history.push_front(line)
	if _history.size() > 4:
		_history.resize(4)
	if _history_label != null:
		_history_label.text = "\n".join(_history)
