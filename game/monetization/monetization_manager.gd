extends Node

signal status_changed(status: String)
signal premium_changed(is_premium: bool)
signal product_details_changed(details: Dictionary)
signal purchase_pending(product_id: String)
signal purchase_failed(message: String)
signal rewarded_ready_changed(ready: bool)
signal reward_granted(reward_id: String)

const PREMIUM_PRODUCT_ID := "football_dynasty_premium"
const SAVE_PATH := "user://monetization.cfg"
const BILLING_CLASS := "BillingClient"
const ADMOB_SCRIPT := "res://addons/AdmobPlugin/Admob.gd"
const PRODUCT_TYPE_INAPP := 0
const PURCHASE_STATE_PURCHASED := 1
const PURCHASE_STATE_PENDING := 2
const RESPONSE_OK := 0
const RESPONSE_USER_CANCELED := 1

var is_premium: bool = false
var billing_available: bool = false
var rewarded_available: bool = false
var status: String = "offline"
var product_details: Dictionary = {}
var pending_reward_id: String = ""

var _billing: Object
var _admob: Node
var _pending_ack_tokens: Dictionary = {}

func _ready() -> void:
	_load_cached_entitlement()
	if OS.has_feature("android"):
		_init_billing()
		_init_rewarded_ads()
	else:
		_set_status("offline")

func buy_premium() -> void:
	if is_premium:
		_set_status("premium_active")
		return
	if _billing == null or not billing_available:
		_fail("Google Play Billing is not available on this build.")
		return
	if product_details.is_empty():
		_billing.call("query_product_details", PackedStringArray([PREMIUM_PRODUCT_ID]), PRODUCT_TYPE_INAPP)
		_fail("Premium pricing is still loading. Try again in a moment.")
		return
	var result: Dictionary = _billing.call("purchase", PREMIUM_PRODUCT_ID)
	var code := int(result.get("response_code", -999))
	if code != RESPONSE_OK:
		_fail("Could not open Google Play purchase flow: %s" % result.get("debug_message", code))

func restore_purchases() -> void:
	if _billing == null or not billing_available:
		_fail("Google Play Billing is not available on this build.")
		return
	_set_status("restoring")
	_billing.call("query_purchases", PRODUCT_TYPE_INAPP)

func request_rewarded_ad(reward_id: String) -> void:
	if is_premium:
		reward_granted.emit(reward_id)
		return
	if _admob == null:
		_fail("Rewarded ads are not available on this build.")
		return
	pending_reward_id = reward_id
	if rewarded_available:
		rewarded_available = false
		rewarded_ready_changed.emit(false)
		_admob.call("show_rewarded_ad")
	else:
		_set_status("loading_rewarded_ad")
		_admob.call("load_rewarded_ad")

func premium_price_text() -> String:
	for offer in product_details.get("one_time_purchase_offer_details", []):
		if offer is Dictionary and offer.has("formatted_price"):
			return String(offer["formatted_price"])
	if product_details.has("formatted_price"):
		return String(product_details["formatted_price"])
	return "See Google Play price"

func _init_billing() -> void:
	if not ClassDB.class_exists(BILLING_CLASS):
		_set_status("billing_plugin_missing")
		return
	_billing = ClassDB.instantiate(BILLING_CLASS)
	if _billing == null:
		_set_status("billing_unavailable")
		return
	add_child(_billing)
	_connect_if_present(_billing, "connected", _on_billing_connected)
	_connect_if_present(_billing, "disconnected", _on_billing_disconnected)
	_connect_if_present(_billing, "connect_error", _on_billing_connect_error)
	_connect_if_present(_billing, "query_product_details_response", _on_product_details)
	_connect_if_present(_billing, "query_purchases_response", _on_query_purchases)
	_connect_if_present(_billing, "on_purchase_updated", _on_purchase_updated)
	_connect_if_present(_billing, "acknowledge_purchase_response", _on_acknowledge_response)
	_billing.call("start_connection")
	_set_status("billing_connecting")

func _on_billing_connected() -> void:
	billing_available = true
	_set_status("billing_ready")
	_billing.call("query_product_details", PackedStringArray([PREMIUM_PRODUCT_ID]), PRODUCT_TYPE_INAPP)
	_billing.call("query_purchases", PRODUCT_TYPE_INAPP)

func _on_billing_disconnected() -> void:
	billing_available = false
	_set_status("billing_disconnected")

func _on_billing_connect_error(response_code: int, debug_message: String) -> void:
	billing_available = false
	_fail("Google Play Billing connection error %d: %s" % [response_code, debug_message])

func _on_product_details(response: Dictionary) -> void:
	if int(response.get("response_code", -1)) != RESPONSE_OK:
		_fail("Could not load Premium product: %s" % response.get("debug_message", "unknown error"))
		return
	for item in response.get("product_details", []):
		if item is Dictionary and String(item.get("product_id", "")) == PREMIUM_PRODUCT_ID:
			product_details = item
			product_details_changed.emit(product_details)
			return

func _on_query_purchases(response: Dictionary) -> void:
	if int(response.get("response_code", -1)) != RESPONSE_OK:
		_fail("Could not restore purchases: %s" % response.get("debug_message", "unknown error"))
		return
	var found_premium := false
	for purchase in response.get("purchases", []):
		if purchase is Dictionary and PREMIUM_PRODUCT_ID in purchase.get("product_ids", []):
			found_premium = _process_premium_purchase(purchase) or found_premium
	if found_premium:
		_set_status("premium_active")
	else:
		_set_status("billing_ready")

func _on_purchase_updated(response: Dictionary) -> void:
	var code := int(response.get("response_code", -1))
	if code == RESPONSE_USER_CANCELED:
		_set_status("purchase_cancelled")
		return
	if code != RESPONSE_OK:
		_fail("Purchase failed: %s" % response.get("debug_message", code))
		return
	for purchase in response.get("purchases", []):
		if purchase is Dictionary and PREMIUM_PRODUCT_ID in purchase.get("product_ids", []):
			_process_premium_purchase(purchase)

func _process_premium_purchase(purchase: Dictionary) -> bool:
	var purchase_state := int(purchase.get("purchase_state", 0))
	if purchase_state == PURCHASE_STATE_PENDING:
		purchase_pending.emit(PREMIUM_PRODUCT_ID)
		_set_status("purchase_pending")
		return false
	if purchase_state != PURCHASE_STATE_PURCHASED:
		return false
	var token := String(purchase.get("purchase_token", ""))
	if not bool(purchase.get("is_acknowledged", false)) and token != "" and _billing != null:
		_pending_ack_tokens[token] = true
		_billing.call("acknowledge_purchase", token)
	_set_premium(true)
	return true

func _on_acknowledge_response(response: Dictionary) -> void:
	var token := String(response.get("token", ""))
	_pending_ack_tokens.erase(token)
	if int(response.get("response_code", -1)) != RESPONSE_OK:
		_fail("Premium purchase completed but acknowledgement failed. Restore purchases while online.")

func _init_rewarded_ads() -> void:
	if not FileAccess.file_exists(ADMOB_SCRIPT):
		return
	var script := load(ADMOB_SCRIPT)
	if script == null:
		return
	_admob = script.new()
	_admob.name = "FootballDynastyAdmob"
	_admob.set("is_real", not OS.is_debug_build())
	_admob.set("auto_show_on_resume", false)
	_admob.set("remove_rewarded_ads_after_displayed", true)
	_connect_if_present(_admob, "initialization_completed", _on_admob_initialized)
	_connect_if_present(_admob, "rewarded_ad_loaded", _on_rewarded_loaded)
	_connect_if_present(_admob, "rewarded_ad_failed_to_load", _on_rewarded_failed)
	_connect_if_present(_admob, "rewarded_ad_user_earned_reward", _on_reward_earned)
	_connect_if_present(_admob, "rewarded_ad_dismissed_full_screen_content", _on_rewarded_dismissed)
	add_child(_admob)
	_admob.call("initialize")

func _on_admob_initialized(_status_data = null) -> void:
	if is_premium:
		return
	_admob.call("load_rewarded_ad")

func _on_rewarded_loaded(_ad_info = null, _response_info = null) -> void:
	rewarded_available = true
	rewarded_ready_changed.emit(true)
	_set_status("rewarded_ready")

func _on_rewarded_failed(_ad_info = null, _error_data = null) -> void:
	rewarded_available = false
	rewarded_ready_changed.emit(false)
	pending_reward_id = ""
	_set_status("rewarded_unavailable")

func _on_reward_earned(_ad_info = null, _reward_data = null) -> void:
	if pending_reward_id == "":
		return
	var granted := pending_reward_id
	pending_reward_id = ""
	reward_granted.emit(granted)

func _on_rewarded_dismissed(_ad_info = null) -> void:
	rewarded_available = false
	rewarded_ready_changed.emit(false)
	if _admob != null and not is_premium:
		_admob.call_deferred("load_rewarded_ad")

func _connect_if_present(object: Object, signal_name: StringName, callable: Callable) -> void:
	if object.has_signal(signal_name) and not object.is_connected(signal_name, callable):
		object.connect(signal_name, callable)

func _set_premium(value: bool) -> void:
	if is_premium == value:
		return
	is_premium = value
	_save_cached_entitlement()
	if is_premium:
		rewarded_available = false
		rewarded_ready_changed.emit(false)
	premium_changed.emit(is_premium)

func _load_cached_entitlement() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		is_premium = bool(cfg.get_value("entitlement", "premium", false))

func _save_cached_entitlement() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("entitlement", "premium", is_premium)
	cfg.save(SAVE_PATH)

func _set_status(value: String) -> void:
	status = value
	status_changed.emit(status)

func _fail(message: String) -> void:
	purchase_failed.emit(message)
	_set_status("error")
