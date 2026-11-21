extends Control

@onready var _progress: ProgressBar = %Progress
@onready var _status: Label = %Status

func _ready() -> void:
	_status.text = "Загружаем кофейню…"
	_load_game()

func _load_game() -> void:
	var earliest_exit_ms := Time.get_ticks_msec() + 5000
	var path := "res://scenes/game.tscn"
	var err := ResourceLoader.load_threaded_request(path, "PackedScene")
	if err != OK:
		_status.text = TranslationServer.translate("Не удалось загрузить игру (%d)") % err
		push_error(_status.text)
		return
	var states := [0.0]
	while true:
		var status := ResourceLoader.load_threaded_get_status(path, states)
		_progress.value = states[0] * 100.0
		if status == ResourceLoader.THREAD_LOAD_LOADED and Time.get_ticks_msec() >= earliest_exit_ms:
			break
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_status.text = "Ошибка загрузки игры"
			push_error(_status.text)
			return
		await get_tree().process_frame
	var scene := ResourceLoader.load_threaded_get(path) as PackedScene
	if scene == null:
		_status.text = "Ошибка загрузки игры"
		push_error(_status.text)
		return
	_progress.value = 100
	await get_tree().process_frame
	if get_tree().change_scene_to_packed(scene) != OK:
		_status.text = "Ошибка загрузки игры"
