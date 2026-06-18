class_name UIKit
## Shared UI palette + factory helpers.
## Style: illuminated manuscript meets apocalyptic tactical interface.

const GOLD := Color(0.85, 0.72, 0.38)
const OBSIDIAN := Color(0.07, 0.06, 0.09)
const CRIMSON := Color(0.62, 0.13, 0.13)
const LAPIS := Color(0.2, 0.32, 0.58)
const ASH := Color(0.55, 0.52, 0.5)
const BRONZE := Color(0.6, 0.42, 0.2)
const STARFIRE := Color(0.45, 0.75, 1.0)
const PARCHMENT := Color(0.92, 0.86, 0.7)

static func panel_style(bg := Color(0.07, 0.06, 0.09, 0.94), border := GOLD, border_w := 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 2)
	return sb

static func text_scale() -> float:
	# Accessibility text scale, applied to every UIKit-built label/button.
	return clampf(float(Game.setting("text_scale")), 0.7, 2.0)

static func scaled(size: int) -> int:
	return int(round(float(size) * text_scale()))

static func label(text: String, size := 16, color := PARCHMENT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", scaled(size))
	l.add_theme_color_override("font_color", color)
	return l

static func title(text: String, size := 30, color := GOLD) -> Label:
	var l := label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	return l

static func button(text: String, size := 18) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", scaled(size))
	b.add_theme_color_override("font_color", PARCHMENT)
	b.add_theme_color_override("font_hover_color", GOLD.lightened(0.2))
	b.add_theme_color_override("font_focus_color", GOLD.lightened(0.2))
	b.add_theme_color_override("font_pressed_color", GOLD)
	var normal := panel_style(Color(0.1, 0.09, 0.12, 0.95), Color(0.4, 0.34, 0.22), 1)
	var hover := panel_style(Color(0.14, 0.12, 0.15, 0.97), GOLD, 2)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", panel_style(Color(0.18, 0.15, 0.12, 1.0), GOLD, 2))
	b.pressed.connect(func(): AudioMan.play("ui"))
	return b

static func vbox(sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func panel(border := GOLD) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(Color(0.07, 0.06, 0.09, 0.94), border))
	return p

static func dim_layer() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.02, 0.02, 0.04, 0.78)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	return r

static func center() -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	return c
