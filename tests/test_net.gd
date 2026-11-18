extends SceneTree
## 친구대전(온라인) 자동 테스트 — 한 프로세스에 Main을 둘 띄우고(방장 A, 친구 B) 서로 다른 SceneMultiplayer로 잇는다.
## 신호는 가짜 Supabase 서버(tests/mock_signal.gd, 포트 24690), 게임 데이터는 진짜 WebRTC(addons/webrtc_native)로 오간다.
## 서버 설정 없음·없는 방 코드·서버가 안 받아 줌, 방 코드로 찾기, 대기실, 경기 시작, 위치 따라가기, 투사체(맞은 쪽 판정)·저격총(쏜 쪽 판정)·처치 수,
## 아이템 줍기 허락, 시간 끝나면 경기 끝, 나가기·방 닫힘을 확인한다.
## 실행: godot --headless --fixed-fps 60 --path . -s tests/test_net.gd   (처음 받은 저장소면 먼저 godot --headless --editor --path . --quit)
## 통과하면 "ALL PASS"와 종료 코드 0, 실패하면 FAIL 줄과 종료 코드 1.

var G: Node
var A: Node   # 방장 Main
var B: Node   # 친구 Main
var fails := 0
var S: Node   # 가짜 신호 서버

const IDLE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false}
const FIRE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false, "fire": true}
const HERE := Vector3(-25, 0, 18)


func _initialize() -> void:
	G = root.get_node("GameData")
	G.save_enabled = false
	G.hitstop_enabled = false
	G.land_trip_override = 0.0  # 착지 넘어짐 끔 (무작위라)
	G.third_person = false
	G.difficulty = "normal"
	G.chosen_cls = "archer"
	S = load("res://tests/mock_signal.gd").new()
	root.add_child(S)
	if S.start(24690) != OK:
		print("FAIL 가짜 신호 서버를 못 엶 (포트 24690)")
	G.ice_override = []  # 같은 컴퓨터 안이라 STUN 없이
	G.end_wait_override = 1.5  # 결과 화면 → 대기실 (원래 10초)
	A = _make("A")
	B = _make("B")
	G.ai_enabled = false
	_run()


## /root/A/Main, /root/B/Main — 각자 자기 multiplayer를 써서 RPC 경로("Main/Net")가 같아진다
func _make(n: String) -> Node:
	var holder := Node.new()
	holder.name = n
	root.add_child(holder)
	set_multiplayer(SceneMultiplayer.new(), NodePath("/root/" + n))  # _initialize 때는 아직 get_path()를 못 씀
	var m: Node = load("res://scenes/main.tscn").instantiate()
	holder.add_child(m)
	return m


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func wait_until(f: Callable, max_frames := 300) -> bool:
	for i in max_frames:
		if f.call():
			return true
		await physics_frame
	return f.call()


func check(name: String, ok: bool, detail := "") -> void:
	print(("PASS " if ok else "FAIL ") + name + "  " + detail)
	if not ok:
		fails += 1


func put(e, pos: Vector3, cls := "archer", yaw := 0.0) -> void:
	e.next_cls = cls
	e.spawn_at(pos)
	e.invuln = 0.0
	e.scripted_input = IDLE
	e.yaw = yaw
	e.pitch = 0.0


func _run() -> void:
	await wait(3)
	var na = A.net
	var nb = B.net
	var pa = A.player
	var pb = B.player

	# ── 서버 설정이 없으면 알려 줌 ──
	check("WebRTC 쓸 수 있음 (webrtc_native)", na.rtc_ok(), "")
	G.signal_url_override = "off"
	var said := [""]
	na.status.connect(func(t: String) -> void: said[0] = t)
	na.host_room("방장", "archer")
	await wait(2)
	check("서버 설정 없음 → 방 안 열림 + 안내", not na.on and said[0].contains("설정"), said[0])
	G.signal_url_override = "ws://127.0.0.1:24690"

	# ── 서버가 방 채널을 안 받아 줌 ──
	S.reject_join = true
	na.host_room("방장", "archer")
	await wait_until(func(): return not said[0].contains("여는"), 120)
	check("채널 거절 → 방 안 열림 + 안내", not na.on and said[0].contains("들어가지 못했"), said[0])
	S.reject_join = false

	# ── 없는 방 코드 ──
	var said_b := [""]
	nb.status.connect(func(t: String) -> void: said_b[0] = t)
	nb.join_room("친구", "barbarian", "ZZZZ")
	await wait(10)
	check("찾는 중 안내", said_b[0].contains("찾는 중"), said_b[0])
	await wait_until(func(): return not said_b[0].contains("찾는 중"), int(G.NET.find_timeout * 60) + 120)
	await wait(5)
	check("없는 방 → 못 찾음 안내, 신호 채널 닫음", not nb.on and said_b[0].contains("찾지 못했") and S.joined_count() == 0, said_b[0])
	nb.join_room("친구", "barbarian", "AB")
	check("코드가 4자리가 아니면 안내", said_b[0].contains("4자리"), said_b[0])

	# ── 방 만들기 ──
	na.host_room("방장", "archer")
	await wait_until(func(): return na.on, 120)
	check("방장: 방이 열림", na.on and na.is_host and na.code.length() == 4, "code=%s" % na.code)
	check("방장은 신호 채널에 남아 있음", S.joined_count() == 1, "n=%d" % S.joined_count())
	check("방장: 대기실 화면, 봇 빠짐", A.state == "menu" and A.menu.cur_page == "lobby" and A.combat.ents.size() == 1, "ents=%d" % A.combat.ents.size())

	# ── 코드로 찾아 들어가기 ──
	nb.join_room("  친구  ", "barbarian", na.code.to_lower())
	var found: bool = await wait_until(func(): return nb.on, 600)
	check("친구: 방 코드로 찾아 들어감 (WebRTC 직접 연결)", found and not nb.is_host and nb.code == na.code and nb.me_id() >= 2, "code=%s id=%d" % [nb.code, nb.me_id()])
	await wait(5)
	check("연결되면 친구는 신호 채널을 닫음", S.joined_count() == 1, "n=%d" % S.joined_count())
	await wait_until(func(): return na.remotes.size() == 1 and nb.remotes.size() == 1 and na.slots().size() == 2 and nb.slots().size() == 2, 120)
	var la: Array = na.lobby_list()
	var lb: Array = nb.lobby_list()
	check("대기실 목록 2명", la.size() == 2 and lb.size() == 2, "%s / %s" % [la, lb])
	check("이름·병과·방장 표시 (방장이 보낸 자리 순서)", la[1].name == "친구" and la[1].cls == "barbarian" and lb[0].host and not lb[1].host and lb[1].name == "친구 (나)", str(lb))
	check("친구 쪽도 봇 빠짐", B.combat.ents.size() == 2 and A.combat.ents.size() == 2, "A=%d B=%d" % [A.combat.ents.size(), B.combat.ents.size()])
	nb.set_cls("crossbow")
	await wait_until(func(): return na.lobby_list()[1].cls == "crossbow", 60)
	check("병과 바꾸면 방장 목록도 바뀜", na.lobby_list()[1].cls == "crossbow")

	# ── 준비·시작 권한 ──
	A.menu.lobby_start.emit()
	await wait(10)
	check("친구가 준비 안 하면 방장도 시작 못 함", A.state == "menu" and B.state == "menu" and not na.can_start(), "%s/%s" % [A.state, B.state])
	nb.ask("ready", true)
	await wait_until(func(): return na.can_start() and nb.my_ready(), 60)
	check("친구 준비 → 방장·친구 목록에 준비", na.lobby_list()[1].rdy and nb.lobby_list()[1].rdy)
	B.start_match()
	nb.host_start()
	nb.ask("mode", "control")  # 방장만 할 수 있는 요청은 무시됨
	await wait(10)
	check("친구는 시작·모드 바꾸기를 못 함", A.state == "menu" and B.state == "menu" and na.mode_now() == "ffa", "%s/%s %s" % [A.state, B.state, na.mode_now()])

	# ── 경기 시작 ──
	A.menu.lobby_start.emit()
	await wait_until(func(): return A.state == "playing" and B.state == "playing", 60)
	check("방장이 시작하면 둘 다 경기", A.state == "playing" and B.state == "playing", "%s/%s" % [A.state, B.state])
	check("시간 4분", absf(B.time_left - G.MATCH_TIME) < 2 and absf(A.time_left - G.MATCH_TIME) < 2, "A=%.1f B=%.1f" % [A.time_left, B.time_left])
	check("친구는 고른 병과로 나옴", pb.cls == "crossbow" and pa.cls == "archer", pb.cls)
	for it in [A.combat.items, B.combat.items]:
		it.sniper_timer = 9999.0
		it.ak_timer = 9999.0
		it.horse_timer = 9999.0
	check("친구대전엔 닭이 없음", A.combat.items.chickens.is_empty() and B.combat.items.chickens.is_empty(), "")

	# ── 위치 따라가기 ──
	put(pa, HERE, "barbarian", -PI / 2)        # 동쪽(+X)을 봄
	put(pb, HERE + Vector3(6, 0, 0), "archer", PI / 2)
	await wait(40)
	var rb = na.remotes.values()[0]   # 방장 화면의 친구
	var ra = nb.remotes.values()[0]   # 친구 화면의 방장
	check("방장 화면에 친구가 제자리에 보임", rb.alive and rb.global_position.distance_to(pb.global_position) < 0.3 and rb.model and rb.model.visible,
		"d=%.2f" % rb.global_position.distance_to(pb.global_position))
	check("친구 화면에 방장이 보임", ra.alive and ra.global_position.distance_to(pa.global_position) < 0.3 and ra.cls == "barbarian", ra.cls)
	check("고개 방향도 따라감", absf(wrapf(rb.yaw - pb.yaw, -PI, PI)) < 0.05, "")

	# ── 투사체: 친구 화면에도 날아가고, 맞은 쪽(친구)이 피해를 판정 ──
	pa.scripted_input = FIRE
	await wait(2)
	pa.scripted_input = IDLE
	await wait(3)
	check("친구 화면에도 돌멩이가 생김", B.combat.projectiles.any(func(p): return p.owner == ra and p.kind == "stone"), "n=%d" % B.combat.projectiles.size())
	await wait(30)
	check("돌멩이에 맞아 친구 체력이 줄어듦 (친구 쪽 판정)", pb.hp < 100 and pb.hp >= 85, "hp=%.0f" % pb.hp)
	check("방장 쪽에선 직접 깎지 않고 상태로 받음", absf(rb.hp - pb.hp) < 1.0, "remote hp=%.0f" % rb.hp)

	# ── 포병 포탄: 친구 화면에도 날아가고, 맞은 쪽(친구)이 직격 100을 판정. 체력은 상태로 방장 화면에 ──
	put(pa, HERE, "cannoneer", -PI / 2)
	put(pb, HERE + Vector3(6, 0, 0), "cannoneer", PI / 2)
	await wait(40)
	check("방장 화면에 친구가 포병으로", rb.cls == "cannoneer" and absf(rb.hp - 150.0) < 1.0, "%s hp=%.0f" % [rb.cls, rb.hp])
	pa.scripted_input = FIRE
	await wait(2)
	pa.scripted_input = IDLE
	await wait(3)
	check("친구 화면에도 포탄이 생김", B.combat.projectiles.any(func(p): return p.owner == ra and p.kind == "cannon"), "n=%d" % B.combat.projectiles.size())
	await wait(30)
	check("포탄 직격: 친구 쪽에서 100 판정", absf(pb.hp - 50.0) < 0.5, "hp=%.0f" % pb.hp)
	check("방장 화면의 친구 체력도 같음 (상태 동기화)", absf(rb.hp - pb.hp) < 1.0, "방장 화면 %.0f / 친구 %.0f" % [rb.hp, pb.hp])
	check("쏜 사람(방장)은 안 다침", pa.hp == 150.0, "hp=%.0f" % pa.hp)
	put(pa, HERE, "barbarian", -PI / 2)
	put(pb, HERE + Vector3(6, 0, 0), "archer", PI / 2)
	await wait(40)

	# ── 흡혈귀 (친구): 문 쪽(친구)이 판정해서 알림 → 방장이 피해 적용, 회복은 친구 쪽. 양쪽 화면 체력이 같음 ──
	put(pa, HERE, "archer", -PI / 2)
	put(pb, HERE + Vector3(1.5, 0, 0), "vampire", PI / 2)  # 서쪽(-X) = 방장 쪽을 봄
	pb.burn_wait = 999.0
	pb.hp = 60.0
	await wait(30)
	pb.scripted_input = FIRE
	await wait(2)
	pb.scripted_input = IDLE
	await wait(20)
	var TW: Dictionary = G.WEAPONS.teeth
	check("흡혈귀 물기: 방장이 28 피해 (방장 쪽에서 적용)", absf(pa.hp - (100.0 - float(TW.dmg))) < 0.5, "hp=%.0f" % pa.hp)
	check("  친구(흡혈귀)는 15 회복", absf(pb.hp - (60.0 + float(TW.heal))) < 0.5, "hp=%.0f" % pb.hp)
	check("  두 화면 체력이 같음 (방장 화면의 친구 / 친구 화면의 방장)", absf(rb.hp - pb.hp) < 1.0 and absf(ra.hp - pa.hp) < 1.0,
		"친구 %.0f/%.0f 방장 %.0f/%.0f" % [pb.hp, rb.hp, pa.hp, ra.hp])
	check("  방장 화면에서도 틀니가 딱 (모습)", rb.cls == "vampire" and rb.fire_anim >= 0.0, "")
	# 화상은 친구 컴퓨터가 깎고 방장 화면엔 상태로
	pb.burn_wait = 0.0
	await wait(70)
	check("흡혈귀 화상: 친구 쪽에서 타고 방장 화면도 같음", pb.hp < 75.0 - 9.0 and absf(rb.hp - pb.hp) < 3.0, "친구 %.1f / 방장 화면 %.0f" % [pb.hp, rb.hp])
	# 박쥐 돌진: 6m 밖에서 돌진해 방장에게 부딪힘
	put(pa, HERE, "archer", -PI / 2)
	put(pb, HERE + Vector3(6, 0, 0), "vampire", PI / 2)
	pb.burn_wait = 999.0
	await wait(30)
	pb.scripted_input = {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false, "aim": true}
	await wait(2)
	pb.scripted_input = IDLE
	await wait(30)
	check("박쥐 돌진: 방장이 20 피해 (방장 쪽에서 적용)", absf(pa.hp - (100.0 - float(G.WEAPONS.bat.dmg))) < 0.5, "hp=%.0f" % pa.hp)
	put(pa, HERE, "barbarian", -PI / 2)
	put(pb, HERE + Vector3(6, 0, 0), "archer", PI / 2)
	await wait(40)

	# ── 저격총: 쏜 쪽(방장)이 판정해서 알림 → 친구 죽음, 방장 처치 +1 ──
	A.combat.items.drop_sniper(pa.global_position, 5)
	await wait(5)
	check("방장은 바로 주움", pa.has_sniper, "")
	await wait(20)
	pa.scripted_input = FIRE
	await wait(2)
	pa.scripted_input = IDLE
	var died: bool = await wait_until(func(): return not pb.alive, 60)
	check("저격총에 맞아 친구가 죽음", died, "hp=%.0f" % pb.hp)
	await wait_until(func(): return pa.kills == 1, 60)
	check("처치 수: 방장 1킬, 친구 1데스", pa.kills == 1 and pb.deaths == 1, "k=%d d=%d" % [pa.kills, pb.deaths])
	await wait(20)
	check("방장 화면에서 친구가 래그돌", not rb.alive and rb.ragdoll != null, "")
	check("친구 화면에도 방장 처치 수가 보임", ra.kills == 1, "k=%d" % ra.kills)
	# 친구 부활 (3초)
	var back: bool = await wait_until(func(): return pb.alive and rb.alive, 300)
	check("친구가 부활하면 방장 화면에도 나타남", back, "")

	# ── 아이템 줍기: 방장이 놓고, 친구가 닿으면 방장이 허락 ──
	pa.has_sniper = false
	pa.wep = "stone"
	var spot := HERE + Vector3(0, 0, -8)
	A.combat.items.drop_ak(spot, 25)
	var seen: bool = await wait_until(func(): return B.combat.items.ak.active, 60)
	check("방장이 놓은 AK가 친구 화면에도 뜸", seen and B.combat.items.ak.pos.distance_to(spot) < 0.1, "")
	put(pb, spot, "archer")
	var got: bool = await wait_until(func(): return pb.has_ak, 90)
	check("친구가 닿으면 방장 허락을 받아 주움", got and not A.combat.items.ak.active, "")
	await wait(20)
	check("방장 화면에서 친구가 AK를 든 걸로 보임", rb.has_ak, "")

	# ── 시간이 다 되면 방장이 끝냄 ──
	na.rem = 0.5
	var ended: bool = await wait_until(func(): return A.state == "ended" and B.state == "ended", 120)
	check("시간 끝 → 둘 다 결과 화면", ended, "%s/%s" % [A.state, B.state])

	# ── 결과 화면에서 '한 판 더'를 눌러도 시작 안 됨 → 대기실에서 준비 → 다시 시작 ──
	A.start_match()
	B.start_match()
	await wait(10)
	check("결과 화면에서 바로 다음 판으로 안 감", A.state == "ended" and B.state == "ended", "%s/%s" % [A.state, B.state])
	check("친구대전 결과 화면: '한 판 더'·'병과 다시 고르기' 숨김, 카운트다운", not A.menu._end_again.visible and not B.menu._end_pick.visible
		and B.menu._end_count.visible and B.menu._end_mm.text == "방 나가기", B.menu._end_count.text)
	var back_lobby: bool = await wait_until(func(): return A.menu.cur_page == "lobby" and B.menu.cur_page == "lobby" and A.state == "menu" and B.state == "menu", 240)
	check("몇 초 뒤 둘 다 같은 방 대기실로 (연결 유지)", back_lobby and na.on and nb.on and na.remotes.size() == 1, "%s/%s" % [A.menu.cur_page, B.menu.cur_page])
	await wait_until(func(): return not na.lobby_list()[1].rdy, 60)
	check("대기실로 오면 준비가 풀림, 병과는 그대로", not na.can_start() and na.lobby_list()[1].cls == "crossbow" and nb.cls == "crossbow")
	await wait(30)
	check("대기실에서 저절로 시작하지 않음", A.state == "menu" and B.state == "menu")
	nb.ask("ready", true)
	await wait_until(func(): return na.can_start(), 60)
	A.menu.lobby_start.emit()
	await wait_until(func(): return A.state == "playing" and B.state == "playing", 60)
	check("다시 준비하면 둘째 판 시작", A.state == "playing" and B.state == "playing", "%s/%s" % [A.state, B.state])
	check("처치 수 0부터", pa.kills == 0 and pb.deaths == 0, "")

	# ── 친구 나가기 ── (방장 화면에 친구의 성수병·웅덩이가 남아 있는 채로 나감)
	rb = na.remotes.values()[0]
	A.combat.remote_fire(rb, "holy", HERE + Vector3(10, 2, -30), Vector3(0, 12, 0), 0.0)
	A.combat.shatter(rb, HERE + Vector3(10, 0, -34))
	B.go_menu("main")
	await wait_until(func(): return na.remotes.is_empty(), 120)
	await wait(3)
	var orphan := func(arr: Array) -> bool: return arr.any(func(x): return not is_instance_valid(x.owner))
	check("나간 친구의 투사체·웅덩이도 치움 (주인 없는 것이 남지 않음)", not orphan.call(A.combat.projectiles) and not orphan.call(A.combat.zones),
		"proj=%d zones=%d" % [A.combat.projectiles.size(), A.combat.zones.size()])
	check("친구가 나가면 메인 메뉴, 봇 돌아옴", not nb.on and B.state == "menu" and B.menu.cur_page == "main" and B.combat.ents.size() == 8, "ents=%d" % B.combat.ents.size())
	check("방장 쪽에서 친구가 사라짐", na.remotes.is_empty() and na.lobby_list().size() == 1, "")

	# ── 방장이 방을 닫으면 친구는 쫓겨남 ──
	nb.join_room("친구", "archer", na.code)
	await wait_until(func(): return nb.on and na.remotes.size() == 1, 600)
	check("다시 들어감 (새 번호)", nb.on and na.remotes.size() == 1 and nb.me_id() == 3, "id=%d" % nb.me_id())
	na.leave()
	var kicked: bool = await wait_until(func(): return not nb.on, 300)
	check("방장이 나가면 친구도 방에서 나옴", kicked and B.state == "menu" and B.menu.cur_page == "main", B.menu.cur_page)
	check("방장도 봇이 돌아옴", not na.on and A.combat.ents.size() == 8, "ents=%d" % A.combat.ents.size())
	await wait(5)
	check("방이 닫히면 신호 채널에 아무도 없음", S.joined_count() == 0, "n=%d" % S.joined_count())
	print("신호 중계 %d개" % S.sent)
	S.stop()

	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
