extends Node
## Обёртка над рекламой (rewarded + interstitial).
## Пока заглушка: логирует вызовы и сразу отдаёт результат, чтобы
## геймплей-код можно было писать до подключения плагина AdMob.

signal rewarded_earned(placement: String, reward: Dictionary)
signal rewarded_failed(placement: String, reason: String)
signal interstitial_shown(placement: String)
signal interstitial_failed(placement: String, reason: String)

## Переключим на true после техспайка плагина.
var use_real_ads := false


func show_rewarded(placement: String, reward: Dictionary = {}) -> void:
	if use_real_ads:
		_show_rewarded_real(placement, reward)
		return
	print("[Ads] rewarded (stub): %s" % placement)
	rewarded_earned.emit(placement, reward)


func show_interstitial(placement: String) -> void:
	if use_real_ads:
		_show_interstitial_real(placement)
		return
	print("[Ads] interstitial (stub): %s" % placement)
	interstitial_shown.emit(placement)


func _show_rewarded_real(placement: String, _reward: Dictionary) -> void:
	# TODO(техспайк): вызвать плагин AdMob.
	rewarded_failed.emit(placement, "not_implemented")


func _show_interstitial_real(placement: String) -> void:
	# TODO(техспайк): вызвать плагин AdMob.
	interstitial_failed.emit(placement, "not_implemented")
