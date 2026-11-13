extends RefCounted
## Pearl type, ocean glass and fine gold inlays shared by every expedition screen.

const Art = preload("res://scripts/art_direction.gd")

static func surface(background: Color, border: Color = Color.TRANSPARENT, radius: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.01, 0.025, 0.035, 0.14)
	style.shadow_size = 8 if background.a > 0.8 else 0
	style.shadow_offset = Vector2(0, 3)
	return style

static func build(font: Font) -> Theme:
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 15
	theme.set_color("font_color", "Label", Art.PAPER)
	theme.set_color("font_color", "Button", Art.PAPER)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Art.MUTED.darkened(0.1))
	theme.set_stylebox("panel", "Panel", surface(Art.PANEL, Color(Art.CYAN, 0.10)))
	return theme

static func button(control: Button, primary: bool) -> void:
	control.add_theme_font_size_override("font_size", 15)
	control.add_theme_color_override("font_color", Art.AMBER if primary else Art.PAPER)
	control.add_theme_color_override("font_hover_color", Art.INK if primary else Color.WHITE)
	control.add_theme_color_override("font_pressed_color", Art.INK if primary else Art.PAPER)
	control.add_theme_color_override("font_disabled_color", Color(Art.MUTED, 0.65))
	control.add_theme_stylebox_override("normal", surface(Color(Art.AMBER, 0.08) if primary else Color(0.035, 0.14, 0.20, 0.32), Color(Art.AMBER, 0.64) if primary else Color(Art.CYAN, 0.16)))
	control.add_theme_stylebox_override("hover", surface(Art.AMBER if primary else Color(0.10, 0.30, 0.36, 0.92), Color(Art.AMBER, 0.9) if primary else Color(Art.CYAN, 0.65)))
	control.add_theme_stylebox_override("pressed", surface(Art.AMBER.darkened(0.1) if primary else Art.INK, Art.CYAN))
	control.add_theme_stylebox_override("disabled", surface(Color(0.06, 0.115, 0.15, 0.65), Color(Art.MUTED, 0.10)))
	control.add_theme_stylebox_override("focus", surface(Color.TRANSPARENT, Art.PAPER))

class ExpeditionPlate extends Control:
	## A restrained constellation, echoing the sunken observatory's gold inlays.
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var center := Vector2(size.x * 0.57, size.y * 0.50)
		var span := minf(size.x, size.y) * 0.34
		for ring in range(4):
			var points := PackedVector2Array()
			for segment in range(97):
				var angle := float(segment) / 96.0 * TAU
				var radius := span * (0.34 + ring * 0.084)
				radius *= 1.0 + 0.035 * sin(angle * 3.0 + ring * 0.22)
				points.append(center + Vector2(cos(angle) * radius, sin(angle) * radius * 0.91))
			draw_polyline(points, Color(Art.PAPER, 0.07), 1.0, true)
		draw_line(center + Vector2(-span * 1.25, 0), center + Vector2(span * 1.25, 0), Color(Art.CYAN, 0.08), 1.0)
		draw_line(center + Vector2(0, -span * 1.2), center + Vector2(0, span * 1.2), Color(Art.CYAN, 0.08), 1.0)
		var path := PackedVector2Array([center + Vector2(-span * 0.45, span * 0.36), center + Vector2(-span * 0.05, span * 0.08), center + Vector2(span * 0.2, -span * 0.42)])
		draw_polyline(path, Color(Art.AMBER, 0.48), 1.0, true)
		for point in path:
			draw_circle(point, 3.0, Art.AMBER)
			draw_circle(point, 7.0, Color(Art.AMBER, 0.18), false, 1.0, true)
