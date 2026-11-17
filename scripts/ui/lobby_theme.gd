class_name LobbyTheme
## 친구대전 대기실 Theme 만들기 — 값은 전부 GameData.LOBBY_UI·UI (색 숫자는 game_data.gd에만).
## 만든 Theme은 ui/lobby_theme.tres로 저장해서 쓴다 (tests/make_lobby_theme.gd). test_ui_kit가 저장본과 build()가 같은지 확인한다.
## 노드는 theme_type_variation 이름만 고르고 스타일을 직접 박지 않는다:
##   Button 변형: Primary(금칠 — 화면에 하나) · Danger(봇 빼기) · SmallButton · SlotEmpty(빈 자리) · ClassPick / ClassPickOn
##   PanelContainer 변형: LobbyBg · LobbyPanel · Slot / SlotMe · SlotBlue(Me) · SlotRed(Me) · TeamBarBlue / TeamBarRed · BadgeReady · BadgeBot · BadgeWait · EmblemRandom
##   Label 변형: Title · Code · Body · Small · OnDark · SmallOnDark · TeamName · BadgeText · BadgeTextLight


static func col(v: Variant) -> Color:
	if v is Array:
		return UiKit.c(str(v[0]), float(v[1]))
	return UiKit.c(str(v))


static func sb(bg: Color, border: Color, bw: Variant, pad: Array, radius := -1) -> StyleBoxFlat:
	var L: Dictionary = GameData.LOBBY_UI
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	if bw is Array:  # [왼, 위, 오, 아래]
		s.border_width_left = int(bw[0])
		s.border_width_top = int(bw[1])
		s.border_width_right = int(bw[2])
		s.border_width_bottom = int(bw[3])
	else:
		s.set_border_width_all(int(bw))
	s.set_corner_radius_all(int(L.radius) if radius < 0 else radius)
	s.content_margin_left = float(pad[0])
	s.content_margin_right = float(pad[0])
	s.content_margin_top = float(pad[1])
	s.content_margin_bottom = float(pad[1] if pad.size() < 3 else pad[2])
	s.anti_aliasing = true
	return s


static func build() -> Theme:
	var L: Dictionary = GameData.LOBBY_UI
	var F: Dictionary = L.font
	var t := Theme.new()
	t.default_font_size = int(F.body)
	var ink := UiKit.c("ink")
	var bw := int(L.border)
	var bp: Array = L.btn_pad
	var sp: Array = L.small_pad
	var pad := int(L.pad)

	# ── 버튼 ──
	_button(t, "Button", UiKit.c("parch"), UiKit.c("cream"), col(L.accent), ink, int(F.body), bp)
	_button(t, "Primary", UiKit.c("gilt"), UiKit.c("gilt_hi"), UiKit.c("gilt_lo"), ink, int(F.body), bp)
	_button(t, "SmallButton", UiKit.c("parch"), UiKit.c("cream"), col(L.accent), ink, int(F.small), sp)
	_button(t, "Danger", UiKit.c("red"), UiKit.c("red"), UiKit.c("red", 0.8), UiKit.c("cream"), int(F.small), sp)
	t.set_stylebox("hover", "Danger", sb(UiKit.c("red"), col(L.accent), bw, sp))
	for v: String in ["Primary", "SmallButton", "Danger"]:
		t.set_type_variation(v, "Button")
	# 빈 자리: 흐리게. 누를 수 있으면(반대 팀) 마우스 올림에 형광펜
	t.set_type_variation("SlotEmpty", "Button")
	var empty := sb(UiKit.c("ink", 0.06), UiKit.c("ink", 0.18), 1, [pad, 4])
	t.set_stylebox("normal", "SlotEmpty", empty)
	t.set_stylebox("disabled", "SlotEmpty", empty)
	t.set_stylebox("hover", "SlotEmpty", sb(col([L.accent, 0.35]), col(L.accent), bw, [pad, 4]))
	t.set_stylebox("pressed", "SlotEmpty", sb(col(L.accent), ink, bw, [pad, 4]))
	t.set_stylebox("focus", "SlotEmpty", StyleBoxEmpty.new())
	for k: String in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		t.set_color(k, "SlotEmpty", UiKit.c("faded"))
	t.set_color("font_hover_color", "SlotEmpty", ink)
	t.set_font_size("font_size", "SlotEmpty", int(F.small))
	# 내 병과 고르기 (글자는 안의 Label이 그림)
	_button(t, "ClassPick", UiKit.c("cream"), UiKit.c("parch"), col(L.accent), ink, int(F.body), [8, 4])
	t.set_stylebox("normal", "ClassPick", sb(UiKit.c("cream"), col(L.line), 1, [8, 4]))
	t.set_type_variation("ClassPick", "Button")
	_button(t, "ClassPickOn", col(L.accent), col(L.accent), col(L.accent), ink, int(F.body), [8, 4])
	t.set_type_variation("ClassPickOn", "Button")

	# OptionButton·PopupMenu (모드·맵·봇 병과·난이도)
	_button(t, "OptionButton", UiKit.c("parch"), UiKit.c("cream"), col(L.accent), ink, int(F.small), [sp[0], sp[1]])
	t.set_stylebox("panel", "PopupMenu", sb(UiKit.c("parch"), ink, bw, [4, 4]))
	t.set_stylebox("hover", "PopupMenu", sb(col(L.accent), Color.TRANSPARENT, 0, [4, 2], 3))
	t.set_color("font_color", "PopupMenu", ink)
	t.set_color("font_hover_color", "PopupMenu", ink)
	t.set_color("font_disabled_color", "PopupMenu", UiKit.c("faded"))
	t.set_font_size("font_size", "PopupMenu", int(F.small))

	# ── 판 ──
	_panel(t, "LobbyBg", sb(col(L.bg), Color.TRANSPARENT, 0, [0, 0], 0))
	_panel(t, "LobbyPanel", sb(col(L.panel), ink, bw, [pad, pad]))
	_panel(t, "Slot", sb(col(L.slot), col(L.line), 1, [10, 4]))
	_panel(t, "SlotMe", sb(col(L.accent), ink, bw, [10, 4]))
	for team: String in ["blue", "red"]:
		var n := team.capitalize()
		var tb := int(L.team_bar)
		# 테두리 = 팀 색 (왼쪽만 굵은 띠). 내 자리는 바탕을 형광펜으로
		_panel(t, "Slot" + n, sb(col(L.slot), UiKit.c(team), [tb, 1, 1, 1], [10, 4]))
		_panel(t, "Slot" + n + "Me", sb(col(L.accent), UiKit.c(team), [tb, bw, bw, bw], [10, 4]))
		_panel(t, "TeamBar" + n, sb(UiKit.c(team), ink, bw, [pad, 6]))
	_panel(t, "BadgeReady", sb(col(L.accent), ink, 1, [7, 1], 4))
	_panel(t, "BadgeBot", sb(ink, Color.TRANSPARENT, 0, [7, 1], 4))
	_panel(t, "BadgeWait", sb(Color.TRANSPARENT, UiKit.c("faded"), 1, [7, 1], 4))
	_panel(t, "EmblemRandom", sb(UiKit.c("faded"), Color.TRANSPARENT, 0, [0, 0], int(L.emblem) / 2))

	# ── 글자 (크기 세 단계: title · body · small) ──
	_label(t, "Title", UiKit.c("cream"), int(F.title), int(L.title_outline))
	_label(t, "Code", col(L.accent), int(F.title), int(L.title_outline))
	_label(t, "Body", ink, int(F.body))
	_label(t, "Small", UiKit.c("faded"), int(F.small))
	_label(t, "OnDark", UiKit.c("cream"), int(F.body))
	_label(t, "SmallOnDark", UiKit.c("dust"), int(F.small))
	_label(t, "TeamName", UiKit.c("cream"), int(F.body), 4)
	_label(t, "BadgeText", ink, int(F.small))
	_label(t, "BadgeTextLight", UiKit.c("cream"), int(F.small))
	return t


static func _button(t: Theme, type: String, n: Color, h: Color, p: Color, fg: Color, fs: int, pad: Array) -> void:
	var L: Dictionary = GameData.LOBBY_UI
	var ink := UiKit.c("ink")
	var bw := int(L.border)
	t.set_stylebox("normal", type, sb(n, ink, bw, pad))
	t.set_stylebox("hover", type, sb(h, ink, bw, pad))
	t.set_stylebox("pressed", type, sb(p, ink, bw, pad))
	t.set_stylebox("hover_pressed", type, sb(p, ink, bw, pad))
	t.set_stylebox("disabled", type, sb(UiKit.c("parch", 0.45), UiKit.c("ink", 0.25), bw, pad))
	t.set_stylebox("focus", type, StyleBoxEmpty.new())
	t.set_color("font_color", type, fg)
	t.set_color("font_hover_color", type, fg)
	t.set_color("font_pressed_color", type, fg)
	t.set_color("font_hover_pressed_color", type, fg)
	t.set_color("font_focus_color", type, fg)
	t.set_color("font_disabled_color", type, UiKit.c("faded", 0.7))
	t.set_font_size("font_size", type, fs)


static func _panel(t: Theme, type: String, s: StyleBox) -> void:
	t.set_type_variation(type, "PanelContainer")
	t.set_stylebox("panel", type, s)


static func _label(t: Theme, type: String, c: Color, fs: int, outline := 0) -> void:
	t.set_type_variation(type, "Label")
	t.set_color("font_color", type, c)
	t.set_font_size("font_size", type, fs)
	if outline > 0:
		t.set_color("font_outline_color", type, UiKit.c("ink"))
		t.set_constant("outline_size", type, outline)
