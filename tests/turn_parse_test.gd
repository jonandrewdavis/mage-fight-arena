extends SceneTree
## Headless test: Godot --headless --path . -s tests/turn_parse_test.gd

const SAMPLE := '{"iceServers":[{"urls":["stun:stun.cloudflare.com:3478"]},{"urls":["turn:turn.cloudflare.com:3478?transport=udp","turn:turn.cloudflare.com:3478?transport=tcp","turns:turn.cloudflare.com:5349?transport=tcp","turn:turn.cloudflare.com:80?transport=tcp","turns:turn.cloudflare.com:443?transport=tcp"],"username":"user1","credential":"cred1","extra":1}]}'

var _done := false

func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_run()
	return true

func _run() -> void:
	var T = load("res://networking/tube_backend.gd")
	assert(T != null, "tube_backend script missing")

	var servers: Array[Dictionary] = T.parse_ice_servers(SAMPLE.to_utf8_buffer())
	assert(servers.size() == 2, "sample -> 2 entries, got %s" % [servers])
	assert(servers[0] == {"urls": ["stun:stun.cloudflare.com:3478"]}, "stun entry kept as-is")
	assert(servers[1].urls.size() == 5, "turn urls preserved")
	assert(servers[1].username == "user1" and servers[1].credential == "cred1", "creds copied")
	assert(not servers[1].has("extra"), "extra keys stripped")

	for bad in ["", "not json", "[]", "{}", '{"iceServers": 5}', '{"iceServers": [{"username": "x"}, {"urls": []}, {"urls": [1]}, 7]}']:
		var out: Array[Dictionary] = T.parse_ice_servers(bad.to_utf8_buffer())
		assert(out.is_empty(), "bad input %s -> empty, got %s" % [bad, out])

	var single: Array[Dictionary] = T.parse_ice_servers('{"iceServers":[{"urls":"turn:a:1","username":"u","credential":"c"}]}'.to_utf8_buffer())
	assert(single == [{"urls": "turn:a:1", "username": "u", "credential": "c"}], "string urls accepted")

	print("TURN parse checks passed: sample payload, malformed inputs, key stripping, string urls.")
