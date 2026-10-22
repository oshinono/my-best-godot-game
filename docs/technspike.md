# Техспайк фазы 0: реклама, консент, покупки

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
`purchases_restored` (см. `docs/analytics.md`).

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
`docs/haptics.md` и workflow `.github/workflows/ios-plugin.yml`.

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
