class_name DiamondShop
extends Control

## In-game diamond shop screen.
## Shows purchasable packs, watch-ad reward, and current diamond balance.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal purchase_requested(pack_id: String)
signal watch_ad_requested
signal back_pressed

# ---------------------------------------------------------------------------
# Diamond pack definitions
# ---------------------------------------------------------------------------

const PACKS: Array = [
	{"id": "small",   "diamonds": 500,  "price_label": "$0.99"},
	{"id": "medium",  "diamonds": 2000, "price_label": "$3.99"},
	{"id": "large",   "diamonds": 5000, "price_label": "$7.99"},
	{"id": "doubler",  "diamonds": 0,    "price_label": "$4.99"},  # Diamond doubler
	{"id": "no_ads",   "diamonds": 0,    "price_label": "$1.99"},  # Remove ads
	{"id": "speed_x2", "diamonds": 500,  "price_label": "500 ◆"},  # x2 speed (diamond purchase)
	{"id": "speed_x3", "diamonds": 0,    "price_label": "$0.99"},  # x3 speed (IAP)
]

# ---------------------------------------------------------------------------
# Node refs
# ---------------------------------------------------------------------------

var _diamonds_label: Label
var _ad_btn: Button
var _confirm_overlay: PanelContainer
var _confirm_label: Label
var _pending_pack_id: String = ""
var _pack_buttons: Dictionary = {}  # pack_id -> Button

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_layout()


func _build_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Dark background
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.03, 0.06, 0.95)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.custom_minimum_size = Vector2(400, 0)
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	# Title — gold color
	var title := Label.new()
	title.text = tr("UI_DIAMOND_SHOP")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
	vbox.add_child(title)

	# Current diamonds — cyan color
	_diamonds_label = Label.new()
	_diamonds_label.text = tr("UI_DIAMONDS") + ": 0"
	_diamonds_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_diamonds_label.add_theme_font_size_override("font_size", 18)
	_diamonds_label.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	vbox.add_child(_diamonds_label)

	# Calculate best diamonds-per-dollar ratio for highlighting
	var best_ratio: float = 0.0
	var best_pack_id: String = ""
	for pack in PACKS:
		var diamonds: int = pack["diamonds"] as int
		if diamonds <= 0:
			continue
		var price_str: String = (pack["price_label"] as String).replace("$", "")
		var price: float = price_str.to_float()
		if price > 0.0:
			var ratio: float = float(diamonds) / price
			if ratio > best_ratio:
				best_ratio = ratio
				best_pack_id = pack["id"] as String

	# Pack buttons — card-style rows
	for pack in PACKS:
		var card := PanelContainer.new()
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.06, 0.06, 0.1, 0.7)
		card_style.border_color = Color(0.2, 0.3, 0.4, 0.5)
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(4)
		card_style.set_content_margin_all(8)
		card.add_theme_stylebox_override("panel", card_style)
		vbox.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)

		var lbl := Label.new()
		if pack["id"] == "no_ads":
			lbl.text = tr("NO_ADS")
		elif pack["id"] == "doubler":
			lbl.text = tr("DIAMOND_DOUBLER")
		elif pack["id"] == "speed_x2":
			lbl.text = tr("SPEED_X2")
		elif pack["id"] == "speed_x3":
			lbl.text = tr("SPEED_X3")
		else:
			lbl.text = "+%d ♦" % (pack["diamonds"] as int)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
		row.add_child(lbl)

		var pid: String = pack["id"] as String

		# Highlight best value pack
		if pid == best_pack_id:
			var best_label := Label.new()
			best_label.text = tr("UI_BEST_VALUE")
			best_label.add_theme_font_size_override("font_size", 14)
			best_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
			row.add_child(best_label)

		var btn := Button.new()
		btn.text = pack["price_label"] as String
		btn.custom_minimum_size = Vector2(100, 48)
		btn.add_theme_font_size_override("font_size", 18)
		btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
		btn.pressed.connect(func() -> void:
			AudioManager.play_ui_click()
			_on_purchase_pressed(pid)
		)
		_pack_buttons[pid] = btn
		row.add_child(btn)

	# Watch ad button — green tint
	_ad_btn = Button.new()
	_ad_btn.text = tr("WATCH_AD").replace("{0}", str(Constants.DIAMONDS_PER_AD))
	_ad_btn.custom_minimum_size = Vector2(0, 56)
	_ad_btn.add_theme_font_size_override("font_size", 18)
	_ad_btn.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	_ad_btn.pressed.connect(_on_watch_ad_pressed)
	vbox.add_child(_ad_btn)

	# Back button — gray tint
	var back_btn := Button.new()
	back_btn.text = tr("UI_BACK")
	back_btn.custom_minimum_size = Vector2(0, 56)
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	back_btn.pressed.connect(func() -> void:
		AudioManager.play_ui_click()
		back_pressed.emit()
	)
	vbox.add_child(back_btn)

	# Confirmation overlay (hidden by default)
	_build_confirm_overlay()


func _build_confirm_overlay() -> void:
	_confirm_overlay = PanelContainer.new()
	_confirm_overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_confirm_overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_confirm_overlay.grow_vertical = Control.GROW_DIRECTION_BOTH
	_confirm_overlay.custom_minimum_size = Vector2(320, 150)
	_confirm_overlay.visible = false
	add_child(_confirm_overlay)

	var overlay_vbox := VBoxContainer.new()
	overlay_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_confirm_overlay.add_child(overlay_vbox)

	_confirm_label = Label.new()
	_confirm_label.text = ""
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_label.add_theme_font_size_override("font_size", 18)
	overlay_vbox.add_child(_confirm_label)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay_vbox.add_child(btn_row)

	var confirm_btn := Button.new()
	confirm_btn.text = tr("UI_CONFIRM")
	confirm_btn.custom_minimum_size = Vector2(120, 48)
	confirm_btn.add_theme_font_size_override("font_size", 18)
	confirm_btn.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	confirm_btn.pressed.connect(func() -> void:
		AudioManager.play_ui_click()
		_on_confirm_purchase()
	)
	btn_row.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = tr("UI_CANCEL")
	cancel_btn.custom_minimum_size = Vector2(120, 48)
	cancel_btn.add_theme_font_size_override("font_size", 18)
	cancel_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	cancel_btn.pressed.connect(func() -> void:
		AudioManager.play_ui_click()
		_on_cancel_purchase()
	)
	btn_row.add_child(cancel_btn)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Refresh the diamond balance display.
func update_diamonds(amount: int) -> void:
	if _diamonds_label != null:
		_diamonds_label.text = tr("UI_DIAMONDS") + ": " + str(amount)


## Mark a one-time pack as purchased (disables button, shows "Purchased").
func mark_purchased(pack_id: String) -> void:
	var btn: Button = _pack_buttons.get(pack_id) as Button
	if btn == null:
		return
	btn.text = tr("UI_PURCHASED")
	btn.disabled = true
	btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))


## Update the watch-ad button: show remaining count and disable when 0.
## Pass ads_remaining = -1 to hide the button entirely (no-ads purchased).
func update_ad_button(ads_remaining: int) -> void:
	if _ad_btn == null:
		return
	if ads_remaining < 0:
		_ad_btn.visible = false
		return
	_ad_btn.visible = true
	var max_ads: int = Constants.MAX_ADS_PER_DAY
	_ad_btn.text = tr("ADS_REMAINING").replace("{0}", str(ads_remaining)).replace("{1}", str(max_ads)).replace("{2}", str(Constants.DIAMONDS_PER_AD))
	_ad_btn.disabled = ads_remaining <= 0

# ---------------------------------------------------------------------------
# Callbacks
# ---------------------------------------------------------------------------

func _on_purchase_pressed(pack_id: String) -> void:
	_pending_pack_id = pack_id
	# Find pack info for the confirmation message
	var diamonds: int = 0
	var price_label: String = ""
	for pack in PACKS:
		if (pack["id"] as String) == pack_id:
			diamonds = pack["diamonds"] as int
			price_label = pack["price_label"] as String
			break
	if pack_id == "speed_x2":
		_confirm_label.text = tr("SHOP_CONFIRM_SPEED_X2").replace("{0}", str(PACKS[5]["diamonds"]))
	elif pack_id == "speed_x3":
		_confirm_label.text = tr("SHOP_CONFIRM_SPEED_X3").replace("{0}", price_label)
	elif pack_id == "no_ads":
		_confirm_label.text = tr("SHOP_CONFIRM_NO_ADS").replace("{0}", price_label)
	elif pack_id == "doubler":
		_confirm_label.text = tr("SHOP_CONFIRM_DOUBLER").replace("{0}", price_label)
	elif diamonds > 0:
		_confirm_label.text = tr("SHOP_CONFIRM_PACK").replace("{0}", str(diamonds)).replace("{1}", price_label)
	AudioManager.play_ui_panel_open()
	_confirm_overlay.visible = true


func _on_confirm_purchase() -> void:
	AudioManager.play_ui_panel_close()
	_confirm_overlay.visible = false
	if _pending_pack_id != "":
		purchase_requested.emit(_pending_pack_id)
		_pending_pack_id = ""


func _on_cancel_purchase() -> void:
	AudioManager.play_ui_panel_close()
	_confirm_overlay.visible = false
	_pending_pack_id = ""


func _on_watch_ad_pressed() -> void:
	AudioManager.play_ui_click()
	watch_ad_requested.emit()
