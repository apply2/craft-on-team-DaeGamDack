extends SceneTree
## 흡혈귀 자동 테스트 — 사용자 요청 새 병과. 수치는 GameData.CLASSES.vampire·WEAPONS.teeth·WEAPONS.bat·BURN
## 실행: godot --headless --fixed-fps 60 --path . -s tests/test_vampire.gd
## 통과하면 "ALL PASS"와 종료 코드 0, 실패하면 FAIL 줄과 종료 코드 1.

var main: Node
var G: Node
var C
var p      # 나 (흡혈귀)
var dm     # 과녁 (봇, 가만히)
var d2     # 두 번째 과녁
var fails := 0
var kills: Array = []
var nums: Array = []

const IDLE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false}
const BITE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false, "fire": true}
const DASH := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false, "aim": true}
const HOME := Vector3(-25, 0, 18)
const OPEN := Vector3(0, 0, 21)   # 돌진 시험: 앞(-Z)으로 9m 넘게 트인 곳
const DT := 1.0 / 60.0


func _initialize() -> void:
	var G0 = root.get_node("GameData")
	G0.save_enabled = false
	G0.hitstop_enabled = false
	G0.land_trip_override = 0.0
	G0.third_person = false
	G0.difficulty = "normal"
	G0.chosen_cls = "vampire"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.start_match.call_deferred()
	root.get_node("GameData").ai_enabled = false
	_run()


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func check(name: String, ok: bool, detail := "") -> void:
	print(("PASS " if ok else "FAIL ") + name + "  " + detail)
	if not ok:
		fails += 1


func near(a: float, b: float, eps := 0.05) -> bool:
	return absf(a - b) < eps


func put(e, pos: Vector3, cls := "archer", yaw := 0.0) -> void:
	e.next_cls = cls
	e.spawn_at(pos)
	e.invuln = 0.0
	e.scripted_input = IDLE
	e.yaw = yaw
	e.pitch = 0.0
	e.velocity = Vector3.ZERO


## 흡혈귀를 HOME에 세우고 화상은 끔 (물기·돌진만 볼 때)
func vamp(hp := 120.0) -> void:
	put(p, HOME, "vampire", 0.0)  # yaw 0 = -Z를 봄
	p.burn_wait = 999.0
	p.hp = hp


func press(inp: Dictionary, n := 2) -> void:
	p.scripted_input = inp
	await wait(n)
	p.scripted_input = IDLE


func wall(c: Vector3, s: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = s
	cs.shape = bs
	b.add_child(cs)
	root.add_child(b)
	b.global_position = c
	return b


func _run() -> void:
	await wait(3)
	G = root.get_node("GameData")
	C = main.get_node("Combat")
	p = main.get_node("Player")
	C.killed.connect(func(v, a, kind, _h): kills.append([v, a, kind]))
	C.num.connect(func(_pos, text, style): nums.append([text, style]))
	var bots: Array = C.ents.filter(func(e): return e.is_bot)
	dm = bots[0]
	d2 = bots[1]
	for i in range(2, bots.size()):
		put(bots[i], Vector3(30, 0, -30 + i * 3))
	put(dm, Vector3(-25, 0, 40))
	put(d2, Vector3(-20, 0, 40))
	var TW: Dictionary = G.WEAPONS.teeth
	var BW: Dictionary = G.WEAPONS.bat
	var BU: Dictionary = G.BURN

	# ── 기본 스탯 ──
	put(p, HOME, "vampire", 0.0)
	await wait(2)
	check("흡혈귀: 체력 120 · 무기 틀니 · 모델에 틀니·망토", p.hp == 120.0 and p.wep == "teeth" and not p.model.jaws.is_empty() and p.model.cape != null, "hp=%.0f wep=%s" % [p.hp, p.wep])
	check("걷기 속도 = 5.4 × 1.25", near(p.max_speed(), G.BASE_SPEED * 1.25, 0.001), "%.3f" % p.max_speed())
	check("자연 회복 없음 (regen 0)", G.class_regen("vampire") == 0.0, "")
	check("병과 목록·봇 병과에 흡혈귀", G.CLASS_ORDER.has("vampire") and G.bot_classes().has("vampire"), "")
	check("친구대전 무기 번호에 틀니·박쥐·화상", main.get_node("Net").WEPS.has("teeth") and main.get_node("Net").WEPS.has("bat") and main.get_node("Net").WEPS.has("burn"), "")

	# ── 화상: 가만히 있으면 3초 뒤부터 타서 12초 뒤에 죽음 (총 15초) ──
	kills.clear()
	put(p, HOME, "vampire", 0.0)
	var k0: int = p.kills
	var f := 0
	var hp3 := -1.0
	var hp35 := -1.0
	var died_at := -1
	while f < 1000:
		await physics_frame
		f += 1
		if f == int(BU.grace / DT) - 2:
			hp3 = p.hp
		if f == int((BU.grace + 0.5) / DT) + 1:
			hp35 = p.hp
		if not p.alive:
			died_at = f
			break
	check("스폰 뒤 3초 동안은 안 탐", hp3 == 120.0, "%.1f" % hp3)
	check("그 뒤 0.25초마다 2.5씩 (0.5초 = 5)", near(hp35, 115.0, 0.01), "%.1f" % hp35)
	check("가만히 있으면 15초(3 + 12)에 죽음", absi(died_at - 900) <= 2, "%d프레임 (%.2f초)" % [died_at, died_at * DT])
	check("  아무도 안 때렸으면 자멸 (처치 +0, 킬피드 공격자 = 자기, 무기 burn)",
		kills.size() == 1 and kills[0][1] == p and kills[0][2] == "burn" and p.kills == k0, str(kills))
	await wait(200)  # 부활

	# ── 화상 사망 처치 인정: 5초 안에 때린 사람이 있으면 그 사람 ──
	kills.clear()
	put(dm, HOME + Vector3(0, 0, 6), "archer", PI)
	put(p, HOME, "vampire", 0.0)
	p.burn_wait = 0.0
	var dk0: int = dm.kills
	C.damage(p, dm, 10, "bow", false, Vector3(0, 0, -1))
	p.hp = 5.0  # 0.5초 안에 타 죽음
	await wait(40)
	check("때린 지 5초 안에 타 죽으면 마지막 공격자 처치", not p.alive and kills.size() == 1 and kills[0][1] == dm and kills[0][2] == "burn" and dm.kills == dk0 + 1,
		"%s kills %d→%d" % [str(kills), dk0, dm.kills])
	await wait(200)
	kills.clear()
	put(p, HOME, "vampire", 0.0)
	p.burn_wait = 0.0
	dk0 = dm.kills
	C.damage(p, dm, 10, "bow", false, Vector3(0, 0, -1))
	p.hp = 60.0  # 6초 뒤에 죽음 → 5초가 지남
	await wait(int(6.5 / DT))
	check("때린 지 5초가 지나서 타 죽으면 자멸", not p.alive and kills.size() == 1 and kills[0][1] == p and dm.kills == dk0, str(kills))
	await wait(200)

	# ── 물기 범위 (사용자 요청으로 넓힘): 3m 앞 적도 닿음, 조준점 고리 빨강 ──
	check("물기 범위 3.0m · 반각 40°", near(float(TW.range), 3.0, 0.001) and near(float(TW.half_angle), 40.0, 0.001), "")
	put(dm, HOME + Vector3(0, 0, -3.2), "archer", 0.0)
	vamp(60.0)
	await wait(3)
	await wait(2)
	check("범위 안 적이 있으면 조준점 고리가 빨갛게 꽉 차고 '물기!'", main.hud._ring._label == "물기!" and main.hud._ring._v >= 1.0, "%s %.2f" % [main.hud._ring._label, main.hud._ring._v])
	await press(BITE)
	check("3.2m 앞 적도 물림 (몸 겉면까지 3m)", near(dm.hp, 100.0 - float(TW.dmg), 0.01), "hp=%.1f" % dm.hp)
	check("  물면 부채꼴·유령 틀니가 보임", C.bite_fx.count() >= 2, "%d" % C.bite_fx.count())
	await wait(30)
	check("  잠깐 뒤 사라짐", C.bite_fx.count() == 0, "%d" % C.bite_fx.count())
	put(dm, HOME + Vector3(1.6, 0, -2.0), "archer", 0.0)  # 옆 39°
	vamp(60.0)
	await wait(3)
	await press(BITE)
	check("옆 39°도 원뿔 안", dm.hp < 100.0, "hp=%.1f" % dm.hp)
	vamp(60.0)
	put(dm, Vector3(-20, 0, 40))
	await wait(40)
	await press(BITE)
	check("허공을 물어도 효과는 보임 (범위 끝에 옅은 틀니)", C.bite_fx.count() >= 2, "%d" % C.bite_fx.count())
	await wait(40)

	# ── 물기: 앞 1.5m, 28 피해 + 15 회복, 최대 체력은 안 넘음 ──
	put(dm, HOME + Vector3(0, 0, -1.5), "archer", 0.0)
	vamp(60.0)
	await wait(3)
	nums.clear()
	await press(BITE)
	check("앞 1.5m 적을 물면 28 피해", near(dm.hp, 100.0 - float(TW.dmg), 0.01), "hp=%.1f" % dm.hp)
	check("  물면 15 회복", near(p.hp, 60.0 + float(TW.heal), 0.01), "hp=%.1f" % p.hp)
	check("  머리 위 초록 +15", nums.any(func(n): return n[0] == "+15" and n[1] == "heal"), str(nums))
	await wait(40)
	put(dm, HOME + Vector3(0, 0, -1.5), "archer", 0.0)
	vamp(118.0)
	await wait(3)
	await press(BITE)
	check("회복해도 120을 안 넘음", p.hp == 120.0, "hp=%.1f" % p.hp)
	await wait(40)
	# 0.5초 간격: 0.67초 동안 누르면 두 번
	put(dm, HOME + Vector3(0, 0, -1.4), "crossbow", 0.0)
	vamp(30.0)
	await wait(3)
	await press(BITE, 40)
	check("누르고 있으면 0.5초마다 (0.67초에 두 번)", near(dm.hp, 110.0 - 2 * float(TW.dmg), 0.01) and near(p.hp, 30.0 + 2 * float(TW.heal), 0.01), "적 %.0f 나 %.0f" % [dm.hp, p.hp])
	await wait(40)
	# 사거리 밖 (3.5m)·허공
	put(dm, HOME + Vector3(0, 0, -4.0), "archer", 0.0)
	vamp(60.0)
	await wait(3)
	await press(BITE)
	check("4m 밖은 안 닿음 (피해·회복 없음)", dm.hp == 100.0 and p.hp == 60.0, "적 %.0f 나 %.0f" % [dm.hp, p.hp])
	await wait(40)
	# 옆으로 크게 벗어남 (원뿔 밖)
	put(dm, HOME + Vector3(1.8, 0, -0.6), "archer", 0.0)
	vamp(60.0)
	await wait(3)
	await press(BITE)
	check("옆 70° 쪽은 원뿔 밖", dm.hp == 100.0, "적 %.0f" % dm.hp)
	await wait(40)
	# 한 번에 한 명: 앞에 둘이면 가까운 쪽만
	put(dm, HOME + Vector3(0.3, 0, -1.2), "archer", 0.0)
	put(d2, HOME + Vector3(-0.3, 0, -2.0), "archer", 0.0)
	vamp(60.0)
	await wait(3)
	await press(BITE)
	check("한 번에 한 명 (가까운 쪽)", dm.hp < 100.0 and d2.hp == 100.0 and near(p.hp, 75.0, 0.01), "가까운 %.0f 먼 %.0f 나 %.0f" % [dm.hp, d2.hp, p.hp])
	put(d2, Vector3(-20, 0, 40))
	await wait(40)
	# 벽 너머
	put(dm, HOME + Vector3(0, 0, -1.9), "archer", 0.0)
	vamp(60.0)
	var wl := wall(HOME + Vector3(0, 1.5, -1.0), Vector3(4, 3, 0.2))
	await wait(3)
	await press(BITE)
	check("벽 너머는 못 묾", dm.hp == 100.0 and p.hp == 60.0, "적 %.0f 나 %.0f" % [dm.hp, p.hp])
	wl.queue_free()
	await wait(40)
	# 아군 (쟁탈전 같은 팀): 피해·회복 없음
	put(dm, HOME + Vector3(0, 0, -1.5), "archer", 0.0)
	vamp(60.0)
	dm.team = "blue"
	p.team = "blue"
	await wait(3)
	await press(BITE)
	check("같은 팀은 안 물림 (회복도 없음)", dm.hp == 100.0 and p.hp == 60.0, "적 %.0f 나 %.0f" % [dm.hp, p.hp])
	dm.team = ""
	p.team = ""
	await wait(40)
	# 스폰 무적인 적: 피해가 막히니 회복도 없음
	put(dm, HOME + Vector3(0, 0, -1.5), "archer", 0.0)
	dm.invuln = 1.0
	vamp(60.0)
	await wait(3)
	await press(BITE)
	check("무적인 적을 물면 회복 없음", dm.hp == 100.0 and p.hp == 60.0, "적 %.0f 나 %.0f" % [dm.hp, p.hp])
	dm.invuln = 0.0
	await wait(40)

	# ── 박쥐 돌진: 9m / 0.3초, 첫 적에게 20 + 멈춤 + 15 회복 + 물기 재사용 초기화, 재사용 7초 ──
	put(dm, Vector3(30, 0, -60))
	vamp(60.0)
	p.global_position = OPEN
	await wait(5)
	var z0: float = p.global_position.z
	await press(DASH)
	check("우클릭하면 돌진 시작 · 재사용 7초", p.dash_t > 0 and near(p.bat_cd, float(BW.cd), 0.05), "dash_t %.2f cd %.2f" % [p.dash_t, p.bat_cd])
	await wait(int(float(BW.time) / DT) + 2)
	var trav: float = z0 - p.global_position.z
	check("돌진 거리 약 9m (0.3초)", near(trav, float(BW.dist), 0.5) and p.dash_t <= 0, "%.2fm" % trav)
	check("  끝나면 걷기 속도 이하로", Vector2(p.velocity.x, p.velocity.z).length() <= p.max_speed() + 0.01, "%.2f" % Vector2(p.velocity.x, p.velocity.z).length())
	await press(DASH)
	check("재사용 중엔 다시 안 됨", p.dash_t <= 0, "")
	await wait(30)
	# 위아래 ±20°로 자름
	vamp(60.0)
	p.pitch = 1.2
	await wait(2)
	await press(DASH)
	check("위로 보고 돌진해도 20°까지만", near(p.dash_dir.y, sin(deg_to_rad(float(BW.pitch_max))), 0.01), "dir %s" % p.dash_dir)
	await wait(60)
	# 적중
	put(dm, OPEN + Vector3(0, 0, -6.0), "crossbow", 0.0)
	vamp(60.0)
	p.global_position = OPEN
	p.cd = 0.4
	await wait(3)
	nums.clear()
	p.scripted_input = DASH
	var gap := 99.0
	for i in 24:
		await physics_frame
		if i == 1:
			p.scripted_input = IDLE
		if dm.hp < 110.0 and gap > 50.0:  # 부딪힌 그 프레임
			gap = Vector2(p.global_position.x - dm.global_position.x, p.global_position.z - dm.global_position.z).length()
	check("돌진하다 적에게 부딪히면 20 피해", near(dm.hp, 110.0 - float(BW.dmg), 0.01), "hp %.0f" % dm.hp)
	check("  그 자리에서 멈춤 (적을 지나치지 않음)", p.dash_t <= 0 and gap < 1.3 and p.global_position.z > dm.global_position.z, "부딪힌 순간 거리 %.2f" % gap)
	check("  물기 1회로 쳐서 15 회복 + 물기 재사용 초기화", near(p.hp, 75.0, 0.01) and p.cd <= 0.0, "hp %.0f cd %.2f" % [p.hp, p.cd])
	await wait(40)
	# 돌진 중엔 물지 못함
	put(dm, Vector3(30, 0, -60))
	vamp(60.0)
	await wait(3)
	p.scripted_input = {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false, "aim": true, "fire": true}
	await wait(2)
	var cd_dash: float = p.cd
	await wait(8)
	p.scripted_input = IDLE
	check("돌진 중엔 공격 못 함", cd_dash <= 0.0 and p.cd <= 0.0, "cd %.2f" % p.cd)
	await wait(30)
	# 벽에 막히면 바로 멈춤
	vamp(60.0)
	wl = wall(HOME + Vector3(0, 1.5, -2.0), Vector3(4, 3, 0.4))
	await wait(3)
	await press(DASH)
	await wait(6)
	check("벽에 부딪히면 돌진 끝", p.dash_t <= 0 and p.global_position.z > HOME.z - 2.0, "z %.2f" % (p.global_position.z - HOME.z))
	wl.queue_free()
	await wait(30)

	# ── 체력 40 이하면 내 화면에 타는 비네트 ──
	vamp(30.0)
	await wait(30)
	check("체력 40 이하면 화면 가장자리 타는 비네트", main.hud._burn.visible, "")
	p.hp = 100.0
	await wait(40)
	check("  체력이 오르면 사라짐", not main.hud._burn.visible, "")
	# 몸에서 불꽃·연기 (3인칭이면 내 것도)
	G.third_person = true
	await wait(20)
	check("몸에서 불꽃·연기가 남", C.burn_fx.count() > 5, "%d" % C.burn_fx.count())
	G.third_person = false

	# ── 봇 흡혈귀: 가까우면 물고, 조금 떨어지면 돌진 ──
	var it = C.items  # 특수 아이템·닭은 치움 (봇이 줍거나 닭을 쫓으러 가지 않게)
	it.clear()
	for c in it.chickens:
		(c.body as Node).queue_free()
	it.chickens.clear()
	it.chicken_timer = 9999.0
	it.sniper_timer = 9999.0
	it.ak_timer = 9999.0
	it.horse_timer = 9999.0
	it.fish_timer = 9999.0
	G.ai_enabled = true
	put(dm, HOME, "vampire", 0.0)
	dm.burn_wait = 999.0
	dm.scripted_input = {}
	put(dm, OPEN, "vampire", 0.0)   # 돌진 시험에서 앞이 트인 걸 확인한 줄 (z 21 → 11.5)
	dm.burn_wait = 999.0
	dm.scripted_input = {}
	put(p, OPEN + Vector3(0, 0, -9.5), "archer", 0.0)
	await physics_frame
	dm.ai.target = p   # 반응 시간 없이 바로 (가만히 있는 과녁이라 걸어가는 동안 돌진 거리를 지나칠 수 있음)
	dm.ai.react = 0.0
	dm.ai.vis = true  # 반응 시간(1초 안팎) 동안 다가와도 돌진 거리(3.5~8.5m)에 남게
	p.burn_wait = 999.0
	var dashed := false
	var bit := false
	var hp0: float = p.hp
	for i in 360:
		await physics_frame
		p.invuln = 0.0
		if dm.dash_t > 0:
			dashed = true
		if p.hp < hp0 - 0.1:
			bit = true
	G.ai_enabled = false
	dm.scripted_input = IDLE
	check("봇 흡혈귀가 돌진함", dashed, "")
	check("봇 흡혈귀가 물어서 피해를 줌", bit, "hp %.0f" % p.hp)

	print("ALL PASS" if fails == 0 else "FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
