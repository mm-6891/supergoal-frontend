## GameAPI
## HTTP wrapper for all Super Gol API endpoints.

extends Node
const BASE_URL = "http://localhost:8000"


func create_game(payload: Dictionary) -> Dictionary:
	return await _http_post_json("/games/", payload)


func get_board_state(game_id: String) -> Dictionary:
	return await _http_get_json("/games/%s/state" % game_id)


func execute_action(game_id: String, action: Dictionary) -> Dictionary:
	return await _http_post_json("/games/%s/actions" % game_id, action)


func get_card(card_id: String) -> Variant:
	return await _http_get_json("/cards/%s" % card_id)


func get_card_profile(card_id: String) -> Variant:
	return await _http_get_json("/cards/%s/profile" % card_id)


func _http_get_json(path: String, _unused: Variant = null) -> Variant:
	var http := HTTPRequest.new()
	add_child(http)
	var _err = http.request(BASE_URL + path)
	var response = await http.request_completed
	http.queue_free()
	return _parse_response(response)


func _http_post_json(path: String, body: Dictionary) -> Variant:
	var http := HTTPRequest.new()
	add_child(http)
	var headers = PackedStringArray(["Content-Type: application/json"])
	var _err = http.request(BASE_URL + path, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	var response = await http.request_completed
	http.queue_free()
	return _parse_response(response)


func _parse_response(response: Array) -> Variant:
	var body: String = response[3].get_string_from_utf8()
	var parsed = JSON.parse_string(body)
	if parsed == null:
		return {}
	return parsed
