# iOS: что можно сделать без подписи, sandbox и без $99

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
"$GODOT" --headless --export-release "iOS" build/ios/TestGame

# 2. Ищем .xcodeproj (имя Godot берёт из config/name проекта)
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
1. Забрать `TestGame.ipa` из артефакта `TestGame-ipa` (или из Telegram).
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
2. Заполнить теми же SKU, что в `docs/economy.md` (`starter_pack`, `gems_small`, …, `no_ads`, `piggy_bank`), с типами consumable / non-consumable.
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
