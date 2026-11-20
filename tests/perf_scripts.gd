extends SceneTree
## 스크립트별 CPU 시간 (어느 스크립트의 _process·_physics_process가 비싼가).
## 경기를 돌리며 매 프레임 각 노드의 콜백을 한 번 더 불러 시간을 재고 스크립트별로 합친다
## (두 번 불러서 타이머 등이 빨리 가지만 비율 보기엔 충분 — 절대값은 대략).
##   godot --headless --path . -s tests/perf_scripts.gd -- mode=control secs=6
## 결과: "SCRIPT 경로 process=ms physics=ms (노드 수)" 줄, 비싼 순

var main: Node
var G: Node
var secs := 6.0
var mode := "ffa"
var acc := {}  # 경로 → [process_us, physics_us, 노드 수]
var parts := {}  # 물리 프레임 안 함수별 us (detail)


class Tick extends Node:
	var cb: Callable
	func _process(dt: float) -> void:
		cb.call(dt, false)
	func _physics_process(dt: float) -> void:
		cb.call(dt, true)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			match kv[0]:
				"secs": secs = float(kv[1])
				"mode": mode = kv[1]
	G = root.get_node("GameData")
	G.save_enabled = false
	G.hitstop_enabled = false
	G.third_person = true
	G.chosen_cls = "archer"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run()


func _nodes(n: Node, out: Array) -> void:
	if n.get_script() != null and n.can_process():
		out.append(n)
	for c in n.get_children():
		_nodes(c, out)


func _part(name: String, f: Callable) -> void:
	var t0 := Time.get_ticks_usec()
	f.call()
	parts[name] = int(parts.get(name, 0)) + Time.get_ticks_usec() - t0


## 물리 프레임 안을 쪼개서 (Combat._physics_process·캐릭터 이동·봇 AI를 한 번 더 불러 잼)
func _detail(dt: float) -> void:
	var C = main.get_node("Combat")
	_part("combat._tick_timers", func(): C._tick_timers(dt))
	_part("combat.weapon_update (모두)", func():
		for e in C.ents:
			if e.alive and not e.is_remote:
				C.weapon_update(e, e.fire_held, dt))
	_part("Trumpet.update_victims", func(): load("res://scripts/trumpet.gd").update_victims(C, dt))
	_part("combat.update_projectiles", func(): C.update_projectiles(dt))
	_part("combat.update_zones", func(): C.update_zones(dt))
	_part("items.update_chickens (닭 %d)" % C.items.chickens.size(), func(): C.items.update_chickens(dt))
	_part("items.update_horses", func(): C.items.update_horses(dt))
	_part("items 특수 (저격총·AK·붕어빵)", func():
		C.items.update_sniper(dt)
		C.items.update_ak(dt)
		C.items.update_fish(dt))
	_part("combat._update_world_arrows", func(): C._update_world_arrows(dt))
	_part("combat._update_helms", func(): C._update_helms(dt))
	if C.mode:
		_part("ControlMode.update", func(): C.mode.update(dt))
	_part("ragdolls", func():
		for rd in C.ragdolls:
			rd.update(dt))
	for e in C.ents:
		if not e.alive or e.is_remote:
			continue
		if e.ai and G.ai_enabled:
			_part("bot_ai.update (봇 모두)", func(): e.ai.update(e, C, dt))
		_part("player.movement (모두)", func(): e.movement(Vector3.ZERO, false, false, dt))
		if e.model:
			_part("derp_model.animate (모두, 화면 프레임 아님)", func(): e.model.animate(e, 1.0 / 60.0))


func _sample(dt: float, phys: bool) -> void:
	if phys:
		_detail(dt)
	var list: Array = []
	_nodes(main, list)
	for n: Node in list:
		var m := "_physics_process" if phys else "_process"
		if not n.has_method(m):
			continue
		if phys and not n.is_physics_processing():
			continue
		if not phys and not n.is_processing():
			continue
		var path: String = (n.get_script() as Script).resource_path.get_file()
		var t0 := Time.get_ticks_usec()
		n.call(m, dt)
		var us := Time.get_ticks_usec() - t0
		var a: Array = acc.get_or_add(path, [0, 0, {}])
		a[1 if phys else 0] += us
		a[2][n.get_instance_id()] = true


func _run() -> void:
	for i in 10:
		await physics_frame
	if mode != "menu":
		G.mode = mode
		main.start_match()
		for i in 30:
			await physics_frame
		main.get_node("Player").invuln = 1e9
	G.ai_enabled = true
	for i in 60:
		await process_frame
	var tk := Tick.new()
	var frames := [0, 0]
	tk.cb = func(dt: float, phys: bool) -> void:
		frames[1 if phys else 0] += 1
		_sample(dt, phys)
	root.add_child(tk)
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < secs:
		await process_frame
	tk.queue_free()
	var rows: Array = acc.keys()
	rows.sort_custom(func(x, y): return acc[x][0] / maxf(1, frames[0]) + acc[x][1] / maxf(1, frames[1]) > acc[y][0] / maxf(1, frames[0]) + acc[y][1] / maxf(1, frames[1]))
	print("== %s · 화면 프레임 %d · 물리 프레임 %d (ms = 프레임 한 번 평균) ==" % [mode, frames[0], frames[1]])
	for p in rows:
		var a: Array = acc[p]
		print("SCRIPT %-24s process=%.3fms physics=%.3fms (노드 %d)" % [p, a[0] / 1000.0 / maxf(1, frames[0]), a[1] / 1000.0 / maxf(1, frames[1]), a[2].size()])
	print("-- 물리 프레임 안 (ms/물리 프레임) --")
	var pk: Array = parts.keys()
	pk.sort_custom(func(x, y): return parts[x] > parts[y])
	for k in pk:
		print("PART %-44s %.3fms" % [k, parts[k] / 1000.0 / maxf(1, frames[1])])
	quit()
