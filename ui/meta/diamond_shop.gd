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
	{"id": "small",   "diamonds": 100, "price_label": "$0.99"},
	{"id": "medium",  "diamonds": 550, "price_label": "$4.99"},
	{"id": "large",   "diamonds": 1200, "price_label": "$9.99"},
	{"id": "doubler", "diamonds": 0,   "price_label": "$2.99"},  # Diamond doubler
]

# ---------------------------------------------------------------------------
# Node refs
# ---------------------------------------------------------------------------

var _diamonds_label: Label
var _ad_btn: Button

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_layout()


func _build_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(400, 0)
	add_child(vbox)

	# Title
	var title := Label.new()
	title.text = tr("UI_DIAMOND_SHOP")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Current diamonds
	_diamonds_label = Label.new()
	_diamonds_label.text = tr("UI_DIAMONDS") + ": 0"
	vbox.add_child(_diamonds_label)

	# Pack buttons
	for pack in PACKS:
		var row := HBoxContainer.new()
		vbox.add_child(row)

		var lbl := Label.new()
		if pack["id"] == "doubler":
			lbl.text = tr("NO_ADS")
		else:
			lbl.text = "+%d ♦" % (pack["diamonds"] as int)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)

		var btn := Button.new()
		btn.text = pack["price_label"] as String
		var pid: String = pack["id"] as String
		btn.pressed.connect(func() -> void: _on_purchase_pressed(pid))
		row.add_child(btn)

	# Watch ad button
	_ad_btn = Button.new()
	_ad_btn.text = tr("WATCH_AD").replace("{0}", str(Constants.DIAMONDS_PER_AD))
	_ad_btn.pressed.connect(_on_watch_ad_pressed)
	vbox.add_child(_ad_btn)

	# Back button
	var back_btn := Button.new()
	back_btn.text = tr("UI_BACK")
	back_btn.pressed.connect(func() -> void: back_pressed.emit())
	vbox.add_child(back_btn)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Refresh the diamond balance display.
func update_diamonds(amount: int) -> void:
	if _diamonds_label != null:
		_diamonds_label.text = tr("UI_DIAMONDS") + ": " + str(amount)


## Update the watch-ad button: show remaining count and disable when 0.
func update_ad_button(ads_remaining: int) -> void:
	if _ad_btn == null:
		return
	var max_ads: int = Constants.MAX_ADS_PER_DAY
	_ad_btn.text = tr("ADS_REMAINING").replace("{0}", str(ads_remaining)).replace("{1}", str(max_ads))
	_ad_btn.disabled = ads_remaining <= 0

# ---------------------------------------------------------------------------
# Callbacks
# ---------------------------------------------------------------------------

func _on_purchase_pressed(pack_id: String) -> void:
	purchase_requested.emit(pack_id)


func _on_watch_ad_pressed() -> void:
	watch_ad_requested.emit()
