extends SceneTree
## 포병(대포) 자동 테스트 — 사용자 요청 새 병과. 수치는 GameData.CLASSES.cannoneer·WEAPONS.cannon
## 실행: godot --headless --fixed-fps 60 --path . -s tests/test_cannon.gd
## 통과하면 "ALL PASS"와 종료 코드 0, 실패하면 FAIL 줄과 종료 코드 1.

var main: Node
var G: Node
var C
var p      # 나 (포병)
var dm     # 과녁 (봇, 가만히)
var fails := 0
var new_shots: Array = []
var kills: Array = []

const IDLE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false}
const FIRE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false, "fire": true}
const SHOOTER := Vector3(-25, 0, 18)
const WEST_YAW := PI / 2    # aim_dir = (-1, 0, 0)
const DT := 1.0 / 60.0


func _initialize() -> void:
	var G0 = root.get_node("GameData")
	G0.save_enabled = false
	G0.hitstop_enabled = false
	G0.land_trip_override = 0.0
	G0.third_person = false
	G0.difficulty = "normal"
	G0.chosen_cls = "archer"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.start_match.call_deferred()
	root.get_node("GameData").ai_enabled = false
	_run()


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func check(name: String, ok: bool, detail: String) -> void:
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


func hold(n: int, inp := FIRE) -> void:
	new_shots.clear()
	var prev: Array = C.projectiles.duplicate()
	p.scripted_input = inp
	for i in n:
		await physics_frame
		for pr in C.projectiles:
			if not prev.has(pr):
				new_shots.append(pr)
		prev = C.projectiles.duplicate()
	p.scripted_input = IDLE


## 공격을 누르고 있다가 포탄이 나간 물리 프레임에 속도가 얼마나 바뀌었나 (그 프레임 이동 + 발사 반동)
func shot_dv() -> Vector3:
	p.scripted_input = FIRE
	var prev: Vector3 = p.velocity
	for i in 10:
		await physics_frame
		if p.cn_t > 0:
			p.scripted_input = IDLE
			return p.velocity - prev
		prev = p.velocity
	p.scripted_input = IDLE
	return Vector3(999, 999, 999)


## 시험용 벽 (월드 층 1): 가운데 c, 크기 s
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
	var bots: Array = C.ents.filter(func(e): return e.is_bot)
	dm = bots[0]
	for i in range(1, bots.size()):
		put(bots[i], Vector3(30, 0, -30 + i * 3))
	put(p, SHOOTER, "cannoneer", WEST_YAW)
	put(dm, Vector3(-25, 0, 40))
	await wait(5)
	var W: Dictionary = G.WEAPONS.cannon
	var K: Dictionary = G.CLASSES.cannoneer

	# ── 기본 스탯 ──
	check("포병: 체력 130 · 무기 대포 · 모델에 포가", p.hp == 130.0 and p.wep == "cannon" and p.model.carriage != null and p.model.wheels.size() == 2,
		"hp=%.0f wep=%s" % [p.hp, p.wep])
	check("몸 판정 1.4배", near(p.body_r(), G.BODY_R * 1.4, 0.001), "r=%.3f" % p.body_r())
	check("걷기 속도 = 5.4 × 0.7 (사용자 요청 0.65 → 0.7)", near(p.max_speed(), G.BASE_SPEED * 0.7, 0.001), "%.3f" % p.max_speed())
	p.scripted_input = {"f": 1.0, "r": 0.0, "jump": false, "crouch": false, "sprint": true}
	await wait(30)
	check("달리기 안 됨 (Shift를 눌러도)", not p.sprinting and Vector2(p.velocity.x, p.velocity.z).length() <= G.BASE_SPEED * 0.7 + 0.01,
		"sprinting=%s v=%.2f" % [p.sprinting, Vector2(p.velocity.x, p.velocity.z).length()])
	p.scripted_input = IDLE
	await wait(40)
	# 가속이 느림: 0.1초 뒤 속도가 궁수보다 느림
	put(p, SHOOTER, "cannoneer", WEST_YAW)
	p.scripted_input = {"f": 1.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false}
	await wait(6)
	var v_slow: float = Vector2(p.velocity.x, p.velocity.z).length() / p.max_speed()
	put(p, SHOOTER, "archer", WEST_YAW)
	p.scripted_input = {"f": 1.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false}
	await wait(6)
	var v_fast: float = Vector2(p.velocity.x, p.velocity.z).length() / p.max_speed()
	check("가속이 느림 (0.1초 뒤 최고 속도 대비)", v_slow < v_fast - 0.15, "포병 %.2f 궁수 %.2f" % [v_slow, v_fast])
	# 점프 높이 0.4배 → 점프 속도 8 × √0.4
	put(p, SHOOTER, "cannoneer", WEST_YAW)
	await wait(10)
	p.scripted_input = {"f": 0.0, "r": 0.0, "jump": true, "crouch": false, "sprint": false}
	var vy := 0.0
	for i in 4:
		await physics_frame
		vy = maxf(vy, p.velocity.y)
	p.scripted_input = IDLE
	check("점프 속도 = 8 × √0.4 (높이 0.4배)", near(vy, G.JUMP_V * sqrt(0.4), 0.45), "vy=%.2f 기대 %.2f" % [vy, G.JUMP_V * sqrt(0.4)])
	await wait(60)

	# ── 쏘기 · 4초 재장전 (사용자 요청 5 → 4) ──
	put(p, SHOOTER, "cannoneer", WEST_YAW)
	put(dm, Vector3(-25, 0, 40))
	await wait(5)
	await hold(2)
	check("한 발 나감, 속도 32", new_shots.size() == 1 and near((new_shots[0].vel as Vector3).length(), 32.0, 0.3) if new_shots.size() == 1 else false,
		"n=%d" % new_shots.size())
	check("쏘면 재장전 4초", near(p.cn_t, 4.0, 0.05), "cn_t=%.2f" % p.cn_t)
	await hold(int(3.8 / DT))
	check("3.8초 동안 누르고 있어도 안 나감", new_shots.is_empty(), "n=%d" % new_shots.size())
	await hold(int(0.4 / DT))
	check("4초가 지나면 다시 나감 (누르고 있으면 장전되는 대로)", new_shots.size() == 1, "n=%d cn_t=%.2f" % [new_shots.size(), p.cn_t])
	await wait(int(4.0 / DT))
	C.projectiles.clear()

	# ── 포탄 점프: 발밑에 쏘면 피해 1/3, 높이 뜸 ──
	put(p, SHOOTER, "cannoneer", WEST_YAW)
	await wait(5)
	p.pitch = -PI / 2 + 0.05
	var y0: float = p.global_position.y
	await hold(2)
	var top := y0
	var vmax := 0.0
	var air_seen := false
	for i in 220:  # 22m/s·중력 0.75배 → 약 2.7초 떠 있음
		await physics_frame
		top = maxf(top, p.global_position.y)
		vmax = maxf(vmax, p.velocity.y)
		air_seen = air_seen or p.blast_air
	var lost: float = 130.0 - p.hp
	check("발밑 사격: 자기 피해 약 27 (80 × 1/3)", near(lost, 80.0 / 3.0, 3.0), "잃은 체력 %.1f" % lost)
	check("위로 22m/s 튕김", near(vmax, 22.0, 0.6), "최고 vy %.1f" % vmax)
	check("높이 뜸 (일반 점프 1.45m의 4배 이상)", top - y0 > 6.0, "높이 %.1fm" % (top - y0))
	check("떠 있는 동안 공중 조작 제한 (blast_air), 착지하면 풀림", air_seen and not p.blast_air and p.grounded, "")
	check("내 포탄에 내가 맞아도 처치 아님", kills.is_empty() and p.kills == 0, "")
	p.pitch = 0.0
	await wait(10)

	# ── 직격 = 100 (범위 피해를 따로 더하지 않음) ──
	put(p, SHOOTER, "cannoneer", WEST_YAW)
	put(dm, SHOOTER + Vector3(-7, 0, 0), "cannoneer")
	await wait(5)
	await hold(2)
	await wait(40)
	check("직격하면 100 (130 → 30)", near(dm.hp, 30.0, 0.01), "dm hp=%.1f" % dm.hp)
	check("직격당하면 뒤로 밀림", dm.velocity.x < -1.0 or dm.global_position.x < SHOOTER.x - 7.2, "vx=%.2f x=%.2f" % [dm.velocity.x, dm.global_position.x])

	# ── 범위 피해: 거리에 따라 80 → 25, 반경 밖 0 ──
	check("폭발 반경 2.5m: 중심 80, 가장자리 25, 밖 0", near(C.cannon.blast_dmg(0.0), 80.0) and near(C.cannon.blast_dmg(2.5), 25.0) and C.cannon.blast_dmg(2.6) == 0.0
		and near(C.cannon.blast_dmg(1.25), 52.5) and C.cannon.blast_dmg(3.0) == 0.0, "")
	var spot := Vector3(-25, 0, 30)
	put(p, SHOOTER, "cannoneer", WEST_YAW)
	for d in [0.0, 1.0, 2.0, 3.0]:
		put(dm, spot, "cannoneer")
		await wait(3)
		var pt: Vector3 = spot + Vector3(0, 0.5, 0) + Vector3(1, 0, 0) * (dm.body_r() + d)
		var exp_d: float = C.cannon.reach(pt, dm).d
		var hp0: float = dm.hp
		C.cannon.explode(p, pt)
		await physics_frame
		var got: float = hp0 - dm.hp
		check("범위 피해 몸까지 %.1fm" % d, near(got, C.cannon.blast_dmg(exp_d), 0.5), "받은 %.1f 기대 %.1f" % [got, C.cannon.blast_dmg(exp_d)])
		if d < 1.8:  # 가장자리는 넉백 배율(1 - 거리/반경)이 거의 0
			check("  폭발 반대쪽으로 날아감 (%.1fm)" % d, dm.velocity.x < -0.5 and dm.velocity.y > 0.5, "v=%s" % dm.velocity)
	var kb_near := 0.0
	var kb_far := 0.0
	for d in [0.3, 1.9]:
		put(dm, spot, "cannoneer")
		await wait(3)
		C.cannon.explode(p, spot + Vector3(0, 0.5, 0) + Vector3(1, 0, 0) * (dm.body_r() + d))
		if d < 1.0:
			kb_near = -dm.velocity.x
		else:
			kb_far = -dm.velocity.x
	check("넉백은 멀수록 약함", kb_near > kb_far * 2.0, "가까이 %.2f 멀리 %.2f" % [kb_near, kb_far])

	# ── 벽 뒤엔 범위 피해 없음 ──
	put(dm, spot, "cannoneer")
	var wl := wall(spot + Vector3(1.6, 1.5, 0), Vector3(0.6, 3.0, 6.0))
	await wait(3)
	var hpw: float = dm.hp
	C.cannon.explode(p, spot + Vector3(2.6, 0.5, 0))
	await physics_frame
	check("벽 뒤 2.6m 폭발: 피해 없음", dm.hp == hpw, "hp %.1f → %.1f" % [hpw, dm.hp])
	wl.queue_free()
	await wait(2)
	C.cannon.explode(p, spot + Vector3(2.6, 0.5, 0))
	await physics_frame
	check("벽을 치우면 같은 폭발에 맞음", dm.hp < hpw - 20.0, "hp %.1f → %.1f" % [hpw, dm.hp])

	# ── 쟁탈전 같은 팀: 아군은 안 맞고, 나는 맞음 (포탄 점프) ──
	put(dm, spot, "cannoneer")
	put(p, spot + Vector3(0, 0, 2.0), "cannoneer", WEST_YAW)
	p.team = "blue"
	dm.team = "blue"
	await wait(3)
	C.cannon.explode(p, spot + Vector3(0, 0.3, 1.0))
	await physics_frame
	check("같은 팀은 범위 피해 없음", dm.hp == 130.0, "dm hp=%.1f" % dm.hp)
	check("같은 팀이어도 내 포탄 피해는 받음", p.hp < 130.0, "my hp=%.1f" % p.hp)
	p.team = ""
	dm.team = ""
	await wait(80)

	# ── 자멸: 자기 포탄으로 죽으면 처치 없음 ──
	put(p, SHOOTER, "cannoneer", WEST_YAW)
	await wait(5)
	kills.clear()
	p.hp = 10.0
	C.cannon.explode(p, p.global_position + Vector3(0, 0.2, 0))
	await physics_frame
	check("자기 포탄으로 죽음 = 자멸 (공격자 = 자기, 처치 +0)", not p.alive and kills.size() == 1 and kills[0][1] == p and kills[0][2] == "cannon" and p.kills == 0,
		"alive=%s kills=%d" % [p.alive, kills.size()])
	await wait(int(3.2 / DT))

	# ── 판정 1.4배: 몸 가운데에서 0.55m 옆을 지나는 선이 포병엔 맞고 궁수엔 안 맞음 ──
	put(dm, spot, "cannoneer")
	await wait(2)
	var o: Vector3 = dm.global_position + Vector3(0.55, 0.8, -3)
	var hc: Dictionary = C.hit_test(o, Vector3(0, 0, 6), dm, 0.0)
	put(dm, spot, "archer")
	await wait(2)
	var ha: Dictionary = C.hit_test(dm.global_position + Vector3(0.55, 0.8, -3), Vector3(0, 0, 6), dm, 0.0)
	check("넓은 몸 판정: 0.55m 옆 — 포병 맞음, 궁수 안 맞음", not hc.is_empty() and ha.is_empty(), "포병=%s 궁수=%s" % [hc, ha])

	# ── 우클릭 탄도 조준: 궤적 점·착탄 고리, 확대, 느려짐 ──
	if not p.alive:
		put(p, SHOOTER, "cannoneer", WEST_YAW)
	put(p, SHOOTER, "cannoneer", WEST_YAW)
	p.pitch = 0.2
	p.scripted_input = {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false, "aim": true}
	await wait(30)
	await process_frame
	check("우클릭: 예상 궤적 점 + 착탄 고리(반경 2.5)", C.cannon._dots.multimesh.visible_instance_count > 5 and C.cannon._ring.visible and near(C.cannon._ring.scale.x, 2.5),
		"점=%d" % C.cannon._dots.multimesh.visible_instance_count)
	check("우클릭: 1.3배 확대 (시야 85 → 65.4)", near(p.cam.fov, 85.0 / 1.3, 1.5), "fov=%.1f" % p.cam.fov)
	check("우클릭: 이동 속도 ×0.7", near(p.max_speed(), G.BASE_SPEED * 0.7 * 0.7, 0.001), "%.3f" % p.max_speed())
	p.scripted_input = IDLE
	await wait(2)
	await process_frame
	check("우클릭을 떼면 궤적이 사라짐", C.cannon._dots.multimesh.visible_instance_count == 0 and not C.cannon._ring.visible, "")
	p.pitch = 0.0

	# ── 공중에서 5초 지나면 터짐 (사용자 요청 4 → 5) ──
	C.projectiles.clear()
	put(p, Vector3(0, 0, 0), "cannoneer", WEST_YAW)
	await wait(3)
	p.pitch = 1.3  # 거의 위로
	p.cn_t = 0.0
	await hold(2)
	var shot = new_shots[0] if new_shots.size() == 1 else null
	check("포탄 수명 = 5초 (fuse)", shot != null and near(float(shot.life), 5.0, 0.05), "life=%s" % (shot.life if shot else "-"))
	await wait(20)  # 올라가는 중 (땅에서 멀리)
	var hp_me: float = p.hp
	if shot and C.projectiles.has(shot):
		shot.life = 0.001  # 5초가 다 됐다고 치고
		var air_y: float = (shot.pos as Vector3).y
		await physics_frame
		check("시간이 다 되면 공중에서 터짐 (사라짐, 높이 %.1fm)" % air_y, not C.projectiles.has(shot) and air_y > 3.0, "")
		check("  하늘에서 터지면 아래에 있는 나는 안 맞음", p.hp == hp_me, "hp %.1f → %.1f" % [hp_me, p.hp])
	else:
		check("올라가는 중인 포탄", false, "벌써 사라짐")
	p.pitch = 0.0


	# ── 조준선 착탄 지점 = 실제 폭발 자리 (속도 32 기준, 가까운 땅·먼 곳) ──
	for b in C.ents:
		if b != p:
			put(b, Vector3(30, 0, -60 + randf() * 3))  # 궤적에서 치움
	for cs in [[Vector3(-25, 0, 18), PI / 2, -0.12, "가까운 땅"], [Vector3(-25, 0, 18), PI / 2, 0.25, "먼 곳"], [Vector3(0, 0, 0), 0.0, 0.05, "북쪽"]]:
		var at: Vector3 = cs[0]
		put(p, at, "cannoneer", float(cs[1]))
		p.cn_t = 0.0
		p.pitch = float(cs[2])
		p.scripted_input = {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false, "aim": true}
		await wait(20)
		await process_frame
		var aim: Variant = C.cannon.aim_hit
		C.cannon.last_blast = Vector3.INF
		p.scripted_input = {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false, "aim": true, "fire": true}
		await wait(2)
		p.scripted_input = IDLE
		var t := 0
		while C.cannon.last_blast == Vector3.INF and t < 400:
			await physics_frame
			t += 1
		var lb: Vector3 = C.cannon.last_blast
		var ad := 999.0
		var dist := 0.0
		if aim != null and lb != Vector3.INF:
			ad = (aim as Vector3).distance_to(lb)
			dist = Vector2(lb.x - at.x, lb.z - at.z).length()
		check("조준선 착탄 = 실제 폭발 (%s, %.0fm)" % [cs[3], dist], ad < 0.35, "차이 %.2fm 조준 %s 폭발 %s" % [ad, aim, lb])
	p.pitch = 0.0
	await wait(10)
	# 최대 사거리: 26 → 32m/s면 (32/26)² ≈ 1.5배 (평지 이론값)
	var g := float(W.grav)
	var r32: float = float(W.speed) * float(W.speed) / g
	var r26: float = 26.0 * 26.0 / g
	check("최대 사거리 약 1.5배 (%.0fm → %.0fm)" % [r26, r32], near(r32 / r26, 1.515, 0.02), "")

	# ── 둔화 50%만 받음 (사용자 요청 — 면역에서 바꿈): 성수 웅덩이에서 다른 병과보다 덜 느려짐 ──
	var toasts: Array = []
	C.toast.connect(func(tx): toasts.append(tx))
	var open := Vector3(-25, 0, 18)
	var holy_keep := float(G.WEAPONS.holy.slow)            # 성수: 속도 ×0.35 (65% 깎음)
	var cn_keep := 1.0 - (1.0 - holy_keep) * 0.5           # 포병: 32.5%만 깎음 → ×0.675
	put(dm, open + Vector3(0, 0, 30), "cleric")
	# 포병: 웅덩이 위 최고 속도 / 평소 최고 속도
	put(p, open, "cannoneer", WEST_YAW)
	await wait(5)
	var cn_full: float = p.max_speed()
	C.shatter(dm, p.global_position)
	await wait(12)
	var cn_ratio: float = p.max_speed() / cn_full
	check("  (포병이 웅덩이 안에서 둔화에 걸림)", p.slow_t > 0, "")
	check("포병: 성수 둔화를 절반만 (65%% → 32.5%%, 속도 ×%.3f)" % cn_keep, near(cn_ratio, cn_keep, 0.001), "×%.3f" % cn_ratio)
	check("  웅덩이 피해는 그대로 받음", p.hp < 130.0, "hp=%.0f" % p.hp)
	check("  '면역' 표시는 없음", not toasts.has("둔화 면역"), "%s" % [toasts])
	# 실제로 걸어 보기: 웅덩이를 계속 발밑에 두고 1.5초 걸은 거리 (평소 대비)
	var walk := func(cls: String, puddle: bool) -> float:
		put(p, open, cls, WEST_YAW)
		C.zones.clear()
		await wait(5)
		var x_start: float = p.global_position.x
		p.scripted_input = {"f": 1.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false}
		for i in 90:
			if puddle and i % 20 == 0:
				C.zones.clear()
				C.shatter(dm, p.global_position)
			await physics_frame
		p.scripted_input = IDLE
		C.zones.clear()
		return absf(p.global_position.x - x_start)
	var cn_norm: float = await walk.call("cannoneer", false)
	var cn_slow: float = await walk.call("cannoneer", true)
	var ar_norm: float = await walk.call("archer", false)
	var ar_slow: float = await walk.call("archer", true)
	check("성수 위에서 포병이 궁수보다 덜 느려짐 (걸은 거리 비율)", cn_slow / cn_norm > ar_slow / ar_norm + 0.2,
		"포병 %.2f/%.2fm = %.0f%%, 궁수 %.2f/%.2fm = %.0f%%" % [cn_slow, cn_norm, cn_slow / cn_norm * 100, ar_slow, ar_norm, ar_slow / ar_norm * 100])
	# 비교: 궁수 최고 속도는 ×0.35
	put(p, open, "archer", WEST_YAW)
	await wait(3)
	var ar_full: float = p.max_speed()
	C.shatter(dm, p.global_position)
	await wait(12)
	check("  (비교) 궁수는 성수 둔화를 다 받음 (×%.2f)" % holy_keep, near(p.max_speed() / ar_full, holy_keep, 0.001), "×%.3f" % (p.max_speed() / ar_full))
	C.zones.clear()
	# 춤도 절반: ×0.6 → ×0.8. 겹치면 합친 둔화량에 0.5: ×0.35×0.6 = ×0.21 → ×0.605
	put(p, open, "cannoneer", WEST_YAW)
	await wait(3)
	var full2: float = p.max_speed()
	p.dance_t = 1.5
	var dance_keep := float(G.DANCE.speed)
	check("포병: 춤 둔화도 절반 (×%.2f → ×%.2f)" % [dance_keep, 1.0 - (1.0 - dance_keep) * 0.5], near(p.max_speed() / full2, 1.0 - (1.0 - dance_keep) * 0.5, 0.001), "×%.3f" % (p.max_speed() / full2))
	p.slow_t = 1.0
	var both := 1.0 - (1.0 - holy_keep * dance_keep) * 0.5
	check("포병: 성수 + 춤 겹치면 합친 둔화량의 절반 (×%.3f)" % both, near(p.max_speed() / full2, both, 0.001), "×%.3f" % (p.max_speed() / full2))
	p.dance_t = 0.0
	p.slow_t = 0.0
	C.zones.clear()
	await wait(5)

	# ── 넉백 속도는 둔화·이동속도의 영향을 안 받음 ──
	# 둔화된 궁수를 포탄으로 띄움 → 떠 있는 동안 수평 속도가 (둔화된 최고 속도 × 2.4)로 잘리지 않음
	put(dm, spot, "archer")
	await wait(3)
	dm.slow_t = 5.0
	var mx_slow: float = dm.max_speed()
	C.cannon.explode(p, spot + Vector3(0, 0.3, 0) + Vector3(1, 0, 0) * (dm.body_r() + 0.2))
	var h0 := Vector2(dm.velocity.x, dm.velocity.z).length()
	var air_frames := 0
	var hmin := 999.0
	for i in 40:
		await physics_frame
		dm.slow_t = 5.0
		if not dm.grounded:
			air_frames += 1
			hmin = minf(hmin, Vector2(dm.velocity.x, dm.velocity.z).length())
	check("둔화된 적의 넉백: 날아가는 동안 속도 안 잘림 (둔화 최고 속도×2.4 = %.1f)" % (mx_slow * 2.4),
		air_frames > 10 and h0 > mx_slow * 2.4 and hmin > mx_slow * 2.4, "처음 %.1f 공중 최저 %.1f 공중 %d프레임" % [h0, hmin, air_frames])
	# 포탄 점프: 둔화 상태값을 억지로 넣어도(포병은 원래 안 걸림) 그대로 높이·멀리 뜸
	put(p, SHOOTER, "cannoneer", WEST_YAW)
	await wait(5)
	p.slow_t = 5.0
	p.pitch = -PI / 2 + 0.05
	var y1: float = p.global_position.y
	await hold(2)
	var top2 := y1
	var hv := 0.0
	for i in 120:
		await physics_frame
		p.slow_t = 5.0
		top2 = maxf(top2, p.global_position.y)
		if p.blast_air:
			hv = maxf(hv, Vector2(p.velocity.x, p.velocity.z).length())
	check("발밑 사격: 반경 2.5m여도 포탄 점프 (6m 넘게 뜸)", top2 - y1 > 6.0, "높이 %.1fm" % (top2 - y1))
	check("  포탄 점프 수평 속도도 그대로", hv > 3.5, "수평 최고 %.1f" % hv)
	p.pitch = 0.0
	p.slow_t = 0.0
	await wait(10)


	# ── 포탄 점프 중력 ×0.75 (일반 점프·낙하는 그대로), 공중에서 또 포탄 점프하면 유지 ──
	put(p, SHOOTER, "cannoneer", WEST_YAW)
	await wait(10)
	var gk := float(W.air_grav)
	C.cannon.blast_jump(p, Vector3.ZERO)
	await physics_frame
	var vy_a: float = p.velocity.y
	await physics_frame
	var g_blast: float = (vy_a - p.velocity.y) / DT
	check("포탄 점프 중 중력 = 22 × 0.75 = 16.5", near(g_blast, G.GRAV * gk, 0.3), "%.2f" % g_blast)
	# 공중에서 다시 포탄 점프 (발밑에서 터짐) → 다시 22m/s, 중력 감소 그대로
	for i in 25:
		await physics_frame
	var was_air: bool = p.blast_air and not p.grounded
	C.cannon.explode(p, p.global_position + Vector3(0, 0.2, 0))
	await physics_frame
	var vy_b: float = p.velocity.y
	await physics_frame
	var g_blast2: float = (vy_b - p.velocity.y) / DT
	check("공중에서 또 포탄 점프: 다시 위로 + 중력 감소 유지", was_air and p.blast_air and vy_b > float(W.jump_up) - 1.0 and near(g_blast2, G.GRAV * gk, 0.3),
		"vy=%.1f g=%.2f" % [vy_b, g_blast2])
	var land_ok: bool = false
	for i in 400:
		await physics_frame
		if p.grounded and not p.blast_air:
			land_ok = true
			break
	check("  착지하면 중력 감소 풀림", land_ok, "")
	# 일반 점프는 원래 중력
	p.scripted_input = {"f": 0.0, "r": 0.0, "jump": true, "crouch": false, "sprint": false}
	await wait(3)
	p.scripted_input = IDLE
	var vy_c: float = p.velocity.y
	await physics_frame
	var g_norm: float = (vy_c - p.velocity.y) / DT
	check("일반 점프는 원래 중력 22", not p.blast_air and near(g_norm, G.GRAV, 0.3), "%.2f" % g_norm)
	await wait(60)
	# 그냥 떨어질 때도 원래 중력 (공중에 띄워 놓기)
	p.global_position += Vector3(0, 6, 0)
	p.velocity = Vector3.ZERO
	p.grounded = false
	await physics_frame
	var vy_d: float = p.velocity.y
	await physics_frame
	var g_fall: float = (vy_d - p.velocity.y) / DT
	check("그냥 떨어질 땐 원래 중력 22", near(g_fall, G.GRAV, 0.3), "%.2f" % g_fall)
	await wait(80)
	# 높이: 22² / (2 × 16.5) ≈ 14.7m
	put(p, SHOOTER, "cannoneer", WEST_YAW)
	await wait(5)
	var y2: float = p.global_position.y
	p.pitch = -PI / 2 + 0.05
	await hold(2)
	var top3 := y2
	for i in 200:
		await physics_frame
		top3 = maxf(top3, p.global_position.y)
	var expect_h: float = float(W.jump_up) * float(W.jump_up) / (2.0 * G.GRAV * gk)
	check("발밑 포탄 점프 높이 ≈ %.1fm (22m/s, 중력 0.75배)" % expect_h, near(top3 - y2, expect_h, 1.0), "높이 %.1fm" % (top3 - y2))
	p.pitch = 0.0
	await wait(20)

	# ── 맵 경계: 성벽 위로 날아 넘어가지 않음 (보이지 않는 벽·천장, 캐릭터만) ──
	var wb = C.world
	var A: float = wb.ARENA_HALF
	var ceil_y: float = float(G.MAP_BOUNDS.ceil)
	var hi := 0.0
	for bb: AABB in wb.aabbs:
		if absf(bb.get_center().x) < A - 1.5 and absf(bb.get_center().z) < A - 1.5:
			hi = maxf(hi, bb.end.y)
	check("천장(%.0fm)이 가장 높은 발판(%.1fm) + 포탄 점프 높이(%.1fm)보다 위" % [ceil_y, hi, expect_h], ceil_y > hi + expect_h + 2.0, "")
	check("경계가 있음 + 캐릭터 mask에 경계 층", wb.bounds != null and wb.bounds.is_inside_tree() and (p.collision_mask & wb.BOUND_LAYER) != 0
		and (dm.collision_mask & wb.BOUND_LAYER) != 0, "mask=%d" % p.collision_mask)
	for dirv: Vector3 in [Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0)]:
		put(p, -dirv * 0.0 + dirv * (A - 6.0), "cannoneer", atan2(-dirv.x, -dirv.z))
		await wait(3)
		p.velocity = dirv * 14.0 + Vector3(0, float(W.jump_up), 0)
		p.grounded = false
		p.blast_air = true
		p.scripted_input = {"f": 1.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false}
		var far := 0.0
		for i in 240:
			await physics_frame
			p.velocity += dirv * 0.3  # 계속 바깥으로 밀어 봄
			far = maxf(far, p.global_position.dot(dirv))
		p.scripted_input = IDLE
		check("성벽 쪽 %s로 날아가도 경계 안 (최대 %.1fm, 성벽 %.0fm)" % [dirv, far, A], far < A - 0.3, "")
	# 천장: 아주 세게 위로 쳐도 천장 아래
	put(p, Vector3(0, 0, 20), "cannoneer", WEST_YAW)
	await wait(3)
	p.velocity = Vector3(0, 60, 0)
	p.grounded = false
	p.blast_air = true
	var topc := 0.0
	for i in 200:
		await physics_frame
		topc = maxf(topc, p.global_position.y)
	check("위로 60m/s로 쳐도 천장(%.0fm) 아래" % ceil_y, topc < ceil_y, "최고 %.1fm" % topc)
	# 투사체는 경계에 안 막힘 (성벽 너머로 쏜 포탄이 허공에서 안 터짐)
	check("포탄·레이는 경계를 무시 (월드 레이가 경계 높이를 그냥 지나감)", C.world_ray(Vector3(A - 5, 20, 0), Vector3(10, 0, 0)) > 1.0, "")
	await wait(200)


	# ── 발사 반동: 조준 반대쪽 W.recoil m/s (사용자 요청 6 → 10 → 8), 땅이면 위로 +2 + 0.3초 미끄러짐, 세로 ±4로 자름, 공중도 같음 ──
	for b in C.ents:
		if b != p:
			put(b, Vector3(30, 0, -60 + randf() * 3))
	# 땅에서 수평으로 쏨 (서쪽을 봄 → 동쪽으로 밀림)
	put(p, SHOOTER, "cannoneer", WEST_YAW)
	await wait(10)
	p.cn_t = 0.0
	var x0: float = p.global_position.x
	var rv: Vector3 = await shot_dv()
	check("땅에서 쏘면 뒤로 약 %.0fm/s + 위로 2m/s" % float(W.recoil), rv.x > float(W.recoil) - 1.0 and rv.x < float(W.recoil) + 0.5 and near(rv.y, 2.0, 0.6), "반동 %s" % rv)
	check("  밀리는 0.3초 동안 마찰 감소 (recoil_t)", near(p.recoil_t, float(W.recoil_t), 0.05), "%.2f" % p.recoil_t)
	await wait(int(0.3 / DT))
	var slid: float = p.global_position.x - x0
	check("  0.3초 동안 뒤로 미끄러짐 (마찰 2)", slid > float(W.recoil) * 0.25, "%.2fm" % slid)
	await wait(int(1.2 / DT))
	var pushed: float = p.global_position.x - x0
	# 비교: 예전 반동(6m/s)을 같은 조건으로 — 땅에서 뒤로 6·위로 2·0.3초 미끄러짐을 직접 넣어 봄
	put(p, SHOOTER, "cannoneer", WEST_YAW)
	await wait(10)
	var x1: float = p.global_position.x
	p.velocity += Vector3(6.0, 2.0, 0.0)
	p.recoil_t = float(W.recoil_t)
	p.kb_air = true
	p.grounded = false
	await wait(int(1.5 / DT))
	var pushed_old: float = p.global_position.x - x1
	check("정면으로 쏘면 예전(6m/s)보다 확실히 멀리 밀림", pushed > pushed_old * 1.25, "지금 %.2fm / 예전 %.2fm (%.1f배)" % [pushed, pushed_old, pushed / maxf(pushed_old, 0.01)])
	await wait(30)
	# 공중에서 수평으로 쏴도 똑같이 W.recoil (위로 +2는 없음)
	put(p, Vector3(0, 0, 20), "cannoneer", WEST_YAW)  # 위가 트인 곳
	await wait(10)
	p.global_position += Vector3(0, 20, 0)
	p.velocity = Vector3.ZERO
	p.grounded = false
	await wait(4)  # 옮긴 직후 한 프레임은 바닥 판정이 남아 있음
	p.cn_t = 0.0
	rv = await shot_dv()
	var gstep: float = -G.GRAV * DT  # 그 사이 한 프레임 중력
	check("공중에서 쏴도 뒤로 %.0fm/s (위로 +2 없음, 속도 상한에 안 잘림)" % float(W.recoil), near(rv.x, float(W.recoil), 0.3) and absf(rv.y - gstep) < 0.3, "반동 %s" % rv)
	await wait(90)
	# 세로 성분 자르기: 공중에서 바로 아래로 쏘면 위로 4 (6이 아니라), 바로 위로 쏘면 아래로 4
	for pc: float in [-PI / 2 + 0.01, PI / 2 - 0.01]:
		put(p, Vector3(0, 0, 20), "cannoneer", WEST_YAW)
		await wait(10)
		p.global_position += Vector3(0, 20, 0)
		p.velocity = Vector3.ZERO
		p.grounded = false
		p.pitch = pc
		await physics_frame
		p.cn_t = 0.0
		C.projectiles.clear()
		var r: Vector3 = C.cannon.fire_recoil(p, p.aim_dir())
		check("세로 반동은 ±4로 자름 (%s로 쏨)" % ("아래" if pc < 0 else "위"), near(absf(r.y), 4.0, 0.01) and signf(r.y) == -signf(pc), "r=%s" % r)
		p.pitch = 0.0
		await wait(120)
	# 땅에서 발밑에 쏘면: 반동 세로 = min(6+2, 4) = 4 → 그다음 포탄 점프 22 (과하게 안 솟음)
	put(p, SHOOTER, "cannoneer", WEST_YAW)
	await wait(10)
	p.pitch = -PI / 2 + 0.05
	p.cn_t = 0.0
	var y3: float = p.global_position.y
	var vy_after_fire: float = (await shot_dv()).y
	var vy_top := 0.0
	var top4 := y3
	for i in 220:
		await physics_frame
		vy_top = maxf(vy_top, p.velocity.y)
		top4 = maxf(top4, p.global_position.y)
	check("발밑 사격: 반동 세로 4로 잘림", near(vy_after_fire, 4.0, 0.5), "vy %.1f" % vy_after_fire)
	check("  그다음 포탄 점프 22m/s를 안 넘음 (높이 %.1fm)" % (top4 - y3), vy_top <= float(W.jump_up) + 0.3 and top4 - y3 < 16.0, "최고 vy %.1f" % vy_top)
	p.pitch = 0.0
	await wait(30)

	# ── 화면 반동: 위로 살짝 튀었다가 0.2초 안에 원래대로, 조준 방향은 그대로 ──
	put(p, SHOOTER, "cannoneer", WEST_YAW)
	await wait(10)
	p.cn_t = 0.0
	var aim0: Vector3 = p.aim_dir()
	await shot_dv()
	var peak := 0.0
	var at_end := 1.0
	var max_t := 0.0
	for i in 24:  # 화면 프레임 24개 = 0.4초 (--fixed-fps 60)
		await process_frame
		var k: float = p.cam_kick_now()
		peak = maxf(peak, k)
		if k > 0.0005:
			max_t = (i + 1) * DT
		at_end = k
	check("화면이 위로 튐 (최대 %.3f rad)" % peak, peak > float(W.cam_kick) * 0.5, "")
	check("  0.2초 안에 돌아옴", at_end == 0.0 and max_t <= 0.26, "마지막으로 튀어 있던 때 %.2f초" % max_t)
	check("  조준 방향은 그대로", p.aim_dir().distance_to(aim0) < 0.001, "")
	# 0.2초 반동 꼴: 시작 0 → 꼭대기 → 끝 0
	p.cam_kick_t = float(W.cam_kick_t)
	var k_start: float = p.cam_kick_now()
	p.cam_kick_t = float(W.cam_kick_t) * (1.0 - float(W.cam_kick_peak))
	var k_peak: float = p.cam_kick_now()
	p.cam_kick_t = 0.0005
	var k_end: float = p.cam_kick_now()
	check("  반동 꼴: 0 → 꼭대기(cam_kick) → 0", near(k_start, 0.0, 0.001) and near(k_peak, float(W.cam_kick), 0.001) and k_end < 0.001, "%.3f %.3f %.4f" % [k_start, k_peak, k_end])
	p.cam_kick_t = 0.0
	await wait(10)

	# ── 지붕 경사면: 포탄 점프로 올라가도 흘러내림 ──
	await roof_drop(p, "cannoneer")
	await roof_drop(p, "archer")
	await wait(10)

	# ── 봇 포병: 대포를 쏘고, 너무 가까우면 안 쏨 ──
	check("친구대전 무기 번호에 대포", main.get_node("Net").WEPS.has("cannon"), "")
	check("봇이 고를 수 있는 병과에 포병", G.bot_classes().has("cannoneer"), "")

	print("ALL PASS" if fails == 0 else "FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)


## 지붕 경사면 흘러내림 (사용자 요청): 지붕마다 꼭대기 근처 두 곳(맵 안쪽으로)에 떨어뜨려
## 지붕 위에 서 있는 프레임이 없고, 4초 안에 지붕 밑(처마 높이 - 0.5m)까지 내려왔는지
func roof_drop(e, cls: String) -> void:
	var roofs = C.world.roofs
	check("맵에 지붕 충돌이 있음 (캐릭터만 막는 층)", roofs != null and roofs.get_child_count() > 0 and roofs.collision_layer == C.world.BOUND_LAYER, "")
	if roofs == null:
		return
	var bad: Array = []
	var n := 0
	for cs in roofs.get_children():
		var pts: PackedVector3Array = cs.shape.points
		var hx: float = pts[1].x
		var hz: float = pts[2].z
		var hy: float = pts[4].y
		var c: Vector3 = cs.position
		var base: float = c.y - hy
		var sx: float = -signf(c.x) if absf(c.x) > 0.1 else 1.0
		var sz: float = -signf(c.z) if absf(c.z) > 0.1 else 1.0
		for off: Vector3 in [Vector3(sx * hx * 0.4, 0, 0), Vector3(0, 0, sz * hz * 0.4)]:
			put(e, Vector3(c.x + off.x, c.y + hy + 0.3, c.z + off.z), cls)
			e.velocity = Vector3.ZERO
			e.grounded = false
			var stood := 0
			for i in 240:
				await physics_frame
				if e.grounded and e.global_position.y > base + 0.05:
					stood += 1
			n += 1
			var y: float = e.global_position.y
			if stood > 0 or y > base - 0.5:
				bad.append("(%.0f,%.0f)+%s 선 %d프레임 y=%.1f 처마 %.1f" % [c.x, c.z, off, stood, y, base])
	check("지붕 %d곳에 떨어뜨리면 서 있지 못하고 흘러내림 (%s)" % [n, cls], bad.is_empty(), str(bad))
	# 지붕 충돌은 투사체·레이에 안 걸림 (예전처럼 지붕을 지나감)
	var cs0 = roofs.get_child(0)
	var top: Vector3 = cs0.position + Vector3(0, cs0.shape.points[4].y, 0)
	check("지붕은 투사체·레이를 막지 않음", C.world_ray(top + Vector3(0, 0.5, 0), Vector3(0, -1.2, 0)) > 1.0, "")
