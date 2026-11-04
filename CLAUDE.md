# CLAUDE.md — Sweetie Cat's Cafe

Merge-игра 2D про кофейню с котами. GDScript, портрет 720×1280
(ref 1080×1920), `gl_compatibility` (Mobile-рендерер не работает в iOS Simulator,
не менять). iOS 14+, Android 7+.

Локальный редактор — Godot 4.7.2, `project.godot` отмечен 4.7; CI и экспортные
шаблоны в workflow пока 4.4. Это расхождение, не подтверждённая совместимость:
перед релизом согласовать версии движка и шаблонов.

Источник правды по дизайну: `docs/GDD.md` (§25 — экономика и цены, §26 — очередь
«Живая кофейня»); спека УТП — `docs/new-usp.md`;
события — `docs/analytics.md` (§10 — справочник); арт/промпты — `docs/art.md`,
статусы ассетов — `docs/art-todo.md`;
платформа (реклама/IAP/iOS/вибрация) — `docs/platform.md`.
При расхождении кода и доков — правим оба.

## Запуск

```bash
godot --headless --path . --import     # импорт
godot --headless --path . -- --selftest  # self-test (только debug)
godot --headless --path . --export-release "Android AAB" build/android/SweetieCatsCafe.aab
```

Main scene — `scenes/game.tscn`.
На macOS без `godot` в PATH: `/Applications/Godot.app/Contents/MacOS/Godot`.
Открытый редактор можно проверять через Godot AI MCP: запуск, логи, скриншоты.
Self-test печатает результат, но не завершает игру сам; для CLI добавлять
`--quit-after 300` перед `-- --selftest` и проверять строки `[selftest]`.

## Структура

```
scenes/           game.tscn, item.tscn, ui/*.tscn (HUD, попапы, карточки)
scripts/game.gd   точка входа: сборка UI, экономика, реклама/IAP, мета, FTUE
scripts/board.gd  поле, merge, drag&drop, генераторы (Node2D, _draw)
scripts/item.gd   предмет;  resources/item_data.gd — данные (Resource)
scripts/order_manager.gd
scripts/autoload/ Config SaveManager Progress Energy Analytics Ads Iap Haptics Meta Wallet
scripts/data/     chains, art, iso, meta — статические таблицы контента
scripts/ui/       cafe_view (изо-кафе/декор), cafe_queue (ряд гостей/бариста), iso_canvas,
                  order_card, cat_card, fx_layer, game_hud, попапы, safe_area
scripts/ads/      admob_backend — единственное место со ссылками на плагин AdMob
scripts/dev/      selftest.gd — самопроверка с откатом состояния
tools/            build_ui_theme, split_sheet, gen_icons, check_sprite_layout (SceneTree-скрипты)
assets/items/<chain>/<chain>_<level>.png
assets/cats/<id>.png, assets/decor/<id>_<S|W|N|E>.png
assets/ui/{hud,buttons,panels,cafe,boosters,tutorial}/ — исходники UI
assets/ui/theme/  рантайм-арт (собирается tools/build_ui_theme.gd)
resources/ui_theme.tres — единая тема (StyleBoxTexture + Type Variations)
```

## Правила проекта

- **Все числа баланса — только в `Config.values`** (`scripts/autoload/config.gd`).
  Никаких магических чисел в геймплее. Ключ читается через `Config.get_value("...")`.
- **Class name через `class_name` не для всех**: сервисы берём `preload` (см. комментарий
  у `ORDER_MANAGER` в `game.gd`) — так избегаем циклов.
- Логика — сигналами: `Board` эмитит `items_merged` / `item_tapped` / `contents_changed`,
  `game.gd` реагирует. Не тянуть `get_parent()`.
- Новые автолоады — только если без них нельзя; порядок в `project.godot` значим
  (`Haptics` после `Iap`, до `Meta`).
- Никаких новых зависимостей/плагинов без нужды: игра обязана собираться и работать
  без AdMob/IAP-плагинов (заглушки в `ads.gd` / `iap.gd`).
- Сохранение — только через `SaveManager`; запись отложенная (1.5 с), атомарная, с `.bak`.
  Не писать файл вручную.
- Звука в коде пока нет, но он нужен (SFX + 2–3 луп-трека, §15 GDD) — это не
  отменённое решение. Сейчас обратная связь тактильная (`Haptics.selection`);
  когда появится звук — шина SFX глушится на время рекламы. Не путать с удалённым
  аудио из прототипа: новые `play()` добавляем вместе с ассетами и шинами.
- Комментарии — по-русски, коротко, объясняют **почему**, а не что.
- Язык интерфейса — русский в строках прототипа; финал — RU+EN (§16 GDD).

## Кор-луп

тап генератора (−1⚡, L1) → drag слияние одинаковых → заказ кота → 🪙 + XP →
декор/уровень → новые генераторы, слоты, коты.

- Поле: `Config.board_width/height` = 5×6 = 30 клеток (меняется правкой Config;
  других мест с числом клеток нет).
- Цепочки (`scripts/data/chains.gd`): кофе 10, выпечка 7, цветы 5 уровней.
- Генераторы — **предметы поля** (`gen_<chain>`, L1–3): заряды, отдых, бонус L2,
  сливаются между собой. Открытие: кофе с начала, выпечка ур. 4, цветы ур. 8.
- Экономика: `sell_value = round(5 × 2.05^(lvl-1))`; продажа вручную ×0.6;
  заказ = 2 × Σ sell_value, ×1.5 если < 20 мин, XP = 50% монет, 10% гем.
- Энергия: max 100, +1/60 c, rewarded +15 (5/день).
- Уровень: `xp_next(n) = round(50 × n^1.5)`, max 20. Декор даёт XP → это и прогресс, и слив.
- Мета (`Meta` + `scripts/data/meta.gd`): 27 предметов декора, 12 котов
  (+5% монет за заказ каждый), 7-дневный стрик.

## Арт и размеры спрайтов

- Канон — `assets/style.png`. При генерации прикладывать как reference **только стиля**,
  не содержимого/композиции. Промпт группы + конкретных ассетов брать из `docs/art.md`.
- Один запрос генерации — один спрайт-лист; показать пользователю, дождаться одобрения,
  затем нарезать `tools/split_sheet.gd` (`--grid 3x2` или по прозрачным областям).
  Не считать нарезку очисткой фона: альфу и края проверять визуально.
- UI-исходники не грузить напрямую в рантайме: добавить в `tools/build_ui_theme.gd`,
  выполнить `-- art`, импорт, `-- theme`; ссылки — только `assets/ui/theme/`.
- Бустеры — `assets/ui/boosters/{hammer,shuffle,magnet}.png`; производные в теме
  подключены к кнопкам `settings_popup.gd`. Повторно не генерировать.
- Указатели — `assets/ui/tutorial/hand_pointer_{1,2,3}.png`, `arrow_hint.png`;
  производные в теме. Три руки используются в `game.gd:_show_merge_pointer()`:
  захват/перенос/отпускание, 180×180, `TRANS_SINE` + `EASE_IN_OUT`.
  Стрелка пока не используется. Шесть `assets/cats/emotion_*.png` нарезаны,
  но к игровым событиям не подключены.
- Пять иконок очереди/бариста/эмоций — `assets/ui/cafe/{queue_full,barista_slot,
  badge_happy,badge_waiting,badge_angry}.png`, производные — в теме.
- Коты в альбоме: `scenes/ui/cat_card.tscn` + `scripts/ui/cat_card.gd`;
  портрет центрируется по высоте карточки, левая зона 116 px. Не возвращать
  отрицательный верхний offset без вертикальных якорей — кот уезжает вверх.
- Изо-декор: `_fit_sprite()` в `scripts/ui/cafe_view.gd` вписывает PNG по тайлам;
  `DECOR_FILL` задаёт область вписывания, `DECOR_SCALE` — множители по id,
  общий множитель `0.5` уменьшает всю мебель. Нижняя опора привязана к полному
  footprint (для 1×1 — локальная Y=32), не к уменьшенной области вписывания.
  Программные тени мебели удалены; выбранный/перетаскиваемый спрайт выделяет shader-обводка.
  Стены рисуются на слое пола позади мебели — не возвращать перекрытие стенами.
- `painting`/`garland`: `scripts/data/meta.gd:wall_mount()` выбирает ближайшую
  наружную заднюю стену. В `Meta.can_place()` настенный и напольный декор не
  блокируют друг друга; у настенного своя проверка пересечений. Поставленный
  предмет и ghost используют `_place_node()`. Полная ручная приёмка ещё нужна.
- Все 27 id декора покрыты файлами: 14×4 ракурса + 13 одиночных `_S.png`.
  Прозрачность проверять по альфа-каналу и в игре: коричневое превью само по
  себе не означает непрозрачный фон. Нарезка не равна очистке краёв.
- Покадровые VFX из `assets/vfx/` **отключены из-за качества**, файлы сохранены.
  Программные искры, полёты статичных иконок монет/предметов и тосты работают.
  Не включать старые кадры автоматически при последующих правках эффектов.

## Очередь и бариста — текущее состояние

- `game_hud.gd` добавляет `cafe_queue.gd` над карточками заказов: портреты гостей,
  полосы терпения, кнопка выбора бариста и кнопка кафе с готовой иконкой.
  В попапе выбора бариста — портреты открытых котов; карточки заказов тоже читают `cat_id`.
- Источник состояния — экземпляр `$Orders` (`scripts/order_manager.gd`), не
  автолоад и не статический `OrderManager`. `game.gd` передаёт состояние в HUD
  и связывает сигнал выбора с `set_active_barista()`.
- Это пока компактный UI-ряд, **не готовая изометрическая витрина УТП**.
  `_orders.start()` из `game.gd` не вызывается: автоматический приход/таймауты
  не считать подключёнными. Новые анимации, бейджи событий и аналитику очереди
  сверять с `docs/GDD.md §26` и фактическим кодом; не включать неявно при правках арта.

## Аналитика (PostHog)

`Analytics.log_event(event_id, params)`. Имя в PostHog = человекочитаемое из
`Analytics.EVENTS`, `event_id` уезжает свойством. **Новое событие = запись в `EVENTS`**,
иначе warning в лог. Батч до 100 / 30 с, ретрай 3×10 с, flush на паузе/закрытии.
Снапшот состояния (`player_level`, `coins`, `gems`, `energy`, `free_cells`) автоматически
мержится в игровые события через `game.gd:_log_game_event()`. Ключ `phc_...` — публичный;
`phx_` в клиент не класть никогда.

## iOS / харднинг

- Плагин вибрации: `ios/plugins/haptics/` (исходники + собранные `*.xcframework`),
  флаг `plugins/Haptics=true` в `export_presets.cfg`. Сборка — `.github/workflows/ios-plugin.yml`.
- CI: `android.yml` (APK/AAB → Telegram), `ios.yml` (unsigned `.ipa` для Sideloadly),
  `ios-plugin.yml`. `GODOT_VERSION` в workflow держать в синхроне с движком.
- Без подписи доступны симулятор, тестовые AdMob-юниты, PostHog, StoreKit Testing;
  реальные IAP/APNs/App Store — только с Apple Developer Program (`docs/platform.md, часть 2`).

## Проверка перед коммитом

1. `godot --headless --path . -- --selftest` → в логе `[selftest] ... OK`,
   результат дублируется в `user://selftest_result.txt`. Тесты откатывают состояние сами.
2. Для размеров котов/декора: `godot --headless --path . --script tools/check_sprite_layout.gd`
   → `[sprite_layout] OK`. Это геометрическая проверка, не замена скриншотам.
3. Пройти кор-луп в редакторе: тап генератора, слияние, заказ, продажа, бустер, мета.
   Для арта проверить альбом котов и изо-кафе: масштаб, опору, обводку, повороты,
   ghost, картину/гирлянду на стенах; в HUD — портреты, выбор бариста и указатели.
4. Новое число баланса — в `Config`; новое событие — в `EVENTS`; новая иконка — через
   `tools/build_ui_theme.gd`, ссылки только на `assets/ui/theme/`.

## Грабли

- Дроп на генератор запрещён; на максимуме цепочки слияния нет.
- Поле заполнено → блокировать тап генератора («Нет места»), не молча терять предмет.
- Сейв во время анимации — только финальное состояние.
- `git`-игнор: `addons/*` кроме `addons/godot_ai/`, `build/`, `plan.md`, `*.translation`.
- Placeholder-арт: без файла рисуется заглушка (`scripts/placeholders.gd`), не падать.
