# Платформа: реклама, IAP, iOS, вибрация

Часть 1 — техспайк (AdMob, консент, покупки). Часть 2 — iOS без подписи и $99.
Часть 3 — вибрация и сборка iOS-плагина. Нумерация разделов — своя внутри каждой части.

---

# Часть 1. Техспайк: реклама, консент, покупки

Цель (plan.md, фаза 0): на **реальном устройстве** обеих платформ получить
rewarded-рекламу, interstitial, UMP-консент, покупку и событие аналитики.
Если плагин не взлетает — узнать это сейчас, а не на 10-й неделе.

Порядок: сначала AdMob + аналитика (это главный риск), покупки — вторым шагом.

---

## 1. Как это устроено в коде

Геймплей зовёт только обёртки-автолоады, поэтому игра собирается и работает
без плагинов:

- `scripts/autoload/ads.gd` — `show_rewarded(placement, reward)`,
  `show_interstitial(placement)`, `request_consent()`, сигналы
  `rewarded_earned` / `rewarded_failed` / `interstitial_shown` /
  `interstitial_failed` / `consent_finished`.
- `scripts/autoload/iap.gd` — `purchase(sku)`, `restore()`, `is_owned(sku)`,
  сигналы `purchase_succeeded` / `purchase_failed` / `purchases_restored`.
- `scripts/ads/admob_backend.gd` — единственный файл, который ссылается на
  классы плагина AdMob. Загружается **в рантайме** (`load()`, не `preload`) и
  только если `OS.get_name()` == iOS/Android **и** существует
  `res://addons/admob/plugin.cfg`. Иначе адаптер не грузится вовсе, и проект
  остаётся валидным.
- IAP-плагины вообще не требуют статических ссылок: `Engine.has_singleton("InAppStore")`
  (iOS) / `Engine.has_singleton("GodotGooglePlayBilling")` (Android).

Проверка без устройства: на десктопе всё работает в режиме заглушки —
rewarded/интерстишиал сразу «показываются», покупка «успешна». Это проверяет
только геймплейную логику, не SDK.

Кнопки проверки — в игре: **⚙ (справа сверху) → Настройки прототипа**:

| Кнопка | Что делает |
| --- | --- |
| 🔎 Реклама: rewarded | грузит и показывает rewarded, пишет результат в статус |
| 🎬 Реклама: interstitial | то же для interstitial (кулдаун `ads_interstitial_min_interval_sec`) |
| 🔒 Консент (UMP/ATT) | `Ads.request_consent()` → UMP-форма |
| 🛒 Купить тестовый SKU | `Iap.purchase(Config.iap_test_sku)` |
| ♻ Восстановить покупки | `Iap.restore()` |

Все действия летят в аналитику событиями `technospike_action`,
`rewarded_*`, `interstitial_*`, `consent_finished`, `purchase_*`,
`purchases_restored` (см. `docs/analytics.md` §10).

---

## 2. Ключи Config

| Ключ | Смысл |
| --- | --- |
| `ads_use_real` | `true` + установленный аддон → реальный AdMob |
| `ads_interstitial_min_interval_sec` | кулдаун между интерстишиалами (180 с) |
| `admob_app_id_ios` / `_android` | App ID из AdMob (можно оставить пустым до релиза) |
| `admob_rewarded_unit_ios` / `_android` | unit id rewarded; **пусто → тестовый Google** |
| `admob_interstitial_unit_ios` / `_android` | unit id interstitial; пусто → тестовый |
| `consent_use_ump` | UMP-форма согласия |
| `iap_use_real` | `true` + нативный плагин → реальные покупки |
| `iap_products` | список sku через запятую |
| `iap_test_sku` | sku для кнопки техспайка |

Тестовые unit id Google (уже зашиты в `Ads.TEST_UNITS`, подставляются
автоматически, если ключ пуст):

| Платформа | Rewarded | Interstitial |
| --- | --- | --- |
| iOS | `ca-app-pub-3940256099942544/1712485313` | `ca-app-pub-3940256099942544/4411468910` |
| Android | `ca-app-pub-3940256099942544/5224354917` | `ca-app-pub-3940256099942544/1033173712` |

---

## 3. AdMob: установка аддона

Плагин: **poingstudios/godot-admob-plugin** (MIT).

**Важно про версии.** Проект на Godot **4.4**, а релизы линии `v5.x`
(`v5.1.0`, `v5.0.0`) требуют движок 4.5+ (в ассетах только
`android-template-v4.5.0…v4.7.2.zip`, PR #520 «minimum Godot version to 4.5»).
Поэтому берём линию **`v4.3.1`** — она поддерживает стабильные 4.x, включая 4.4.

1. Скачать `poing-godot-admob-v4.3.1.zip` из релиза репозитория и распаковать
   в корень проекта (появится `res://addons/admob/`), либо поставить через
   AssetLib («AdMob by poing.studios», id 2063).
2. `Project → Project Settings → Plugins` → включить **AdMob**.
3. Дозагрузить нативные зависимости:
   `Project → Tools → AdMob Manager → Android / iOS → Download & Install`.
4. В `Config` выставить `ads_use_real = true`.
5. Проверить на устройстве (см. §6).

Если вместо 4.4 решено обновиться до Godot 4.5 — тогда брать `v5.1.0`
(там UMP и Ad Inspector «из коробки», Editor Mock Ads для проверки в
редакторе) и обязательно перепроверить `.github/workflows/ios.yml`
(`GODOT_VERSION=4.4` → 4.5 и соответствующие export templates).

**Сверить после установки.** В `scripts/ads/admob_backend.gd` имена
`OnUserEarnedRewardListener` и `RewardItem` (`item.amount`, `item.type`) взяты
из C#-примеров README и не подтверждены GDScript-документацией v4.3.1 — при
установке аддона открыть `addons/admob/` и поправить имена, если отличаются.
UMP-методы (`present_privacy_options_form`, `request_consent_info_update`)
там же.

---

## 4. IAP: iOS

Плагин: **godot-sdk-integrations/godot-ios-plugins**, компонент `InAppStore`.
Готовых бинарников под Godot 4 нет (последний релиз — 3.5-stable, 2022).
Собрать самому:

```bash
git clone --recursive https://github.com/godot-sdk-integrations/godot-ios-plugins
cd godot-ios-plugins
# в каталоге godot/ выставить нужный тег движка, например 4.4-stable
scons platform=ios target=editor
./scripts/generate_xcframework.sh inappstore release 4.0
```

(Тот же шаг можно делать в CI на `macos-latest` — там уже есть Xcode.)

Установка в проект: положить `inappstore.gdip` и оба `*.xcframework` (debug и
release) в `res://ios/plugins/` (в 4.4 — именно `plugins`, не `plugin`; редактор
находит `.gdip` и в подпапках), затем в iOS-пресете экспорта →
`Options → Plugins` включить InAppStore. В редакторе синглтона нет, он
появляется только на устройстве/симуляторе. Товары заранее создать в
App Store Connect (для теста — Sandbox).

Свой плагин в проекте собирается так же — см. `ios/plugins/haptics/` (вибрация),
часть 3 и workflow `.github/workflows/ios-plugin.yml`.

Поведение обёртки: `request_product_info` при старте, опрос очереди событий
раз в секунду, `set_auto_finish_transaction(true)`.

---

## 5. IAP: Android

Плагин: **godot-sdk-integrations/godot-google-play-billing** (ветка master, Godot 4.2+).

1. Распаковать релиз в `res://addons/GodotGooglePlayBilling/`.
2. `Project Settings → Plugins` → включить.
3. В Android-пресете обязательно `gradle/use_gradle_build = true`.
4. Товары создать в Play Console; тестировать через internal testing
   (лицензионные тестировщики).

---

## 6. Проверка на живом iPhone

1. `git add -A && git commit -m "…" && git push origin main`.
2. GitHub → Actions → **iOS unsigned IPA (Sideloadly-ready)** → *Run workflow*.
3. Забрать артефакт `SweetieCatsCafe-ipa` (или из Telegram, если заданы
   `TELEGRAM_BOT_TOKEN` и `TELEGRAM_CHAT_IDS`).
4. Установить через Sideloadly (бесплатный Apple ID: срок 7 дней).
5. В игре: ⚙ → пройти кнопки техспайка по очереди, смотреть статус-строку и
   лог PostHog.

**Внимание:** `.github/workflows/ios.yml` содержит гейт `strict_free_signing`,
который требует `entitlements/push_notifications = "Disabled"` и
`entitlements/game_center = false` в iOS-пресете. Если плагин добавит push или
Game Center — гейт упадёт, его надо будет обновить.

Первый прогон без AdMob-ключа: PostHog включаеться одним ключом
`posthog_api_key` в `Config` — имеет смысл сначала проверить доставку событий,
потом рекламу.

---

## 7. Чек-лист фазы 0

- [ ] rewarded показан на iPhone, `rewarded_earned` дошёл (статус в игре)
- [ ] interstitial показан на iPhone, кулдаун работает
- [ ] UMP-форма открылась, `consent_finished(ok=true)`
- [ ] событие аналитики видно в PostHog (`rewarded_completed`/`technospike_action`)
- [ ] то же для Android (APK из `android.yml`)
- [ ] покупка тестового SKU на iPhone (Sandbox) → `purchase_succeeded`
- [ ] `restore()` вернул владения
- [ ] решение записано: остаёмся на плагинах или нужен нативный разработчик
      (Kotlin/Swift, 1–2 недели)

---

## 8. Что осталось за рамками техспайка

- Валидация чеков на сервере (фаза 3).
- Push-уведомления (фаза 2, нужен свой плагин или OneSignal).
- Медиация (AppLovin MAX и т. п.) — после софт-лонча, в MVP достаточно AdMob.
- ATT-запрос: если UMP-форма недоступна — дергать `OS.request_permission`
  вручную (iOS 14+).


---

# Часть 2. iOS без подписи и $99
Коротко: **установить игру на свой iPhone можно бесплатно — через Sideloadly с обычным бесплатным Apple ID.** Ни аккаунт разработчика, ни подпись, ни TestFlight для этого не нужны. Ограничение одно: приложение живёт **7 дней**, потом надо переустановить тем же Apple ID.

Что остаётся платным и недостижимым без Apple Developer Program ($99/год): **реальные IAP (в т.ч. sandbox), APNs-пуши, Game Center, iCloud, TestFlight, App Store, доход с рекламы в прод-виде.**

Ниже — что именно доступно и как это проверить.

---

## 1. Что доступно

| Что | Нужен $99? | Как |
|---|---|---|
| Компиляция Xcode-проекта | нет | `.github/workflows/ios.yml` (unsigned archive) |
| Запуск в **iOS Simulator** | нет | `xcodebuild -sdk iphonesimulator` + `xcrun simctl` |
| Проверка старта, UI, кор-лупа | нет | симулятор |
| **Установка на реальный iPhone** | **нет** | **Sideloadly + бесплатный Apple ID** (IPA из `ios.yml`), живёт 7 дней |
| Проверка производительности/FPS на реальном железе | **нет** | Sideloadly |
| Реклама AdMob (**тестовые** unit ID) | нет | симулятор и sideload-сборка |
| Флоу ATT-запроса | нет | на **устройстве** через sideload — настоящий статус |
| События PostHog | нет | любая сборка, нужен только интернет |
| IAP через **StoreKit Testing** | нет | только запуск из Xcode на симуляторе |
| IAP на устройстве | **да** | sideload не даёт entitlement → покупка падает |
| Push (имитация доставки) | нет | `xcrun simctl push` (симулятор) |
| Реальные APNs-пуши | **да** | сертификат + подпись (sideload не подходит) |
| TestFlight / App Store | **да** | Apple Developer Program |

---

## 2. Рендерер ⚠️

**iOS Simulator поддерживает только `Compatibility`.** Проект уже переведён на `gl_compatibility` (`project.godot` → `rendering/renderer/rendering_method`), так что симулятор работает. Откат — одна строка.

Для 2D merge-игры Compatibility не хуже: меньше требований, шире совместимость, стабильнее на слабых Android. Минус — часть 2D glow/bloom недоступна.

---

## 3. Симулятор локально

```bash
# 1. Экспорт Xcode-проекта из Godot (в iOS-пресете application/export_project_only=true)
"$GODOT" --headless --import
"$GODOT" --headless --export-release "iOS" build/ios/SweetieCatsCafe

# 2. Ищем .xcodeproj (имя Godot берёт из пути экспорта: SweetieCatsCafe)
XCPROJ=$(find build/ios -maxdepth 3 -name "*.xcodeproj" | head -n1)
SCHEME=$(basename "$XCPROJ" .xcodeproj)

# 3. Сборка под симулятор (подпись не нужна)
xcodebuild -project "$XCPROJ" -scheme "$SCHEME" \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/dd \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build

# 4. Запуск
xcrun simctl list devices available
xcrun simctl boot "iPhone 15"          # или доступный аналог
open -a Simulator
xcrun simctl install booted "$(find build/dd/Build/Products -maxdepth 2 -name '*.app' | head -n1)"
xcrun simctl launch --console booted com.oshinoko.mygame
```

Скриншот: `xcrun simctl io booted screenshot shot.png`. Логи Godot идут в stdout — `--console` их покажет.

---

## 4. CI

- `.github/workflows/ios-simulator.yml` — собирает `.app` под симулятор, поднимает симулятор, ставит, запускает, снимает скриншот.
- `.github/workflows/ios.yml` — собирает **`.ipa` под устройство** (arm64, iphoneos, unsigned) и отдаёт его в Telegram/artifact.

Второй — это и есть вход для Sideloadly.

---

## 5. Sideloadly: установка на реальный iPhone без $99

**Что нужно:**
- Mac (с Xcode) или Windows (с Apple Devices / iTunes);
- кабель + доверенный компьютер;
- **iOS 16+:** на iPhone включить *Настройки → Конфиденциальность и безопасность → Режим разработчика* (пункт появляется после первой попытки установки) и перезагрузить;
- бесплатный Apple ID (тот же, что в App Store; при 2FA — сгенерировать *пароль для приложения* на appleid.apple.com).

**Порядок:**
1. Забрать `SweetieCatsCafe.ipa` из артефакта `SweetieCatsCafe-ipa` (или из Telegram).
2. Sideloadly → подключить iPhone → перетащить `.ipa` в окно.
3. Ввести Apple ID (при 2FA — пароль для приложения) → **Start**.
4. На iPhone: *Настройки → Основные → VPN и управление устройством → Профиль разработчика → Доверять*.
5. Запуск.

**Сроки и лимиты:**
- Приложение работает **7 дней** с момента подписи, затем перестаёт открываться. Лечится повторным Sideloadly **тем же Apple ID** — данные при этом сохраняются, потому что bundle id не меняется.
- Бесплатный Apple ID умеет порядка **~10 уникальных App ID** (bundle id) за период, лимит периодически сбрасывается. Обычно хватает с запасом.
- Платный аккаунт ($99) поднимает срок до года и открывает push/IAP.

**Практические нюансы:**
- Не удаляй приложение с телефона — иначе потеряется `user://` (локальные сохранения). Для перезаливки Sideloadly переустанавливает поверх.
- В Sideloadly есть *Advanced → Change Bundle ID* — если bundle id конфликтует с уже установленным приложением.
- Сборка обязана быть под устройство (arm64/iphoneos). `.app` для симулятора не подойдёт — поэтому в CI собирается именно IPA.

**Что на sideload-сборке работает:**
- вся игра, UI, звук, FPS на реальном железе;
- вибрация (плагин `HapticsIOS`; в симуляторе её нет вообще — только на устройстве);
- rewarded/interstitial AdMob (в дев-сборке — **тестовые** unit ID);
- ATT-запрос — по-настоящему, со реальным статусом;
- PostHog-события.

**Что не работает:**
- IAP — нет entitlement, покупка не проходит (ни sandbox, ни StoreKit Testing);
- APNs-пуши, Game Center, iCloud, Apple Pay;
- TestFlight/App Store и публичный доход с рекламы.

**Почему CI собирает unsigned:** подпись делает Sideloadly твоим Apple ID. `application/app_store_team_id` в пресете нужен только для Xcode-подписи — для sideload он не важен (в CI стоит плейсхолдер и это нормально).

---

## 6. Реклама без аккаунта

- Google официально рекомендует **тестовые unit ID** (`ca-app-pub-3940256099942544/...`) — работают в симуляторе и на sideload-сборке.
- Реальная выдача в симуляторе не идёт; на устройстве через sideload живые ID могут показываться, но для дев-сборок использовать **тестовые** (самонажатия = риск бана).
- Тот же код, отличается только плагин (`godot-admob-ios` vs `godot-admob-android`).
- ATT: на устройстве через sideload запрос показывается по-настоящему — это единственный бесплатный способ проверить ATT целиком.

---

## 7. IAP без sandbox — StoreKit Testing

StoreKit Testing работает **только при запуске из Xcode** (симулятор или устройство, подключённое к Xcode). На sideload-сборке IAP **нет**.

1. Xcode: **File → New → File → StoreKit Configuration File** рядом с `.xcodeproj` (например `Products.storekit`).
2. Заполнить теми же SKU, что в `docs/GDD.md` §25.9 (`starter_pack`, `gems_small`, …, `no_ads`, `piggy_bank`), с типами consumable / non-consumable.
3. **Product → Scheme → Edit Scheme → Run → Options → StoreKit Configuration → Products.storekit**.
4. Запустить из Xcode — покупки идут локально, без App Store Connect и без sandbox-аккаунта.
5. Проверить: consumable, повторная покупка, `restore()`, кнопку «Восстановить покупки».

Полноценный IAP (реальные продукты, sandbox-аккаунт) — только с платным аккаунтом. До него IAP-код гоняем на **Android/Play Internal testing** (там всё доступно бесплатно) + StoreKit Testing в Xcode.

---

## 8. Push без подписи

Реальный APNs недоступен ни в симуляторе, ни на sideload-сборке. Проверяем **обработку** пейлоада:

```bash
xcrun simctl push booted com.oshinoko.mygame payload.json
```

`payload.json` — обычный APNs-payload (`{"aps":{"alert":"Кофе готов!","badge":1}}`). Локальные напоминания (`UNUserNotificationCenter` с триггером по времени) работают и без сертификатов — их и стоит закладывать в MVP по умолчанию.

---

## 9. Чек-лист

- [ ] кор-луп играется в симуляторе, FPS устраивает;
- [ ] IPA из `ios.yml` ставится через Sideloadly на iPhone и запускается;
- [ ] ATT-запрос реально показывается на устройстве;
- [ ] rewarded/interstitial показываются на тестовых ID;
- [ ] StoreKit Testing проходит в Xcode (покупка + restore);
- [ ] события PostHog улетают;
- [ ] UI не разъезжается на разных размерах экрана;
- [ ] сохранения переживают переустановку IPA (тот же bundle id).

Дальше уже можно думать про $99: он нужен **перед** TestFlight, реальными IAP и пушами — и позволяет поднять срок sideload-сборки с 7 дней до года.


---

# Часть 3. Вибрация (тактильный отклик)
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
