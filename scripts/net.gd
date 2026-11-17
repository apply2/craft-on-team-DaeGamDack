class_name Net
extends Node
## 친구대전 (온라인) — HTML의 MP(claude.ai 방 기능)를 WebRTC로 옮긴 것. 웹·PC 어디서든, 같은 와이파이가 아니어도 된다.
## 방장 컴퓨터(브라우저)가 WebRTC 서버(peer 1)가 되고, 친구는 방 코드 4자리로 들어온다:
##   방장과 친구가 Supabase Realtime의 같은 방 채널(NetSignal)에 들어가서 연결 정보(SDP·ICE)만 주고받고,
##   그 뒤 게임 데이터는 WebRTC로 방장 ↔ 친구가 직접 오간다 (친구끼리는 방장이 중계 — ENet 때와 같은 별 모양).
##   신호 순서: 친구 "hi"(sid) → 방장 "id"(sid, 번호 2,3,…) → 방장 "sdp" offer → 친구 "sdp" answer ↔ 서로 "ice".
##   친구는 연결되면 신호 채널을 닫고, 방장은 새 친구를 받으려고 방이 열린 동안 계속 들어가 있는다.
##   PC 버전은 addons/webrtc_native(GDExtension)가 WebRTC를 맡고, 웹은 브라우저 것을 쓴다.
## 권한은 HTML과 같다:
##   - 각자 자기 캐릭터를 움직이고 30Hz로 상태를 보낸다. 남의 캐릭터는 받은 상태를 따라 그린다.
##   - 투사체(돌·활·석궁·성수) 피해는 맞은 사람 쪽에서 판정, 저격총·AK·마상창은 쏜 사람 쪽에서 판정.
##   - 방장이 경기 시간·종료, 저격총·AK·말 등장과 줍기 허락을 맡는다.
## 사건(발사·명중·처치)은 따로 믿을 수 있게(reliable) 보낸다.
## HTML과 다른 점: 방장이 나가면 방이 끝난다 (HTML은 다음 사람이 방장을 이어받음).
## 대기실 (사용자 요청 — 커스텀 게임식): 방장이 진짜 상태 room(모드·맵·자리·팀·병과·준비·봇)을 들고 바뀔 때마다 모두에게 보낸다.
##   친구는 ask(op)로 요청만 하고 방장이 검사해서 반영한다. 시작은 방장만, 모두 준비했을 때만.
## 쟁탈전: 사람은 블루/레드 (처음엔 방장이 적은 쪽에 넣어 줌), 방장이 넣은 봇 자리는 방장 컴퓨터의 봇이 맡는다. 봇은 음수 id(-1, -2 …)로 부르고, 방장이 명단(_roster)과 상태(_bots)를 보낸다.
##   방장 봇이 맞는 판정·처치 수는 방장 컴퓨터가 한다 (봇의 '맞은 쪽' = 방장). 사건은 누구 일인지(who)를 같이 보낸다.
##   라운드·점령·점수는 방장 ControlMode가 정하고 snapshot을 _cm으로 보낸다 (친구는 follower).

signal status(text: String)        # 친구대전 화면 아래 문구
signal lobby_changed               # 대기실 다시 그리기
signal start_requested(rem: float) # 경기 시작 (HTML mpStart)
signal end_requested               # 방장이 경기를 끝냄
signal closed(reason: String)      # 연결이 끊겨 방을 나감

const WEPS := ["stone", "bow", "crossbow", "sniper", "holy", "chicken", "lance", "ak", "trumpet", "fanfare", "star"]  # 번호가 바뀌지 않게 뒤에만 더함
const CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const PLAYER_SCENE := preload("res://scenes/player.tscn")

var main: Node            # Main (상태·페이지 확인)
var combat: Combat
var player: PlayerController

var on := false
var is_host := false
var code := ""
var my_name := ""
var cls := "archer"
var remotes := {}         # peer id → PlayerController
var info := {}            # peer id → {n, c, st, k, d} (이름·처치 수 소개. 자리·팀은 room)
var team := ""            # 쟁탈전에서 내 팀 (blue / red)
var bot_roster: Array = []  # 쟁탈전 빈자리 봇 [[id(음수), 이름, 병과, 팀], …] — 방장이 정해서 보냄
var last_mt := {}         # 방장이 보낸 경기 상태 {st, ep, rem}
var seen_epoch := 0
# 방장 쪽
var mst := "lobby"        # lobby / play / end
var epoch := 0
var rem := 0.0
var grants := {}          # 줍기 허락 {sn: [seq, peer], ak: …, hs: …}
# 아이템 줍기 요청·허락 (HTML MP.seqSeen / MP.req / MP.got)
var seq_seen := {}
var req := {}
var got := {}

var _send_t := 0.0
var _host_t := 0.0
var _mt_t := 0.0
var _cm_t := 0.0
var _sig: NetSignal       # 방 채널 (방장: 방이 열린 동안 / 친구: 연결될 때까지)
var _rtc: WebRTCMultiplayerPeer
var _conns := {}          # peer id → {pc: WebRTCPeerConnection, sid, t: 연결 기다린 시간, ice: 설명보다 먼저 온 ICE, has_remote}
var _sid := ""            # 친구: 방장이 번호를 줄 때까지 나를 부르는 임시 이름
var _my_id := 0           # 친구: 방장이 준 번호 (2, 3, …)
var _next_id := 2         # 방장: 다음 친구 번호
var _opening := false     # 방장: 방 채널에 들어가는 중
var _find_t := 0.0        # 친구: 방장이 대답하기를 기다리는 남은 시간
var _hi_t := 0.0
var _conn_t := 0.0        # 친구: 번호를 받은 뒤 직접 연결까지 남은 시간
var _joining := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func() -> void: _fail(NO_LINK))
	multiplayer.server_disconnected.connect(func() -> void: _close("방장이 방을 닫았어요"))
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


static func gen_code() -> String:
	var c := ""
	for i in 4:
		c += CODE_CHARS[randi() % CODE_CHARS.length()]
	return c


func me_id() -> int:
	return multiplayer.get_unique_id() if on else 0


## 이 캐릭터의 peer id (나면 내 id, 없으면 0)
func peer_of(e: PlayerController) -> int:
	if e == null:
		return 0
	if e.is_bot and not e.is_remote and e.peer < 0:  # 방장 봇
		return e.peer
	if e.is_local:
		return me_id()
	return e.peer if e.is_remote else 0


func ent_of(peer: int) -> PlayerController:
	if peer == 0:
		return null
	if peer == me_id():
		return player
	if peer < 0 and is_host:
		return main.bot_by_id(peer)
	return remotes.get(peer)


## 이 id가 내 컴퓨터에서 피해를 판정하는 캐릭터면 돌려줌 (나, 방장이면 내 봇)
func mine(peer: int) -> PlayerController:
	if peer == 0:
		return null
	if peer == me_id():
		return player
	if peer < 0 and is_host:
		var b: PlayerController = main.bot_by_id(peer)
		return b if b and combat.ents.has(b) else null
	return null


# ── 방 만들기·들어가기·나가기 ────────────────────────────────
const NO_LINK := "친구와 직접 연결하지 못했어요. 학교·회사 와이파이처럼 막힌 곳이면 휴대폰 핫스팟 같은 다른 인터넷으로 해 보세요."
const NO_RTC := "이 PC 버전엔 온라인 연결 부품(addons/webrtc_native)이 없어요. exe 옆에 함께 나온 dll 파일도 같이 두세요."

var _sig_retry_t := 0.0   # 방장: 신호 채널이 끊기면 잠깐 뒤 다시 들어감 (이미 들어온 친구는 직접 연결이라 상관없음)


## 이 컴퓨터에서 WebRTC를 쓸 수 있나 (웹 = 브라우저, PC = GDExtension)
static func rtc_ok() -> bool:
	var pc := WebRTCPeerConnection.new()
	var ok := pc.initialize({"iceServers": []}) == OK
	pc.close()
	return ok


static func _ice() -> Array:
	return GameData.ice_override if GameData.ice_override is Array else GameData.NET.ice


func host_room(nick: String, c: String) -> void:
	if on or _sig:
		return
	if not rtc_ok():
		status.emit(NO_RTC)
		return
	my_name = _nick(nick)
	cls = c
	code = gen_code()
	_opening = true
	_open_sig()
	if _sig:
		status.emit("방 여는 중…")


func join_room(nick: String, c: String, room: String) -> void:
	var s := room.strip_edges().to_upper()
	if not _valid_code(s):
		status.emit("방 코드 4자리를 입력하세요.")
		return
	if not rtc_ok():
		status.emit(NO_RTC)
		return
	if on:
		return
	_shutdown()
	my_name = _nick(nick)
	cls = c
	code = s
	_sid = "%08x%08x" % [randi(), randi()]
	_my_id = 0
	_find_t = float(GameData.NET.find_timeout)
	_hi_t = 0.0
	_open_sig()
	if _sig:
		status.emit("방 %s을(를) 찾는 중…" % s)


static func _valid_code(s: String) -> bool:
	if s.length() != 4:
		return false
	for ch in s:
		if not CODE_CHARS.contains(ch) and not "01IO".contains(ch):
			return false
	return true


static func _nick(n: String) -> String:
	n = n.strip_edges().substr(0, int(GameData.NET.name_max))
	return n if n != "" else "기사%d" % randi_range(10, 99)


func _on_connected() -> void:
	_joining = false
	if _sig:  # 이제 방장과 직접 이어졌으니 신호 채널은 닫는다 (Supabase 동시 접속 수 아끼기)
		_sig.close()
		_sig = null
	_begin(my_name, cls, code, false)
	_hello_all()
	ask("hi", {"n": my_name, "c": cls})  # 방장에게 자리 달라고


func _begin(nick: String, c: String, room_code: String, host: bool) -> void:
	on = true
	is_host = host
	my_name = _nick(nick)
	cls = c
	code = room_code
	last_mt = {}
	seen_epoch = 0
	mst = "lobby"
	epoch = 0
	rem = 0.0
	grants = {}
	seq_seen = {}
	req = {}
	got = {}
	team = ""
	room = {}
	if host:
		_room_new()
	bot_roster = []
	combat.net = self
	status.emit("")
	main.enter_mp()
	lobby_changed.emit()


func leave() -> void:
	if not on and not _joining and _sig == null:
		return
	var was_on := on
	_shutdown()
	if was_on:
		main.leave_mp()


func _close(reason: String) -> void:
	if not on:
		return
	_shutdown()
	closed.emit(reason)


func _fail(text: String) -> void:
	if on:  # 방 안에 있다가 끊김 → 방 닫힘과 같게
		_close(text)
		return
	_joining = false
	_shutdown()
	status.emit(text)


func _shutdown() -> void:
	if _sig:
		_sig.close()
	_sig = null
	_opening = false
	_find_t = 0.0
	_my_id = 0
	_sig_retry_t = 0.0
	for p: int in remotes.keys():
		_remove_remote(p)
	info.clear()
	room = {}
	bot_roster = []
	_conns.clear()
	if multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_rtc = null
	on = false
	is_host = false
	_joining = false
	if combat:
		combat.net = null


# ── 신호 (Supabase Realtime 방 채널) ─────────────────────────
func _open_sig() -> void:
	var s := NetSignal.new()
	_sig = s
	s.joined.connect(_on_sig_joined)
	s.message.connect(_on_sig)
	s.failed.connect(_on_sig_failed.bind(s))
	s.open(code)


func _on_sig_joined() -> void:
	if not _opening:
		return
	_opening = false  # 방장: 채널에 들어갔으니 방을 연다
	_rtc = WebRTCMultiplayerPeer.new()
	_rtc.create_server()
	multiplayer.multiplayer_peer = _rtc
	_next_id = 2
	_begin(my_name, cls, code, true)


func _on_sig_failed(reason: String, s: NetSignal) -> void:
	if _sig != s:
		return
	_sig = null
	if is_host and on:  # 방은 그대로 두고 잠깐 뒤 다시 들어감
		_sig_retry_t = 3.0
		return
	if _opening or not on:
		_fail(reason)


func _send_sig(d: Dictionary) -> void:
	if _sig:
		d["from"] = 1 if is_host or _opening else _my_id
		_sig.send(d)


func _on_sig(d: Dictionary) -> void:
	var k := str(d.get("k", ""))
	var from := int(d.get("from", 0))
	if is_host:
		if not on:
			return
		match k:
			"hi":  # 새 친구: 번호를 주고 연결 제안(offer)을 만든다
				var sid := str(d.get("sid", ""))
				if sid == "":
					return
				for id: int in _conns:
					if _conns[id].sid == sid:  # 대답을 못 받아서 또 물어봄
						_send_sig({"k": "id", "to": sid, "id": id})
						return
				if _conns.size() >= int(GameData.NET.max_players) - 1:
					_send_sig({"k": "full", "to": sid})
					return
				var nid := _next_id
				_next_id += 1
				_send_sig({"k": "id", "to": sid, "id": nid})
				var pc := _new_pc(nid, sid)
				_rtc.add_peer(pc, nid)
				pc.create_offer()
			"sdp":
				if _conns.has(from) and int(d.get("to", 0)) == 1:
					_set_remote(from, d)
			"ice":
				if _conns.has(from) and int(d.get("to", 0)) == 1:
					_add_ice(from, d)
		return
	match k:
		"id":
			if str(d.get("to", "")) == _sid and _my_id == 0 and from == 1:
				_start_client(int(d.get("id", 0)))
		"full":
			if str(d.get("to", "")) == _sid and _my_id == 0:
				_fail("방이 꽉 찼어요 (최대 %d명)" % int(GameData.NET.max_players))
		"sdp":
			if _my_id != 0 and from == 1 and int(d.get("to", 0)) == _my_id:
				_set_remote(1, d)
		"ice":
			if _my_id != 0 and from == 1 and int(d.get("to", 0)) == _my_id:
				_add_ice(1, d)


## 친구: 방장이 번호를 줬다 → 그 번호로 WebRTC 클라이언트가 되어 방장(1)의 제안을 기다림
func _start_client(id: int) -> void:
	if id < 2:
		return
	_my_id = id
	_rtc = WebRTCMultiplayerPeer.new()
	_rtc.create_client(id)
	var pc := _new_pc(1, "")
	_rtc.add_peer(pc, 1)
	multiplayer.multiplayer_peer = _rtc
	_joining = true
	_conn_t = float(GameData.NET.connect_timeout)
	status.emit("방장과 연결하는 중…")


## 상대(peer)와 잇는 연결 하나. 만든 설명(SDP)·후보(ICE)는 신호 채널로 상대에게 보낸다
func _new_pc(peer: int, sid: String) -> WebRTCPeerConnection:
	var pc := WebRTCPeerConnection.new()
	pc.initialize({"iceServers": _ice()})
	_conns[peer] = {"pc": pc, "sid": sid, "t": 0.0, "ice": [], "remote": false, "ok": false}
	pc.session_description_created.connect(func(type: String, sdp: String) -> void:
		if not _conns.has(peer) or _conns[peer].pc != pc:
			return
		pc.set_local_description(type, sdp)
		_send_sig({"k": "sdp", "to": peer, "type": type, "sdp": sdp}))
	pc.ice_candidate_created.connect(func(mid: String, idx: int, cand: String) -> void:
		if _conns.has(peer) and _conns[peer].pc == pc:
			_send_sig({"k": "ice", "to": peer, "mid": mid, "idx": idx, "c": cand}))
	return pc


func _set_remote(peer: int, d: Dictionary) -> void:
	var c: Dictionary = _conns[peer]
	if c.remote:
		return
	var pc: WebRTCPeerConnection = c.pc
	pc.set_remote_description(str(d.get("type", "")), str(d.get("sdp", "")))  # offer를 받으면 answer를 알아서 만든다
	c.remote = true
	for x: Dictionary in c.ice:  # 설명보다 먼저 온 후보
		pc.add_ice_candidate(str(x.get("mid", "")), int(x.get("idx", 0)), str(x.get("c", "")))
	c.ice = []


func _add_ice(peer: int, d: Dictionary) -> void:
	var c: Dictionary = _conns[peer]
	if not c.remote:
		(c.ice as Array).append(d)
		return
	(c.pc as WebRTCPeerConnection).add_ice_candidate(str(d.get("mid", "")), int(d.get("idx", 0)), str(d.get("c", "")))


## 매 프레임: 신호 채널, 방 찾기·연결 기다리기, 방장의 다시 들어가기·안 이어진 연결 치우기
func _poll_sig(dt: float) -> void:
	var s := _sig  # 콜백에서 _sig가 null이 돼도 poll 도중 사라지지 않게
	if s:
		s.poll(dt)
	var N: Dictionary = GameData.NET
	if is_host and on:
		if _sig == null:
			_sig_retry_t -= dt
			if _sig_retry_t <= 0:
				_open_sig()
		for id: int in _conns.keys():
			var c: Dictionary = _conns[id]
			if c.ok:
				continue
			c.t = float(c.t) + dt
			if float(c.t) > float(N.connect_timeout) + 5.0:  # 끝내 안 이어진 친구 자리 비우기
				_conns.erase(id)
				if _rtc and _rtc.has_peer(id):
					_rtc.remove_peer(id)
		return
	if on:
		return
	if _my_id == 0 and _sig and _sig.state == "ready":
		_hi_t -= dt
		if _hi_t <= 0:
			_hi_t = float(N.hi_every)
			_sig.send({"k": "hi", "sid": _sid})
		_find_t -= dt
		if _find_t <= 0:
			_fail("방 %s을(를) 찾지 못했어요. 코드를 다시 확인해 주세요." % code)
	elif _joining:
		_conn_t -= dt
		if _conn_t <= 0:
			_fail(NO_LINK)


# ── 사람 들어오고 나가기 ─────────────────────────────────────
func _on_peer_connected(id: int) -> void:
	if _conns.has(id):  # 방장: 직접 연결 완료 (더는 기다리지 않음)
		_conns[id].ok = true
	if on:  # 새로 온 사람에게 내 소개 (서버가 다른 친구에게도 전해 준다)
		_hello.rpc_id(id, _my_info())
		if is_host:
			_room.rpc_id(id, room)
			_roster.rpc_id(id, bot_roster)
			_mt.rpc_id(id, _mt_dict())


func _on_peer_disconnected(id: int) -> void:
	if is_host:
		_conns.erase(id)
	_remove_remote(id)
	info.erase(id)
	if is_host and not slot_of(id).is_empty():  # 자리를 비우고 모두에게 알림
		(room.slots as Array).erase(slot_of(id))
		_push_room()
	lobby_changed.emit()


func _hello_all() -> void:
	_hello.rpc(_my_info())


func _my_info() -> Dictionary:
	var st := "play" if main.state == "playing" or main.state == "paused" else "lobby"
	return {"n": my_name, "c": cls, "st": st, "k": player.kills, "d": player.deaths}


## 이름·처치 수 소개 (경기 중 캐릭터 이름표·점수판용). 대기실 자리·팀·병과는 room이 정한다
@rpc("any_peer", "reliable")
func _hello(d: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id()
	info[id] = d
	var e := _ensure_remote(id)
	e.ent_name = str(d.get("n", "친구")).substr(0, int(GameData.NET.name_max))
	e.kills = int(d.get("k", 0))
	e.deaths = int(d.get("d", 0))
	var t := team_of(id)
	if t != "" and main.mode and e.team != t:  # 쟁탈전 중에 들어옴: 팀 색으로
		_set_remote_team(e, t)
	lobby_changed.emit()


# ── 대기실 상태 (room) ───────────────────────────────────────
## 방장이 진짜 상태를 들고, 바뀔 때마다 통째로 모두에게 보낸다 (_room). 친구는 요청(_req)만 보내고 방장이 검사해서 반영.
## room = {ver, md: ffa/control, map, slots: [{id, bot, n, c, t, rdy, diff}]}
##   id: 사람 = peer id(1 = 방장), 봇 = 음수 (Main.bot_by_id). c "" = 봇 병과 무작위. diff = 봇 난이도. rdy = 준비 (방장·봇은 늘 준비)
var room := {}


static func _slot(id: int, n: String, c: String, t: String, bot := false, diff := "") -> Dictionary:
	return {"id": id, "bot": bot, "n": n, "c": c, "t": t, "rdy": bot, "diff": diff}


func _room_new() -> void:
	room = {"ver": 0, "md": "ffa", "map": GameData.room_map("ffa"), "slots": [_slot(1, my_name, cls, "")]}


func slots() -> Array:
	return room.get("slots", [])


func slot_of(id: int) -> Dictionary:
	for s: Dictionary in slots():
		if int(s.id) == id:
			return s
	return {}


## 이 방 모드의 최대 인원 (사람 + 봇)
func room_cap() -> int:
	if mode_now() == "control":
		return int(GameData.MODES.control.team_size) * 2
	return int(GameData.NET.max_players)


func team_cap() -> int:
	return int(GameData.MODES.control.team_size)


## 팀별 자리 수 (사람 + 봇)
func team_counts() -> Dictionary:
	var n := {"blue": 0, "red": 0}
	for s: Dictionary in slots():
		if str(s.t) in n:
			n[s.t] += 1
	return n


## 팀별 사람 수
func human_counts() -> Dictionary:
	var n := {"blue": 0, "red": 0}
	for s: Dictionary in slots():
		if not s.bot and str(s.t) in n:
			n[s.t] += 1
	return n


## 준비한 사람 / 준비해야 하는 사람 (방장·봇 빼고)
func ready_counts() -> Vector2i:
	var r := Vector2i.ZERO
	for s: Dictionary in slots():
		if not s.bot and int(s.id) != 1:
			r.y += 1
			if s.rdy:
				r.x += 1
	return r


func my_ready() -> bool:
	return bool(slot_of(me_id()).get("rdy", false))


## 방장: 지금 시작할 수 있나 (대기실이고 모두 준비)
func can_start() -> bool:
	var r := ready_counts()
	return is_host and mst == "lobby" and r.x == r.y


## 방장: room이 바뀌었다 → 모두에게
func _push_room() -> void:
	if not is_host:
		return
	room.ver = int(room.get("ver", 0)) + 1
	if on:
		_room.rpc(room)
	_take_room()


@rpc("authority", "reliable")
func _room(r: Dictionary) -> void:
	room = r
	_take_room()


func _take_room() -> void:
	var s := slot_of(me_id())
	if not s.is_empty():
		team = str(s.t)
	lobby_changed.emit()


## 대기실 요청 (방장은 바로 처리, 친구는 방장에게 보냄)
##   누구나: hi {n, c} · cls 병과 · team 팀 · ready 준비
##   방장만: mode · map · bot_add 팀 · bot_del id · bot_set [id, 병과("" = 무작위), 난이도]
func ask(op: String, arg: Variant = null) -> void:
	if not on:
		return
	if is_host:
		_apply_req(1, op, arg)
	else:
		_req.rpc_id(1, op, arg)


@rpc("any_peer", "reliable")
func _req(op: String, arg: Variant) -> void:
	if is_host:
		_apply_req(multiplayer.get_remote_sender_id(), op, arg)


func _apply_req(from: int, op: String, arg: Variant) -> void:
	var lobby := mst == "lobby"
	var s := slot_of(from)
	match op:
		"hi":
			if arg is Dictionary:
				_join_slot(from, str(arg.get("n", "")), str(arg.get("c", "")))
		"cls":
			if s.is_empty() or not GameData.CLASSES.has(str(arg)):
				return
			s.c = str(arg)
		"ready":
			if s.is_empty() or from == 1 or not lobby:
				return
			s.rdy = bool(arg)
		"team":
			var t := str(arg)
			if s.is_empty() or mode_now() != "control" or not t in ["blue", "red"] or s.t == t:
				return
			if not lobby:
				_deny(from, "경기 중엔 팀을 바꿀 수 없어요")
				return
			if int(team_counts()[t]) >= team_cap():
				_deny(from, "%s이 꽉 찼어요" % ControlMode.team_name(t))
				return
			s.t = t
		_:
			if from != 1 or not lobby:  # 아래는 방장만, 대기실에서만
				return
			match op:
				"mode":
					if not _set_mode(str(arg)):
						return
				"map":
					if not GameData.room_maps(mode_now()).any(func(m: Dictionary) -> bool: return m.key == str(arg)):
						return
					room.map = str(arg)
				"bot_add":
					if not _add_bot(str(arg)):
						return
				"bot_del":
					var b := slot_of(int(arg))
					if b.is_empty() or not b.bot:
						return
					(room.slots as Array).erase(b)
				"bot_set":
					if not arg is Array or (arg as Array).size() < 3:
						return
					var b := slot_of(int(arg[0]))
					var c := str(arg[1])
					var d := str(arg[2])
					if b.is_empty() or not b.bot or not (c == "" or GameData.bot_classes().has(c)) or not GameData.DIFF.has(d):
						return
					b.c = c
					b.diff = d
				_:
					return
	_push_room()


## 거절 안내 (요청한 사람 화면에 알림)
func _deny(to: int, text: String) -> void:
	if to == me_id():
		main.menu.toast(text)
	elif on:
		_notice.rpc_id(to, text)


@rpc("authority", "reliable")
func _notice(text: String) -> void:
	main.menu.toast(text)


## 방장: 새로 온 사람 자리. 꽉 찼으면 봇 하나를 빼고 그 자리를 준다 (쟁탈전은 사람이 적은 팀, 그 팀 봇부터)
func _join_slot(id: int, n: String, c: String) -> void:
	n = n.strip_edges().substr(0, int(GameData.NET.name_max))
	if n == "":
		n = "친구"
	if not GameData.CLASSES.has(c):
		c = "archer"
	var s := slot_of(id)
	if not s.is_empty():
		s.n = n
		s.c = c
		return
	var t := ""
	if mode_now() == "control":
		t = _place_team()
		if t == "":
			return
	elif slots().size() >= room_cap() and not _drop_bot(""):
		return
	(room.slots as Array).append(_slot(id, n, c, t))


func _place_team() -> String:
	var h := human_counts()
	var order := ["blue", "red"] if int(h.blue) <= int(h.red) else ["red", "blue"]
	var n := team_counts()
	for t: String in order:
		if int(n[t]) < team_cap():
			return t
	for t: String in order:
		if _drop_bot(t):
			return t
	return ""


## 봇 하나 빼기 (t = 팀, "" = 아무 봇). 마지막에 넣은 봇부터
func _drop_bot(t: String) -> bool:
	var arr: Array = room.slots
	for i in range(arr.size() - 1, -1, -1):
		var s: Dictionary = arr[i]
		if s.bot and (t == "" or s.t == t):
			arr.remove_at(i)
			return true
	return false


## 방장: 모드 바꾸기. 쟁탈전이면 사람 먼저, 봇은 그다음으로 사람이 적은 팀에 번갈아 넣고 넘치는 봇은 뺀다
func _set_mode(k: String) -> bool:
	if not (k == "ffa" or GameData.MODES.has(k)) or room.md == k:
		return false
	room.md = k
	room.map = GameData.room_map(k)
	for s: Dictionary in slots():
		s.t = ""
	if k == "control":
		for bot_pass: bool in [false, true]:
			for s: Dictionary in slots():
				if bool(s.bot) != bot_pass:
					continue
				var n := team_counts()
				var t := "blue" if int(n.blue) <= int(n.red) else "red"
				if int(n[t]) < team_cap():
					s.t = t
		room.slots = slots().filter(func(x: Dictionary) -> bool: return x.t != "")
	return true


## 방장: 봇 넣기 (쟁탈전은 그 팀에 자리가 있을 때만)
func _add_bot(t: String) -> bool:
	if mode_now() == "control":
		if not t in ["blue", "red"] or int(team_counts()[t]) >= team_cap():
			return false
	else:
		t = ""
		if slots().size() >= room_cap():
			return false
	for i in main.bots.size():
		var id: int = -(i + 1)
		if slot_of(id).is_empty():
			(room.slots as Array).append(_slot(id, (main.bots[i] as PlayerController).ent_name, "", t, true, GameData.difficulty))
			return true
	return false


## 대기실 '팀 바꾸기' — 상대 팀에 자리가 있을 때만
func switch_team() -> bool:
	return move_team("red" if team == "blue" else "blue")


func move_team(t: String) -> bool:
	if mode_now() != "control" or t == team:
		return false
	if int(team_counts().get(t, 0)) >= team_cap():
		main.menu.toast("%s이 꽉 찼어요" % ControlMode.team_name(t))
		return false
	ask("team", t)
	return true


## 방장: 대기실에서 모드 고르기
func set_room_mode(k: String) -> void:
	if is_host:
		ask("mode", k)


## 이 방의 모드 (방장이 고른 것)
func mode_now() -> String:
	if room.has("md"):
		return str(room.md)
	return str(last_mt.get("md", "ffa"))


func team_of(peer: int) -> String:
	if peer == me_id():
		return team
	return str(slot_of(peer).get("t", ""))


func _set_remote_team(e: PlayerController, t: String) -> void:
	main.set_team(e, t)
	if e.model:  # 팀 색으로 몸을 다시 만듦
		var was := e.model.visible
		var hp := e.hp
		e.set_class(e.cls)
		e.hp = hp
		e.model.visible = was


## 병과를 바꾸거나 게임에 들어가고 나올 때 다시 소개
func send_info() -> void:
	if on:
		_hello_all()
	lobby_changed.emit()


func set_cls(c: String) -> void:
	cls = c
	ask("cls", c)
	send_info()


func _ensure_remote(id: int, c := "") -> PlayerController:
	if remotes.has(id):
		return remotes[id]
	var e: PlayerController = PLAYER_SCENE.instantiate()
	e.is_local = false
	e.is_remote = true
	e.peer = id
	e.cls = c if c != "" else str(info.get(id, {}).get("c", "archer"))
	if not GameData.CLASSES.has(e.cls):
		e.cls = "archer"
	e.ent_name = "친구"
	main.add_child(e)
	e.alive = false
	e.spectating = false
	if e.model:
		e.model.visible = false
	combat.register(e)
	remotes[id] = e
	return e


func _remove_remote(id: int) -> void:
	var e: PlayerController = remotes.get(id)
	if not e:
		return
	remotes.erase(id)
	combat.unregister(e)
	if not e.horse.is_empty():
		(e.horse.g as Node).queue_free()
		e.horse = {}
	e.queue_free()


## 대기실 목록 (room 순서): [{id, name, cls("" = 무작위 봇), host, me, bot, rdy, diff, st, team}]
func lobby_list() -> Array:
	var me_st := "play" if main.state == "playing" or main.state == "paused" else ""
	var me := me_id()
	var list: Array = []
	for s: Dictionary in slots():
		var id := int(s.id)
		var st := me_st if id == me else ("" if s.bot else str(info.get(id, {}).get("st", "")))
		list.append({"id": id, "name": str(s.n) + (" (나)" if id == me else ""), "cls": str(s.c), "host": id == 1, "me": id == me,
			"bot": bool(s.bot), "rdy": bool(s.rdy) or id == 1, "diff": str(s.diff), "st": st, "team": str(s.t)})
	return list


func live_match() -> bool:
	return not is_host and last_mt.get("st", "") == "play"


# ── 경기 시작·끝 (방장) ──────────────────────────────────────
func _mt_dict() -> Dictionary:
	return {"st": mst, "ep": epoch, "rem": maxf(0.0, roundf(rem)), "md": mode_now()}


## 방장만, 대기실에서, 모두 준비했을 때만 시작한다
func host_start() -> bool:
	if not is_host:
		return false
	if not can_start():
		if mst == "lobby":
			main.menu.toast("모두 준비해야 시작할 수 있어요")
		return false
	epoch += 1
	seen_epoch = epoch
	mst = "play"
	rem = GameData.MATCH_TIME
	grants = {}
	bot_roster = main.mp_pick_bots() if mode_now() == "control" else []  # 쟁탈전: 빈자리를 봇으로
	_roster.rpc(bot_roster)  # 시작 알림보다 먼저 (친구가 봇을 만들어 두게)
	_mt.rpc(_mt_dict())
	start_requested.emit(rem)
	_host_t = 0.0
	return true


## 결과 화면·대기실로 돌아감 (HTML goLobby)
func to_lobby() -> void:
	if is_host:
		mst = "lobby"
		for s: Dictionary in slots():  # 다음 판은 다시 준비부터
			if not s.bot:
				s.rdy = false
		if not bot_roster.is_empty():
			bot_roster = []
			_roster.rpc(bot_roster)
		_push_room()
		_mt.rpc(_mt_dict())
	send_info()


## 친구: 방장 봇 명단 — 봇을 친구 캐릭터처럼 만들고(음수 id), 명단에 없는 봇은 지운다
@rpc("authority", "reliable")
func _roster(r: Array) -> void:
	bot_roster = r
	var keep := {}
	for b: Array in r:
		if b.size() < 4:
			continue
		var id := int(b[0])
		keep[id] = true
		var c := str(b[2])
		var e := _ensure_remote(id, c if GameData.CLASSES.has(c) else "archer")
		e.ent_name = str(b[1])
		if e.team != str(b[3]):
			_set_remote_team(e, str(b[3]))
	for id: int in remotes.keys():
		if id < 0 and not keep.has(id):
			_remove_remote(id)
	lobby_changed.emit()


## 친구: 진행 중인 경기에 들어가기
func join_live() -> void:
	if live_match():
		seen_epoch = int(last_mt.get("ep", 0))
		start_requested.emit(float(last_mt.get("rem", GameData.MATCH_TIME)))


@rpc("authority", "reliable")
func _mt(mt: Dictionary) -> void:
	last_mt = mt
	var st := str(mt.get("st", "lobby"))
	var ep := int(mt.get("ep", 0))
	if st == "play" and ep > seen_epoch and (main.state == "menu" or main.state == "ended") and main.menu.cur_page != "friend":
		seen_epoch = ep
		start_requested.emit(float(mt.get("rem", GameData.MATCH_TIME)))
	elif st == "end" and main.state in ["playing", "paused"] and ep == seen_epoch:
		end_requested.emit()
	if main.state in ["playing", "paused"] and mt.has("rem") and absf(main.time_left - float(mt.rem)) > 1.5:
		main.time_left = float(mt.rem)
	lobby_changed.emit()


# ── 매 프레임 ────────────────────────────────────────────────
func _physics_process(dt: float) -> void:
	_poll_sig(dt)
	if not on:
		return
	for id: int in remotes:
		_apply_remote(remotes[id], dt)
	var N: Dictionary = GameData.NET
	_send_t -= dt
	if _send_t <= 0:
		_send_t = 1.0 / float(N.send_hz)
		_state.rpc(_state_of(player))
		if is_host and not bot_roster.is_empty():  # 봇 상태는 4명씩 나눠 보냄 (한 묶음이 MTU를 넘지 않게)
			var bs := _bot_states()
			for i in range(0, bs.size(), 4):
				_bots.rpc(bs.slice(i, i + 4))
	if is_host:
		_host_tick(dt)
		if main.mode and mst == "play":  # 쟁탈전 상태 (라운드·점령·점수)
			_cm_t -= dt
			if _cm_t <= 0:
				_cm_t = 1.0 / float(N.ctrl_hz)
				_cm.rpc(main.mode.snapshot())


func _host_tick(dt: float) -> void:
	var N: Dictionary = GameData.NET
	if mst == "play":
		rem -= dt
		main.time_left = maxf(0.0, rem)
	_host_t -= dt
	_mt_t -= dt
	if _host_t <= 0:
		_host_t = 1.0 / float(N.host_hz)
		if mst == "play":
			var mx := player.kills
			for e: PlayerController in remotes.values():
				mx = maxi(mx, e.kills)
			var over := rem <= 0 or mx >= GameData.KILL_LIMIT
			if main.mode:  # 쟁탈전: 라운드 규칙이 끝을 정함 (킬·시간 제한 없음)
				over = main.mode.phase == "over"
			if over:
				mst = "end"
				_mt.rpc(_mt_dict())
				end_requested.emit()
		_it.rpc(_items_dict())
	if _mt_t <= 0:  # 시간 맞추기 겸 1초마다
		_mt_t = 1.0
		_mt.rpc(_mt_dict())


# ── 내 상태 보내기 / 남의 상태 따라가기 (HTML mpTick / applyRemote) ──
func _my_state() -> Array:
	return _state_of(player)


func _state_of(p: PlayerController) -> Array:
	var playing: bool = main.state == "playing" or main.state == "paused"
	var fl := (1 if p.crouch else 0) | (2 if p.sliding else 0) | (4 if p.grounded else 0) | (8 if p.alive and playing else 0) \
		| (16 if p.sprinting else 0) | (32 if p.charging else 0) | (64 if p.helmet else 0) | (128 if p.has_sniper else 0) \
		| (256 if p.invuln > 0 else 0) | (512 if p.has_ak else 0) | (1024 if p.playing else 0) | (2048 if p.dance_t > 0 else 0) \
		| (4096 if p.star_t > 0 else 0)
	return [p.global_position, p.yaw, p.pitch, p.velocity, fl, p.fall_t, p.fall_rx, p.fall_rz, p.fall_yaw, p.mounted,
		maxf(0.0, ceilf(p.hp)), maxi(0, WEPS.find(p.wep)), p.charge, p.cls, p.kills, p.deaths, "play" if playing else "lobby", p.xb_wind]


@rpc("any_peer", "unreliable_ordered")
func _state(s: Array) -> void:
	var id := multiplayer.get_remote_sender_id()
	var e: PlayerController = remotes.get(id)
	if not e or s.size() < 17:
		return
	e.net_s = s
	e.kills = int(s[14])
	e.deaths = int(s[15])
	if info.has(id):
		(info[id] as Dictionary).st = str(s[16])


## 방장: 봇 상태 묶음 [[id, 상태], …]
func _bot_states() -> Array:
	var out: Array = []
	for b: Array in bot_roster:
		var e: PlayerController = main.bot_by_id(int(b[0]))
		if e:
			out.append([int(b[0]), _state_of(e)])
	return out


@rpc("authority", "unreliable_ordered")
func _bots(arr: Array) -> void:
	for x: Variant in arr:
		if not x is Array or (x as Array).size() < 2:
			continue
		var e: PlayerController = remotes.get(int(x[0]))
		var st: Array = x[1]
		if not e or st.size() < 17:
			continue
		e.net_s = st
		e.kills = int(st[14])
		e.deaths = int(st[15])


## 친구: 방장 쟁탈전 상태 (작아서 믿을 수 있게 보냄 — unreliable은 reliable 사건 뒤로 밀리면 버려질 수 있다)
@rpc("authority", "reliable")
func _cm(snap: Array) -> void:
	if main.mode and main.mode.follower and main.state in ["playing", "paused"]:
		main.mode.apply_snapshot(snap)


func _apply_remote(e: PlayerController, dt: float) -> void:
	var s: Array = e.net_s
	e.respawn = maxf(0.0, e.respawn - dt)
	if s.is_empty():
		return
	var N: Dictionary = GameData.NET
	var fl := int(s[4])
	var alive := (fl & 8) != 0
	var pos: Vector3 = s[0]
	if alive and not e.alive:
		if e.respawn > 0:  # 방금 죽었다는 사건을 받았으면 옛 상태로 되살리지 않는다
			return
		var c := str(s[13])
		e.set_class(c if GameData.CLASSES.has(c) else e.cls)
		e.alive = true
		e.ragdoll = null
		e.helmet = true
		e.hp = float(s[10])
		e.global_position = pos
		e.yaw = float(s[1])
		e.velocity = Vector3.ZERO
		e.net_dead_t = 0.0
		e.reset_physics_interpolation()
	if not alive:
		if e.alive:  # 처치 사건보다 상태가 먼저 왔을 수 있으니 잠깐 기다렸다가 숨김
			e.net_dead_t += dt
			if e.net_dead_t > float(N.dead_wait):
				e.alive = false
				if e.model:
					e.model.visible = false
				if not e.horse.is_empty():
					combat.items.dismount(e)
		return
	e.net_dead_t = 0.0
	var sc := str(s[13])
	if sc != e.cls and GameData.CLASSES.has(sc):  # 병과가 바뀌면 몸을 새로 만듦
		e.set_class(sc)
	var k := 1.0 - exp(-dt * float(N.follow))
	var p := e.global_position
	if Vector2(pos.x - p.x, pos.z - p.z).length() > float(N.snap_dist):
		p = pos
		e.global_position = p
		e.reset_physics_interpolation()
	e.global_position = p + (pos - p) * k
	e.yaw += wrapf(float(s[1]) - e.yaw, -PI, PI) * k
	e.pitch += (float(s[2]) - e.pitch) * k
	e.velocity = s[3]
	e.crouch = (fl & 1) != 0
	e.sliding = (fl & 2) != 0
	e.grounded = (fl & 4) != 0
	e.sprinting = (fl & 16) != 0
	e.charging = (fl & 32) != 0
	e.has_sniper = (fl & 128) != 0
	e.invuln = 0.5 if (fl & 256) != 0 else 0.0
	e.has_ak = (fl & 512) != 0
	e.playing = (fl & 1024) != 0  # 연주 중이면 내 쪽에서 원뿔 안인지 계산한다 (Trumpet.update_victims)
	e.dance_t = 0.2 if (fl & 2048) != 0 else 0.0  # 춤은 친구 컴퓨터가 정하고, 나는 모습만
	var was_star := e.star_t > 0
	e.star_t = float(GameData.STAR_FX.end_t) + 1.0 if (fl & 4096) != 0 else 0.0
	if e.star_t > 0 and not was_star:  # 친구가 먹었다: 배너 + 그 자리에서 작게 반짝 소리
		combat.items.ate_fx(e)  # 황금 붕어빵 무적: 반짝임만 (끝나기 직전 깜빡임은 못 봄)
	var hel := (fl & 64) != 0
	if e.helmet and not hel and e.model and e.model.helm:
		combat.knock_helmet(e, Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized())
	e.helmet = hel
	e.fall_t = float(s[5])
	e.fall_rx = float(s[6])
	e.fall_rz = float(s[7])
	e.fall_yaw = float(s[8])
	e.mounted = float(s[9])
	e.mount_h = GameData.MOUNT_H if e.mounted > 0 else 0.0
	e.hp = float(s[10])
	var wi := int(s[11])
	if wi >= 0 and wi < WEPS.size():
		e.wep = WEPS[wi]
	e.charge = float(s[12])
	if s.size() > 17:  # 석궁 감은 칸 수 (모션·끼릭 소리는 Combat._xbow_anim)
		e.xb_wind = int(s[17])


# ── 사건 (HTML mpEvent / handleEvent) ───────────────────────
## x = [종류, …]. f 발사 / sn 저격총 / ak / ln 마상창 / fan 팡파레 / h 맞음 / k 죽음 / st 몸박치기
## from = 누구 일인가 (방장 봇이면 그 봇 id를 같이 보냄, 아니면 보낸 사람)
func event(x: Array, from: PlayerController = null) -> void:
	if on:
		_ev.rpc(x, from.peer if from and from.is_bot and not from.is_remote and from.peer < 0 else 0)


@rpc("any_peer", "reliable")
func _ev(x: Array, who: int) -> void:
	var sid := multiplayer.get_remote_sender_id()
	var e: PlayerController = remotes.get(who if who < 0 and sid == 1 else sid)  # 봇 일은 방장만 보낼 수 있음
	if not e or x.is_empty() or not (main.state in ["playing", "paused"]):
		return
	match str(x[0]):
		"f":  # [f, 무기, 위치, 속도, 당김]
			if e.alive:
				combat.remote_fire(e, WEPS[clampi(int(x[1]), 0, WEPS.size() - 1)], x[2], x[3], clampf(float(x[4]), 0, 1))
		"sn":  # [sn, 총구, 끝, 맞은 사람, 머리]
			combat.remote_shot(e, "sniper", x[1], x[2])
			var v := mine(int(x[3]))
			if v and v.alive:
				combat.damage(v, e, GameData.ITEM.sniper_kill, "sniper", bool(x[4]), ((x[2] as Vector3) - (x[1] as Vector3)).normalized(), x[2])
		"ak":  # [ak, 총구, 끝, 맞은 사람, 머리, 피해]
			combat.remote_shot(e, "ak", x[1], x[2])
			var v := mine(int(x[3]))
			if v and v.alive:
				combat.damage(v, e, clampf(float(x[5]), 0, GameData.WEAPONS.ak.dmg), "ak", bool(x[4]), ((x[2] as Vector3) - (x[1] as Vector3)).normalized(), x[2])
		"fan":  # [fan] — 친구 음유시인의 팡파레. 내가 앞에 있었는지는 내 쪽에서 판정
			if e.alive:
				combat.remote_fanfare(e)
		"ln":  # [ln, 맞은 사람, 머리, 방향]
			var v := mine(int(x[1]))
			if v and v.alive:
				var d: Vector3 = x[3]
				d.y = 0
				combat.damage(v, e, GameData.WEAPONS.lance.dmg, "lance", bool(x[2]), d.normalized() if d.length_squared() > 1e-4 else Vector3(0, 0, 1))
		"st":  # [st, 맞은 사람, 방향] — 황금 붕어빵 무적 몸박치기 (내가 무적이면 damage가 막음)
			var v := mine(int(x[1]))
			if v and v.alive:
				var d: Vector3 = x[2]
				d.y = 0
				combat.damage(v, e, GameData.WEAPONS.star.dmg, "star", false, d.normalized() if d.length_squared() > 1e-4 else Vector3(0, 0, 1))
		"h":  # [h, 때린 사람, 피해, 무기, 머리] — e가 맞음 (맞은 쪽이 판정해서 알려줌)
			if e.alive:
				combat.remote_hit(e, ent_of(int(x[1])), float(x[2]), WEPS[clampi(int(x[3]), 0, WEPS.size() - 1)], bool(x[4]))
		"k":  # [k, 죽인 사람, 무기, 머리, 방향] — e가 죽음
			var d: Vector3 = x[4]
			d.y = 0
			e.respawn = float(GameData.NET.revive_guard)
			combat.remote_kill(e, ent_of(int(x[1])), WEPS[clampi(int(x[2]), 0, WEPS.size() - 1)], bool(x[3]), d.normalized() if d.length_squared() > 1e-4 else Vector3(0, 0, 1))


# ── 특수 아이템: 방장이 등장·위치를 알리고 줍기를 허락 (HTML mirrorItems / handleRequest / mpRequest) ──
func _items_dict() -> Dictionary:
	var I = combat.items
	return {"sn": _pack(I.sniper), "ak": _pack(I.ak), "hs": _pack(I.horse), "hb": _pack(I.horse_b), "gf": _pack(I.fish), "gr": grants}


static func _pack(it: Dictionary) -> Array:
	if it.active:
		return [1, it.pos, ceilf(float(it.life)), int(it.get("seq", 0))]
	return [0, Vector3.ZERO, 0, int(it.get("seq", 0))]


@rpc("authority", "unreliable_ordered")
func _it(it: Dictionary) -> void:
	if is_host:
		return
	var I = combat.items
	var playing: bool = main.state == "playing"
	_mirror(I.sniper, it.get("sn"), "sn", func() -> void:
		if playing:
			I.announce("sn"))
	_mirror(I.ak, it.get("ak"), "ak", func() -> void:
		if playing:
			I.announce("ak"))
	_mirror(I.horse, it.get("hs"), "hs", func() -> void:
		if playing:
			I.announce("hs"))
	_mirror(I.horse_b, it.get("hb"), "hb", func() -> void:  # 쟁탈전 두 번째 말 (알림은 첫 말이 함께 띄움)
		pass)
	_mirror(I.fish, it.get("gf"), "gf", func() -> void:
		if playing:
			I.announce("gf"))
	var gr: Dictionary = it.get("gr", {})
	var me := me_id()
	var p := player
	for key: String in ["sn", "ak", "hs", "hb", "gf"]:
		var g: Array = gr.get(key, [])
		if g.size() == 2 and int(g[1]) == me and got.get(key, -1) != int(g[0]):
			got[key] = int(g[0])
			if key == "gf":
				if p.alive:
					I.eat_fish(p)
			elif key == "hs" or key == "hb":
				if p.alive and p.mounted <= 0:
					I.mount(p, I.horse_b if key == "hb" else I.horse)
			elif p.alive and not p.has_sniper and not p.has_ak and p.mounted <= 0:
				if key == "sn":
					I.pickup_sniper(p)
				else:
					I.pickup_ak(p)


func _mirror(item: Dictionary, arr: Variant, key: String, on_new: Callable) -> void:
	if not arr is Array or (arr as Array).size() < 4:
		return
	var a: Array = arr
	var sq := int(a[3])
	var g: Node3D = item.group
	if int(a[0]) == 1:
		if seq_seen.get(key, -1) != sq:
			seq_seen[key] = sq
			on_new.call()
		item.active = true
		item.pos = a[1]
		item.life = float(a[2])
		if g.global_position.distance_to(a[1]) > 0.01:
			g.global_position = a[1]
			g.reset_physics_interpolation()
		g.visible = true
	else:
		seq_seen[key] = sq
		item.active = false
		g.visible = false


## 친구: 아이템에 닿았으니 방장에게 달라고 함 (같은 아이템에 한 번만)
func request(key: String) -> void:
	if not on or is_host:
		return
	var sq: int = seq_seen.get(key, -1)
	if sq < 0 or req.get(key, -1) == sq:
		return
	req[key] = sq
	_pick.rpc_id(1, key, sq)


@rpc("any_peer", "reliable")
func _pick(key: String, sq: int) -> void:
	if not is_host:
		return
	var I = combat.items
	var it: Dictionary = {"sn": I.sniper, "ak": I.ak, "hs": I.horse, "hb": I.horse_b, "gf": I.fish}.get(key, {})
	if it.is_empty() or not it.active or int(it.get("seq", 0)) != sq:
		return
	it.active = false
	(it.group as Node3D).visible = false
	grants[key] = [sq, multiplayer.get_remote_sender_id()]
	_host_t = 0.0
