extends Control


#  DON'T BLOCK ME 
# PALETTE 
const C_BG         := Color(0.015, 0.015, 0.022)
const C_PANEL      := Color(0.045, 0.050, 0.062)
const C_BORDER     := Color(0.10,  0.55,  0.38,  0.55)
const C_ACCENT     := Color(0.10,  0.82,  0.50)
const C_ACCENT_DIM := Color(0.04,  0.25,  0.16)
const C_TEXT       := Color(0.68,  0.88,  0.74)
const C_MUTED      := Color(0.20,  0.32,  0.26)
const C_RED        := Color(0.88,  0.16,  0.16)
const C_RED_DIM    := Color(0.28,  0.05,  0.05)
const C_EYE        := Color(0.75,  0.05,  0.05)
const C_TERM_GREEN := Color(0.2,   0.9,   0.2)
const C_FAN        := Color(0.15,  0.15,  0.18)
const WIN_ROUND    := 50

# DEVICE / MESSAGE DATA 
var safe_devices: Array[String] = [
	"ROUTER-01","LAPTOP-HOME","PHONE","SMART-TV","TABLET-A3",
	"PRINTER-LAN","NAS-DRIVE","DESKTOP-PC","WORKSTATION","SWITCH-02",
	"GATEWAY-X","RASPI-03","CAM-FRONT","CAM-BACK","DOORBELL",
	"THERMOSTAT","SPEAKER","WATCH","FRIDGE-NET","LOCK-MAIN","SMART-LIGHTS"
]
var terminal_msgs: Array[String] = [
	"Pinging subnet...","Packet loss: 0.01%.","Establishing handshake...",
	"Firewall rules updated.","Port 80 closed.","Scanning TCP...",
	"Verifying MAC tables...","DHCP lease renewed.","ARP cache flushed.",
	"Routing table stable.","NAT traversal OK.","Link state: UP."
]
var creepy_terminal_msgs: Array[String] = [
	"CRITICAL_PROCESS_DIED: shadow_service.exe found a listener.",
	"ERR: Mirror node refused termination.",
	"Packet intercepted by UNKNOWN.",
	"WARN: It is learning your patterns.",
	"Too many open ports. They are inside.",
	"SYS_HALT: Do you hear the fan?",
	"It sees your cursor.",
	"Dont. Block. Me.",
	"WARN: Breathing detected on localhost.",
	"ERR: Your device has been indexed.",
	"It has been here since boot.",
	"Ping reply from 0.0.0.0: something answered."
]

# GAME STATE 
var fake_index:   int   = 0
var score:        int   = 0
var round_number: int   = 0
var mistake_count:int   = 0
var game_active:  bool  = false
var device_count: int   = 3
var horror_level: float = 0.0

# UI NODES 
var bg_rect:        ColorRect
var start_screen:   Control
var fan_root:       Node2D
var hidden_text:    Label
var scanline_rect:  ColorRect
var ca_rect:        ColorRect
var eye_root:       Node2D
var title_label:    Label
var subtitle_label: Label
var score_label:    Label
var round_label:    Label
var threat_bar:     ProgressBar
var panel:          PanelContainer
var panel_vbox:     VBoxContainer
var terminal_log:   RichTextLabel
var buttons:        Array[Button] = []
var bios_root:      ColorRect
var bios_text:      RichTextLabel
var win_root:       ColorRect
var message_label:  Label

# FAN 
var fan_rot:        float = 0.0
var fan_spd:        float = 2.0
var fan_target_spd: float = 2.0

# AUDIO 
var ambient_player: AudioStreamPlayer
var sfx_player:     AudioStreamPlayer
var ambient_gen:    AudioStreamGenerator
var ambient_pb:     AudioStreamGeneratorPlayback
var _phase:         float = 0.0
var _hb_timer:      float = 0.0
var _ambient_vol:   float = 1.0   # multiplier, faded to 0 on BIOS/win

# EYE 
class CreepyEye:
	var pos:   Vector2
	var size:  float
	var alpha: float
	var drift: Vector2
	var veins: Array[Vector2] = []
	func _init(p: Vector2, s: float) -> void:
		pos = p; size = s; alpha = 0.0; drift = Vector2.ZERO
		for _i in 12:
			var a := randf() * TAU
			veins.append(Vector2(cos(a), sin(a)) * s * randf_range(0.6, 1.7))

var _eyes: Array[CreepyEye] = []

func _ready() -> void:
	randomize()
	_build_ui()
	_build_start_screen()
	_build_audio()
	_start_ambient()
	
#  UI BUILD
func _build_ui() -> void:
	bg_rect = ColorRect.new()
	bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_rect.color = C_BG
	add_child(bg_rect)

	fan_root = Node2D.new()
	fan_root.connect("draw", _draw_fan)
	add_child(fan_root)

	hidden_text = Label.new()
	hidden_text.text = "I  A M  W A T C H I N G  Y O U"
	hidden_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hidden_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hidden_text.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	hidden_text.add_theme_font_size_override("font_size", 80)
	hidden_text.add_theme_color_override("font_color", Color(0,0,0,0))
	add_child(hidden_text)

	eye_root = Node2D.new()
	eye_root.connect("draw", _draw_eyes)
	add_child(eye_root)

	var ui_layer := Control.new()
	ui_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ui_layer)

	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.add_theme_constant_override("separation", 10)
	ui_layer.add_child(outer)

	# Header
	var header := VBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(header)

	title_label = _make_label("Don't Block Me.", 32, C_ACCENT)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)

	subtitle_label = _make_label("identify and remove the suspicious device", 11, C_MUTED)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(subtitle_label)

	# Status bar
	var sp0 := Control.new(); sp0.custom_minimum_size = Vector2(0,10)
	outer.add_child(sp0)
	var status := HBoxContainer.new()
	status.alignment = BoxContainer.ALIGNMENT_CENTER
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_theme_constant_override("separation", 24)
	outer.add_child(status)

	score_label = _make_label("SCORE  0", 13, C_TEXT)
	status.add_child(score_label)
	round_label = _make_label("ROUND  1", 13, C_MUTED)
	status.add_child(round_label)

	var threat_row := HBoxContainer.new()
	threat_row.alignment = BoxContainer.ALIGNMENT_CENTER
	status.add_child(threat_row)
	threat_row.add_child(_make_label("THREAT ", 10, C_MUTED))
	threat_bar = ProgressBar.new()
	threat_bar.custom_minimum_size = Vector2(96, 7)
	threat_bar.show_percentage = false
	threat_bar.add_theme_stylebox_override("fill",       _make_sb(C_RED))
	threat_bar.add_theme_stylebox_override("background", _make_sb(C_RED_DIM))
	threat_row.add_child(threat_bar)

	# Main split: device panel + terminal
	var sp1 := Control.new(); sp1.custom_minimum_size = Vector2(0,8)
	outer.add_child(sp1)
	var main_split := HBoxContainer.new()
	main_split.alignment = BoxContainer.ALIGNMENT_CENTER
	main_split.add_theme_constant_override("separation", 18)
	outer.add_child(main_split)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_restyle_panel(0.0)
	main_split.add_child(panel)
	panel_vbox = VBoxContainer.new()
	panel_vbox.add_theme_constant_override("separation", 8)
	panel.add_child(panel_vbox)
	var ptitle := _make_label("── CONNECTED DEVICES ──", 10, C_MUTED)
	ptitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_vbox.add_child(ptitle)
	var sep_sb := StyleBoxFlat.new()
	sep_sb.bg_color = C_ACCENT_DIM; sep_sb.content_margin_top = 1
	var sep_line := HSeparator.new()
	sep_line.add_theme_stylebox_override("separator", sep_sb)
	panel_vbox.add_child(sep_line)

	# Terminal
	var term_panel := PanelContainer.new()
	term_panel.custom_minimum_size = Vector2(300, 240)
	term_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var term_sb := StyleBoxFlat.new()
	term_sb.bg_color = Color(0.005, 0.005, 0.01)
	term_sb.set_border_width_all(1)
	term_sb.border_color = Color(0.04, 0.18, 0.04)
	term_sb.set_corner_radius_all(4)
	term_panel.add_theme_stylebox_override("panel", term_sb)
	main_split.add_child(term_panel)
	terminal_log = RichTextLabel.new()
	terminal_log.bbcode_enabled   = true
	terminal_log.scroll_following = true
	terminal_log.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["JetBrains Mono","Consolas","Courier New","monospace"])
	terminal_log.add_theme_font_override("normal_font", mono)
	terminal_log.add_theme_font_size_override("normal_font_size", 12)
	term_panel.add_child(terminal_log)

	# Message + chromatic aberration + scanline
	var sp2 := Control.new(); sp2.custom_minimum_size = Vector2(0,8)
	outer.add_child(sp2)
	message_label = _make_label("", 13, C_ACCENT)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(message_label)

	# CA lives in its own CanvasLayer so it composites over the entire scene.
	# Without this, hint_screen_texture on a plain Control child doesn't reliably
	# capture all children rendered before it in Godot 4.
	var ca_layer := CanvasLayer.new()
	ca_layer.layer = 10          # above everything else
	add_child(ca_layer)
	ca_rect = ColorRect.new()
	ca_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ca_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ca_mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	float r = texture(screen_texture, uv + vec2(amount,  0.0)).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, uv - vec2(amount,  0.0)).b;
	// Also shift vertically by half amount for a more organic feel
	r = mix(r, texture(screen_texture, uv + vec2(amount, amount * 0.4)).r, 0.4);
	b = mix(b, texture(screen_texture, uv - vec2(amount, amount * 0.4)).b, 0.4);
	COLOR = vec4(r, g, b, 1.0);
}"""
	ca_mat.shader = shader
	ca_rect.material = ca_mat
	ca_layer.add_child(ca_rect)

	scanline_rect = ColorRect.new()
	scanline_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scanline_rect.color = Color(0,0,0,0.10)
	scanline_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scanline_rect)

	# BIOS game-over screen
	bios_root = ColorRect.new()
	bios_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bios_root.color = Color(0.0, 0.0, 0.06)
	bios_root.hide()
	add_child(bios_root)
	var bvbox := VBoxContainer.new()
	bvbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bvbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bvbox.add_theme_constant_override("separation", 20)
	bios_root.add_child(bvbox)
	bios_text = RichTextLabel.new()
	bios_text.bbcode_enabled = true
	bios_text.custom_minimum_size = Vector2(620, 420)
	bios_text.add_theme_font_override("normal_font", mono)
	bios_text.add_theme_font_size_override("normal_font_size", 13)
	bios_text.add_theme_color_override("default_color", Color(0.72, 0.72, 0.72))
	bvbox.add_child(bios_text)
	var rb := Button.new()
	rb.text = "[ REBOOT SYSTEM ]"
	rb.custom_minimum_size = Vector2(220, 50)
	rb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_button(rb, true)
	rb.pressed.connect(_on_restart_pressed)
	bvbox.add_child(rb)

	# WIN screen
	win_root = ColorRect.new()
	win_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win_root.color = Color(0.0, 0.0, 0.0)
	win_root.hide()
	add_child(win_root)
	var wvbox := VBoxContainer.new()
	wvbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wvbox.alignment = BoxContainer.ALIGNMENT_CENTER
	wvbox.add_theme_constant_override("separation", 22)
	win_root.add_child(wvbox)
	var wt1 := _make_label("LISTENER TERMINATED.", 36, C_ACCENT)
	wt1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wvbox.add_child(wt1)
	var wt2 := _make_label("Network is silent.\nAll anomalous nodes have been purged.\nYou are the last connection.", 15, C_TEXT)
	wt2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wvbox.add_child(wt2)
	var wt3 := _make_label("...or so you think.", 13, C_MUTED)
	wt3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wvbox.add_child(wt3)
	var wr := Button.new()
	wr.text = "[ DISCONNECT ]"
	wr.custom_minimum_size = Vector2(220, 50)
	wr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_button(wr, false)
	wr.pressed.connect(_on_restart_pressed)
	wvbox.add_child(wr)

	_rebuild_buttons(3)

	# Timers
	_make_timer(0.09, _on_glitch_tick)
	_make_timer(2.8,  _on_flicker_tick)
	_make_timer(1.2,  _on_log_tick)

#  START SCREEN
func _build_start_screen() -> void:
	start_screen = ColorRect.new()
	start_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	start_screen.color = C_BG
	add_child(start_screen)

	# Subtle scanline on start screen too
	var sc := ColorRect.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.color = Color(0,0,0,0.08)
	sc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_screen.add_child(sc)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	start_screen.add_child(vbox)

	# Top bar: simulated terminal prompt
	var prompt := _make_label("root@localhost:~# ./dont_block_me --start", 11, C_MUTED)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(prompt)

	var sep_label := _make_label("────────────────────────────────────────", 11, C_ACCENT_DIM)
	sep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sep_label)

	var title := _make_label("Don't Block Me.", 52, C_ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var tagline := _make_label("Something is connected that should not be.", 13, C_MUTED)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(tagline)

	var sp := Control.new(); sp.custom_minimum_size = Vector2(0,14)
	vbox.add_child(sp)

	# Info box
	var info_wrap := HBoxContainer.new()
	info_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(info_wrap)
	var info_box := PanelContainer.new()
	info_box.custom_minimum_size = Vector2(380, 0)
	var ib_sb := StyleBoxFlat.new()
	ib_sb.bg_color = C_PANEL
	ib_sb.set_border_width_all(1)
	ib_sb.border_color = C_ACCENT_DIM
	ib_sb.set_corner_radius_all(5)
	ib_sb.set_content_margin_all(16)
	info_box.add_theme_stylebox_override("panel", ib_sb)
	info_wrap.add_child(info_box)
	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 7)
	info_box.add_child(info_vbox)
	for line in [
		"[OBJECTIVE]  Block the suspicious device each round.",
		"[RULES]      3 mistakes disconnects you permanently.",
		"[WARNING]    The network adapts. Do not trust names.",
		"[GOAL]       Survive 50 rounds. Terminate the Listener."
	]:
		var lbl := _make_label(line, 11, C_MUTED)
		info_vbox.add_child(lbl)

	var sp2 := Control.new(); sp2.custom_minimum_size = Vector2(0,10)
	vbox.add_child(sp2)

	var play_btn := Button.new()
	play_btn.text = "CONNECT TO NETWORK"
	play_btn.custom_minimum_size = Vector2(260, 58)
	play_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_button(play_btn, false)
	play_btn.pressed.connect(func():
		var tw := create_tween()
		tw.tween_property(start_screen, "modulate:a", 0.0, 0.6)
		await tw.finished
		start_screen.hide()
		_start_game()
	)
	vbox.add_child(play_btn)

	var ver := _make_label("v1.0.0  //  DON'T BLOCK ME  //  NETWORK HORROR", 9, Color(C_MUTED.r, C_MUTED.g, C_MUTED.b, 0.45))
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(ver)

# ───────────────────────────────────────────────────────────────────────
#  HELPERS
# ───────────────────────────────────────────────────────────────────────
func _make_sb(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c; sb.set_corner_radius_all(2)
	return sb

func _make_timer(wait: float, cb: Callable) -> Timer:
	var t := Timer.new()
	t.wait_time = wait; t.autostart = true
	t.timeout.connect(cb)
	add_child(t)
	return t

func _make_label(txt: String, size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	return lbl

func _make_timer_oneshot(wait: float, cb: Callable) -> void:
	var t := Timer.new()
	t.wait_time = wait; t.one_shot = true
	t.timeout.connect(cb)
	t.timeout.connect(t.queue_free)
	add_child(t)
	t.start()

func _rebuild_buttons(count: int) -> void:
	for child in panel_vbox.get_children():
		if child is Button:
			panel_vbox.remove_child(child)
			child.free()
	buttons.clear()
	for i in count:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(320, 50)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_button(btn, false)
		panel_vbox.add_child(btn)
		buttons.append(btn)

func _restyle_panel(hl: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_PANEL
	sb.set_border_width_all(1)
	sb.border_color = C_BORDER.lerp(C_RED, hl * 0.85)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)

func _style_button(btn: Button, danger: bool) -> void:
	var accent := C_RED     if danger else C_ACCENT
	var dim    := C_RED_DIM if danger else C_ACCENT_DIM
	var text_c := Color(1.0,0.65,0.65) if danger else C_TEXT
	btn.add_theme_color_override("font_color",         text_c)
	btn.add_theme_color_override("font_hover_color",   accent)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 12)
	for state in ["normal","hover","pressed","disabled","focus"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(4)
		sb.set_content_margin_all(10)
		match state:
			"normal":   sb.bg_color=C_PANEL;                sb.set_border_width_all(1); sb.border_color=dim
			"hover":    sb.bg_color=dim;                    sb.set_border_width_all(1); sb.border_color=accent
			"pressed":  sb.bg_color=accent;                 sb.set_border_width_all(1); sb.border_color=accent
			"disabled": sb.bg_color=Color(0.025,0.025,0.032); sb.set_border_width_all(1); sb.border_color=Color(0.07,0.07,0.09)
			"focus":    sb.bg_color=C_PANEL;                sb.set_border_width_all(1); sb.border_color=accent
		btn.add_theme_stylebox_override(state, sb)

# ───────────────────────────────────────────────────────────────────────
#  GAME LOGIC
# ───────────────────────────────────────────────────────────────────────
func _start_game() -> void:
	score=0; round_number=0; mistake_count=0; game_active=true
	device_count=3; fan_spd=2.0; fan_target_spd=2.0
	_eyes.clear(); _phase=0.0; _hb_timer=0.0
	_ambient_vol = 1.0
	score_label.text = "SCORE  0"
	message_label.text = ""
	terminal_log.clear()
	bios_root.hide()
	win_root.hide()
	bg_rect.color = C_BG
	_print_log("kernel_init: Network bridge active.", C_TERM_GREEN)
	_rebuild_buttons(device_count)
	title_label.modulate.a = 0.0
	panel.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(title_label, "modulate:a", 1.0, 1.0)
	tw.tween_property(panel,       "modulate:a", 1.0, 1.5).set_delay(0.3)
	new_round()

func new_round() -> void:
	round_number += 1
	round_label.text = "ROUND  " + str(round_number)
	message_label.text = ""

	# Check win condition
	if round_number > WIN_ROUND:
		_trigger_win()
		return

	horror_level = clampf(float(round_number) / float(WIN_ROUND) + mistake_count * 0.15, 0.0, 1.0)
	threat_bar.value = horror_level * 100.0
	bg_rect.color = C_BG.lerp(Color(0.08, 0.0, 0.0), minf(mistake_count * 0.22, 0.7))
	_restyle_panel(horror_level)

	fan_target_spd = 2.0 + horror_level * 18.0

	var new_count := 3
	if round_number >= 5:  new_count = 4
	if round_number >= 10: new_count = 5
	if round_number >= 18: new_count = 6
	if new_count != device_count:
		device_count = new_count
		_rebuild_buttons(device_count)

	if round_number > 6 and randf() < 0.55: _add_eye()

	# Clamp fake_index to actual button count to prevent out-of-bounds skip
	var btn_count := buttons.size()
	if btn_count == 0: return
	fake_index = randi() % btn_count

	var pool: Array[String] = safe_devices.duplicate()
	pool.shuffle()

	for i in btn_count:
		var dname: String = pool[i % pool.size()]
		var is_fake := (i == fake_index)
		if is_fake: dname = _make_fake_name(pool, i, horror_level)

		var mac := "%02X:%02X:%02X:%02X:%02X:%02X" % [
			randi()%256,randi()%256,randi()%256,
			randi()%256,randi()%256,randi()%256]

		# Fake device: always high PL (55-99%) so there's always one clear clue.
		# Real devices: 0-3%. Gap is intentionally wide — the name may be
		# distorted at high horror, but PL is the fallback tell.
		var pl: int = randi_range(55, 99) if is_fake else randi_range(0, 3)

		buttons[i].text = "%s\n[%s | PL:%d%%]" % [dname, mac, pl]
		buttons[i].disabled = false
		buttons[i].modulate = Color.WHITE
		for conn in buttons[i].pressed.get_connections():
			buttons[i].pressed.disconnect(conn.callable)
		buttons[i].pressed.connect(_on_button_pressed.bind(i))

	if fake_index < buttons.size():
		var existing := buttons[fake_index].text
		var guaranteed_pl := randi_range(65, 99)
		var pl_pattern := RegEx.new()
		pl_pattern.compile("PL:\\d+%")
		buttons[fake_index].text = pl_pattern.sub(existing, "PL:%d%%" % guaranteed_pl)

func _make_fake_name(names: Array[String], index: int, hl: float) -> String:
	var victim: String = names[(index + 1) % names.size()]
	if hl < 0.25: return "UNKNOWN_" + str(randi() % 999)
	if hl < 0.55:
		var sfx: String = ["_2","_X","-COPY",".ReaL","_old","~"][randi()%6]
		return victim + sfx
	# Distort characters
	var dist := ""
	for c in victim:
		dist += (["X","?","#","0","_"][randi()%5] if randf() < 0.20 else c)
	return dist

func _on_button_pressed(index: int) -> void:
	if not game_active: return
	if index == fake_index:
		score += 1
		score_label.text = "SCORE  " + str(score)
		message_label.text = "Device terminated."
		message_label.add_theme_color_override("font_color", C_ACCENT)
		_print_log("SUCCESS: Anomalous node blocked.", C_ACCENT)
		_play_sfx("click")
		_flash_buttons_correct(index)
		await get_tree().create_timer(0.45).timeout
		new_round()
	else:
		mistake_count += 1
		_play_sfx("wrong")
		_do_shake(15.0, 0.4)
		_flash_buttons_wrong(index)
		if mistake_count >= 3:
			await get_tree().create_timer(0.3).timeout
			_trigger_bios_game_over()
		else:
			var msgs := ["WARN: That was your device.","ERR: WRONG NODE. Connection breached.","FATAL: Mistake logged. It grows stronger."]
			_print_log(msgs[randi()%3], C_RED)
			message_label.text = ["Wrong device.","That one was yours.","It's still in there."][randi()%3]
			message_label.add_theme_color_override("font_color", C_RED)
			score = maxi(score - 1, 0)
			score_label.text = "SCORE  " + str(score)
			# Add more eyes on mistake
			for _i in range(2 + mistake_count): _add_eye()
			await get_tree().create_timer(1.0).timeout
			new_round()

func _trigger_bios_game_over() -> void:
	game_active = false
	# Fade ambient to silence
	var tw := create_tween()
	tw.tween_method(func(v: float): _ambient_vol = v, 1.0, 0.0, 2.0)

	_play_sfx("gameover")
	_do_shake(20.0, 0.6)
	await get_tree().create_timer(0.5).timeout
	bios_root.show()

	var owned := []
	var pool := safe_devices.duplicate()
	pool.shuffle()
	for i in mini(6, pool.size()): owned.append(pool[i])

	var bios_lines := """[color=#aaaaaa]AMIBIOS(C)2026  American Megatrends Inc.
BIOS Date: 04/27/26  |  Version 6.66

CPU: [color=#ffffff]Unknown Entity[/color] @ 6.66GHz
RAM: [color=#ffffff]???[/color] MB OK

Detecting storage...[/color]
[color=#555555]  Pri Master : [color=#ff3333]THEY_ARE_IN_YOUR_HOUSE[/color]
  Sec Master : [color=#ff3333]IT_FOUND_YOUR_MAC[/color]

[color=#aaaaaa]Detected devices on your network:[/color]"""

	for d in owned:
		bios_lines += "\n[color=#cc4444]  %-20s  [COMPROMISED][/color]" % d

	bios_lines += """

[color=#ff2222]
FATAL ERROR: SYSTEM HAS BEEN COMPROMISED.
The listener was never blocked.
It indexed your devices.
It knows your network.
It is still here.[/color]

[color=#888888]Press [ REBOOT SYSTEM ] to attempt recovery...[/color]"""

	bios_text.bbcode_enabled = true
	bios_text.text = bios_lines

func _trigger_win() -> void:
	game_active = false
	# Fade ambient fully to silence
	var tw := create_tween()
	tw.tween_method(func(v: float): _ambient_vol = v, 1.0, 0.0, 3.0)
	_eyes.clear()
	eye_root.queue_redraw()
	_play_sfx("win")
	await get_tree().create_timer(1.5).timeout
	win_root.modulate.a = 0.0
	win_root.show()
	var wtw := create_tween()
	wtw.tween_property(win_root, "modulate:a", 1.0, 2.0)

func _on_restart_pressed() -> void:
	_ambient_vol = 1.0
	_start_game()

#  VISUALS
func _draw_fan() -> void:
	var screen := get_viewport_rect().size
	var center := Vector2(screen.x * 0.88, screen.y * 0.12)
	var radius  := 58.0
	var alpha   := clampf(fan_spd / 20.0, 0.0, 0.7)
	fan_root.draw_circle(center, radius + 5.0, Color(0.08, 0.08, 0.10, alpha))
	fan_root.draw_circle(center, radius,       Color(0.015, 0.015, 0.02, alpha))
	var pc := PackedColorArray([Color(C_FAN.r,C_FAN.g,C_FAN.b,alpha),
								 Color(C_FAN.r,C_FAN.g,C_FAN.b,alpha),
								 Color(C_FAN.r,C_FAN.g,C_FAN.b,alpha)])
	for i in 4:
		var a := fan_rot + (i * TAU / 4.0)
		fan_root.draw_polygon(PackedVector2Array([
			center,
			center + Vector2(cos(a - 0.28), sin(a - 0.28)) * radius * 0.92,
			center + Vector2(cos(a + 0.28), sin(a + 0.28)) * radius * 0.92
		]), pc)
	fan_root.draw_circle(center, 12.0, Color(C_FAN.r,C_FAN.g,C_FAN.b,alpha))

func _add_eye() -> void:
	var screen := get_viewport_rect().size
	var e := CreepyEye.new(
		Vector2(randf_range(50, screen.x-50), randf_range(50, screen.y-50)),
		randf_range(8.0, 20.0))
	_eyes.append(e)

func _draw_eyes() -> void:
	var m := get_local_mouse_position()
	for e in _eyes:
		if e.alpha <= 0.01: continue
		var dir := (m - e.pos).normalized()
		e.drift = dir * (e.size * 0.38)
		var a   := e.alpha
		eye_root.draw_circle(e.pos, e.size * 1.9, Color(0,0,0, a * 0.55))
		eye_root.draw_circle(e.pos, e.size,        Color(0.88, 0.82, 0.82, a))
		for v in e.veins:
			eye_root.draw_line(e.pos + v*0.3, e.pos + v, Color(0.55,0.0,0.0, a*0.65), 1.1)
		eye_root.draw_circle(e.pos + e.drift, e.size*0.55, Color(C_EYE.r,0.04,0.04,a))
		var pp := e.pos + e.drift
		eye_root.draw_rect(
			Rect2(pp.x - e.size*0.08, pp.y - e.size*0.42, e.size*0.16, e.size*0.84),
			Color(0,0,0,a))

func _flash_buttons_correct(idx: int) -> void:
	buttons[idx].modulate = C_ACCENT
	var tw := create_tween()
	tw.tween_property(buttons[idx], "modulate", Color.WHITE, 0.5)

func _flash_buttons_wrong(idx: int) -> void:
	buttons[idx].modulate = C_RED
	var tw := create_tween()
	tw.tween_property(buttons[idx], "modulate", Color.WHITE, 0.6)

func _do_shake(strength: float, duration: float) -> void:
	var orig := position
	var tw   := create_tween()
	for _i in int(duration / 0.04):
		tw.tween_property(self, "position",
			orig + Vector2(randf_range(-strength,strength), randf_range(-strength,strength)), 0.04)
	tw.tween_property(self, "position", orig, 0.06)

func _on_glitch_tick() -> void:
	if not game_active or buttons.is_empty(): return
	if horror_level < 0.18 or randf() > horror_level * 0.55: return
	var target      := randi() % buttons.size()
	var orig        := buttons[target].text
	var snap_round  := round_number          # snapshot — if round changes, discard restore
	buttons[target].text = "ERR 0x%04X" % (randi() % 0xFFFF)
	await get_tree().create_timer(0.08).timeout
	# Only restore if we're still in the same round AND button still exists
	if is_instance_valid(buttons[target]) and round_number == snap_round:
		buttons[target].text = orig

func _on_flicker_tick() -> void:
	if not game_active: return
	var tw := create_tween()
	tw.tween_property(title_label, "modulate:a", 0.2,  0.04)
	tw.tween_property(title_label, "modulate:a", 1.0,  0.18)

func _on_log_tick() -> void:
	if not game_active: return
	if horror_level > 0.35 and randf() < horror_level:
		_print_log(creepy_terminal_msgs.pick_random(), C_RED)
	else:
		_print_log(terminal_msgs.pick_random(), C_TERM_GREEN)

func _print_log(msg: String, color: Color) -> void:
	terminal_log.append_text("[color=#%s]> %s[/color]\n" % [color.to_html(false), msg])

func _process(delta: float) -> void:
	_fill_ambient()
	fan_spd = move_toward(fan_spd, fan_target_spd, delta * 4.0)
	fan_rot += fan_spd * delta
	fan_root.queue_redraw()

	if horror_level > 0.45 and randf() < 0.10:
		hidden_text.add_theme_color_override("font_color",
			Color(0.45, 0.0, 0.0, randf_range(0.06, 0.38)))
	else:
		hidden_text.add_theme_color_override("font_color", Color(0,0,0,0))

	for e in _eyes: e.alpha = move_toward(e.alpha, 0.88, 0.55 * delta)
	eye_root.queue_redraw()
	scanline_rect.color.a = 0.06 + sin(Time.get_ticks_msec() * 0.0025) * 0.022
	# Base flicker so CA is always subtly present; ramps hard with horror
	var ca_base  := 0.003
	var ca_scale := horror_level * 0.022
	var ca_noise := randf() * 0.008 * horror_level
	ca_rect.material.set_shader_parameter("amount",
		(ca_base + ca_scale + ca_noise) * _ambient_vol)

#  AUDIO ENGINE
func _build_audio() -> void:
	ambient_gen             = AudioStreamGenerator.new()
	ambient_gen.mix_rate    = 22050.0
	ambient_gen.buffer_length = 0.25
	ambient_player          = AudioStreamPlayer.new()
	ambient_player.stream   = ambient_gen
	ambient_player.volume_db = -10.0
	add_child(ambient_player)
	sfx_player = AudioStreamPlayer.new()
	sfx_player.volume_db = -4.0
	add_child(sfx_player)

func _start_ambient() -> void:
	ambient_player.play()
	ambient_pb = ambient_player.get_stream_playback()

func _fill_ambient() -> void:
	if ambient_pb == null: return
	var avail := ambient_pb.get_frames_available()

	# Heartbeat BPM: starts at 48, climbs to 130 at max horror
	var bpm          := 48.0 + horror_level * 82.0 + mistake_count * 22.0
	var hb_interval  := 60.0 / bpm

	for _i in avail:
		_phase    += 1.0 / 22050.0
		_hb_timer += 1.0 / 22050.0
		if _hb_timer >= hb_interval:
			_hb_timer -= hb_interval

		# ── Drone ──
		var drone := sin(TAU * 48.0  * _phase) * 0.18
		drone     += sin(TAU * 96.2  * _phase) * 0.09   # detuned octave → beats
		drone     += sin(TAU * 72.0  * _phase) * 0.07
		drone     += sin(TAU * 24.0  * _phase) * 0.06
		drone     *= (0.50 + 0.50 * sin(TAU * 0.08 * _phase))

		# ── Fan hiss ── fades with _ambient_vol so it's silent on BIOS
		var fan_hiss := (randf() - 0.5) * (fan_spd / 45.0) * _ambient_vol

		# ── Electrical hiss ──
		var hiss := (randf() - 0.5) * 0.010

		# ── Realistic two-thump heartbeat (LUB-DUB) ──
		# Systole LUB  : 0.00 – 0.12s  (sharp, louder)
		# Gap          : 0.12 – 0.22s
		# Diastole DUB : 0.22 – 0.32s  (softer, higher pitch)
		var hb := 0.0
		var hb_vol := clampf(horror_level * 1.4 + mistake_count * 0.35, 0.0, 1.2)
		if _hb_timer < 0.12:
			# LUB — deeper thump using 38Hz + body resonance
			var t2 := _hb_timer / 0.12
			var env := sin(PI * t2)
			hb = sin(TAU * 38.0 * _hb_timer) * env * 0.85
			hb += sin(TAU * 80.0 * _hb_timer) * env * 0.25
			hb += (randf()-0.5) * env * 0.08
		elif _hb_timer > 0.22 and _hb_timer < 0.32:
			# DUB — slightly higher, softer
			var t2 := (_hb_timer - 0.22) / 0.10
			var env := sin(PI * t2)
			hb = sin(TAU * 46.0 * (_hb_timer - 0.22)) * env * 0.55
			hb += sin(TAU * 95.0 * (_hb_timer - 0.22)) * env * 0.15
			hb += (randf()-0.5) * env * 0.05

		var s := (drone * 0.5 + fan_hiss + hiss + hb * hb_vol) * _ambient_vol
		ambient_pb.push_frame(Vector2(s, s))

func _play_sfx(type: String) -> void:
	var sr   := 22050
	var dur  := 0.5
	var data := PackedFloat32Array()

	match type:
		"click":
			dur = 0.35; data.resize(int(sr * dur))
			for i in data.size():
				var t    := float(i) / sr
				var freq: float = lerp(88.0, 18.0, t / dur)
				data[i]   = sin(TAU * freq * t) * exp(-t * 14.0) * 0.75

		"wrong":
			dur = 0.90; data.resize(int(sr * dur))
			for i in data.size():
				var t    := float(i) / sr
				var freq: float = lerp(120.0, 14.0, t / dur)
				data[i]   = sin(TAU * freq * t) * exp(-t * 5.5) * 0.85
				data[i]  += (randf()-0.5) * exp(-t*3.0) * 0.12

		"gameover":
			dur = 2.2; data.resize(int(sr * dur))
			for i in data.size():
				var t    := float(i) / sr
				var slam := exp(-t * 10.0)
				data[i]  = sin(TAU * 42.0 * t) * slam * 0.55
				data[i] += (randf()-0.5) * slam * 0.18
				var swell_env: float = clamp((t-0.05)*2.0, 0.0, 1.0) * exp(-(t-0.1)*1.6)
				data[i] += sin(TAU * 110.0 * t) * swell_env * 0.22
				data[i] += sin(TAU * 146.8 * t) * swell_env * 0.18
				data[i]  = clamp(data[i], -1.0, 1.0)

		"win":
			# Eerie ascending chord, like a signal finally going quiet
			dur = 3.5; data.resize(int(sr * dur))
			for i in data.size():
				var t    := float(i) / sr
				var fade := exp(-t * 0.9)
				# Major 7th chord: C3-E3-G3-B3 (261, 329, 392, 493 Hz) — unsettlingly pretty
				data[i]  = sin(TAU * 130.8 * t) * fade * 0.30
				data[i] += sin(TAU * 164.8 * t) * fade * 0.22
				data[i] += sin(TAU * 196.0 * t) * fade * 0.18
				data[i] += sin(TAU * 246.9 * t) * fade * 0.14
				# Faint high harmonic shimmer
				data[i] += sin(TAU * 523.2 * t) * exp(-t * 2.5) * 0.06
				data[i]  = clamp(data[i], -1.0, 1.0)

	if data.size() == 0: return
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = float(sr); gen.buffer_length = dur + 0.06
	sfx_player.stream = gen; sfx_player.play()
	var pb: AudioStreamGeneratorPlayback = sfx_player.get_stream_playback()
	if pb:
		for i in data.size(): pb.push_frame(Vector2(data[i], data[i])) 
												   
		# gulu gulu  
