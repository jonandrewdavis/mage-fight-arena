class_name TubeBackend
extends MultiplayerBackend

const CONTEXT: TubeContext = preload("uid://334o3kg81fih")
const TRACKER_TIMEOUT := 5.0
const LOST_REASON := "Disconnected from host."
const TURN_URL := "https://api.androodev.com/turn_complete"
const TURN_TIMEOUT := 5.0
const TURN_CACHE_SEC := 300.0
const TURN_FALLBACK_STATUS := "TURN unavailable; using STUN only."
enum Phase {IDLE, HOSTING, JOINING, IN_SESSION}

signal _ice_fetch_done

var client: TubeClient
var phase := Phase.IDLE
var joinable := false
var max_players := 0
var lobby_name := ""
var leaving := false
var listing := false
var listing_ready := false
var _http: HTTPRequest
var _ice_fetched_msec := -1
var _ice_fetching := false

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = TURN_TIMEOUT
	add_child(_http)
	client = TubeClient.new()
	# Duplicated so runtime TURN injection never mutates the preloaded resource.
	client.context = CONTEXT.duplicate()
	client.tracker_connect_timeout = TRACKER_TIMEOUT
	client.multiplayer_api = get_tree().get_multiplayer()
	client.session_created.connect(_on_session_created)
	client.session_joined.connect(_on_session_joined)
	client.session_left.connect(_on_session_left)
	client.error_raised.connect(_on_error)
	client.public_sessions_changed.connect(_emit_sessions)
	client.listing_stopped.connect(_on_listing_stopped)
	client.listing_started.connect(_on_listing_started)
	add_child(client)
	multiplayer.peer_connected.connect(_on_peer_changed)
	multiplayer.peer_disconnected.connect(_on_peer_changed)
	status_changed.emit("Tube ready" if TubeClient.is_webrtc_available() else "WebRTC extension missing; install addons/webrtc_native.")

func host_game(options: HostOptions) -> void:
	lobby_name = options.lobby_name
	max_players = options.max_players
	_stop_listing()
	phase = Phase.HOSTING
	await _ensure_ice_servers()
	if phase != Phase.HOSTING:
		return
	client.create_session()
	if phase != Phase.HOSTING:
		return
	client.refuse_new_connections = true
	status_changed.emit("Creating session...")

func join_game(address: Variant) -> void:
	_stop_listing()
	phase = Phase.JOINING
	await _ensure_ice_servers()
	if phase != Phase.JOINING:
		return
	client.join_session(str(address).strip_edges())
	if phase == Phase.JOINING:
		status_changed.emit("Connecting to session...")

## Fetches TURN credentials into client.context before a host/join. Falls back to STUN-only on
## any failure so play is never blocked by the credential API.
func _ensure_ice_servers() -> void:
	if _ice_fetched_msec >= 0 and Time.get_ticks_msec() - _ice_fetched_msec < TURN_CACHE_SEC * 1000.0:
		return
	if _ice_fetching:
		await _ice_fetch_done
		return
	_ice_fetching = true
	status_changed.emit("Fetching TURN credentials...")
	var servers: Array[Dictionary] = []
	if _http.request(TURN_URL) == OK:
		var result: Array = await _http.request_completed
		if result[0] == HTTPRequest.RESULT_SUCCESS and result[1] == 200:
			servers = parse_ice_servers(result[3])
	if servers.is_empty():
		push_warning("TURN fetch failed: " + TURN_URL)
		status_changed.emit(TURN_FALLBACK_STATUS)
	else:
		client.context.turn_servers = servers
		_ice_fetched_msec = Time.get_ticks_msec()
	_ice_fetching = false
	_ice_fetch_done.emit()

## Parses a {"iceServers": [{"urls": ..., "username": ..., "credential": ...}]} body into the
## entry shape TubeContext.turn_servers expects. Malformed input yields an empty array.
static func parse_ice_servers(body: PackedByteArray) -> Array[Dictionary]:
	var servers: Array[Dictionary] = []
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return servers
	var parsed: Variant = json.data
	if not parsed is Dictionary or not parsed.get("iceServers") is Array:
		return servers
	for entry: Variant in parsed.iceServers:
		if not entry is Dictionary:
			continue
		var urls: Variant = entry.get("urls")
		if urls is Array:
			if urls.is_empty() or urls.any(func(u: Variant) -> bool: return not u is String):
				continue
		elif not urls is String:
			continue
		var server := {"urls": urls}
		for key in ["username", "credential"]:
			if entry.get(key) is String:
				server[key] = entry[key]
		servers.append(server)
	return servers

func _on_session_created() -> void:
	if phase != Phase.HOSTING:
		return
	phase = Phase.IN_SESSION
	status_changed.emit("Session code: " + client.session_id)
	lobby_joined.emit()

func _on_session_joined() -> void:
	if phase != Phase.JOINING:
		return
	phase = Phase.IN_SESSION
	status_changed.emit("Session joined")
	lobby_joined.emit()

func _on_session_left() -> void:
	if leaving:
		return
	var was_in_session := phase == Phase.IN_SESSION
	phase = Phase.IDLE
	joinable = false
	if was_in_session:
		lobby_lost.emit(LOST_REASON)

func _on_error(code: TubeClient.SessionError, message: String) -> void:
	match code:
		TubeClient.SessionError.CREATE_SESSION_FAILED:
			if phase == Phase.HOSTING:
				_fail(message)
		TubeClient.SessionError.JOIN_SESSION_FAILED:
			if phase == Phase.JOINING:
				_fail(message)
		TubeClient.SessionError.LIST_SESSIONS_FAILED:
			listing = false
			listing_ready = false
			status_changed.emit("Session list unavailable (broker unreachable).")
		TubeClient.SessionError.ONLINE_SIGNALING_FAILED:
			status_changed.emit("Broker unreachable; session is LAN-only.")
		_:
			status_changed.emit(message)

func _fail(reason: String) -> void:
	phase = Phase.IDLE
	joinable = false
	join_lobby_failed.emit(reason)

func _on_peer_changed(peer_id: int) -> void:
	if phase != Phase.IN_SESSION or not client.is_server:
		return
	var peers := multiplayer.get_peers()
	if peer_id in peers and peers.size() + 1 > max_players:
		client.kick_peer.call_deferred(peer_id)
	_update_admission()
	if joinable:
		# Deferred so peer_count in TubeClient._publish_metadata sees the settled peer list.
		client.publish_session.call_deferred(_lobby_metadata())

func _update_admission() -> void:
	if client.is_server and client.state != TubeClient.State.IDLE:
		client.refuse_new_connections = not joinable or multiplayer.get_peers().size() + 1 >= max_players

func set_joinable(value: bool) -> void:
	joinable = value
	_update_admission()
	if phase == Phase.IN_SESSION and client.is_server:
		if value:
			client.publish_session(_lobby_metadata())
		else:
			client.unpublish_session()

func _lobby_metadata() -> Dictionary:
	return {"name": lobby_name, "max": max_players}

func get_joinable() -> bool:
	return joinable

func fetch_lobby_list() -> void:
	if phase != Phase.IDLE:
		return
	if listing:
		if listing_ready:
			listing_started.emit()
		_emit_sessions()
	else:
		listing = true
		client.list_sessions()

func _emit_sessions() -> void:
	if phase != Phase.IDLE:
		return
	var sessions := client.get_public_sessions()
	for id: String in sessions:
		var metadata: Dictionary = sessions[id]
		if metadata.get("name") is String and (metadata.get("peer_count") is float or metadata.get("peer_count") is int) and (metadata.get("max") is float or metadata.get("max") is int):
			lobby_found.emit(id, metadata.name, int(metadata.peer_count), int(metadata.max))

func _on_listing_started() -> void:
	listing_ready = true
	listing_started.emit()

func _on_listing_stopped() -> void:
	listing = false
	listing_ready = false

func _stop_listing() -> void:
	listing = false
	listing_ready = false
	client.stop_listing_sessions()

func get_uid(peer_id: int) -> String:
	return str(peer_id)

func get_username(peer_id: int) -> String:
	return str(peer_id)

func get_lobby_address() -> String:
	return client.session_id

func leave_game() -> void:
	_stop_listing()
	phase = Phase.IDLE
	joinable = false
	if client.state != TubeClient.State.IDLE:
		leaving = true
		client.leave_session()
		leaving = false
