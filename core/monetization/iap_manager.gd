extends Node

## In-App Purchase manager.
## Uses GodotGooglePlayBilling plugin on Android when available.
## Falls back to instant simulation on desktop/editor.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal purchase_complete(pack_id: String, diamonds: int)
signal purchase_failed(pack_id: String)
signal no_ads_purchased

# ---------------------------------------------------------------------------
# Pack catalogue
# ---------------------------------------------------------------------------

## Maps internal pack_id to Google Play product ID and pack metadata.
## product_id must match what's configured in Google Play Console.
const PACKS: Dictionary = {
	"small":    {"product_id": "diamonds_500",      "diamonds": 500,  "type": "diamonds"},
	"medium":   {"product_id": "diamonds_2000",     "diamonds": 2000, "type": "diamonds"},
	"large":    {"product_id": "diamonds_5000",     "diamonds": 5000, "type": "diamonds"},
	"doubler":  {"product_id": "diamond_doubler",   "diamonds": 0,    "type": "doubler"},
	"no_ads":   {"product_id": "remove_ads",        "diamonds": 0,    "type": "no_ads"},
	"speed_x3": {"product_id": "speed_x3_unlock",  "diamonds": 0,    "type": "speed_x3"},
}

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _billing = null  # GodotGooglePlayBilling singleton
var _connected: bool = false
var _pending_pack_id: String = ""
var _pending_economy = null
var _pending_save = null

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	if Engine.has_singleton("GodotGooglePlayBilling"):
		_billing = Engine.get_singleton("GodotGooglePlayBilling")
		_connect_billing_signals()
		_billing.startConnection()

func _connect_billing_signals() -> void:
	if _billing == null:
		return
	_billing.connected.connect(_on_connected)
	_billing.disconnected.connect(_on_disconnected)
	_billing.connect_error.connect(_on_connect_error)
	_billing.purchases_updated.connect(_on_purchases_updated)
	_billing.purchase_error.connect(_on_purchase_error)
	_billing.purchase_acknowledged.connect(_on_purchase_acknowledged)
	_billing.purchase_consumed.connect(_on_purchase_consumed)

# ---------------------------------------------------------------------------
# Billing connection callbacks
# ---------------------------------------------------------------------------

func _on_connected() -> void:
	_connected = true
	# Query product details so Google Play knows our products
	var product_ids: PackedStringArray = PackedStringArray()
	for pack_id in PACKS:
		product_ids.append(PACKS[pack_id]["product_id"])
	_billing.querySkuDetails(product_ids, "inapp")

func _on_disconnected() -> void:
	_connected = false

func _on_connect_error(_code: int = 0, _message: String = "") -> void:
	_connected = false
	push_warning("IAPManager: billing connect error %d: %s" % [_code, _message])

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Request a purchase. On Android with billing plugin, initiates real purchase flow.
## On desktop/editor, simulates instantly.
func request_purchase(pack_id: String, economy, save) -> void:
	if not PACKS.has(pack_id):
		push_warning("IAPManager: unknown pack '%s'" % pack_id)
		purchase_failed.emit(pack_id)
		return

	if _billing != null and _connected:
		# Real Google Play purchase
		_pending_pack_id = pack_id
		_pending_economy = economy
		_pending_save = save
		var product_id: String = PACKS[pack_id]["product_id"]
		_billing.purchase(product_id)
		return

	# Simulation fallback (desktop/editor or billing not connected)
	_apply_purchase(pack_id, economy, save)

## Returns true if the diamond doubler has been purchased.
func has_doubler(save) -> bool:
	if save == null:
		return false
	return save.data["economy"].get("diamond_doubler", false) as bool

# ---------------------------------------------------------------------------
# Purchase callbacks
# ---------------------------------------------------------------------------

func _on_purchases_updated(purchases: Array) -> void:
	for purchase in purchases:
		if purchase.purchase_state != 1:  # 1 = PURCHASED
			continue
		_handle_completed_purchase(purchase)

func _on_purchase_error(_code: int = 0, _message: String = "") -> void:
	push_warning("IAPManager: purchase error %d: %s" % [_code, _message])
	if _pending_pack_id != "":
		purchase_failed.emit(_pending_pack_id)
	_clear_pending()

func _on_purchase_acknowledged(_purchase_token: String = "") -> void:
	pass  # Non-consumable acknowledged successfully

func _on_purchase_consumed(_purchase_token: String = "") -> void:
	pass  # Consumable consumed successfully

func _handle_completed_purchase(purchase) -> void:
	# Find which pack_id matches this product
	var pack_id: String = _pending_pack_id
	if pack_id.is_empty():
		# Try to match by product ID (e.g., restoring purchases)
		for pid in PACKS:
			if purchase.products.has(PACKS[pid]["product_id"]):
				pack_id = pid
				break
	if pack_id.is_empty():
		return

	# Apply the purchase rewards
	if _pending_economy != null and _pending_save != null:
		_apply_purchase(pack_id, _pending_economy, _pending_save)
	_clear_pending()

	# Acknowledge or consume based on type
	var pack_type: String = PACKS[pack_id].get("type", "diamonds")
	if pack_type == "diamonds":
		# Consumable — consume so it can be bought again
		_billing.consumePurchase(purchase.purchase_token)
	else:
		# Non-consumable (doubler, no_ads, speed_x3) — acknowledge
		if not purchase.is_acknowledged:
			_billing.acknowledgePurchase(purchase.purchase_token)

# ---------------------------------------------------------------------------
# Apply purchase rewards
# ---------------------------------------------------------------------------

func _apply_purchase(pack_id: String, economy, save) -> void:
	var pack: Dictionary = PACKS[pack_id] as Dictionary
	var pack_type: String = pack.get("type", "diamonds") as String
	var diamonds: int = pack.get("diamonds", 0) as int

	match pack_type:
		"doubler":
			economy.diamond_doubler = true
			if save != null:
				save.data["economy"]["diamond_doubler"] = true
		"no_ads":
			if save != null:
				save.data["monetization"]["no_ads_purchased"] = true
			no_ads_purchased.emit()
		"speed_x3":
			if save != null:
				save.data["unlocks"]["speed_x3"] = true
		_:
			if economy != null:
				economy.add_diamonds(diamonds)

	if save != null and economy != null:
		save.sync_economy(economy)
		save.save_game()

	purchase_complete.emit(pack_id, diamonds)

func _clear_pending() -> void:
	_pending_pack_id = ""
	_pending_economy = null
	_pending_save = null
