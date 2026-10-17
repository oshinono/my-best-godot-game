extends RefCounted

## Адаптер над плагином AdMob (poingstudios/godot-admob-plugin, линия v4.3.x —
## она собирается под стабильные Godot 4.x, включая наш 4.4; v5 требует 4.5+).
##
## Файл НЕ подключается через preload: классы плагина (MobileAds,
## RewardedAdLoader, AdRequest, ...) существуют только когда аддон лежит в
## проекте, и жёсткая ссылка сломала бы парсер на десктопе. Загружает его
## рантаймом scripts/autoload/ads.gd — см. Ads._create_backend().
##
## Имена классов сверены с README v4.3.1. Что НЕ подтверждено доками и требует
## проверки после установки плагина (помечено TODO(техспайк) в docs/technspike.md):
##   - класс награды (RewardItem) и слушателя (OnUserEarnedRewardListener);
##   - классы UMP (ConsentInformation/ConsentForm) — здесь не используются,
##     консент дёргается через сам синглтон MobileAds, если у него есть метод.

## Загруженный rewarded-креатив: держим между загрузкой и показом.
var _rewarded: RewardedAd
var _interstitial: InterstitialAd
var _initialized := false


## Инициализация SDK. Вызывается один раз при создании адаптера.
func initialize() -> void:
	if _initialized:
		return
	var ads := _singleton()
	if ads != null and ads.has_method("initialize"):
		ads.initialize()
	else:
		# Синглтона нет (например, iOS-плагин виден только на устройстве) —
		# но глобальный класс MobileAds из аддона доступен всегда.
		MobileAds.initialize()
	_initialized = true


## Загрузить rewarded. Готово → on_ready(), иначе on_error(reason).
func load_rewarded(unit_id: String, on_ready: Callable, on_error: Callable) -> void:
	initialize()
	if unit_id.is_empty():
		on_error.call("empty_unit_id")
		return
	var callback := RewardedAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: RewardedAd) -> void:
		_rewarded = ad
		on_ready.call()
	callback.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		on_error.call("load_failed: %s" % error.message)
	RewardedAdLoader.new().load(unit_id, AdRequest.new(), callback)


## Показать загруженный rewarded. on_reward(amount, type) — награда выдана.
## Если креатив не загружен — on_error("no_ad_loaded").
func show_rewarded(on_reward: Callable, on_error: Callable) -> void:
	if _rewarded == null:
		on_error.call("no_ad_loaded")
		return
	var listener := OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward = func(item: RewardItem) -> void:
		on_reward.call(int(item.amount), String(item.type))
	var ad := _rewarded
	_rewarded = null
	ad.show(listener)


## Загрузить interstitial. Показ — отдельным вызовом show_interstitial().
func load_interstitial(unit_id: String, on_ready: Callable, on_error: Callable) -> void:
	initialize()
	if unit_id.is_empty():
		on_error.call("empty_unit_id")
		return
	var callback := InterstitialAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: InterstitialAd) -> void:
		_interstitial = ad
		on_ready.call()
	callback.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		on_error.call("load_failed: %s" % error.message)
	InterstitialAdLoader.new().load(unit_id, AdRequest.new(), callback)


## Показать загруженный interstitial. on_shown() — креатив открыт,
## on_error(reason) — показать нечего.
func show_interstitial(on_shown: Callable, on_error: Callable) -> void:
	if _interstitial == null:
		on_error.call("no_ad_loaded")
		return
	var ad := _interstitial
	_interstitial = null
	ad.show()
	on_shown.call()


## UMP-консент (GDPR/ATT). В v4.3.1 UMP-классы не документированы, поэтому
## пробуем методы самого синглтона; on_done(ok, reason).
func request_consent(on_done: Callable) -> void:
	var ads := _singleton()
	if ads == null:
		on_done.call(false, "no_singleton")
		return
	if ads.has_method("present_privacy_options_form"):
		ads.present_privacy_options_form()
		on_done.call(true, "privacy_options_form")
		return
	if ads.has_method("request_consent_info_update"):
		ads.request_consent_info_update()
		on_done.call(true, "consent_info_update")
		return
	on_done.call(false, "ump_unavailable")


## Нативный синглтон AdMob, если платформа его зарегистрировала.
func _singleton() -> Object:
	if Engine.has_singleton("MobileAds"):
		return Engine.get_singleton("MobileAds")
	return null
