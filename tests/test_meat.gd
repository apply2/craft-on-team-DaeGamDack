extends SceneTree
## 야만인 우클릭 "고기 먹기" 자동 테스트 (사용자 요청). 수치는 GameData.WEAPONS.meat
## 실행: godot --headless --fixed-fps 60 --path . -s tests/test_meat.gd
## 통과하면 "ALL PASS"와 종료 코드 0, 실패하면 FAIL 줄과 종료 코드 1.

var main: Node
var G: Node
var C
var p
var fails := 0
var nums: Array = []

const IDLE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false}
const EAT := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false, "aim": true}
const EAT_FIRE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false, "aim": true, "fire": true}
const HOME := Vector3(-25, 0, 18)


func _initialize() -> void:
	var G0 = root.get_node("GameData")
	G0.save_enabled = false
	G0.hitstop_enabled = false
	G0.land_trip_override = 0.0
	G0.third_person = false
	G0.difficulty = "normal"
	G0.chosen_cls = "barbarian"
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


func put(e, pos: Vector3, cls := "barbarian", yaw := 0.0) -> void:
	e.next_cls = cls
	e.spawn_at(pos)
	e.invuln = 0.0
	e.scripted_input = IDLE
	e.yaw = yaw
	e.pitch = 0.0
	e.velocity = Vector3.ZERO


func press(inp: Dictionary, n := 2) -> void:
	p.scripted_input = inp
	await wait(n)
	p.scripted_input = IDLE


func _run() -> void:
	await wait(3)
	G = root.get_node("GameData")
	C = main.get_node("Combat")
	p = main.get_node("Player")
	C.num.connect(func(_pos, text, style): nums.append([text, style]))
	for b in C.ents.filter(func(e): return e.is_bot):
		put(b, Vector3(30, 0, -30 + C.ents.find(b) * 3), "archer")
	var W: Dictionary = G.WEAPONS.meat
	var MH := float(G.class_hp("barbarian"))

	# ── 먹기: 30 회복 · 재사용 8.3초 · 먹는 모습 · 소리 · 초록 +30 ──
	put(p, HOME)
	await wait(3)
	p.hp = 40.0
	nums.clear()
	var sfx = root.get_node("Sfx")
	sfx.played.clear()
	await press(EAT)
	check("우클릭하면 고기를 먹고 30 회복", is_equal_approx(p.hp, 40.0 + float(W.heal)), "hp=%.1f" % p.hp)
	check("  재사용 8.3초 · 먹는 중", is_equal_approx(float(W.cd), 8.3) and p.meat_cd > float(W.cd) - 0.1 and p.eat_t > 0, "cd=%.2f eat=%.2f" % [p.meat_cd, p.eat_t])
	check("  머리 위 초록 +30 · 냠 소리", nums.any(func(n): return n[0] == "+30" and n[1] == "heal") and sfx.played.has("nyam"), "%s %s" % [str(nums), str(sfx.played)])
	check("  3인칭 모델 왼손에 고기가 보임", p.model.meat != null and p.model.meat.visible, "")
	await wait(int(float(W.eat_t) * 60.0) + 4)
	check("  다 먹으면 고기 숨김", not p.model.meat.visible and p.eat_t <= 0, "")
	# 재사용 대기 중엔 안 먹어짐
	var hp1: float = p.hp
	await press(EAT)
	check("재사용 대기 중엔 안 먹어짐", p.hp == hp1, "hp=%.1f" % p.hp)
	# 재사용 대기가 끝나면 다시
	await wait(int(float(W.cd) * 60.0))
	await press(EAT)
	check("재사용 대기가 끝나면 다시 먹음", is_equal_approx(p.hp, minf(MH, hp1 + float(W.heal))), "hp=%.1f" % p.hp)
	# 최대 체력 넘지 않음
	put(p, HOME)
	await wait(3)
	p.hp = MH - 5.0
	await press(EAT)
	check("최대 체력(90)을 안 넘음", p.hp == MH, "hp=%.1f" % p.hp)

	# ── 상태이상 풀기: 춤(+게이지)·성수 둔화·경직 ──
	put(p, HOME)
	await wait(3)
	p.dance_t = 2.0
	p.dance_log.append([C.clock, 0.5])
	p.slow_t = 1.5
	p.stagger = 0.4
	await press(EAT)
	check("춤추는 중에도 먹을 수 있고 춤이 풀림", p.dance_t == 0.0 and p.dance_log.is_empty(), "dance=%.2f log=%d" % [p.dance_t, p.dance_log.size()])
	check("  성수 둔화·경직도 풀림", p.slow_t <= 0.0 and p.stagger <= 0.0, "slow=%.2f stagger=%.2f" % [p.slow_t, p.stagger])
	await wait(40)
	# 체력이 꽉 차 있어도 풀려고 먹을 수 있음
	put(p, HOME)
	await wait(3)
	p.slow_t = 1.5
	await press(EAT)
	check("체력이 꽉 차도 먹어서 둔화를 풂", p.slow_t <= 0.0 and p.meat_cd > 0, "")
	await wait(40)

	# ── 먹는 동안은 돌을 못 던짐 ──
	put(p, HOME)
	await wait(3)
	var n0: int = C.projectiles.filter(func(q): return q.owner == p).size()
	await press(EAT_FIRE, 6)
	var n1: int = C.projectiles.filter(func(q): return q.owner == p).size()
	check("먹는 동안은 돌을 안 던짐", n1 == n0, "%d → %d" % [n0, n1])
	await wait(int(float(W.eat_t) * 60.0))
	await press({"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false, "fire": true})
	await wait(2)
	check("  다 먹으면 다시 던짐", C.projectiles.filter(func(q): return q.owner == p).size() > n0, "")
	await wait(30)

	# ── 안 되는 경우: 넘어짐 · 다른 무기(저격총) · 다른 병과 ──
	put(p, HOME)
	await wait(3)
	p.hp = 40.0
	p.fall_t = 0.5
	p.scripted_input = EAT
	await wait(2)
	p.scripted_input = IDLE
	check("넘어져 있으면 못 먹음", p.hp == 40.0 and p.meat_cd == 0.0, "hp=%.1f" % p.hp)
	await wait(60)
	put(p, HOME)
	await wait(3)
	p.hp = 40.0
	C.items.drop_sniper(p.global_position, 5)
	await wait(30)
	check("  (저격총 주움)", p.has_sniper and p.wep == "sniper", p.wep)
	await press(EAT)
	check("저격총을 들고 우클릭하면 스코프 (고기 아님)", p.hp == 40.0 and p.meat_cd == 0.0, "hp=%.1f" % p.hp)
	put(p, HOME, "archer")
	await wait(3)
	p.hp = 40.0
	await press(EAT)
	check("다른 병과는 우클릭해도 고기 없음", p.hp == 40.0 and p.model.meat == null, "hp=%.1f" % p.hp)

	# ── HUD: 무기 칸 안내 · 조준점 고리 = 재사용 대기 ──
	put(p, HOME)
	await wait(5)
	check("무기 칸에 '우클릭 고기 먹기'", main.hud._w_state.text.contains("우클릭 고기 먹기"), main.hud._w_state.text)
	await press(EAT)
	await wait(int(float(W.eat_t) * 60.0) + 30)
	var rv: float = main.hud._ring._v
	check("먹은 뒤 조준점 고리 = 재사용 대기 (0~1)", rv > 0.0 and rv < 1.0, "%.2f" % rv)

	# ── 봇: 체력이 절반 아래면 먹음 ──
	G.ai_enabled = true
	var bot = C.ents.filter(func(e): return e.is_bot)[0]
	put(bot, Vector3(0, 0, 21), "barbarian")
	bot.scripted_input = {}
	await wait(2)
	bot.hp = 30.0
	nums.clear()
	var ate := false
	for i in 120:
		await physics_frame
		if bot.meat_cd > 0:
			ate = true
			break
	G.ai_enabled = false
	bot.scripted_input = IDLE
	check("봇 야만인은 체력이 절반 아래면 고기를 먹음", ate and bot.hp >= 60.0 - 0.01, "hp=%.1f" % bot.hp)
	await wait(5)
	check("  상대가 먹을 땐 +30 자막이 안 뜸 (사용자 요청)", not nums.any(func(n): return n[1] == "heal"), str(nums))

	print("ALL PASS" if fails == 0 else "FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
