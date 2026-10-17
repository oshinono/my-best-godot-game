# Аналитика — PostHog

Решение: **PostHog Cloud** (не Firebase, не свой REST). Причины:

- бесплатный тариф — 1 млн событий/мес, для софт-лонча хватает с запасом;
- воронки, retention, тренды и дашборды из коробки — не надо писать SQL;
- нет Firebase-зависимости (у Godot нет официального Firebase SDK, community-плагины часто отстают);
- можно self-host, если понадобится (Docker / PostHog Cloud EU для GDPR);
- проектный ключ `phc_...` публичный — его **безопасно** держать внутри игры.

Реализация — прямой HTTP POST на `capture` API, без SDK.
`scripts/autoload/analytics.gd`.

---

## 1. Настройка

1. Создать проект в PostHog → Settings → Project → скопировать **Project API Key** (`phc_...`).
2. Определиться с регионом:
   - `https://us.i.posthog.com` — US Cloud (по умолчанию);
   - `https://eu.i.posthog.com` — EU Cloud (для GDPR-чувствительных проектов).
3. Вписать в `Config` (`scripts/autoload/config.gd`):

| ключ | значение |
|---|---|
| `posthog_api_key` | `phc_...` (пусто = аналитика полностью выключена) |
| `posthog_host` | `https://us.i.posthog.com` или `https://eu.i.posthog.com` |
| `analytics_enabled` | `true` |
| `analytics_consent_default` | `true` для дев-сборок; при появлении экрана согласия — `false` |

> ⚠️ В игру кладём **только** проектный ключ (`phc_`). Персональный API-ключ (`phx_`) имеет полный доступ к аккаунту и в клиент не попадает никогда.

Ключ можно переопределить удалённым конфигом (`Config.REMOTE_CONFIG_URL`) — тогда аналитику можно включать/выключать без релиза.

---

## 2. Транспорт

`POST {host}/batch/` с телом:

```json
{
  "api_key": "phc_...",
  "batch": [
    {
      "event": "order_completed",
      "distinct_id": "8f3a...",
      "timestamp": "2026-10-16T12:00:00Z",
      "properties": { "$lib": "godot", "$session_id": "1c9b..." }
    }
  ]
}
```

Особенности, которые уже учтены в коде:

- **батч-отправка** — до 100 событий или каждые 30 с (`MAX_BUFFER`, `FLUSH_INTERVAL`);
- **ретрай** — до 3 попыток с задержкой 10 с, события возвращаются в буфер; после 3 неудач батч теряется, чтобы не течь памятью;
- **отправка при сворачивании/закрытии** — `NOTIFICATION_APPLICATION_PAUSED`, `NOTIFICATION_WM_CLOSE_REQUEST`;
- **оффлайн** — HTTPRequest падает → события лежат в буфере и уходят при следующем flush; при долгом оффлайне выживает только последнее окно (буфер в файл не пишем — для MVP не нужно).

---

## 3. Идентификация

- `distinct_id` — случайные 16 байт (`Crypto.generate_random_bytes(16).hex_encode()`), хранится в `user://analytics.cfg`. Ничего личного: ни email, ни имени, ни IDFA.
- `session_id` — новый на каждый запуск приложения, уезжает в `$session_id`.
- В `user://analytics.cfg` дополнительно лежат `first_seen_at` (unix первого запуска) и `sessions` (номер текущего запуска) — из них считаются `days_since_install`, `is_first_session`, `session_number`.

### Что собираем о платформе и устройстве (`$set_once`, один раз за установку)

Ключи с `$` — «родные» для PostHog: по ним из коробки работают дашборды **Devices / OS / GeoIP** и сегментация. Полный список — `Analytics._collect_device_props()`:

| Группа | Свойства |
|---|---|
| Платформа | `$os` (`OS.get_name()`), `$os_version`, `$device_type` (`mobile`/`desktop`/`web`), `$device_model` (`OS.get_model_name()` — на iOS/Android это `iPhone15,2`, `SM-G991B` и т.п.) |
| Приложение | `$app_version`, `$app_name`, `install_id_created_at` (unix первого запуска) |
| Локаль | `$locale`, `locale_language`, `$timezone` (`Time.get_time_zone_from_system().name`) |
| Экран | `$screen_width`, `$screen_height` (окно), `screen_native_width/height`, `screen_dpi`, `screen_count`, `screen_refresh_rate`, `touchscreen` |
| Железо | `cpu_count`, `cpu_name`, `memory_mb` (`OS.get_memory_info().physical`), `renderer` (GPU), `gpu_vendor`, `gpu_api` |
| Сборка | `engine_version`, `engine_build`, `engine_arch`, `renderer_method` (`gl_compatibility`), `is_debug_build`, `is_editor` |

Гео (страна/город/провайдер) PostHog добавляет сам на сервере по IP — в клиенте ничего для этого делать не нужно.

### Что обновляется каждый запуск (`$set`)
`platform`, `app_version`, `session_number`, `days_since_install`, `locale`, `device_type`, `last_seen_at` — см. `Analytics._session_person_props()`.

### Изменяемое состояние игрока (`$set`, с троттлингом)
Уровень, XP, монеты, гемы, энергия, занятость поля, число активных заказов, использованные бустеры. Источник — `game.gd:_push_analytics_state()`, который вызывается из `_refresh_hud()` (то есть после любого изменения состояния).

`Analytics.update_user_props()` копит словарь и отправляет его **не чаще `analytics_person_interval` секунд** (Config, по умолчанию 60), иначе каждое нажатие генератора порождало бы `$set`-событие. На сворачивании/закрытии приложения состояние дописывается принудительно (`flush(true)`).

Выключатель: `analytics_collect_device = false` в Config — тогда профиль устройства не собирается вовсе (остаются только ОС и версия приложения).

**Анонимные события.** Если хочется вообще без person profiles (экономия квоты и приватнее), добавить в properties `"$process_person_profile": false`. Тогда `identify()` теряет смысл — выбираем один из двух режимов до софт-лонча.

---

## 4. Согласие (GDPR / ATT)

- По умолчанию `analytics_consent_default = true` — для дев-сборок и тестов.
- Перед публичным релизом: поставить `false`, показать экран согласия (UMP на Android, ATT+UMP на iOS) и вызвать `Analytics.set_consent(true/false)`.
- `set_consent(false)` очищает буфер — ничего не уйдёт.
- Событие `consent_granted` фиксируется, чтобы видеть, какая доля игроков вообще даёт согласие (это же влияет на атрибуцию рекламы).

---

## 5. Схема событий (минимум MVP)

### Системное имя и человекочитаемое название

В PostHog событие хранится под человекочитаемым **английским названием** («Item: merged»), а системный snake_case id уезжает в свойство `event_id` (`item_merged`) — фильтры, выгрузки и код работают по стабильному id, а в интерфейсе видно понятный текст. Названия — реестр `Analytics.EVENTS` (`scripts/autoload/analytics.gd`), схема `id → "Название"`.

Добавить новое событие = одна запись в `EVENTS`; если её забыть, `Analytics` напишет в лог `warning: у события <id> нет названия в EVENTS`. Служебные события PostHog (`$set`, `$set_once`) и `$session_id` не переводятся: у них имя начинается с `$`.

### Реализовано сейчас

| Название в PostHog | `event_id` | Когда | Параметры |
|---|---|---|---|
| Install: very first launch | `first_open` | первый старт | `app_version`, `platform`, `device_type`, `locale` |
| Session: started | `session_start` | каждый старт | `session_number`, `days_since_install`, `is_first_session` |
| Game: opened | `game_opened` | `game.tscn` готова | — |
| Main: scene ready | `main_ready` | старт | — |
| Tutorial: step passed | `ftue_step` | по шагам FTUE | `step` |
| Generator: tapped | `generator_tap` | тап по генератору | `chain` |
| Item: merged | `item_merged` | drag-слияние | `chain`, `level` |
| Item: sold | `item_sold` | продажа (тап по предмету → меню действий) | `chain`, `level`, `coins` |
| Board: sold everything | `sell_all` | ⚙ → продать всё | `count` |
| Booster: used | `booster_used` | бустеры | `kind`, `cost` |
| Hammer: target picked | `booster_target` | молоток | `kind`, `cell` |
| Energy: out-of-energy screen shown | `energy_empty_shown` | нехватка энергии | `required`, `left` |
| Order: completed | `order_completed` | тап по карточке заказа | `coins`, `xp`, `gems`, `bonus` |
| Order: rerolled for gems | `order_rerolled` | кнопка реролла | `index`, `cost` |
| Level: up | `level_up` | `Progress.add_xp` | `level`, `previous` |
| Rewarded ad: started | `rewarded_started` | оффер энергии | `placement` |
| Rewarded ad: reward granted | `rewarded_completed` | конец rewarded | `placement`, `reward`/`amount` |
| Rewarded ad: failed | `rewarded_failed` | ошибка rewarded | `placement`, `reason` |
| Interstitial ad: shown | `interstitial_shown` | между уровнями/экранами | `placement` |
| Interstitial ad: failed | `interstitial_failed` | ошибка показа | `placement`, `reason` |
| Consent: dialog closed | `consent_finished` | онбординг | `ok`, `reason` |
| Consent: granted | `consent_granted` | после консента | — |
| Tech spike: action | `technospike_action` | ⚙ техспайк | `action` |
| Purchase: succeeded | `purchase_succeeded` | техспайк IAP | `sku`, `keys` |
| Purchase: failed | `purchase_failed` | техспайк IAP | `sku`, `reason` |
| Purchases: restored | `purchases_restored` | техспайк IAP | `count` |

### Запланировано (ещё не отправляется)

| Название в PostHog | `event_id` | Когда | Параметры |
|---|---|---|---|
| Rewarded ad: offer shown | `rewarded_offered` | оффер появился на экране | `placement` |
| Ad revenue | `ad_revenue` | paid-event от рекламного SDK | `ecpm`, `placement`, `network` |
| Shop: opened | `shop_open` | открыт магазин | `source_screen` |
| Purchase: initiated | `purchase_initiated` | тап по SKU | `sku`, `price_local` |
| Purchases: restore requested | `restore_purchases` | нажато восстановление | `count` |
| Piggy bank: filled | `piggy_bank_fill` | прогресс копилки вырос | `gems` |
| Piggy bank: unlocked | `piggy_bank_unlock` | копилка оплачена | `gems` |
| Daily reward: claimed | `daily_reward_claim` | daily-награда забрана | `day` (1–7) |
| Cat: unlocked | `cat_unlocked` | разблокирован новый кот | `cat_id`, `level` |
| Decor: purchased | `decor_purchased` | куплен предмет декора | `decor_id`, `cost`, `level` |

Общие свойства добавляются к каждому событию автоматически: `$lib`, `$lib_version`, `$session_id`, `session_number`, `is_first_session`. Служебные `$set` / `$set_once` (профиль устройства и состояние игрока) описаны в §3 — так события остаются маленькими, а дашборды всё равно знают, кто их прислал.

**Правило против мусора:** если событие стреляет чаще 1 раза в 10 секунд (например, «Генератор: нажат»), шлём с сэмплированием ~10% и добавляем `sampled: true`, иначе квота сгорит на тапы.

---

## 6. Воронки и дашборды

Что собрать в PostHog в первый день:

1. **FTUE-воронка:** `first_open` → `ftue_step(step=opened)` → `ftue_step(step=first_generator)` → `ftue_step(step=first_merge)` → `ftue_step(step=first_order)` → `ftue_step(step=out_of_energy)`.
2. **Retention** по `session_start` (D1 / D7 / D30) — сверять с KPI из `docs/economy.md`.
3. **Рекламная воронка:** `rewarded_offered` → `rewarded_started` → `rewarded_completed` (цель конверсии >60%).
4. **Монетизация:** `shop_open` → `purchase_initiated` → `purchase_succeeded` по `sku`.
5. **Энергия:** распределение `energy_empty_shown` по времени от `session_start` (цель — первая пустая энергия через 6–8 мин).
6. **Точка отвала:** где именно обрывается `ftue_step`.

---

## 7. Проверка

Локально (без сборки) — подставить ключ и запустить проект, в логах появится `[Analytics]`, в PostHog → **Activity → Live events** прилетит `session_start`.

Проверить сам эндпоинт без игры:

```bash
curl -X POST https://us.i.posthog.com/batch/ \
  -H 'Content-Type: application/json' \
  -d '{"api_key":"phc_ВАШ_КЛЮЧ","batch":[{"event":"test_event","distinct_id":"dev-local","properties":{"$lib":"curl"}}]}'
```

Ожидаемо: `{"status":1}` (или `200 OK`). Ошибка валидации ключа → сообщение об ошибке.

> PostHog НЕ возвращает ошибку, если у события нет `event`, нет `distinct_id` или `distinct_id` пустой — событие молча не попадёт в дашборды, но ответ будет 200. Поэтому писать в логи количество отправленных событий (`batch_sent`).

---

## 8. Объём и стоимость

- Ориентир: ~25–40 событий на игровую сессию.
- 5 сессий/день → ~150–200 событий на DAU в день → ~5–6 млн событий/мес на 1000 DAU (⚠️ это уже выше бесплатного 1 млн).
- Значит: либо сэмплирование «частых» событий, либо мягкий лонч с ограниченным набором событий (только FTUE + монетизация + реклама), либо платный тариф.
- Числа обязательно перепроверить до софт-лонча по факту.

---

## 9. Что дальше

- Дашборд «здоровье экономики»: монеты заработано/потрачено, гемы заработано/потрачено, источники и стоки.
- Feature flags PostHog (замена «своего серверного конфига» из плана) — можно катать A/B цен и офферов без релиза.
- Session replay для мобильных в MVP не используем (нужен нативный SDK).
- Нативные SDK PostHog (`posthog-android`, `posthog-ios`) подключать только если понадобятся push/feature flags — сейчас HTTP достаточно.
