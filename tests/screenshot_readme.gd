extends SceneTree
## README용 경기 화면: 봇들이 진짜로 싸우는 경기(나도 봇 AI)를 돌리며 from초부터 every초마다 찍는다 (화면 있어야 함).
##   godot --path . --resolution 1600x900 --fixed-fps 60 -s tests/screenshot_readme.gd -- mode=control cls=archer from=30 to=90 every=3 out=<폴더>
## 결과: <out>/<mode>_<초>.jpg (기본 out = tests/screenshots/readme_raw). 마음에 드는 걸 골라 tests/screenshots/readme_*.jpg로 복사해 README에 씀.

var G: Node
var M: Node
var mode := "control"
var cls := "archer"
var from_t := 30.0
var to_t := 90.0
var every := 3.0
var quality := "high"
var out := "res://tests/screenshots/readme_raw"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() != 2:
			continue
		match kv[0]:
			"mode": mode = kv[1]
			"cls": cls = kv[1]
			"from": from_t = float(kv[1])
			"to": to_t = float(kv[1])
			"every": every = float(kv[1])
			"quality": quality = kv[1]
			"out": out = kv[1]
	G = root.get_node("GameData")
	G.save_enabled = false
	G.hitstop_enabled = false
	G.third_person = true
	G.difficulty = "normal"
	G.chosen_cls = cls
	G.mode = mode if mode == "control" else "ffa"
	G.set_gfx(quality)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out) if out.begins_with("res://") else out)
	M = load("res://scenes/main.tscn").instantiate()
	root.add_child(M)
	M.start_match.call_deferred()
	_run()


func _run() -> void:
	await physics_frame
	await physics_frame
	var p = M.get_node("Player")
	p.ai = load("res://scripts/bot_ai.gd").new()  # 나도 봇처럼 움직이고 싸움 (카메라는 내 3인칭 그대로)
	var t := 0.0
	var next := from_t
	while t < to_t:
		await process_frame
		t += 1.0 / 60.0
		if M.state == "paused":  # 창 포커스를 잃어도 계속
			M.resume_game()
		if t >= next:
			next += every
			var img := root.get_texture().get_image()
			var base := out.path_join("%s_%03d.jpg" % [mode, int(t)])
			img.save_jpg(ProjectSettings.globalize_path(base) if base.begins_with("res://") else base, 0.88)
			print("saved ", base, " alive=", p.alive)
		if M.state == "ended":
			break
	quit()
