class_name IAPManager
extends Node

## Simulated In-App Purchase manager.
## In a real build, replace request_purchase() internals with platform SDK calls.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal purchase_complete(pack_id: String, diamonds: int)
signal purchase_failed(pack_id: String)

# ---------------------------------------------------------------------------
# Pack catalogue
# ---------------------------------------------------------------------------

## pack_id → { "diamonds": int, "price": String, "is_doubler": bool }
const PACKS: Dictionary = {
	"small":   {"diamonds": 500,  "price": "$0.99", "type": "diamonds"},
	"medium":  {"diamonds": 2000, "price": "$3.99", "type": "diamonds"},
	"large":   {"diamonds": 5000, "price": "$7.99", "type": "diamonds"},
	"doubler": {"diamonds": 0,    "price": "$9.99", "type": "doubler"},
	"no_ads":  {"diamonds": 0,    "price": "$1.99", "type": "no_ads"},
	"speed_x3": {"diamonds": 0,  "price": "$0.99", "type": "speed_x3"},
}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Simulate a purchase of the given pack.
## On success: credits diamonds to economy, sets doubler flag if applicable,
## syncs save, and emits purchase_complete.
func request_purchase(pack_id: String, economy, save) -> void:
	if not PACKS.has(pack_id):
		push_warning("IAPManager: unknown pack '%s'" % pack_id)
		purchase_failed.emit(pack_id)
		return

	var pack: Dictionary = PACKS[pack_id] as Dictionary

	# Simulate platform purchase — in production this would be async.
	# For simulation, purchase always succeeds.
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

## Returns true if the diamond doubler has been purchased.
func has_doubler(save) -> bool:
	if save == null:
		return false
	return save.data["economy"].get("diamond_doubler", false) as bool
