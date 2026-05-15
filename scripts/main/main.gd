## Main - Escena raiz: crea la partida y gestiona el turno.

extends Node2D

@onready var _board       = $Board
@onready var _hud         = $HUDLayer/HUD
@onready var _action_menu = $ActionMenuLayer/ActionMenu

var _api        = null
var _game_id:    String     = ""
var _last_state: Dictionary = {}
var _card_id_map: Dictionary = {}
var _gk_card_map: Dictionary = {"home": "card-courtois", "away": "card-terstegen"}

const _GameAPI   = preload("res://scripts/api/game_api.gd")

const HOME_SQUAD = [
	# --- 3-4-3 formation, HOME attacks toward row 5 ---
	# Forwards (row 2 - center)  -  Ronaldo FIRST -> backend gives him has_ball
	{"player_id": "h1",  "card_id": "card-ronaldo",    "row": 2, "col": 2},
	{"player_id": "h2",  "card_id": "card-vinicius",   "row": 2, "col": 1},
	{"player_id": "h3",  "card_id": "card-bellingham", "row": 2, "col": 3},
	# Midfielders (row 1 - PA/DL)
	{"player_id": "h4",  "card_id": "card-modric",     "row": 1, "col": 0},
	{"player_id": "h5",  "card_id": "card-debruyne",   "row": 1, "col": 1},
	{"player_id": "h8",  "card_id": "card-carvajal",   "row": 1, "col": 3},
	{"player_id": "h9",  "card_id": "card-alaba",      "row": 1, "col": 4},
	# Defenders (row 0 - RM, closest to HOME goal)
	{"player_id": "h6",  "card_id": "card-vandijk",    "row": 0, "col": 1},
	{"player_id": "h10", "card_id": "card-militao",    "row": 0, "col": 2},
	{"player_id": "h7",  "card_id": "card-rudiger",    "row": 0, "col": 3},
]

const AWAY_SQUAD = [
	# --- 3-4-3 formation, AWAY attacks toward row 0 ---
	# Forwards (row 3 - center)
	{"player_id": "a3",  "card_id": "card-mbappe",      "row": 3, "col": 1},
	{"player_id": "a1",  "card_id": "card-messi",       "row": 3, "col": 2},
	{"player_id": "a2",  "card_id": "card-lewandowski", "row": 3, "col": 3},
	# Midfielders (row 4 - PA/DL)
	{"player_id": "a4",  "card_id": "card-yamal",       "row": 4, "col": 0},
	{"player_id": "a5",  "card_id": "card-pedri",       "row": 4, "col": 1},
	{"player_id": "a6",  "card_id": "card-kroos",       "row": 4, "col": 3},
	{"player_id": "a7",  "card_id": "card-gavi",        "row": 4, "col": 4},
	# Defenders (row 5 - RM, closest to AWAY goal)
	{"player_id": "a8",  "card_id": "card-theo",        "row": 5, "col": 1},
	{"player_id": "a10", "card_id": "card-busquets",    "row": 5, "col": 2},
	{"player_id": "a9",  "card_id": "card-kounde",      "row": 5, "col": 3},
]


func _ready() -> void:
	_api = _GameAPI.new()
	add_child(_api)
	for p in HOME_SQUAD:
		_card_id_map[p["player_id"]] = p["card_id"]
	for p in AWAY_SQUAD:
		_card_id_map[p["player_id"]] = p["card_id"]
	_board.player_clicked.connect(_on_player_clicked)
	_board.goalkeeper_clicked.connect(_on_goalkeeper_clicked)
	_action_menu.action_chosen.connect(_on_action_chosen)
	_action_menu.cancelled.connect(func(): _board.set_selected(""))
	_hud.card_actuar_pressed.connect(_on_actuar_pressed)
	_hud.setup("HOME (Tu)", "AWAY (CPU)")
	await _start_match()


func _start_match() -> void:
	_hud.clear_result()
	var payload = {
		"mode": "advanced",
		"opponent_type": "cpu",
		"cpu_difficulty": "medium",
		"max_turns": 60,
		"goals_to_win": 2,
		"home": {"players": HOME_SQUAD, "goalkeeper_id": "card-courtois"},
		"away": {"players": AWAY_SQUAD, "goalkeeper_id": "card-terstegen"},
	}
	var summary = await _api.create_game(payload)
	if not _check(summary, "game_id"):
		push_error("Error al crear la partida")
		return
	_game_id = summary["game_id"]
	print("[SuperGol] Partida creada: " + _game_id)
	await _refresh_board()


func _refresh_board() -> void:
	var state = await _api.get_board_state(_game_id)
	if not _check(state, "home"):
		push_error("Error al obtener estado")
		return
	_last_state = state
	_board.update_from_state(state)
	_hud.update_from_state(state)


func _on_player_clicked(player_id: String) -> void:
	await _show_player_card(player_id)


func _on_goalkeeper_clicked(team: String) -> void:
	var card_id: String = _gk_card_map.get(team, "")
	if card_id == "":
		return
	var card_data    = await _api.get_card(card_id)
	var profile_data = await _api.get_card_profile(card_id)
	var c: Dictionary = card_data    if card_data    is Dictionary else {}
	var p: Dictionary = profile_data if profile_data is Dictionary else {}
	_hud.show_card(c, p, "", false)


func _on_actuar_pressed(player_id: String) -> void:
	_board.set_selected(player_id)
	_action_menu.show_for_player(player_id, _last_state)


func _show_player_card(player_id: String) -> void:
	var card_id: String = _card_id_map.get(player_id, "")
	if card_id == "":
		return
	var card_data    = await _api.get_card(card_id)
	var profile_data = await _api.get_card_profile(card_id)
	var c: Dictionary = card_data    if card_data    is Dictionary else {}
	var p: Dictionary = profile_data if profile_data is Dictionary else {}
	var is_home_turn:   bool = _last_state.get("turn", "") == "home"
	var is_home_player: bool = false
	for pl in _last_state.get("home", {}).get("players", []):
		if pl["id"] == player_id:
			is_home_player = true
			break
	var can_act: bool = is_home_turn and is_home_player
	_hud.show_card(c, p, player_id if can_act else "", can_act)


func _on_action_chosen(action: Dictionary) -> void:
	_board.set_selected("")
	_hud.clear_result()
	var response = await _api.execute_action(_game_id, action)
	if not _check(response, "game"):
		push_error("Error al ejecutar accion")
		return
	_hud.show_result(response.get("human_result", {}), "Tu: ")
	var cpu_results = response.get("cpu_results", [])
	if cpu_results is Array and cpu_results.size() > 0:
		await get_tree().create_timer(1.0).timeout
		for cpu_result in cpu_results:
			_hud.append_cpu_result(cpu_result)
	var game_summary = response.get("game", {})
	if game_summary.get("finished", false):
		_hud.update_from_state(game_summary)
		return
	await get_tree().create_timer(1.2).timeout
	await _refresh_board()


static func _check(data, key) -> bool:
	return data != null and data is Dictionary and data.has(key)
