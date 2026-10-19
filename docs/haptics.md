# Вибрация (тактильный отклик)

Звука в прототипе нет: вся «сочность» — вибрация (решение владельца продукта,
GDD §15). Автолоад `Haptics` (`scripts/autoload/haptics.gd`), порядок автолоадов —
после `Iap`, перед `Meta`.

Откликов два. Первый — тик `UISelectionFeedbackGenerator.selectionChanged()`, как
щелчок системного пикера: «сила» — длина серии, `LIGHT` = 1 тик, `MEDIUM` = 2,
`HEAVY` = 3, пауза между тиками 30 мс. Второй — одиночный удар
`UIImpactFeedbackGenerator` (`impact(style)`, по умолчанию medium).

Почему так: у `UISelectionFeedbackGenerator` нет параметра силы — сила есть
только у `UIImpactFeedbackGenerator` (light/medium/heavy/soft/rigid), поэтому
мелкие и частые отклики идут серией тиков. Для слияний серия не подходит: нужен
один «сочный» импульс без задержки — там вызывается `Haptics.impact()`.

## Файлы

| Файл | Роль |
| --- | --- |
| `scripts/autoload/haptics.gd` | Автолоад `Haptics`: гейт по платформе/настройке/рекламе, троттлинг, обращение к плагину |
| `ios/plugins/haptics/haptics.h` | Класс `GodotHaptics` (Godot Object) + enum `Strength` |
| `ios/plugins/haptics/haptics.mm` | Реализация: `selection()` на `UISelectionFeedbackGenerator`, `impact(strength)` на `UIImpactFeedbackGenerator` |
| `ios/plugins/haptics/haptics_plugin.cpp` | `haptics_init` / `haptics_deinit`, регистрация синглтона `HapticsIOS` |
| `ios/plugins/haptics/haptics.gdip` | Манифест плагина (имя, бинарь, точки входа, `UIKit.framework`) |
| `ios/plugins/haptics/haptics.debug.xcframework` / `haptics.release.xcframework` | Собранные бинари — уже лежат в репозитории |
| `scripts/ui/settings_popup.gd` | Тумблер «📳 Вибрация» |

## API

| Вызов | Что делает |
| --- | --- |
| `Haptics.selection(strength := Strength.LIGHT)` | Серия тиков выбора: `LIGHT` — 1, `MEDIUM` — 2, `HEAVY` — 3 (пауза `TICK_GAP = 0.03` с). Начало серии троттлится ~40 мс |
| `Haptics.impact(style := ImpactStyle.MEDIUM)` | Одиночный удар системного `UIImpactFeedbackGenerator` со стилем из `enum ImpactStyle`. Гейт и троттлинг те же, что у `selection()` |
| `Haptics.prepare()` | Прогреть генератор заранее. На iOS при вызове плагина тик отдаётся без задержки |
| `Haptics.mute_for_ads(true/false)` | Молчать на время rewarded/interstitial (требование GDD §15) |
| `Haptics.set_enabled(value)` | Вкл/выкл + запись в сейв (ключ `haptics_enabled`) |
| `Haptics.enabled` | Текущее состояние (его читает тумблер в настройках) |
| `Haptics.SINGLETON` | Имя нативного синглтона (`"HapticsIOS"`), пусто на десктопе |

`Strength` — длина серии (0..2):

| Значение | Тиков | Смысл |
| --- | --- | --- |
| `LIGHT` | 1 | Мелкое: кнопки, провалы, гем (`selection()` без аргумента — тоже LIGHT) |
| `MEDIUM` | 2 | Обычное действие: заказ, покупка декора, «мало энергии» |
| `HEAVY` | 3 | Значимое: level up, сундук, покупка за деньги, новый кот |

`ImpactStyle` — стиль системного impact-генератора (совпадает с `UIImpactFeedbackStyle`):

| Значение | Смысл |
| --- | --- |
| `LIGHT` | Лёгкий удар |
| `MEDIUM` | Обычный удар — слияние предметов |
| `HEAVY` | Тяжёлый удар |
| `SOFT` | Мягкий удар |
| `RIGID` | Жёсткий удар |

## Соответствие событий и вызовов

Вызовы в `scripts/game.gd` (сила — из `enum Strength`, стиль удара — из `enum ImpactStyle`):

| Событие | Вызов |
| --- | --- |
| кнопка, «ещё»-кнопка, тап предмета, тап генератора, монеты, старт rewarded | `Haptics.selection()` |
| слияние | `Haptics.impact(ImpactStyle.MEDIUM)` |
| провал слияния | `Haptics.selection(Strength.LIGHT)` |
| заказ выполнен, rewarded закончен, daily | `Haptics.selection(Strength.MEDIUM)` |
| бустер применён, куплен декор | `Haptics.selection(Strength.MEDIUM)` |
| отказ: бустер не сработал, хаммер отменён, генератор заперт или поле полно, заказ не сдан, декор не снят | `Haptics.selection(Strength.LIGHT)` |
| дроп гема | `Haptics.selection()` |
| level up, новый кот, покупка гема за деньги | `Haptics.selection(Strength.HEAVY)` |
| сундук (крупная награда) | `Haptics.selection(Strength.HEAVY)` |
| ошибка (9 мест), «мало энергии» | `Haptics.selection(Strength.MEDIUM)` |

## Правила

- Вибрация молчит, если: она выключена, идёт реклама, или это не `OS.has_feature("mobile")`.
- Троттлинг один на все отклики: гейт проходит один раз на серию, тики внутри серии идут без него — иначе два-три тика схлопнулись бы в один.
- 40 мс гасят только совсем близкие вызовы: два разных события в очереди (заказ → гем → кот) звучат раздельно.
- Серия тиков — это одна вибрация, а не «импульс + паузы». Единственный `impact` в игре — слияние предметов (`ImpactStyle.MEDIUM`).

## Сборка iOS-плагина

Готовые бинари (`haptics.debug.xcframework`, `haptics.release.xcframework`) уже
лежат в репозитории, и флаг `plugins/Haptics=true` в iOS-пресете уже включён.
Шаги ниже — как пересобрать их после правок плагина.

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

Если бинарь удалить или выключить флаг `plugins/Haptics`, игра всё равно работает:
автолоад не находит синглтон `HapticsIOS` и уходит в запасной `Input.vibrate_handheld`.
Плагин — опция, не блокер сборки.

⚠️ На симуляторе iOS вибрации нет вообще (ни плагин, ни `Input.vibrate_handheld`).
Проверять только на устройстве.

## Android и десктоп

Пока используется запасной вариант `Input.vibrate_handheld(ms, amplitude)` — по одному вызову на каждый тик серии:
на Android это короткий импульс (в 4.3+ работает), на десктопе — ничего.
Идеальный «щелчок» на Android — `view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)`,
но для него нужен отдельный Java-плагин и включённый Gradle-билд; это отложенная работа.

## Настройка и сейв

Тумблер «📳 Вибрация» — в `scripts/ui/settings_popup.gd`, читает `Haptics.enabled`
и зовёт `Haptics.set_enabled(value)`. Ключ сейва — `haptics_enabled`; старый ключ
`audio_haptics` читается как фолбек для сейвов игроков.

## Как добавить новый отклик

1. Мелкое и частое — `Haptics.selection()` (то же, что `LIGHT`).
2. Заметнее — `Haptics.selection(Strength.MEDIUM)` или `HEAVY`: это 2 и 3 тика, новых значений enum не нужно.
3. «Сочное» редкое событие — `Haptics.impact(ImpactStyle.MEDIUM)`: один системный удар без серии тиков.
4. Если событие частое — не звать на каждый кадр: гейт 40 мс гасит только совсем близкие вызовы.
