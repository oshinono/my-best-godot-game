# Sweetie Cat's Cafe — инструкции проекта

Merge-игра 2D про кофейню с котами. GDScript, портрет 720×1280 (ref 1080×1920), `gl_compatibility` (не менять: Mobile ломается в iOS Simulator). iOS 14+, Android 7+.

Локально Godot 4.7.2; `project.godot` — 4.7, CI и шаблоны экспорта пока 4.4. Версии не считать совместимыми без проверки; синхронизировать до релиза.

## Запуск и структура

```bash
godot --headless --path . --import
godot --headless --path . -- --selftest
godot --headless --path . --export-release "Android AAB" build/android/SweetieCatsCafe.aab
```

Если `godot` отсутствует в PATH на macOS: `/Applications/Godot.app/Contents/MacOS/Godot`. Main scene: `scenes/ui/loading_screen.tscn`, затем `scenes/game.tscn`. Self-test требует debug и не завершает процесс сам; для CLI использовать `--quit-after 300` перед `-- --selftest`, проверить `[selftest]`.

- `scripts/game.gd` — вход, UI, экономика, FTUE, мета.
- `scripts/board.gd`, `scripts/item.gd`, `resources/item_data.gd` — поле и предметы.
- `scripts/order_manager.gd`; `scripts/autoload/` — сервисы.
- `scripts/data/` — таблицы контента; `scripts/ui/` — HUD, кафе, карточки, попапы.
- `scripts/ads/admob_backend.gd` — единственное место с прямыми ссылками на AdMob.
- `scenes/`, `assets/`, `tools/`, `resources/ui_theme.tres` — сцены, арт, инструменты, тема.

## Обязательные правила

- Все числа баланса в `Config.values` (`scripts/autoload/config.gd`), чтение через `Config.get_value("key")`. Не вводить игровые magic numbers.
- Сервисы с риском циклов брать через `preload`, не полагаться на `class_name` во всех файлах.
- Логика поля через сигналы `Board`: `items_merged`, `item_tapped`, `contents_changed`. Не связывать логику через `get_parent()`.
- Новые autoload — только при необходимости; порядок в `project.godot` значим (`Haptics` после `Iap`, до `Meta`).
- Не добавлять зависимости/плагины без нужды. Игра работает без AdMob/IAP-плагинов (заглушки в `ads.gd`/`iap.gd`).
- Сейвы только через `SaveManager`: отложенная запись 1.5 с, атомарно, с `.bak`; не писать файлы вручную.
- Комментарии по-русски, короткие, объясняют причину.
- Исходные строки UI — русские; переводы EN, ZH, HI, ES, AR — `locale/ui.csv`. Переводить шаблон до подстановки значений.
- Не добавлять звук без готовых ассетов и шин. При появлении звука SFX приглушать на время рекламы.

## Игровая модель

Кор-луп: генератор (−1⚡, L1) → drag/merge → заказ кота → монеты+XP → декор/уровень → генераторы/слоты/коты.

- Поле 5×6: `Config.board_width/height`; не дублировать число клеток.
- Цепочки в `scripts/data/chains.gd`: кофе 10, выпечка 7, цветы 5 уровней.
- Генераторы — предметы поля `gen_<chain>` L1–3, заряды/отдых/бонус L2; открытие: кофе сразу, выпечка ур. 4, цветы ур. 8.
- Баланс: продажа `round(5 × 2.05^(lvl-1))`, ручная продажа ×0.6; заказ `2 × Σ sell_value`, ×1.5 если в пределах терпения гостя (максимум 2 мин); XP 50% монет, 10% гем.
- Энергия: max 100, +1/60 с, rewarded +15, 5/день. Уровень: `round(50 × n^1.5)`, max 20.
- Meta: 27 декора, 12 котов (+5% монет за заказ каждый), стрик 7 дней.
- Дроп на генератор запрещён; max level не merge’ится. Нет места — блокировать тап генератора и показать причину. Сейв во время анимации — только финальное состояние.

## Арт и UI

- Стиль-референс: `assets/style.png`. При генерации использовать только как reference стиля, содержимое/композицию не копировать.
- Один запрос генерации — один sprite sheet; показать человеку до нарезки. `tools/split_sheet.gd`; нарезка не очищает края/фон. Прозрачность проверять альфой и в игре.
- UI исходники не подключать напрямую в рантайм: добавить в `tools/build_ui_theme.gd`, запустить `-- art`, импорт, `-- theme`; ссылки только `assets/ui/theme/`.
- Арт иконок: `icon.jpg`/`icon.png` → `tools/gen_icons.gd`, запуск `tools/run_gen_icons.gd`; PNG производные идут в Godot/iOS/Android presets.
- `scripts/ui/cafe_view.gd`: мебель вписывается по тайлам через `_fit_sprite()`, масштаб `DECOR_FILL`/`DECOR_SCALE`; общая мебель ×0.5. Опора привязана к footprint (1×1: локальная Y=32), не к области вписывания. Тени удалены; выделение shader-обводкой. Стены за мебелью.
- `painting`/`garland`: `scripts/data/meta.gd:wall_mount()` выбирает заднюю стену; настенный/напольный декор имеют независимую проверку пересечений. Поставленный предмет и ghost используют `_place_node()`.
- 27 id декора: 14×4 ракурса + 13 одиночных `_S.png`. Арт VFX в `assets/vfx/` отключён из-за качества; не подключать автоматически.
- Cat album: `scenes/ui/cat_card.tscn`, `scripts/ui/cat_card.gd`; портрет 116 px слева, центрирование по высоте.
- Указатели `assets/ui/tutorial/hand_pointer_{1,2,3}.png`, `arrow_hint.png`; три руки задействованы в `game.gd:_show_merge_pointer()`. Эмоции `assets/cats/emotion_*.png` существуют, но не подключены.
- Очередь: `game_hud.gd`/`cafe_queue.gd` показывают котов, терпение, бариста. Состояние из `$Orders`, не статического OrderManager. `_orders.start()` запускается после восстановления игры; свободные места пополняются каждые `queue_refill_sec`.
- Фоны в `assets/backgrounds/`. Статичный boot splash не может показывать live progress.

## Сервисы и проверки

- Analytics: `Analytics.log_event(event_id, params)`. Новое событие обязательно добавить в `Analytics.EVENTS`; имя в PostHog человекочитаемое, ID уезжает свойством. Батч 100/30 с, retry 3×10 с, flush на паузе/закрытии.
- Снапшот игровых событий добавляется в `game.gd:_log_game_event()`: player_level, coins, gems, energy, free_cells. `phc_...` публичный; `phx_...` запрещён в клиенте.
- Haptics: `ios/plugins/haptics/`; `plugins/Haptics=true`. CI: `.github/workflows/{android,ios,ios-plugin}.yml`; GODOT_VERSION синхронизировать.
- Перед коммитом: selftest (`--quit-after 300` в CLI) искать `[selftest] ... OK`; `tools/check_sprite_layout.gd` → `[sprite_layout] OK`; вручную пройти core loop, проверить альбом/кафе/HUD.
- Новые числа баланса → Config; события → `EVENTS`; UI-иконки → сборщик темы.

## Git и устойчивость

`.gitignore`: `addons/*` кроме `addons/godot_ai/`, `build/`, `*.translation`. Placeholder без файла не должен приводить к падению (`scripts/placeholders.gd`).
