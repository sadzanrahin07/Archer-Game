extends SceneTree

func _init():
    print("Testing profile.gd...")
    var p = load("res://campaign/profile.gd")
    print("profile.gd: ", p != null)
    print("Testing menu_ui.gd...")
    var m = load("res://campaign/menu_ui.gd")
    print("menu_ui.gd: ", m != null)
    print("Testing game.gd...")
    var g = load("res://campaign/game.gd")
    print("game.gd: ", g != null)
    quit(0 if (p != null and m != null and g != null) else 1)
