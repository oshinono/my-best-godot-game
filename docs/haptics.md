# Вибрация (тактильный отклик)

Звука в прототипе нет: вся «сочность» — вибрация (решение владельца продукта,
GDD §15). Автолоад `Haptics` (`scripts/autoload/haptics.gd`), порядок автолоадов —
после `Iap`, перед `Meta`.

Отклик бывает двух видов, и это принципиально:

| Вид | Что это | Где применять |
| --- | --- | --- |
| **tick** (`selection()`) | Тот самый лёгкий «щелчок» системного пикера | Тапы по кнопкам, смена значения, выбор предмета — всё мелкое и частое |
| **impact** (`impact(strength, count)`) | Импульс с силой | Слияние, награды, level up, покупки, провалы |

Причина разделения: `UISelectionFeedbackGenerator.selectionChanged()` даёт
дискретный тик, а `UIImpactFeedbackGenerator` — физический «удар». Разные
события не должны звучать одинаково.

## Файлы

| Файл | Роль |
| --- | --- |
| `scripts/autoload/haptics.gd` | Автолоад `Haptics`: гейт по платформе/настройке/рекламе, троттлинг, обращение к плагину |
| `ios/plugins/haptics/haptics.h` | Класс `GodotHaptics` (Godot Object) + enum `Strength` |
| `ios/plugins/haptics/haptics.mm` | Реализация на `UISelectionFeedbackGenerator` / `UIImpactFeedbackGenerator` |
| `ios/plugins/haptics/haptics_plugin.cpp` | `haptics_init` / `haptics_deinit`, регистрация синглтона `HapticsIOS` |
| `ios/plugins/haptics/haptics.gdip` | Манифест плагина (имя, бинарь, точки входа, `UIKit.framework`) |
| `ios/plugins/haptics/haptics.release.xcframework` | Собранный бинарь (генерируется, в git может не лежать) |
| `scripts/ui/settings_popup.gd` | Тумблер «📳 Вибрация» и кнопка «🎛 Тест вибрации» |
| `scripts/ui/haptics_test_popup.gd` | Стенд проверки: кнопка на каждый вид отклика |

## API

| Вызов | Что делает |
| --- | --- |
| `Haptics.selection()` | Лёгкий тик. Вызывать на каждую смену значения/выбор, не чаще ~40 мс |
| `Haptics.impact(strength := Strength.MEDIUM, count := 1)` | Импульс силой `LIGHT/MEDIUM/HEAVY/SOFT/RIGID`; `count` — сколько раз подряд (пауза 80 мс) |
| `Haptics.prepare()` | Прогреть генератор заранее. На iOS при вызове плагина тик отдаётся без задержки |
| `Haptics.mute_for_ads(true/false)` | Молчать на время rewarded/interstitial (требование GDD §15) |
| `Haptics.set_enabled(value)` | Вкл/выкл + запись в сейв (ключ `haptics_enabled`) |
| `Haptics.enabled` | Текущее состояние (его читает тумблер в настройках) |
| `Haptics.SINGLETON` | Имя нативного синглтона (`"HapticsIOS"`), пусто на десктопе |

`Strength` — обычный enum, числа совпадают с `UIImpactFeedbackStyle`:

| Значение | Смысл |
| --- | --- |
| `LIGHT` | Мелкая награда (гем) |
| `MEDIUM` | Обычное действие (слияние, заказ) |
| `HEAVY` | Значимое (level up, сундук, покупка, новый кот) |
| `SOFT` | Провал, «нет»: ошибка, не хватило энергии |
| `RIGID` | Резкий тап (в игре пока не используется) |

## Соответствие событий и вызовов

Вызовы в `scripts/game.gd` (сила — из `enum Strength`):

| Событие | Вызов |
| --- | --- |
| кнопка, «ещё»-кнопка, тап предмета, тап генератора, монеты, старт rewarded | `Haptics.selection()` |
| слияние | `Haptics.impact(Strength.MEDIUM)` |
| слияние уровня ≥ 4 | `Haptics.impact(Strength.HEAVY)` |
| провал слияния | `Haptics.impact(Strength.SOFT)` |
| заказ выполнен, rewarded закончен, daily | `Haptics.impact(Strength.MEDIUM)` |
| дроп гема | `Haptics.impact(Strength.LIGHT)` |
| level up, новый кот, покупка гема за деньги | `Haptics.impact(Strength.HEAVY, 2)` |
| сундук (крупная награда) | `Haptics.impact(Strength.HEAVY, 3)` |
| ошибка (9 мест), «мало энергии» | `Haptics.impact(Strength.SOFT, 2)` |

## Правила

- Вибрация молчит, если: она выключена, идёт реклама, или это не `OS.has_feature("mobile")`.
- Одинаковые события чаще, чем раз в `THROTTLE_MS = 40` мс, гасятся.
- Повторы `count` троттлингом не режутся — гейт проходит один раз на вызов.
- Рисунков больше нет: вместо массива пауз — один импульс или тик.

## Сборка iOS-плагина

Готовый бинарь в репозиторий не входит: его собирают на macOS и один раз
коммитят `haptics.release.xcframework` / `haptics.debug.xcframework`.

1. Клонировать шаблон официальных плагинов: `git clone --recursive https://github.com/godot-sdk-integrations/godot-ios-plugins`
2. В каталоге `godot/` (сабмодуль движка) выставить нужный тег, например `4.4-stable`.
3. Собрать движок для iOS в сабмодуле — `cd godot && scons platform=ios target=editor`. Это обязательно и делается один раз: часть заголовков движка в репозитории не хранится, их создаёт сам `scons` (`core/version_generated.gen.h`, `core/disabled_classes.gen.h`, `core/object/gdvirtual.gen.inc`). Без этого сборка плагина падает на `fatal error: 'core/disabled_classes.gen.h' file not found` (файл подключает `core/object/class_db.h`) или на `'core/object/gdvirtual.gen.inc' file not found` (подключает `core/io/resource.h`). Точечная сборка только генераторов тоже возможна, но список легко неполный — надёжнее полная сборка движка.
4. Положить исходники нашего плагина в шаблон: `cp -R <проект>/ios/plugins/haptics godot-ios-plugins/plugins/haptics`
5. В корневом `SConstruct` добавить `'haptics'` в список `EnumVariable('plugin', ...)` — иначе `scons` не примет имя.
6. Собрать xcframework: `./scripts/generate_xcframework.sh haptics release 4.0` (и `... haptics debug 4.0` для debug).
7. Скопировать `bin/haptics.release.xcframework` (и debug) обратно в `<проект>/ios/plugins/haptics/`.
8. В Godot: `Проект → Экспорт… → iOS → Options → Plugins` включить `Haptics` — это дописывает `plugins/Haptics=true` в `export_presets.cfg`.

Символы плагина манглированы: `.gdip` просит `initialization="haptics_init"`, а в
библиотеке лежит `_Z12haptics_initv`, потому что файл собран C++-компилятором, и
экспорт Godot генерирует объявление с тем же манглингом. Так же устроены официальные
плагины (`apn` — `godot_apn_init`, `inappstore` — `register_inappstore_types`), поэтому
`extern "C"` к `haptics_init`/`haptics_deinit` добавлять НЕ надо — он сломает эту
связку. По этой же причине «чистое» имя искать бесполезно, а `-fvisibility=hidden` из
шаблона безвреден.

Те же шаги можно не делать руками: workflow `.github/workflows/ios-plugin.yml`
(`iOS plugin (xcframework)`) собирает плагин на `macos-latest`. Запуск вручную —
`workflow_dispatch` с параметрами `plugin` (по умолчанию `haptics`) и
`engine_tag` (по умолчанию `4.4-stable`); артефакт — `<plugin>-xcframework.zip`.
С галочкой `commit_back=true` workflow сам коммитит `*.xcframework` в
`ios/plugins/<plugin>/` и дописывает `plugins/<Name>=true` в `export_presets.cfg`;
без неё он только предупредит, что флага нет. `engine_tag` держать в синхроне с
`GODOT_VERSION` из `ios.yml` — заголовки движка и экспорт должны быть одной версии.
Шаг 3 (генерация заголовков движка) workflow делает сам: сначала пробует
`target=template_release` только на файлах генераторов (`core/*.gen.h`,
`core/object/gdvirtual.gen.inc`), затем пробует собрать один плагин; если проба
не прошла — поднимает движок целиком (`target=editor`). Первый запуск без кэша
поэтому может идти 20–40 минут.

Пока бинаря нет или плагин не включён, игра работает: автолоад просто не находит
синглтон `HapticsIOS` и уходит в запасной вариант. Плагин — опция, не блокер сборки.

⚠️ На симуляторе iOS вибрации нет вообще (ни плагин, ни `Input.vibrate_handheld`).
Проверять только на устройстве.

## Android и десктоп

Пока используется запасной вариант `Input.vibrate_handheld(ms, amplitude)`:
на Android это короткий импульс (в 4.3+ работает), на десктопе — ничего.
Идеальный «щелчок» на Android — `view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)`,
но для него нужен отдельный Java-плагин и включённый Gradle-билд; это отложенная работа.

## Настройка и сейв

Тумблер «📳 Вибрация» — в `scripts/ui/settings_popup.gd`, читает `Haptics.enabled`
и зовёт `Haptics.set_enabled(value)`. Ключ сейва — `haptics_enabled`; старый ключ
`audio_haptics` читается как фолбек для сейвов игроков.

## Стенд проверки вибрации

Кнопка «🎛 Тест вибрации» в настройках открывает `scripts/ui/haptics_test_popup.gd`
(layer 4, поверх самих настроек): отдельная кнопка на каждый доступный отклик —
тик `selection()`, пять сил `impact()`, готовые игровые повторы `SOFT ×2` и
`HEAVY ×3`, а также `prepare()`. Внизу строка статуса: нашёлся ли нативный синглтон
`HapticsIOS`, включён ли тумблер, какой порог троттлинга.

Стенд зовёт автолоад напрямую, в обход игры, поэтому троттлинг 40 мс действует и на
нём: слишком частые подряд нажатия гасятся — это ожидаемое поведение, а не баг.
Смысл есть только на устройстве: в симуляторе вибрации нет, на Android плагина нет
и работает запасной импульс.

## Селфтест

При старте (при `SELFTEST := true`) в консоль уходит `[selftest] haptics: OK`.
Проверяется: у каждой силы есть импульс в `FALLBACK`, имя синглтона совпадает с
плагином, у автолоада есть методы `selection()` и `impact()`.

## Как добавить новый отклик

1. Мелкое и частое — просто `Haptics.selection()`.
2. Импульс — выбрать силу из `enum Strength` (новая сила не нужна: их пять, как в iOS).
3. Если это частое событие — обернуть троттлингом на своей стороне или не звать на каждый кадр.
