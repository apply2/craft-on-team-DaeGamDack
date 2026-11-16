class_name NetSignal
extends RefCounted
## 친구대전 온라인: 서로를 이어 주는 짧은 메시지(신호)만 Supabase Realtime으로 주고받는다.
## 게임 데이터는 WebRTC로 브라우저·PC끼리 직접 오가고, 이 연결은 처음에 "어디로 연결하면 돼?"를 알려 줄 때만 쓴다.
## Supabase Realtime = Phoenix 채널 (WebSocket, JSON 1.0.0). 방 코드마다 채널 하나 ("realtime:jnp-코드").
##   phx_join으로 들어가고 → broadcast로 보내고 받고 → 25초마다 heartbeat.
## 라이브러리 없이 WebSocketPeer로 직접 해서 웹·PC가 같은 코드로 돈다.
## 테스트는 tests/mock_signal.gd(같은 규칙의 가짜 서버)에 붙는다 (GameData.signal_url_override).

signal joined                       # 채널에 들어감 — 이제 send() 가능
signal message(d: Dictionary)       # 같은 방의 다른 사람이 보낸 신호
signal failed(reason: String)       # 연결 안 됨 / 끊김 (사용자에게 보일 문구)

const EVENT := "sig"

var state := "off"   # off / connecting / joining / ready
var topic := ""
var _ws := WebSocketPeer.new()
var _ref := 0
var _join_ref := ""
var _hb_t := 0.0
var _wait_t := 0.0
var _queue: Array = []   # 채널에 들어가기 전에 보낸 신호 (들어가면 보냄)


## base: "https://xxxx.supabase.co" (Supabase) 또는 "ws://127.0.0.1:포트" (테스트용 가짜 서버)
static func ws_url(base: String, key: String) -> String:
	var b := base.strip_edges().trim_suffix("/")
	if b.begins_with("https://"):
		b = "wss://" + b.substr(8) + "/realtime/v1/websocket"
	elif b.begins_with("http://"):
		b = "ws://" + b.substr(7) + "/realtime/v1/websocket"
	elif b.count("/") == 2:  # "ws://주소:포트"처럼 경로가 없으면 "/"를 붙여야 Godot가 주소를 읽는다
		b += "/"
	return "%s?apikey=%s&vsn=1.0.0" % [b, key.uri_encode()]


## 설정된 서버 주소 (테스트면 가짜 서버). 비어 있으면 온라인 친구대전을 못 함
static func server_base() -> String:
	if GameData.signal_url_override == "off":  # 테스트: 서버 설정이 없는 것처럼
		return ""
	if GameData.signal_url_override != "":
		return GameData.signal_url_override
	return str(GameData.NET.supabase_url)


func open(room: String) -> void:
	close()
	var base := server_base()
	var key := str(GameData.NET.supabase_key)
	if base == "" or (base == str(GameData.NET.supabase_url) and key == ""):
		_fail("온라인 서버 설정이 아직 없어요 (game_data.gd의 NET.supabase_url·supabase_key)")
		return
	topic = "realtime:%s%s" % [GameData.NET.room_prefix, room]
	_ws = WebSocketPeer.new()
	if _ws.connect_to_url(ws_url(base, key)) != OK:
		_fail("온라인 서버에 연결하지 못했어요")
		return
	state = "connecting"
	_wait_t = float(GameData.NET.signal_timeout)


func send(d: Dictionary) -> void:
	if state == "ready":
		_push("broadcast", {"type": "broadcast", "event": EVENT, "payload": d}, true)
	elif state != "off":
		_queue.append(d)


func close() -> void:
	if state == "off":
		return
	if state == "ready":
		_push("phx_leave", {}, true)
	_ws.close()
	state = "off"
	_queue.clear()


## 매 프레임 부른다 (Net._physics_process)
func poll(dt: float) -> void:
	if state == "off":
		return
	_ws.poll()
	var ws_state := _ws.get_ready_state()
	if ws_state == WebSocketPeer.STATE_CLOSED:
		_fail("온라인 서버와 연결이 끊겼어요")
		return
	if state != "ready":
		_wait_t -= dt
		if _wait_t <= 0:
			_fail("온라인 서버가 대답하지 않아요")
			return
	if ws_state != WebSocketPeer.STATE_OPEN:
		return
	if state == "connecting":  # 열렸으니 방 채널에 들어감
		state = "joining"
		_join_ref = _push("phx_join", {"config": {"broadcast": {"ack": false, "self": false}, "presence": {"enabled": false}, "private": false}}, false)
	_hb_t -= dt
	if _hb_t <= 0:
		_hb_t = float(GameData.NET.heartbeat)
		_ws.send_text(JSON.stringify({"topic": "phoenix", "event": "heartbeat", "payload": {}, "ref": _next_ref()}))
	while state != "off" and _ws.get_available_packet_count() > 0:
		var raw := _ws.get_packet().get_string_from_utf8()
		var m: Variant = JSON.parse_string(raw)
		if m is Dictionary:
			_on_msg(m)


func _on_msg(m: Dictionary) -> void:
	if str(m.get("topic", "")) != topic:
		return
	var ev := str(m.get("event", ""))
	var pl: Variant = m.get("payload", {})
	if not pl is Dictionary:
		return
	match ev:
		"phx_reply":
			if state == "joining" and str(m.get("ref", "")) == _join_ref:
				if str(pl.get("status", "")) == "ok":
					state = "ready"
					joined.emit()
					var q := _queue.duplicate()
					_queue.clear()
					for d: Dictionary in q:
						send(d)
				else:
					_fail("온라인 방에 들어가지 못했어요")
		"broadcast":
			if str(pl.get("event", "")) == EVENT and pl.get("payload") is Dictionary:
				message.emit(pl.payload)
		"phx_error", "phx_close":
			_fail("온라인 방 연결이 끊겼어요")


func _push(ev: String, payload: Dictionary, with_join: bool) -> String:
	var r := _next_ref()
	var m := {"topic": topic, "event": ev, "payload": payload, "ref": r}
	if with_join:
		m.join_ref = _join_ref
	elif ev == "phx_join":
		m.join_ref = r
	_ws.send_text(JSON.stringify(m))
	return r


func _next_ref() -> String:
	_ref += 1
	return str(_ref)


func _fail(reason: String) -> void:
	var was := state
	close()
	state = "off"
	if was != "off" or reason != "":
		failed.emit(reason)
