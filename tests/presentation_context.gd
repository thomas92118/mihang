extends SceneTree
## Behavioral checks for quiet HUD, alert stacking and feedback lifetime.
const HUD = preload("res://scripts/hud.gd")

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		printerr("PRESENTATION_CONTEXT_TIMEOUT")
		quit(1)
	)
	_run.call_deferred()

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	root.add_child(viewport)
	var hud = HUD.new()
	viewport.add_child(hud)
	await process_frame
	hud.set_process(false)
	hud.set_screen("play")
	var data := {"mode": "survival", "oxygen": 80.0, "max_oxygen": 90.0,
		"health": 100.0, "current_weapon": "knife", "inventory": {"titanium": 2}}
	hud.update_hud(data)
	hud._process(4.0)
	hud.update_hud(data)
	assert(not hud._cargo.visible and not hud.mission_title.visible and not hud.reticle.visible)
	assert(hud.oxygen_value.is_visible_in_tree() and hud.health_value.is_visible_in_tree())
	# Resizing must not resurrect expired contextual panels.
	viewport.size = Vector2i(1920, 1080)
	await process_frame
	hud._apply_layout()
	assert(not hud._cargo.visible and not hud.explore_summary_label.visible)
	data["oxygen"] = 8.0
	data["health"] = 15.0
	data["boss"] = {"active": true, "name": "深渊水龙", "health": 650.0, "max_health": 1800.0}
	hud.update_hud(data)
	hud.toast("发现新的科考地标 · 已记录海图与航向")
	hud._process(0.1)
	assert(hud.status_value.text.contains("氧气不足"))
	assert(hud.boss_panel.is_visible_in_tree() and hud.toast_label.is_visible_in_tree())
	assert(not hud.toast_label.get_global_rect().intersects(hud.boss_panel.get_global_rect()))
	assert(not hud.toast_label.get_global_rect().intersects(hud.status_value.get_global_rect()))
	hud._process(4.0)
	assert(not hud.toast_label.visible, "Expired discovery feedback must disappear")
	assert(hud.status_value.is_visible_in_tree() and hud.boss_panel.is_visible_in_tree())
	# Craft/shop actions must retain their feedback instead of hiding next frame.
	hud.set_screen("craft")
	hud.toast("已装备高容量氧气瓶")
	hud._process(0.1)
	assert(hud.toast_label.is_visible_in_tree())
	hud.set_screen("pause")
	assert(not hud.toast_label.visible)
	viewport.free()
	print("PASS: quiet exploration, resize persistence, low-O2/Boss/discovery separation and feedback expiry")
	quit()
