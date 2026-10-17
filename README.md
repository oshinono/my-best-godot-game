# Merge MVP (Godot 4.4)

2D merge-игра. Движок: Godot 4.4, рендерер `gl_compatibility` (Compatibility — `mobile`
не запускается в iOS Simulator), язык GDScript.

## Структура

```
project.godot              конфиг проекта, автолоады, main scene
export_presets.cfg         пресеты экспорта: iOS, Android (APK), Android AAB
scenes/                    сцены (*.tscn)
scenes/game.tscn           точка входа — прототип ядра
scenes/item.tscn           предмет на поле
scenes/main.tscn           старый boot-экран (не используется)
scripts/                   скрипты (*.gd)
scripts/game.gd            корневой скрипт game scene
scripts/board.gd           поле: сетка, перемещение, слияние, шафл, продажа
scripts/item.gd            предмет: данные + визуал
scripts/order_manager.gd   заказы: генерация, подсчёт награды, выдача
scripts/data/chains.gd     цепочки предметов (кофе/выпечка/цветы)
scripts/data/art.gd        резолвер реального арта из assets/ (PNG/JPEG + вырезка фона)
scripts/placeholders.gd    плейсхолдер-текстуры, пока нет арта
scripts/ui/energy_popup.gd экран пустой энергии (таймер + rewarded)
scripts/ui/settings_popup.gd настройки прототипа (техспайк, продать всё, сброс)
scripts/ui/safe_area.gd     безопасные зоны iPhone (вырез, home-индикатор)
scripts/ads/admob_backend.gd адаптер AdMob (грузится в рантайме, только с аддоном)
scripts/main.gd            корневой скрипт main scene
scripts/autoload/          синглтоны (автолоады)
resources/                 данные (*.tres), создаётся по мере надобности
assets/                    арт: items/<chain>/<chain>_<level>.png, generators/, cats/, ui/, vfx/
docs/                      GDD, экономика, арт-промпты, аналитика, техспайк, iOS-тесты
.github/workflows/         CI-экспорт
plan.md                    план MVP
```

## Автолоады

| Имя | Файл | Роль |
|---|---|---|
| `Config` | `scripts/autoload/config.gd` | числа баланса + server-driven config |
| `SaveManager` | `scripts/autoload/save_manager.gd` | локальное сохранение (JSON в `user://`) |
| `Progress` | `scripts/autoload/progress.gd` | XP, уровень кофейни, гейты генераторов и слотов |
| `Energy` | `scripts/autoload/energy.gd` | энергия: реген, оффлайн-догрузка, списание |
| `Analytics` | `scripts/autoload/analytics.gd` | события → PostHog `/batch/` (буфер + ретрай) |
| `Ads` | `scripts/autoload/ads.gd` | rewarded / interstitial (заглушка) |
| `Iap` | `scripts/autoload/iap.gd` | покупки (заглушка) |

Все числа баланса — в `Config.values`. Плагины `Ads`/`Iap` включаются флагом
`use_real_ads` / `use_real_iap` после техспайка.

## Прототип (фаза 1): что уже работает

- Поле 4×5 (крупные клетки; размеры — `Config.board_width` / `board_height`), drag-and-drop, слияние одинаковых предметов одного уровня.
- Бросок мимо поля = продажа предмета (монеты по `sell_value`).
- Генераторы трёх цепочек: тап тратит энергию и кладёт L1 (выпечка с ур. 4, цветы с ур. 8).
- Энергия: реген 1/60 c, оффлайн-догрузка по `energy_ts`.
- Заказы (2 слота → 3 на ур. 6 → 4 на ур. 12), награда монетами и XP, шанс гема 10%,
  бонус ×1.5 за сдачу < 20 мин с таймером `⏱ M:SS` на карточке, реролл за 5💎.
- Прогресс: XP, уровень кофейни по `xp_next(n) = round(50 × n^1.5)`, гейты и текст «Открыто: …».
- Бустеры: хаммер 5💎, шафл 10💎, магнит 15💎 (лимит 1 раз на сессию каждый).
- Экран пустой энергии (`scripts/ui/energy_popup.gd`): таймер до +1 ⚡ и rewarded «+15 за рекламу»
  с суточным лимитом `rewarded_energy_daily_cap`.
- Настройки прототипа (⚙): кнопки техспайка (rewarded / interstitial / UMP-консент / покупка тестового SKU / restore), плюс «продать всё поле» и «сбросить прогресс» — для плейтеста. См. `docs/technspike.md`.
- Реклама и покупки — обёртки `Ads`/`Iap` с авто-детектом плагина: без аддона работают заглушкой, с аддоном (`addons/admob`, `InAppStore`, `GodotGooglePlayBilling`) — по-настоящему (`Config.ads_use_real` / `iap_use_real`).
- Адаптация под iPhone: `scripts/ui/safe_area.gd` — HUD и поле сдвигаются из выреза и от home-индикатора.
- FTUE-метрики: `ftue_step` (opened / first_generator / first_merge / first_order / out_of_energy).
- Сохранение в `user://save.json` (поле, энергия, заказы, монеты, гемы, уровень, XP).
- Арт: реальные PNG/JPEG из `assets/items/<chain>/` подхватываются автоматически,
  остальное — плейсхолдеры из `scripts/placeholders.gd`.
- Самопроверка при старте пишет `user://selftest_result.txt` (board / orders / progress / boosters / rewards).

## Экспорт

- iOS: `.github/workflows/ios.yml` — **unsigned IPA под устройство** (arm64, iphoneos) → Telegram/artifact. Ставится на iPhone через **Sideloadly** с бесплатным Apple ID (живёт 7 дней) — см. `docs/ios-testing.md`.
- iOS Simulator: `.github/workflows/ios-simulator.yml` — сборка без подписи и запуск в симуляторе (+ скриншот).
- Android: `.github/workflows/android.yml`, presets `Android` (APK) и `Android AAB`.

### Android CI

Образ `barichello/godot-ci:4.4` — Godot 4.4 + export templates + Android SDK.
Запуск вручную: Actions → *Android build* → Run workflow. Два джоба:

| Джоб | Что делает | Артефакт |
|---|---|---|
| `apk` | legacy-экспорт, подпись release-ключом | `TestGame.apk` (+ отправка в Telegram) |
| `aab` | ставит Android build template, gradle-сборка | `TestGame.aab` |

Секреты (необязательны; без них генерируется временный keystore — только для внутреннего теста):

| Секрет | Смысл |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | release.keystore в base64 |
| `ANDROID_KEYSTORE_USER` | alias ключа |
| `ANDROID_KEYSTORE_PASSWORD` | пароль store/key |
| `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_IDS` | отправка APK в Telegram |

Получить base64: `base64 -i release.keystore | pbcopy`.
Перед первым релизом в Play заменить `package/unique_name` на реальный и поднять `version/code`.

## Документация

- [`docs/GDD.md`](docs/GDD.md) — гейм-дизайн: кор-луп, поле 7×8, цепочки, заказы, мета, сцены.
- [`docs/economy.md`](docs/economy.md) — экономика: валюты, цены, заказы, IAP, KPI, ключи `Config`.
- [`docs/art-prompts.md`](docs/art-prompts.md) — стиль-гайд, палитра и промпты для генерации арта.
- [`docs/analytics.md`](docs/analytics.md) — PostHog: настройка, события, воронки, стоимость.
- [`docs/technspike.md`](docs/technspike.md) — техспайк фазы 0: AdMob (rewarded/interstitial/UMP), IAP iOS/Android, проверка на устройстве, чек-лист.
- [`docs/ios-testing.md`](docs/ios-testing.md) — iOS без $99: симулятор, StoreKit Testing, установка на устройство через Sideloadly.

## В планах

- Реализовать грамотную генерацию ключей подписи для Android-приложений:
  отдельный upload-keystore вне репозитория, Play App Signing, безопасный бэкап
  ключа и пароля, ротация при компрометации, автоматическая подстановка
  через CI-секреты без временных ключей.
