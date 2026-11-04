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

### Медленно меняющееся состояние — в профиль (`$set`, с троттлингом)
`level`, `xp`, `board_cells`, `order_slots`, `boosters_used`. Источник — `game.gd:_push_analytics_state()`, который вызывается из `_refresh_hud()` (то есть после любого изменения состояния).

`Analytics.update_user_props()` копит словарь и отправляет его **не чаще `analytics_person_interval` секунд** (Config, по умолчанию 60), иначе каждое нажатие генератора порождало бы `$set`-событие. На сворачивании/закрытии приложения состояние дописывается принудительно (`flush(true)`).

### Моментальные значения — в свойствах событий, а не в профиле
`player_level`, `coins`, `gems`, `energy`, `free_cells` **не пишутся в person properties**: они меняются на каждом тапе, а профиль хранит одно «последнее» значение — по нему нельзя построить динамику (и каждое `$set` тратит квоту). Вместо этого они добавляются свойствами к важным игровым событиям через `game.gd:_log_game_event()` — он мержит `_analytics_snapshot()` в `params` (ключи из `params` перекрывают снимок: например `item_sold.level` — уровень предмета, а не игрока).

Правило: **нужно фильтровать игроков по значению во всей истории** → в профиль (`$set`/`$set_once`); **нужно знать, что было в момент события** → свойство события; **нужны суммы/средние** → считать в PostHog из событий, не хранить счётчик в профиле.

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
| Tutorial: step passed | `ftue_step` | по шагам FTUE | `step` |
| Generator: tapped | `generator_tap` | тап по генератору | `chain` |
| Item: merged | `item_merged` | drag-слияние | `chain`, `level` |
| Item: sold | `item_sold` | продажа (тап по предмету → меню действий) | `chain`, `level`, `coins` |
| Board: sold everything | `sell_all` | ⚙ → продать всё (кроме генераторов) | `count`, `coins` |
| Booster: used | `booster_used` | бустеры | `kind`, `cost` |
| Hammer: target picked | `booster_target` | молоток | `kind`, `cell` |
| Energy: out-of-energy screen shown | `energy_empty_shown` | нехватка энергии | `required`, `left` |
| Order: completed | `order_completed` | тап по карточке заказа | `coins`, `xp`, `gems`, `bonus` |
| Order: rerolled for gems | `order_rerolled` | кнопка реролла | `index`, `cost` |
| Level: up | `level_up` | `Progress.add_xp` | `level`, `previous` |
| Shop: opened | `shop_open` | попап меты (🐱) | — |
| Daily reward: claimed | `daily_reward_claim` | выдача ежедневной награды | `day`, `coins`, `gems`, `energy`, `cat` |
| Cat: unlocked | `cat_unlocked` | открыт новый кот | `cat`, `rarity`, `total` |
| Decor: purchased | `decor_purchased` | покупка в магазине мебели | `decor`, `cost`, `xp`, `via` |
| Decor: placed | `decor_placed` | декор поставлен в слот | `decor`, `slot`, `room` |
| Decor: rotated | `decor_rotated` | поворот предмета в слоте | `slot`, `rot` |
| Bubble: bought for gems | `bubble_bought` | пузырь забран | `chain`, `level`, `gems` |
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
| Purchase: initiated | `purchase_initiated` | тап по SKU | `sku`, `price_local` |
| Purchases: restore requested | `restore_purchases` | нажато восстановление | `count` |
| Piggy bank: filled | `piggy_bank_fill` | прогресс копилки вырос | `gems` |
| Piggy bank: unlocked | `piggy_bank_unlock` | копилка оплачена | `gems` |

Общие свойства добавляются к каждому событию автоматически: `$lib`, `$lib_version`, `$session_id`, `session_number`, `is_first_session`. Служебные `$set` / `$set_once` (профиль устройства и состояние игрока) описаны в §3 — так события остаются маленькими, а дашборды всё равно знают, кто их прислал.

**Правило против мусора:** если событие стреляет чаще 1 раза в 10 секунд (например, «Генератор: нажат»), шлём с сэмплированием ~10% и добавляем `sampled: true`, иначе квота сгорит на тапы.

---

## 6. Воронки и дашборды

Что собрать в PostHog в первый день:

1. **FTUE-воронка:** `first_open` → `ftue_step(step=opened)` → `ftue_step(step=first_generator)` → `ftue_step(step=first_merge)` → `ftue_step(step=first_order)` → `ftue_step(step=out_of_energy)`.
2. **Retention** по `session_start` (D1 / D7 / D30) — сверять с KPI из §25.11.
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

---

## 10. Справочник событий

> Подробное описание каждого события: что означает, когда срабатывает, какие параметры несёт.

Справочник по всем событиям PostHog: что означает, когда срабатывает, какие параметры несёт.

Схема именования (см. §5):
- в колонке **Event** в PostHog лежит человекочитаемое английское название (`Item: merged`);
- системный id (`item_merged`) уезжает свойством **`event_id`** — по нему строятся фильтры, выгрузки и старые дашборды;
- реестр названий — `Analytics.EVENTS` в `scripts/autoload/analytics.gd`. Забыли добавить событие — в лог уйдёт `warning: [Analytics] у события <id> нет названия в EVENTS`;
- в каждое событие автоматически добавляются `$lib`, `$lib_version`, `$session_id`, `session_number`, `is_first_session`;
- служебные `$set` / `$set_once` / `$session_id` не переводятся (названия с `$`).

---

### 10.1 Реализовано сейчас

| `event_id` | Название в PostHog | Когда | Параметры | Описание |
|---|---|---|---|---|
| `first_open` | Install: very first launch | Самый первый запуск игры на устройстве (`session_number == 1`) | `app_version`, `platform`, `device_type`, `locale` | Точка отсчёта воронки: установка состоялась и игра запущена. По нему считается new users, install→tutorial, install→first purchase. Один раз за установку. |
| `session_start` | Session: started | Каждый запуск приложения (`_ready()` аналитики) | `session_number`, `days_since_install`, `is_first_session` | Начало сессии. Даёт DAU/WAU/MAU, число запусков на игрока и retention по дням от установки. |
| `game_opened` | Game: opened | Сцена игры загрузилась и состояние восстановлено из сохранения | — | Успешный вход в игру с валидным сохранением. Разница `session_start` vs `game_opened` = падения/краши на загрузке. |
| `main_ready` | Main: scene ready | Готова главная (загрузочная) сцена | — | Метка готовности бут-пути, мерим время холодного старта. |
| `ftue_step` | Tutorial: step passed | Игрок прошёл шаг обучения | `step` | Воронка FTUE. По шагам видно, где новичок отваливается: первый генератор, первое слияние, первый заказ, экран «нет энергии». |
| `generator_tap` | Generator: tapped | Нажат генератор (успешно, предмет появился) | `chain` | Ключевая частота действий. По `chain` видно, какими цепочками игрок реально пользуется. Не логируется, если не хватило энергии или поле забито. |
| `item_merged` | Item: merged | Два одинаковых предмета слились в следующий уровень | `chain`, `level` | Ядро merge-геймплея. `level` — уровень получившегося предмета. По нему строится распределение прогресса и «стены» слияний. |
| `item_sold` | Item: sold | Предмет продан (тап по предмету → меню действий, кнопка «Продать», либо «Продать всё» из настроек) | `chain`, `level`, `coins` | Продажа за монеты. Показывает, что игроки считают лишним, и сколько монет приходит не через заказы. |
| `sell_all` | Board: sold everything | Массовая продажа всего поля из меню настроек | `count` | Реакция на «поле забито»/тупик. Частые `sell_all` = проблемы с экономикой поля, а не удобство. |
| `booster_used` | Booster: used | Бустер применён и списан | `kind`, `cost` | Спрос на бустеры и их цена (гемы за `kind`). Основа для оценки монетизации гемов. |
| `booster_target` | Hammer: target picked | Выбрана цель для молотка (после нажатия бустера) | `kind: hammer`, `cell` | Показывает, доходил ли игрок до конца применения молотка и куда бил (какая клетка). |
| `energy_empty_shown` | Energy: out-of-energy screen shown | Энергии не хватило на действие — открыт экран «нет энергии» | `required`, `left` | Главный момент монетизации: сколько энергии потребовалось и сколько осталось. |
| `order_completed` | Order: completed | Заказ сдан (все предметы на месте, награда выдана) | `coins`, `xp`, `gems`, `bonus` | Основной источник монет и XP. `bonus` — множитель за скорость (до ×1.5), `gems` — редкая гем-награда. |
| `order_rerolled` | Order: rerolled for gems | Заказ прокручен (реролл за гемы) | `index`, `cost` | Заказы, которые игрок не готов собирать. `cost` — списанные гемы. |
| `level_up` | Level: up | Повышен уровень прогресса | `level`, `previous` | Скорость прогрессии. От уровня висят гейты генераторов, слотов заказов, максимума. |
| `rewarded_started` | Rewarded ad: started | Игрок нажал кнопку «за рекламу» (показ начался) | `placement` | Спрос на rewarded-рекламу. Разрыв с `rewarded_completed` = проблемы SDK/заполнения. |
| `rewarded_completed` | Rewarded ad: reward granted | Реклама досмотрена, награда выдана | `placement`, `reward` / `amount` | Доходная реклама в действии. Считает конверсию «нажал → досмотрел». |
| `rewarded_failed` | Rewarded ad: failed | Реклама за награду не показалась или не дала награды | `placement`, `reason` | Причины: нет заполнения, ошибка SDK, игрок закрыл. Диагностика техспайка AdMob. |
| `interstitial_shown` | Interstitial ad: shown | Межстраничная реклама показана | `placement` | Частота и места показа. Вместе с `interstitial_failed` даёт реальный fill rate. |
| `interstitial_failed` | Interstitial ad: failed | Межстраничная реклама не показана | `placement`, `reason` | Проблемы с заполнением/частотой. Отсюда видно, не съедает ли реклама впечатление зря. |
| `consent_finished` | Consent: dialog closed | Экран GDPR-согласия закрыт | `ok`, `reason` | Обязательная для EU метрика: сколько игроков дали согласие, сколько отказались и по какой причине. |
| `consent_granted` | Consent: granted | Согласие выдано (аналитика получает право отправлять события) | — | Виден только у тех, у кого `analytics_consent_default = false` и игрок согласился вручную. |
| `technospike_action` | Tech spike: action | Нажата тестовая кнопка техспайка (в меню настроек тестового билда) | `action` | Служебное: проверка AdMob/IAP вручную. В релизном билде кнопки должны быть выключены. |
| `purchase_succeeded` | Purchase: succeeded | Покупка завершена успешно | `sku`, `keys` | Конверсия в платящих и структура платежей. `keys` — список полей из чека. |
| `purchase_failed` | Purchase: failed | Покупка не прошла | `sku`, `reason` | Причины отвалов на оплате. Прямо влияет на деньги, смотреть в первую очередь при просадке. |
| `purchases_restored` | Purchases: restored | Восстановление покупок завершено | `count` | Переустановки и смена устройства. Много восстановлений = игроки возвращаются с прошлым прогрессом покупок. |
| `shop_open` | Shop: opened | Открыт попап меты «Кофейня» (коты, декор, ежедневная награда) | — | Интерес к мета-контенту и к покупкам. Соотносится с `purchase_initiated` → `purchase_succeeded`. |
| `daily_reward_claim` | Daily reward: claimed | Получена ежедневная награда | `day`, `coins`, `gems`, `energy`, `cat` | Работа ежедневного цикла: `day` и стрик показывают, держит ли механика возвраты. |
| `cat_unlocked` | Cat: unlocked | Открыт кот (коллекционный контент) | `cat`, `rarity`, `total` | Прогресс по коллекции и интерес к мета-контенту. |
| `decor_purchased` | Decor: purchased | Куплен декор кафе (магазин мебели за монеты) | `decor`, `cost`, `xp`, `via` | Вложение монет в косметику — сигнал, что экономику можно углублять. |
| `decor_placed` | Decor: placed | Купленный декор поставлен в слот комнаты («🏠 Карта») | `decor`, `slot`, `room` | Насколько игрок вообще трогает расстановку: база для решения, развивать ли декорирование локации. |
| `decor_rotated` | Decor: rotated | Предмет в слоте повёрнут | `slot`, `rot` | Пользуются ли поворотом мебели. |
| `bubble_bought` | Bubble: bought for gems | Пузырь-копия после слияния забран за гемы | `chain`, `level`, `gems` | Конверсия «пузыря» в трату гемов. |

---

### 10.2 Запланировано (ещё не отправляется)

Этих id в `EVENTS` пока нет: когда появится код, id обязательно добавить в `EVENTS` (`scripts/autoload/analytics.gd`), иначе в лог уйдёт warning.

| `event_id` | Название в PostHog | Когда | Параметры | Описание |
|---|---|---|---|---|
| `rewarded_offered` | Rewarded ad: offer shown | Кнопка rewarded-рекламы показана игроку | `placement` | Знаменатель воронки рекламы: сколько раз предложили vs сколько нажали. |
| `ad_revenue` | Ad revenue | Импрессия с оценкой дохода (per-impression revenue) | `placement`, `value`, `currency` | Деньги с рекламы. Нужен, чтобы считать ARPDAU и LTV по каналам. |
| `purchase_initiated` | Purchase: initiated | Нажат товар, начато оформление | `sku` | Верх воронки оплаты: видно провал между «заинтересовался» и «заплатил». |
| `restore_purchases` | Purchases: restore requested | Нажата кнопка «восстановить покупки» | — | Явный интерес к восстановлению (до результата в `purchases_restored`). |
| `piggy_bank_fill` | Piggy bank: filled | Копилка наполнилась до порога | `amount`, `level` | Готовность игрока к разовой покупке копилки. |
| `piggy_bank_unlock` | Piggy bank: unlocked | Копилка открыта (куплена) | `amount`, `sku` | Конверсия из «наполнил» в «купил». Одна из ключевых точек монетизации. |
