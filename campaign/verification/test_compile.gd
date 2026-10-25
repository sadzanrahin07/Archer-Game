extends SceneTree

func _init() -> void:
	print('--- Testing Script Compilations ---')
	var scripts = [
		'res://campaign/catalog.gd',
		'res://campaign/profile.gd',
		'res://campaign/menu_ui.gd',
		'res://campaign/game.gd',
		'res://campaign/player.gd',
		'res://campaign/projectile.gd',
		'res://campaign/target.gd',
		'res://campaign/touch_controls.gd'
	]
	for s in scripts:
		var loaded = load(s)
		if loaded == null:
			printerr('FAIL to load: ', s)
			quit(1)
			return
		print('Compiled OK: ', s)
	print('SUCCESS: All campaign core scripts compiled cleanly!')
	quit(0)
