extends Node
## 테스트용 가짜 신호 서버 — Supabase Realtime(Phoenix 채널 JSON 1.0.0) 중에서 NetSignal이 쓰는 것만 흉내 낸다.
## phx_join → ok 대답, broadcast → 같은 채널의 다른 사람에게 (self: false), heartbeat → ok, phx_leave → 채널에서 뺌.
## 쓰는 법: var S = load("res://tests/mock_signal.gd").new(); root.add_child(S); S.start(포트)
##   GameData.signal_url_override = "ws://127.0.0.1:포트"
## sent: 지금까지 중계한 broadcast 수 (신호가 몇 개 오갔나 보려고), drop: true면 broadcast를 버림 (방이 없는 것처럼)

var tcp := TCPServer.new()
var clients: Array = []   # [{ws: WebSocketPeer, topics: {}}]
var sent := 0
var drop := false
var reject_join := false


func start(port: int) -> int:
	process_mode = Node.PROCESS_MODE_ALWAYS
	return tcp.listen(port, "127.0.0.1")


func stop() -> void:
	for c: Dictionary in clients:
		(c.ws as WebSocketPeer).close()
	clients.clear()
	tcp.stop()


## 들어와 있는 사람 수 (채널에 하나라도 들어간 연결)
func joined_count() -> int:
	var n := 0
	for c: Dictionary in clients:
		if not (c.topics as Dictionary).is_empty():
			n += 1
	return n


func _physics_process(_dt: float) -> void:
	while tcp.is_listening() and tcp.is_connection_available():
		var ws := WebSocketPeer.new()
		ws.accept_stream(tcp.take_connection())
		clients.append({"ws": ws, "topics": {}})
	for c: Dictionary in clients.duplicate():
		var ws: WebSocketPeer = c.ws
		ws.poll()
		if ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			clients.erase(c)
			continue
		if ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
			continue
		while ws.get_available_packet_count() > 0:
			var m: Variant = JSON.parse_string(ws.get_packet().get_string_from_utf8())
			if m is Dictionary:
				_on_msg(c, m)


func _on_msg(c: Dictionary, m: Dictionary) -> void:
	var ws: WebSocketPeer = c.ws
	var topic := str(m.get("topic", ""))
	match str(m.get("event", "")):
		"heartbeat":
			_reply(ws, topic, m, "ok")
		"phx_join":
			if reject_join:
				_reply(ws, topic, m, "error")
				return
			c.topics[topic] = true
			_reply(ws, topic, m, "ok")
		"phx_leave":
			(c.topics as Dictionary).erase(topic)
		"broadcast":
			if drop or not c.topics.has(topic):
				return
			var out := JSON.stringify({"topic": topic, "event": "broadcast", "payload": m.get("payload", {}), "ref": null})
			for o: Dictionary in clients:
				if o != c and o.topics.has(topic) and (o.ws as WebSocketPeer).get_ready_state() == WebSocketPeer.STATE_OPEN:
					(o.ws as WebSocketPeer).send_text(out)
			sent += 1


func _reply(ws: WebSocketPeer, topic: String, m: Dictionary, status: String) -> void:
	ws.send_text(JSON.stringify({"topic": topic, "event": "phx_reply", "payload": {"status": status, "response": {}}, "ref": m.get("ref"), "join_ref": m.get("join_ref")}))
