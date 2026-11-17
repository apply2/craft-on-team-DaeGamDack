class_name LobbyPage
extends Control
## 친구대전 대기실 (사용자 요청 — 오버워치·롤 커스텀 게임 느낌, 게시판 색 + 정갈한 배치).
## 스타일은 전부 ui/lobby_theme.tres (LobbyTheme) — 노드는 theme_type_variation만 고른다. 수치는 GameData.LOBBY_UI.
##   위: [← 방 나가기] 나무 간판 · 방 코드 [복사] · 모드 · 맵 · 인원 N/M
##   가운데: 개인전 = 자리 2열 그리드 / 쟁탈전 = 블루 | 레드 두 칸 (팀마다 자리 5칸 고정) + 아래 [+ 봇 추가] (방장만)
##   오른쪽: 내 병과
##   아래: [팀 이동] · 안내 · [준비] (친구) / [게임 시작 (준비 N/M)] (방장)
## 상태는 방장이 정한 room을 Main이 view로 만들어 render()에 넘긴다. 누른 것은 act(op, arg)로만 알림:
##   leave · start · ready(bool) · cls(병과) · team(팀) · mode · map · bot_add(팀) · bot_del(id) · bot_set([id, 병과, 난이도]) · copy

signal act(op: String, arg: Variant)

const THEME := preload("res://ui/lobby_theme.tres")
const MODES := ["ffa", "control"]

var _code: Label
var _mode_opt: OptionButton
var _map_opt: OptionButton
var _count: Label
var _slots: VBoxContainer       # 자리 영역 (모드가 바뀌면 다시 만듦)
var _class_btns := {}           # 병과 → Button
var _team_btn: Button
var _status: Label
var _main_btn: Button
var _view := {}
var _sig := ""
var _maps_md := ""
var _quiet := false             # 코드로 값을 바꾸는 중 (신호 안 냄)


func _init() -> void:
	theme = THEME
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # 뒤의 게임 화면으로 클릭이 새지 않게
	var L: Dictionary = GameData.LOBBY_UI
	var bg := PanelContainer.new()
	bg.theme_type_variation = "LobbyBg"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mg: Array = L.margin
	m.add_theme_constant_override("margin_left", int(mg[0]))
	m.add_theme_constant_override("margin_right", int(mg[0]))
	m.add_theme_constant_override("margin_top", int(mg[1]))
	m.add_theme_constant_override("margin_bottom", int(mg[1]))
	add_child(m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(L.gap))
	m.add_child(col)
	_build_top(col)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", int(L.gap))
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	var sc := ScrollContainer.new()  # 창이 작으면 자리 영역만 스크롤
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(sc)
	_slots = VBoxContainer.new()
	_slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slots.add_theme_constant_override("separation", int(L.slot_gap))
	sc.add_child(_slots)
	_build_classes(body)
	_build_bottom(col)


# ── 뼈대 ─────────────────────────────────────────────────────
func _build_top(parent: Node) -> void:
	var L: Dictionary = GameData.LOBBY_UI
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", int(L.gap))
	parent.add_child(hb)
	var back := _btn("← 방 나가기", "")
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: act.emit("leave", null))
	hb.add_child(back)
	# 중세 느낌은 이 간판 하나만 (나무판 + 크림 글자)
	var sign := UiKit.Board.new("wood", Vector4(18, 2, 18, 4))
	sign.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(sign)
	var tl := _lbl("친구대전", "Title", sign)
	UiKit.trim_font(tl, int(L.font.title), 0.12)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 8)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(info)
	_lbl("방 코드", "SmallOnDark", info)
	_code = _lbl("", "Code", info)
	var cp := _btn("복사", "SmallButton")
	cp.pressed.connect(func() -> void: act.emit("copy", null))
	info.add_child(cp)
	_gap(info, 10)
	_lbl("모드", "SmallOnDark", info)
	_mode_opt = OptionButton.new()
	_mode_opt.focus_mode = Control.FOCUS_NONE
	for k: String in MODES:
		_mode_opt.add_item(GameData.MODE_NAMES.get(k, k) + (" 5:5" if k == "control" else ""))
	_mode_opt.item_selected.connect(func(i: int) -> void:
		if not _quiet:
			act.emit("mode", MODES[i]))
	info.add_child(_mode_opt)
	_lbl("맵", "SmallOnDark", info)
	_map_opt = OptionButton.new()
	_map_opt.focus_mode = Control.FOCUS_NONE
	_map_opt.item_selected.connect(func(i: int) -> void:
		if not _quiet:
			act.emit("map", str(_map_opt.get_item_metadata(i))))
	info.add_child(_map_opt)
	_gap(info, 10)
	_count = _lbl("", "OnDark", info)


func _build_classes(parent: Node) -> void:
	var L: Dictionary = GameData.LOBBY_UI
	var pc := PanelContainer.new()
	pc.theme_type_variation = "LobbyPanel"
	pc.custom_minimum_size.x = float(L.side_w)
	pc.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(L.slot_gap))
	pc.add_child(vb)
	_lbl("내 병과", "Body", vb)
	for k: String in GameData.CLASS_ORDER:
		var C: Dictionary = GameData.CLASSES[k]
		var b := Button.new()
		b.theme_type_variation = "ClassPick"
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size.y = float(L.class_h)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var hb := HBoxContainer.new()
		hb.set_anchors_preset(Control.PRESET_FULL_RECT)
		hb.add_theme_constant_override("separation", 10)
		hb.offset_left = 8
		hb.offset_right = -8
		b.add_child(hb)
		hb.add_child(UiKit.emblem(k, float(L.emblem)))
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", -4)
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		hb.add_child(tv)
		_lbl(str(C.name), "Body", tv)
		_lbl(str(GameData.WEAPONS[C.weapon].name), "Small", tv)
		_mouse_through(hb)
		b.pressed.connect(func() -> void: act.emit("cls", k))
		vb.add_child(b)
		_class_btns[k] = b
	var tip := _lbl("경기 중에 바꾸면 다음 부활부터", "Small", vb)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _build_bottom(parent: Node) -> void:
	var L: Dictionary = GameData.LOBBY_UI
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", int(L.gap))
	parent.add_child(hb)
	_team_btn = _btn("팀 이동", "")
	_team_btn.pressed.connect(func() -> void:
		act.emit("team", "red" if str(_view.get("my_team", "")) == "blue" else "blue"))
	hb.add_child(_team_btn)
	_status = _lbl("", "SmallOnDark", hb)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_main_btn = _btn("", "Primary")
	_main_btn.custom_minimum_size.x = 220
	_main_btn.pressed.connect(_on_main)
	hb.add_child(_main_btn)


func _on_main() -> void:
	if _view.get("host", false) or _view.get("live", false):
		act.emit("start", null)
	else:
		act.emit("ready", not bool(_view.get("me_ready", false)))


# ── 그리기 ───────────────────────────────────────────────────
## v = {code, list (Net.lobby_list), md, map, host, cap, team_cap, my_team, cls, ready: Vector2i, me_ready, can_start, live, mst}
func render(v: Dictionary) -> void:
	_view = v
	var host: bool = v.get("host", false)
	var md := str(v.get("md", "ffa"))
	var list: Array = v.get("list", [])
	var lobby := str(v.get("mst", "lobby")) == "lobby"
	_code.text = str(v.get("code", ""))
	_quiet = true
	_mode_opt.select(maxi(0, MODES.find(md)))
	_mode_opt.disabled = not host or not lobby
	if _maps_md != md:
		_maps_md = md
		_map_opt.clear()
		for mp: Dictionary in GameData.room_maps(md):
			_map_opt.add_item(str(mp.name))
			_map_opt.set_item_metadata(_map_opt.item_count - 1, str(mp.key))
	for i in _map_opt.item_count:
		if str(_map_opt.get_item_metadata(i)) == str(v.get("map", "")):
			_map_opt.select(i)
	_map_opt.disabled = not host or not lobby or _map_opt.item_count < 2
	_quiet = false
	_count.text = "인원 %d/%d" % [list.size(), int(v.get("cap", 10))]
	for k: String in _class_btns:
		(_class_btns[k] as Button).theme_type_variation = "ClassPickOn" if k == str(v.get("cls", "")) else "ClassPick"
	# 팀 이동: 쟁탈전·대기실에서, 상대 팀에 자리가 있을 때만
	var ctrl := md == "control"
	var my_team := str(v.get("my_team", ""))
	_team_btn.visible = ctrl
	if ctrl:
		var other := "red" if my_team == "blue" else "blue"
		_team_btn.disabled = not lobby or list.filter(func(p: Dictionary) -> bool: return p.team == other).size() >= int(v.get("team_cap", 5))
	# 아래 큰 버튼 + 안내
	var r: Vector2i = v.get("ready", Vector2i.ZERO)
	if host:
		_main_btn.text = "게임 시작" + (" (준비 %d/%d)" % [r.x, r.y] if r.y > 0 else "")
		_main_btn.theme_type_variation = "Primary"
		_main_btn.disabled = not bool(v.get("can_start", false))
		if not lobby:
			_status.text = "경기가 진행 중이에요"
		elif r.x < r.y:
			_status.text = "모두 준비하면 시작할 수 있어요"
		else:
			_status.text = "친구에게 방 코드를 알려주세요" if list.size() < 2 else "시작할 수 있어요!"
	elif v.get("live", false):
		_main_btn.text = "진행 중인 게임 참가"
		_main_btn.theme_type_variation = "Primary"
		_main_btn.disabled = false
		_status.text = "게임이 진행 중이에요"
	else:
		var rdy: bool = v.get("me_ready", false)
		_main_btn.text = "준비 취소" if rdy else "준비"
		_main_btn.theme_type_variation = "" if rdy else "Primary"
		_main_btn.disabled = not lobby
		_status.text = "방장이 시작하기를 기다리는 중 · 준비 %d/%d" % [r.x, r.y] if rdy else "준비를 누르세요"
	var sig := str([list, md, host, my_team, v.get("cap"), lobby])
	if sig != _sig:
		_sig = sig
		_rebuild_slots(v)


## 다음 render에서 자리를 꼭 다시 그림 (대기실을 새로 열 때)
func reset() -> void:
	_sig = ""
	_maps_md = ""


func _rebuild_slots(v: Dictionary) -> void:
	for ch in _slots.get_children():
		_slots.remove_child(ch)
		ch.queue_free()
	var L: Dictionary = GameData.LOBBY_UI
	var list: Array = v.get("list", [])
	var host: bool = v.get("host", false)
	var lobby := str(v.get("mst", "lobby")) == "lobby"
	if str(v.get("md", "ffa")) == "control":
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", int(L.gap))
		_slots.add_child(hb)
		var cap := int(v.get("team_cap", 5))
		for t: String in ["blue", "red"]:
			var tc := _panel_box(hb)
			var mem: Array = list.filter(func(p: Dictionary) -> bool: return p.team == t)
			var bar := PanelContainer.new()
			bar.theme_type_variation = "TeamBar" + t.capitalize()
			tc.add_child(bar)
			var bh := HBoxContainer.new()
			bar.add_child(bh)
			var tn := _lbl(ControlMode.team_name(t), "TeamName", bh)
			tn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_lbl("%d/%d" % [mem.size(), cap], "TeamName", bh)
			for i in cap:
				if i < mem.size():
					tc.add_child(_slot(mem[i], t, v))
				else:
					tc.add_child(_empty(t, v))
			if host:
				tc.add_child(_add_bot_btn(t, lobby and mem.size() < cap))
	else:
		var cap := int(v.get("cap", 10))
		var box := _panel_box(_slots)
		_lbl("참가자", "Body", box)
		var g := GridContainer.new()
		g.columns = 2
		g.add_theme_constant_override("h_separation", int(L.slot_gap))
		g.add_theme_constant_override("v_separation", int(L.slot_gap))
		g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(g)
		for i in cap:
			var c: Control = _slot(list[i], "", v) if i < list.size() else _empty("", v)
			c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			g.add_child(c)
		if host:
			box.add_child(_add_bot_btn("", lobby and list.size() < cap))


## 양피지 판 하나 + 안의 세로 줄 (자리 칸들을 담음)
func _panel_box(parent: Node) -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.theme_type_variation = "LobbyPanel"
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(GameData.LOBBY_UI.slot_gap))
	pc.add_child(vb)
	return vb


func _add_bot_btn(t: String, ok: bool) -> Button:
	var b := _btn("+ 봇 추가", "SmallButton")
	b.disabled = not ok
	b.pressed.connect(func() -> void: act.emit("bot_add", t))
	return b


## 사람·봇 자리 한 칸
func _slot(p: Dictionary, t: String, v: Dictionary) -> Control:
	var L: Dictionary = GameData.LOBBY_UI
	var me: bool = p.get("me", false)
	var pc := PanelContainer.new()
	pc.theme_type_variation = "Slot" + t.capitalize() + ("Me" if me else "")
	pc.custom_minimum_size.y = float(L.slot_h)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	pc.add_child(hb)
	var c := str(p.get("cls", ""))
	if GameData.CLASSES.has(c):
		hb.add_child(UiKit.emblem(c, float(L.emblem)))
	else:  # 봇 병과 무작위
		var e := PanelContainer.new()
		e.theme_type_variation = "EmblemRandom"
		e.custom_minimum_size = Vector2.ONE * float(L.emblem)
		e.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var q := _lbl("?", "BadgeTextLight", e)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hb.add_child(e)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", -4)
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(tv)
	var nh := HBoxContainer.new()
	nh.add_theme_constant_override("separation", 6)
	tv.add_child(nh)
	var nl := _lbl(str(p.get("name", "")), "Body", nh)
	nl.clip_text = true
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if p.get("host", false):
		nh.add_child(Crown.new())
	var sub := str(GameData.CLASSES[c].name) if GameData.CLASSES.has(c) else "병과 무작위"
	if p.get("bot", false):
		sub += " · " + str(GameData.DIFF.get(str(p.get("diff", "")), {}).get("name", ""))
	if p.get("st", "") == "play":
		sub += " · 게임 중"
	_lbl(sub, "Small", tv)
	if p.get("bot", false):
		hb.add_child(_badge("BOT", "BadgeBot", "BadgeTextLight"))
		if v.get("host", false) and str(v.get("mst", "lobby")) == "lobby":
			hb.add_child(_bot_cls_opt(p))
			hb.add_child(_bot_diff_opt(p))
			var x := _btn("X", "Danger")
			x.tooltip_text = "봇 빼기"
			x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			x.pressed.connect(func() -> void: act.emit("bot_del", int(p.id)))
			hb.add_child(x)
	elif not p.get("host", false):
		hb.add_child(_badge("준비", "BadgeReady", "BadgeText") if p.get("rdy", false) else _badge("대기", "BadgeWait", "Small"))
	return pc


func _bot_cls_opt(p: Dictionary) -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var keys: Array = [""]
	keys.append_array(GameData.bot_classes())
	for k: String in keys:
		o.add_item("랜덤" if k == "" else str(GameData.CLASSES[k].name))
	o.select(maxi(0, keys.find(str(p.get("cls", "")))))
	o.item_selected.connect(func(i: int) -> void: act.emit("bot_set", [int(p.id), keys[i], str(p.get("diff", "normal"))]))
	return o


func _bot_diff_opt(p: Dictionary) -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var keys: Array = GameData.DIFF.keys()
	for k: String in keys:
		o.add_item(str(GameData.DIFF[k].name))
	o.select(maxi(0, keys.find(str(p.get("diff", "")))))
	o.item_selected.connect(func(i: int) -> void: act.emit("bot_set", [int(p.id), str(p.get("cls", "")), keys[i]]))
	return o


## 빈 자리 (쟁탈전 반대 팀이면 눌러서 그 팀으로)
func _empty(t: String, v: Dictionary) -> Control:
	var b := Button.new()
	b.theme_type_variation = "SlotEmpty"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = float(GameData.LOBBY_UI.slot_h)
	var can := t != "" and t != str(v.get("my_team", "")) and str(v.get("mst", "lobby")) == "lobby"
	b.text = "빈 자리 - 눌러서 이동" if can else "빈 자리"
	b.disabled = not can
	if can:
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(func() -> void: act.emit("team", t))
	return b


func _badge(text: String, kind: String, text_kind: String) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.theme_type_variation = kind
	pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_lbl(text, text_kind, pc)
	return pc


# ── 조각 ─────────────────────────────────────────────────────
static func _lbl(text: String, kind: String, parent: Node = null) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = kind
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent:
		parent.add_child(l)
	return l


static func _btn(text: String, kind: String) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = kind
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


static func _gap(parent: Node, w: float) -> void:
	var c := Control.new()
	c.custom_minimum_size.x = w
	parent.add_child(c)


static func _mouse_through(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ch in n.get_children():
		_mouse_through(ch)


## 방장 왕관 (도형으로 — 글꼴에 없는 기호 대신)
class Crown extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(20, 15)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		tooltip_text = "방장"

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var pts := PackedVector2Array([Vector2(1, h - 1), Vector2(1, 3), Vector2(w * 0.3, h * 0.55), Vector2(w * 0.5, 1),
			Vector2(w * 0.7, h * 0.55), Vector2(w - 1, 3), Vector2(w - 1, h - 1)])
		draw_colored_polygon(pts, UiKit.c("gilt"))
		pts.append(pts[0])
		draw_polyline(pts, UiKit.c("ink"), 1.5, true)
