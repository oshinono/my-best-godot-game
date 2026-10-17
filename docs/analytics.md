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
- `identify({...})` шлёт событие `$set` и обновляет свойства пользователя (person properties). Вызывать редко: уровень, монеты, число покупок. Каждое `$set` — это тоже событие в лимите.

**Анонимные события.** Если хочется вообще без person profiles (экономия квоты и приватнее), добавить в properties `"$process_person_profile": false`. Тогда `identify()` теряет смысл — выбираем один из двух режимов до софт-лонча.

---

## 4. Согласие (GDPR / ATT)

- По умолчанию `analytics_consent_default = true` — для дев-сборок и тестов.
- Перед публичным релизом: поставить `false`, показать экран согласия (UMP на Android, ATT+UMP на iOS) и вызвать `Analytics.set_consent(true/false)`.
- `set_consent(false)` очищает буфер — ничего не уйдёт.
- Событие `consent_granted` фиксируется, чтобы видеть, какая доля игроков вообще даёт согласие (это же влияет на атрибуцию рекламы).

---

## 5. Схема событий (минимум MVP)

| Событие | Когда | Параметры |
|---|---|---|
| `session_start` | старт приложения | — |
| `game_opened` | сцена `game.tscn` готова | — |
| `first_open` | самый первый запуск | `app_version` |
| `ftue_step` | шаг туториала (один раз на шаг, флаг `ftue_<step>` в сейве) | `step` (name) |
| `generator_tap` | тап по генератору (удачный) | `chain` |
| `item_merged` | успешное слияние | `chain`, `level` (результат) |
| `item_sold` | предмет продан (drag за поле / «продать всё») | `chain`, `level`, `coins` |
| `sell_all` | кнопка «продать всё поле» в настройках | `count` |
| `order_completed` | заказ выполнен | `coins`, `xp`, `gems`, `bonus` |
| `order_rerolled` | смена заказа за гемы | `index`, `cost` |
| `booster_used` | бустер сработал | `booster` |
| `booster_target` | выбран предмет для молотка | — |
| `energy_empty_shown` | показан экран пустой энергии | `required`, `left` |
| `level_up` | новый уровень | `level`, `previous` |
| `rewarded_offered` | оффер показан игроку | `placement` |
| `rewarded_started` | игрок нажал «смотреть» | `placement` |
| `rewarded_completed` | награда выдана | `placement`, `amount` (у техспайка — `reward`) |
| `rewarded_failed` | реклама не загрузилась | `placement`, `reason` |
| `interstitial_shown` | показ межстраничной | `placement` |
| `interstitial_failed` | межстраничная не показана | `placement`, `reason` (например `cooldown`) |
| `consent_finished` | итог UMP/ATT-консента | `ok`, `reason` |
| `technospike_action` | нажата кнопка техспайка в настройках | `action` |
| `ad_revenue` | paid-event от SDK | `ecpm`, `placement`, `network` |
| `shop_open` | открыт магазин | `source_screen` |
| `purchase_initiated` | тап по SKU | `sku`, `price_local` |
| `purchase_succeeded` | покупка прошла | `sku` |
| `purchase_failed` | ошибка/отмена | `sku`, `reason` |
| `restore_purchases` | восстановление | `count` |
| `piggy_bank_fill` | копилка пополнена | `gems` |
| `piggy_bank_unlock` | копилка куплена | `gems` |
| `daily_reward_claim` | забран daily | `day` (1–7) |
| `cat_unlocked` | открыт кот | `cat_id`, `level` |
| `decor_purchased` | куплен декор | `decor_id`, `cost`, `level` |

Общие свойства добавляются автоматически: `$lib`, `$lib_version`, `$session_id`, `platform`, `app_version`.

**Правило против мусора:** если событие стреляет чаще 1 раза в 10 секунд (например, `generator_tap`), шлём с сэмплированием ~10% и добавляем `sampled: true`, иначе квота сгорит на тапы.

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
