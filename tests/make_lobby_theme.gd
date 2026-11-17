extends SceneTree
## 친구대전 대기실 Theme 만들기: GameData.LOBBY_UI·UI 값 → ui/lobby_theme.tres
## 실행: godot --headless --path . -s tests/make_lobby_theme.gd   (LOBBY_UI·UI 색을 바꾸면 다시 돌릴 것)


func _initialize() -> void:
	var th: Theme = load("res://scripts/ui/lobby_theme.gd").build()
	var err := ResourceSaver.save(th, "res://ui/lobby_theme.tres")
	print("ui/lobby_theme.tres 저장 " + ("OK" if err == OK else "실패 %d" % err))
	quit(0 if err == OK else 1)
