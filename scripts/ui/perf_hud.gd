class_name PerfHud
extends CanvasLayer
## 성능 표시 (F3로 켜고 끔, 사용자 "웹에서 렉" — 어디가 느린지 숫자로 보려고). 왼쪽 위 작은 자막.
## FPS·가장 느린 프레임, 평균 프레임 시간·물리 한 번 시간(물리를 한 프레임에 몇 번 돌았나), 그리기 호출·삼각형, 3D 해상도, 그래픽 카드 이름.
## 그래픽 카드가 소프트웨어(SwiftShader 등)면 브라우저 하드웨어 가속이 꺼진 것 → 경고 줄.
## 수치는 GameData.PERF_HUD. 저장 안 함 (켤 때마다 F3).

var label: Label
var _t := 0.0
var _frames := 0
var _worst := 0.0
var _phys := 0.0
var _steps := 0
var gpu := ""


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	label = Label.new()
	label.position = Vector2(10, 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.caption(label, int(GameData.PERF_HUD.font))
	add_child(label)
	visible = false
	gpu = RenderingServer.get_video_adapter_name()
	if OS.has_feature("web"):  # 브라우저는 "WebKit WebGL"처럼 가려서 알려 줌 → 진짜 이름을 따로 물어봄
		var js := "(function(){try{var g=document.createElement('canvas').getContext('webgl2');var e=g.getExtension('WEBGL_debug_renderer_info');return e?g.getParameter(e.UNMASKED_RENDERER_WEBGL):'';}catch(x){return '';}})()"
		var real: Variant = JavaScriptBridge.eval(js)
		if real is String and real != "":
			gpu = real


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("perf_hud"):
		visible = not visible
		_reset()
		get_viewport().set_input_as_handled()


static func soft_gpu(name: String) -> bool:
	var n := name.to_lower()
	for k: String in GameData.PERF_HUD.soft_gpu:
		if n.contains(k):
			return true
	return false


func _physics_process(_dt: float) -> void:
	_steps += 1


func _process(_dt: float) -> void:
	if not visible:
		return
	_phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	var real_dt := get_process_delta_time() / maxf(Engine.time_scale, 0.001)  # 히트스톱에 안 느려지게 실제 시간
	_worst = maxf(_worst, real_dt)
	_frames += 1
	_t += real_dt
	if _t < float(GameData.PERF_HUD.every):
		return
	var f := float(_frames)
	var vp := get_viewport()
	var sz := Vector2(DisplayServer.window_get_size())  # 실제 화면 점 (웹은 브라우저 창 × 화면 배율)
	var px := Vector2i(roundi(sz.x * vp.scaling_3d_scale), roundi(sz.y * vp.scaling_3d_scale))
	var tris := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var lines := PackedStringArray()
	lines.append("FPS %d · 가장 느린 프레임 %d ms" % [roundi(f / _t), roundi(_worst * 1000.0)])
	lines.append("평균 프레임 %.1f ms · 물리 한 번 %.1f ms (한 프레임에 %.1f번)" % [_t / f * 1000.0, _phys / f * 1000.0, float(_steps) / f])
	lines.append("그리기 %d번 · 삼각형 %.1f만 · 3D %dx%d (%d%%) · MSAA %dx" % [
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), tris / 10000.0, px.x, px.y,
		roundi(vp.scaling_3d_scale * 100.0), _msaa(vp)])
	lines.append("그래픽 카드: %s" % (gpu if gpu != "" else "(알 수 없음)"))
	if soft_gpu(gpu):
		lines.append("⚠ 하드웨어 가속이 꺼져 있어요 (브라우저 설정에서 켜 주세요)")
	label.text = "\n".join(lines)
	_reset()


func _msaa(vp: Viewport) -> int:
	match vp.msaa_3d:
		Viewport.MSAA_2X: return 2
		Viewport.MSAA_4X: return 4
		Viewport.MSAA_8X: return 8
	return 0


func _reset() -> void:
	_t = 0.0
	_frames = 0
	_worst = 0.0
	_phys = 0.0
	_steps = 0
