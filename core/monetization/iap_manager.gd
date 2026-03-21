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
	"small":   {"diamonds": 500,  "price": "$0.99", "is_doubler": false},
	"medium":  {"diamonds": 2000, "price": "$3.99", "is_doubler": false},
	"large":   {"diamonds": 5000, "price": "$7.99", "is_doubler": false},
	"doubler": {"diamonds": 0,    "price": "$4.99", "is_doubler": true},
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
	var is_doubler: bool = pack.get("is_doubler", false) as bool
	var diamonds: int = pack.get("diamonds", 0) as int

	if is_doubler:
		# Activate the doubler flag in economy and save
		economy.diamond_doubler = true
		if save != null:
			save.data["economy"]["diamond_doubler"] = true
	else:
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
