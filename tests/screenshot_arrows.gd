extends SceneTree
## 날아가는 화살·볼트 사진 (예전 모습 / 지금 모습). 봇이 내 앞을 가로질러 쏜 걸 3인칭으로 찍는다.
## 화면 필요: godot --path . --resolution 1280x720 -s tests/screenshot_arrows.gd
## → tests/screenshots/arrows_<bow|crossbow>_<before|after>.png

var main: Node
var G: Node
var C
var p
var dm

const IDLE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false}
const SPOT := Vector3(-25, 0, 18)


func _initialize() -> void:
	var G0 = root.get_node("GameData")
	G0.save_enabled = false
	G0.hitstop_enabled = false
	G0.land_trip_override = 0.0
	G0.third_person = true
	G0.chosen_cls = "archer"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.start_match.call_deferred()
	G0.ai_enabled = false
	_run()


func wait(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame


func put(e, pos: Vector3, cls: String, yaw: float) -> void:
	e.next_cls = cls
	e.spawn_at(pos)
	e.invuln = 0.0
	e.scripted_input = IDLE
	e.yaw = yaw
	e.pitch = 0.0
	e.velocity = Vector3.ZERO


func _run() -> void:
	await wait(5)
	G = root.get_node("GameData")
	C = main.get_node("Combat")
	p = main.get_node("Player")
	main.get_node("HUD").visible = false
	var bots: Array = C.ents.filter(func(e): return e.is_bot)
	dm = bots[0]
	for i in range(1, bots.size()):
		put(bots[i], Vector3(60 + i * 3, 0, -60), "archer", 0.0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/screenshots"))
	for kind in ["bow", "crossbow"]:
		for after in [false, true]:
			put(p, SPOT, "archer", 0.0)           # 북쪽(-z)을 봄
			put(dm, SPOT + Vector3(-22, 0, -14), "archer" if kind == "bow" else "crossbow", -PI / 2)  # 왼쪽에서 오른쪽(+x)으로 쏨
			await wait(20)
			var n0: int = C.projectiles.size()
			dm.cd = 0.0
			dm.pitch = 0.06
			C.fire(dm, kind, 1.0)
			var pr: Dictionary = C.projectiles[n0]
			if not after:
				var m: Node3D = pr.mesh
				var W = load("res://scripts/weapon_models.gd")
				W.end_flight_fx(m)
			# 화면 가운데(x ≈ SPOT.x)에 올 때까지
			for i in 60:
				await wait(1)
				if not C.projectiles.has(pr) or float(pr.pos.x) > SPOT.x + 3.0:
					break
			await process_frame
			print(kind, " 화살 화면 위치 ", p.cam.unproject_position(pr.pos))
			var img := root.get_viewport().get_texture().get_image()
			var path := "res://tests/screenshots/arrows_%s_%s.png" % [kind, "after" if after else "before"]
			img.save_png(ProjectSettings.globalize_path(path))
			print("saved ", path)
			await wait(30)
	quit()
