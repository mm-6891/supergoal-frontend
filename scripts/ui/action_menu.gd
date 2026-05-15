## ActionMenu
## Menu contextual que aparece al seleccionar un jugador de HOME.
## Calcula las acciones disponibles segun la posicion del jugador
## y el estado del tablero, y emite action_chosen(action) al confirmar.
## Adjunto a ActionMenuLayer/ActionMenu (PanelContainer) en Main.tscn.

extends PanelContainer
class_name ActionMenu

@onready var _title:   Label          = $VBox/TitleLabel
@onready var _buttons: VBoxContainer  = $VBox/ButtonsScroll/ButtonsContainer
@onready var _cancel:  Button         = $VBox/CancelButton

signal action_chosen(action: Dictionary)
signal cancelled

var _state: Dictionary = {}


func _ready() -> void:
	_cancel.pressed.connect(_on_cancel)


func show_for_player(player_id: String, state: Dictionary) -> void:
	_state = state

	# Limpiar botones anteriores
	for child in _buttons.get_children():
		child.queue_free()

	var player = _find_player(player_id)
	if player.is_empty():
		return

	_title.text = player.get("name", player_id)

	for action_data in _get_actions(player):
		var btn := Button.new()
		btn.text = action_data["label"]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var a: Dictionary = action_data["action"]
		btn.pressed.connect(func(): _emit_action(a))
		_buttons.add_child(btn)

	visible = true


# ---------------------------------------------------------------------------
# Construccion de acciones disponibles
# ---------------------------------------------------------------------------

func _get_actions(player: Dictionary) -> Array:
	var actions: Array = []
	var pid:          String = player["id"]
	var row:          int    = player["row"]
	var col:          int    = player["col"]
	var has_ball:     bool   = player.get("has_ball", false)
	var marking_type: String = player.get("marking_type", "free")
	var _raw_marker = player.get("marking")
	var marker_id:    String = _raw_marker if _raw_marker != null else ""
	var turn:         String = _state.get("turn", "home")

	if has_ball:
		# --- Remate cercano (zona RM) ---
		var in_rm_col: bool = col >= 1 and col <= 3
		var in_close: bool = in_rm_col and ((turn == "home" and row == 5) or (turn == "away" and row == 0))
		if in_close:
			actions.append(_action("[RM] Remate cercano",
				{"action_type": "shoot_close", "player_id": pid}))

		# --- Disparo lejano (zona DL) ---
		var in_far: bool = in_rm_col and ((turn == "home" and row == 4) or (turn == "away" and row == 1))
		if in_far:
			actions.append(_action("[DL] Disparo lejano",
				{"action_type": "shoot_far", "player_id": pid}))

		# --- Regate: disponible si hay marcaje (al hombre o en zona) ---
		if marking_type != "free" and marker_id != "":
			var marker = _find_player_by_id(marker_id)
			var marker_name: String = marker.get("name", marker_id).split(" ")[-1] if not marker.is_empty() else marker_id
			var dribble_label: String
			if marking_type == "man_to_man":
				dribble_label = "[RG] Regatear vs %s (2 dados)" % marker_name
			else:
				dribble_label = "[RG] Regatear en zona (1 dado)"
			actions.append(_action(dribble_label, {
				"action_type": "dribble",
				"player_id": pid,
				"target_player_id": marker_id,
			}))

		# --- Pases a companeros ---
		var passer_marked: bool = marking_type == "man_to_man"
		var in_pa_zone: bool = (col == 0 or col == 4) or \
			((row == 1 or row == 4) and (col == 1 or col == 3))
		var side_key: String = "home" if turn == "home" else "away"
		for tm in _state.get(side_key, {}).get("players", []):
			if tm["id"] == pid:
				continue
			var dist: int = max(abs(tm["row"] - row), abs(tm["col"] - col))
			var ptype: String
			var plabel: String
			if dist == 1:
				var receiver_marked: bool = tm.get("marking_type", "free") == "man_to_man"
				if passer_marked or receiver_marked:
					ptype  = "pass_short"
					plabel = "-> Corto"
				else:
					ptype  = "pass_direct"
					plabel = "-> Directo"
			elif dist <= 3:
				ptype  = "pass_long"
				plabel = "-> Largo"
			else:
				continue
			var tm_name: String = tm.get("name", tm["id"]).split(" ")[-1]
			actions.append(_action("%s %s" % [plabel, tm_name], {
				"action_type": ptype,
				"player_id": pid,
				"target_player_id": tm["id"],
			}))

		# --- Pase alto (PA) desde zonas de esquina/banda ---
		if in_pa_zone:
			for tm in _state.get(side_key, {}).get("players", []):
				if tm["id"] == pid:
					continue
				var dist: int = max(abs(tm["row"] - row), abs(tm["col"] - col))
				if dist < 2:
					continue  # pase alto solo a distancia >= 2
				var tm_name: String = tm.get("name", tm["id"]).split(" ")[-1]
				actions.append(_action("[PA] Alto %s" % tm_name, {
					"action_type": "pass_high",
					"player_id": pid,
					"target_player_id": tm["id"],
				}))

		# --- Mover con balon (cualquier celda adyacente) ---
		for nb in _get_neighbors(row, col):
			var arr: String = _dir_label(nb[0] - row, nb[1] - col)
			actions.append(_action("[>>] %s" % arr, {
				"action_type": "move_with_ball",
				"player_id": pid,
				"target_position": [nb[0], nb[1]],
			}))
	else:
		var side_key: String = "home" if turn == "home" else "away"
		var opp_key:  String = "away" if turn == "home" else "home"

		# --- Robo de balon ---
		# Disponible si el jugador pertenece al equipo con turno y hay un portador
		# rival en la misma casilla o adyacente, sin que otro companero tenga prioridad
		# por estar en la misma casilla que el portador.
		var is_current_team: bool = false
		for p in _state.get(side_key, {}).get("players", []):
			if p["id"] == pid:
				is_current_team = true
				break

		if is_current_team:
			var carrier: Dictionary = {}
			for p in _state.get(opp_key, {}).get("players", []):
				if p.get("has_ball", false):
					carrier = p
					break

			if not carrier.is_empty():
				var c_row: int = carrier["row"]
				var c_col: int = carrier["col"]
				var in_same_cell: bool = (row == c_row and col == c_col)
				var dist: int = max(abs(c_row - row), abs(c_col - col))

				if in_same_cell or dist == 1:
					# Prioridad: si hay otro companero en la misma casilla que el portador,
					# solo ese jugador puede robar (bloquea a los adyacentes)
					var blocked: bool = false
					if not in_same_cell:
						for p in _state.get(side_key, {}).get("players", []):
							if p["id"] != pid and p["row"] == c_row and p["col"] == c_col:
								blocked = true
								break

					if not blocked:
						var carrier_name: String = carrier.get("name", carrier["id"]).split(" ")[-1]
						actions.append(_action("[RB] Robar a %s" % carrier_name, {
							"action_type": "steal",
							"player_id": pid,
							"target_player_id": carrier["id"],
						}))

		# --- Mover sin balon (cualquier celda adyacente) ---
		for nb in _get_neighbors(row, col):
			var arr: String = _dir_label(nb[0] - row, nb[1] - col)
			actions.append(_action("[>] %s" % arr, {
				"action_type": "move",
				"player_id": pid,
				"target_position": [nb[0], nb[1]],
			}))

	return actions


static func _action(label: String, action: Dictionary) -> Dictionary:
	return {"label": label, "action": action}


static func _get_neighbors(row: int, col: int) -> Array:
	var result: Array = []
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			if dr == 0 and dc == 0:
				continue
			var nr: int = row + dr
			var nc: int = col + dc
			if nr >= 0 and nr <= 5 and nc >= 0 and nc <= 4:
				result.append([nr, nc])
	return result


static func _dir_label(dr: int, dc: int) -> String:
	if dr == -1 and dc == -1: return "↖"
	if dr == -1 and dc ==  0: return "←"
	if dr == -1 and dc ==  1: return "↙"
	if dr ==  0 and dc == -1: return "↑"
	if dr ==  0 and dc ==  1: return "↓"
	if dr ==  1 and dc == -1: return "↗"
	if dr ==  1 and dc ==  0: return "→"
	if dr ==  1 and dc ==  1: return "↘"
	return "?"


func _find_player(player_id: String) -> Dictionary:
	return _find_player_by_id(player_id)


func _find_player_by_id(player_id: String) -> Dictionary:
	for side in ["home", "away"]:
		for p in _state.get(side, {}).get("players", []):
			if p["id"] == player_id:
				return p
	return {}


# ---------------------------------------------------------------------------
# Senales
# ---------------------------------------------------------------------------

func _emit_action(action: Dictionary) -> void:
	visible = false
	action_chosen.emit(action)


func _on_cancel() -> void:
	visible = false
	cancelled.emit()
