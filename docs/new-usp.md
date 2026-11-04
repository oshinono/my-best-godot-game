# ТЗ: УТП «Живая кофейня»

Версия 1.0 · Sweetie Cat's Cafe · Godot 4.4, GDScript, portrait 720×1280 (ref 1080×1920), `gl_compatibility`.

---

## 1. Цель

Сшить два экрана в один мир: **кот в изометрии и кот в очереди заказов — это одно и то же существо с общим `customer_id`**. Очередь — видимый ресурс, а не UI-карточка. Коты-бариста — менеджеры этой очереди, а не пассивный +5% монет.

**Проверочный критерий успеха:** скринкаст 5 секунд, в котором видно как кот заходит в кофейню → появляется заказ на мердже → игрок обслуживает → кот уходит довольный. Без пояснений понятно, что происходит.

---

## 2. Границы

### Входит в MVP
- Очередь котов как единый источник правды в `OrderManager`.
- Компактное окно кофейни (изометрия) **постоянно видимо** на игровом экране над полем мерджа.
- Кот в окне: вход → ожидание → обслуживание → уход. Эмоции через badge.
- Полоса терпения над котом, уход по таймауту.
- Один слот бариста с одним перком (из 5 доступных).
- Аналитика, вибро, сейв.

### Не входит (v2+)
- Репутация кафе (УТП #7).
- Угощения / настроение (УТП #8).
- День-ночь (УТП #10).
- Фото-режим (УТП #9).
- Несколько слотов бариста.
- Коты ходят по изометрии между столиками и декором.
- Очередь переживает рестарт игры.

---

## 3. Пользовательский сценарий (кор-флоу)

1. Игрок на экране мерджа. Над полем — **окно кофейни** (изометрия, 720×180 px).
2. Раз в `queue.spawn_interval_min..max` секунд в кофейню **заходит кот**: Tween от края окна к слоту в очереди у стойки.
3. Одновременно над полем мерджа **падает карточка заказа** с тем же `customer_id` (существующий UI заказа, теперь с привязкой к коту).
4. Игрок мерджит предметы, добивается нужного сета, **тапает карточку заказа** → предметы списываются с борда → `customer_served`.
5. Кот в окне **встаёт, идёт к стойке, эмодзи «!», уходит вправо** (Tween + вибро `Haptics.impact`). Слот в очереди освобождается.
6. Если кот дождался таймаута терпения — **уходит грустный** («×», красная вспышка, `Haptics.selection`). Заказ исчезает с поля мерджа. Слот освобождается.
7. Если очередь **полна** — новый кот **не заходит**, над окном на 1 сек показывается «Полная очередь» (без блокировки мерджа).
8. **Бариста:** в окне стоит кот-бариста (по умолчанию — первый открытый кот из `Meta`). Тап по нему → попап выбора активного бариста из доступных в `Meta`. Выбранный даёт один перк (см. §7.3).

---

## 4. Компоновка экрана (portrait 720×1280)

```
┌────────────────────────────────────┐
│  HUD (coins / gems / energy / XP)  │  ~120px
├────────────────────────────────────┤
│  CAFE WINDOW (изометрия, окно)     │  ~180px   ← новое
│  [вход] [очередь котов] [стойка]   │           вибро-зона
│             [бариста]              │
├────────────────────────────────────┤
│  ORDER CARDS (существующие)        │  ~100px
├────────────────────────────────────┤
│  BOARD 5×6                         │  ~640px
│                                    │
├────────────────────────────────────┤
│  Generator bar / boosters          │  ~240px
└────────────────────────────────────┘
```

- Окно кофейни **сворачиваемое**: тап по шапке окна → expand в `cafe_view` (существующий полноэкранный вид декора). Свайп вниз / «назад» → обратно.
- В свёрнутом режиме — `cafe_view` не активен, показывает только очередь (см. §10).
- Полный экран `cafe_view` — существующий, добавляем только визуализацию очереди и бариста.

---

## 5. Архитектура: сигналы и поток данных

**Источник правды — `OrderManager`** (расширяем, не создаём автолоад). `cafe_view` — только визуализация. Правило проекта «логика сигналами» соблюдается.

### 5.1. `scripts/order_manager.gd` — новые сигналы

```gdscript
# Существующие сигналы сохраняются. Добавляем:
signal customer_arrived(customer_id: int, cat_id: String, order: Dictionary, patience_sec: float)
signal customer_state_changed(customer_id: int, state: String)
# state: "waiting" | "served" | "leaving_happy" | "leaving_angry"
signal customer_left(customer_id: int, reason: String)
# reason: "served" | "timeout" | "queue_full_rejected"
signal queue_changed(used: int, capacity: int)
signal barista_changed(barista_id: String)
```

### 5.2. Поток

```
OrderManager._timer.timeout()
  → spawn_customer()
      → создаёт Customer (id, cat_id, order, patience)
      → эмитит customer_arrived
      → эмитит queue_changed

cafe_view.on_customer_arrived()  → создаёт визуального кота, Tween «вход»
game.gd.on_customer_arrived()    → создаёт карточку заказа (существующий UI)

player taps order card
  → OrderManager.serve_customer(id)
      → эмитит customer_state_changed(id, "served")
      → эмитит customer_left(id, "served")
      → эмитит queue_changed

cafe_view.on_customer_left("served") → Tween «уход счастливый», Haptics.impact
game.gd.on_customer_left()           → удаляет карточку заказа

OrderManager._tick(delta)  # в _process
  → уменьшает patience у waiting-customer'ов
  → при 0 → customer_left(id, "timeout")
      → cafe_view: Tween «уход грустный», Haptics.selection
```

**Миграция:** существующий `create_order()` превращается в `spawn_customer()`. Внешний API заказов (`game.gd` создаёт карточки) не ломается — карточка теперь читает `customer_id` и при тапе вызывает `serve_customer(id)` вместо старого «отдать заказ».

### 5.3. Состояние Customer (внутренняя структура, не Resource)

```gdscript
# scripts/order_manager.gd
# Почему не Resource: живёт только в сессии, сериализация не нужна.
{
    "id": int,             # уникальный в сессии, автоинкремент
    "cat_id": String,      # из scripts/data/meta.gd (например "barista_mochi")
    "order": Dictionary,   # { chain: String, level: int, count: int, reward: {...}, xp: int }
    "patience_sec": float,
    "elapsed": float,
    "state": String,       # "waiting" | "served" | "leaving_*"
    "slot": int,           # индекс в очереди 0..capacity-1
}
```

---

## 6. Изменения по файлам

### 6.1. `scripts/autoload/config.gd`

Добавить в `values` (все числа — только здесь):

```gdscript
"queue.capacity": 5,
"queue.spawn_interval_min_sec": 20.0,
"queue.spawn_interval_max_sec": 45.0,
"queue.patience_base_sec": 90.0,
"queue.patience_by_temperament": {
    "hasty":  30.0,
    "normal": 90.0,
    "sleepy": 180.0,
},
"queue.patience_warn_ratio": 0.2,       # ниже — полоса краснеет
"queue.angry_xp_penalty_ratio": 0.5,    # сколько XP теряется при уходе (если успел накопить)
"cafe.window_height_px": 180,
"cafe.window_animation_in_sec": 0.5,
"cafe.window_animation_out_sec": 0.7,
"cafe.window_queue_full_badge_sec": 1.0,
```

> Значения — стартовые для плейтеста; правим в `Config` по фидбеку. Не зашивать в код.

### 6.2. `scripts/data/meta.gd` — barista-перки

Дополнить записи котов полем `barista_perk` (nullable):

```gdscript
{
    "id": "barista_mochi",
    "name": "Моти",
    "unlocked_by": "decor_kitchen_l2",
    "barista_perk": null,                # обычный кот — только +5% монет (как сейчас)
},
{
    "id": "barista_hasty",
    "name": "Соня",
    "barista_perk": "patience_plus_30",  # +30% терпения всем в очереди
},
{
    "id": "barista_speed",
    "name": "Скороход",
    "barista_perk": "slot_free_20",      # слот освобождается на 20% быстрее
},
{
    "id": "barista_manager",
    "name": "Менеджер",
    "barista_perk": "queue_plus_1",      # +1 слот очереди
},
{
    "id": "barista_esthete",
    "name": "Эстет",
    "barista_perk": "save_once_per_min",
    # раз в 60 сек один случайный кот в очереди не уходит по таймауту
},
{
    "id": "barista_barman",
    "name": "Бармен",
    "barista_perk": "next_order_x1_3",   # следующий обслуженный заказ ×1.3 к награде
},
```

**Правило:** только **один активный бариста** одновременно. Активный бариста **не даёт** пассивный +5% монет (чтобы был выбор, а не «просто лучше»). Коты вне слота — дают +5% как сейчас.

### 6.3. `scripts/order_manager.gd` — детально

```gdscript
# Новые поля
var _queue: Array[Dictionary] = []
var _next_customer_id: int = 1
var _spawn_timer: float = 0.0
var _spawn_interval: float = 0.0
var _active_barista_id: String = ""
var _esthete_cooldown: float = 0.0   # для перка Эстета

# Готово в _ready():
# _spawn_interval = randf_range(min, max)
# _active_barista_id = SaveManager.get("active_barista", "")

func _process(delta: float) -> void:
    _tick_spawn(delta)
    _tick_patience(delta)
    _tick_esthete(delta)

func spawn_customer() -> void:
    # Проверка полной очереди
    var cap := _get_queue_capacity()
    if _queue.size() >= cap:
        customer_left.emit(-1, "queue_full_rejected")   # без id — визуальный бейдж
        return
    var cust := _make_customer()
    _queue.append(cust)
    queue_changed.emit(_queue.size(), cap)
    customer_arrived.emit(cust.id, cust.cat_id, cust.order, cust.patience_sec)

func serve_customer(customer_id: int) -> void:
    var idx := _find_customer(customer_id)
    if idx < 0: return
    var cust := _queue[idx]
    cust.state = "served"
    customer_state_changed.emit(customer_id, "served")
    # награда через существующий _grant_order_reward(cust.order)
    _queue.remove_at(idx)
    customer_left.emit(customer_id, "served")
    queue_changed.emit(_queue.size(), _get_queue_capacity())

func _tick_patience(delta: float) -> void:
    for cust in _queue:
        if cust.state != "waiting": continue
        cust.elapsed += delta
        if cust.elapsed >= cust.patience_sec:
            cust.state = "leaving_angry"
            customer_left.emit(cust.id, "timeout")
            # penalty: XP не начисляется, монеты не списываются (уход — уже наказание)
    # удаление после итерации, чтобы не портить итератор
    for i in range(_queue.size() - 1, -1, -1):
        if _queue[i].state == "leaving_angry":
            _queue.remove_at(i)
    queue_changed.emit(_queue.size(), _get_queue_capacity())

func _get_queue_capacity() -> int:
    var cap: int = Config.get_value("queue.capacity")
    if _active_barista_id != "":
        var perk := _get_barista_perk(_active_barista_id)
        if perk == "queue_plus_1": cap += 1
    return cap

func set_active_barista(cat_id: String) -> void:
    _active_barista_id = cat_id
    SaveManager.set("active_barista", cat_id)
    barista_changed.emit(cat_id)
```

**Важно:** `_process` в `OrderManager` — новый расход. Раньше, вероятно, заказы спавнились по таймеру; проверяем, что таймер не дублируется (не должно быть одновременно `_timer` и `_process` — оставляем `_process`, убираем `_timer`).

### 6.4. `scripts/ui/cafe_view.gd` — окно кофейни

```gdscript
# Режимы
enum Mode { COLLAPSED, FULLSCREEN }
var _mode: Mode = Mode.COLLAPSED

# Контейнеры
@onready var _cats_layer: Node2D  # динамические коты, Tween-позиции
@onready var _barista_slot: Node2D
@onready var _queue_full_badge: Control

# Внутри
const SLOT_POSITIONS_PX := [Vector2(180, 120), Vector2(260, 120), Vector2(340, 120),
                            Vector2(420, 120), Vector2(500, 120), Vector2(580, 120)]  # 6 слотов max
const ENTRY_POS := Vector2(-100, 120)
const EXIT_POS  := Vector2(820, 120)
const COUNTER_POS := Vector2(360, 60)

func _ready() -> void:
    OrderManager.customer_arrived.connect(_on_customer_arrived)
    OrderManager.customer_left.connect(_on_customer_left)
    OrderManager.queue_changed.connect(_on_queue_changed)
    OrderManager.barista_changed.connect(_on_barista_changed)
    _spawn_barista()
    for cust in OrderManager.get_queue():    # восстановление после expand
        _spawn_visual_cat(cust, true)

func _on_customer_arrived(customer_id, cat_id, order, patience_sec) -> void:
    var cat := _spawn_visual_cat_from_cat_id(cat_id)
    cat.set_meta("customer_id", customer_id)
    cat.set_meta("patience_sec", patience_sec)
    cat.set_meta("elapsed", 0.0)
    var target := SLOT_POSITIONS_PX[_find_free_slot()]
    _tween_in(cat, target)
    Haptics.selection()   # лёгкий отклик «кто-то зашёл»

func _on_customer_left(customer_id, reason) -> void:
    var cat := _find_visual_cat(customer_id)
    if cat == null: return
    if reason == "served":
        _tween_served(cat)         # к стойке → «!» → exit, Haptics.impact
    elif reason == "timeout":
        _tween_angry(cat)          # «×» красным → exit, Haptics.selection

func _process(delta):
    # Полоса терпения над каждым котом
    for cat in _cats_layer.get_children():
        var ps: float = cat.get_meta("patience_sec", 90.0)
        var el: float = cat.get_meta("elapsed", 0.0) + delta
        cat.set_meta("elapsed", el)
        var ratio := clampf(1.0 - el / ps, 0.0, 1.0)
        cat.queue_redraw()   # _draw() рисует полосу
        if ratio < Config.get_value("queue.patience_warn_ratio"):
            cat.modulate = Color(1.0, 0.6, 0.6)   # легкий тинт

func _on_queue_changed(used, capacity):
    if used >= capacity:
        _show_queue_full_badge()
```

**Не пишем в `_draw()` для котов** — используем отдельный `Node2D` per-кот со своим `_draw()` для полосы, или `Label`/`TextureProgressBar` через тему. Иначе перерисовка всего окна 60 раз в секунду.

### 6.5. `scripts/ui/hud.gd` или `scenes/ui/cafe_window.tscn`

Если создаём отдельную сцену — подключаем к `game.tscn` в узле `CafeWindow` (не автолоад, не глобальный). Высота по `Config.get_value("cafe.window_height_px")`.

### 6.6. `scripts/game.gd` — минимальные изменения

```gdscript
# _ready(): добавлен узел CafeWindow в scene tree, OrderManager доступен
# Слушаем customer_arrived → создаём карточку заказа (существующий код)
# Слушаем customer_left → удаляем карточку

func _on_customer_arrived(customer_id, cat_id, order, patience_sec):
    var card := _make_order_card(customer_id, order)
    _order_cards_layer.add_child(card)

func _on_customer_left(customer_id, reason):
    var card := _find_order_card(customer_id)
    if card: card.queue_free()
```

**Не тянем `get_parent()`** — сигналы идут через `OrderManager`.

### 6.7. `resources/ui_theme.tres` + `assets/ui/theme/`

- Иконка `queue_full.png` для бейджа.
- Иконка `barista_slot.png` (пустой слот бариста).
- Badge-эмоции (`badge_happy`, `badge_waiting`, `badge_angry`) — 3 значка 32×32 px (ref 4x).
- **Собирать через `tools/build_ui_theme.gd`**, ссылки только на `assets/ui/theme/`.

### 6.8. `scripts/dev/selftest.gd`

Добавить сценарий:
1. Создать 5 customers → очередь полна → проверить `queue_full_rejected`.
2. Обслужить 1 → `queue.size() == 4`.
3. Проверить таймаут: установить `patience = 0.1`, дождаться `customer_left("timeout")`.
4. Назначить бариста с `queue_plus_1` → `capacity == 6`.
5. Снять бариста → `capacity == 5`.
6. **Откатить состояние** (save/restore) — правило selftest.

---

## 7. Перки бариста (детально)

| per|perk|поведение|где реализовать|
|---|---|---|---|
| Скороход | `slot_free_20` | Слот освобождается на 20% быстрее — снижаем `patience_sec` * 0.8 при `spawn_customer` | `OrderManager._make_customer` |
| Дипломат | `patience_plus_30` | `patience_sec *= 1.3` | `OrderManager._make_customer` |
| Эстет | `save_once_per_min` | Раз в `60 сек` один случайный waiting-кот получает +30 сек к терпению (визуально — «любуется декором», heart badge) | `OrderManager._tick_esthete` |
| Менеджер | `queue_plus_1` | `_get_queue_capacity() += 1` | `OrderManager._get_queue_capacity` |
| Бармен | `next_order_x1_3` | После `serve_customer` следующий `_grant_order_reward` × 1.3, флаг сбрасывается | `OrderManager.serve_customer` / `_grant_order_reward` |

Правило: **один бариста в слоте**. Перк **стакается** с пассивными +5% от остальных котов.

---

## 8. Save-поля (`SaveManager`)

```gdscript
# Только то, что должно переживать рестарт.
{
    "active_barista": "",                 # String cat_id или ""
    "customers_served_total": 0,          # счётчик для аналитики и будущих ачивок
    "customers_lost_total": 0,            # счётчик ушедших
}
```

Очередь **не сохраняется** (MVP). На старте сессии `_queue` пустая, спавн по обычному таймеру. Пишем аналитику — можно потом решить, надо ли.

Запись — только через `SaveManager` (отложенная 1.5 с, атомарная, с `.bak`). Не писать файл вручную.

---

## 9. Аналитика (PostHog)

**Правило проекта:** новое событие = запись в `Analytics.EVENTS`. Иначе warning в лог.

### Добавить в `Analytics.EVENTS`:

```gdscript
"customer_arrived":        "Customer Arrived",
"customer_served":         "Customer Served",
"customer_left_angry":     "Customer Left Angry",
"queue_full_rejected":     "Queue Full Rejected",
"barista_assigned":        "Barista Assigned",
"cafe_window_expanded":    "Cafe Window Expanded",
```

### Отправка через `game.gd:_log_game_event()` (снапшот уже мержится автоматически):

```gdscript
Analytics.track("customer_arrived", {
    "cat_id": cat_id,
    "order_value": order.total_reward,   # сумма в монетах
    "queue_used": _queue.size(),
    "queue_capacity": _get_queue_capacity(),
})

Analytics.track("customer_served", {
    "cat_id": cat_id,
    "time_to_serve_sec": cust.elapsed,
    "queue_used": _queue.size(),
})

Analytics.track("customer_left_angry", {
    "cat_id": cat_id,
    "waited_sec": cust.elapsed,
    "patience_sec": cust.patience_sec,
    "queue_used": _queue.size(),
})

Analytics.track("barista_assigned", {
    "barista_id": cat_id,
    "perk": perk_name,
})
```

Ключевые метрики для проверки УТП:
- **% сессий с ≥1 обслуженным котом** (вовлечённость в очередь)
- **Средний `time_to_serve_sec`** (реально ли борд справляется)
- **`customer_left_angry` / `customer_served`** (сложность — держать 20–40%)
- **`cafe_window_expanded` на сессию** (интерес к изометрии)

---

## 10. UX: анимация, эмоции, вибро

### 10.1. Анимации (Tween)

| Событие | Позиция | Длительность | Эмоция |
|---|---|---|---|
| Вход | ENTRY_POS → слот | `cafe.window_animation_in_sec` (0.5) | «?» |
| Ожидание | bob (sin) ±4 px | бесконечно | «?» / «!» при ratio > warn |
| Обслуживание | слот → COUNTER_POS → EXIT_POS | 0.3 + 0.4 = 0.7 | «!» зелёный |
| Уход по таймауту | слот → EXIT_POS (быстро, вниз) | `cafe.window_animation_out_sec` (0.7) | «×» красный |

Позиции слотов — константы в `cafe_view.gd` (UI, не баланс — выносить в Config не нужно). Шесть слотов максимум.

### 10.2. Полоса терпения

- Тонкая (3 px) горизонтальная полоса над головой.
- Цвет: зелёный → жёлтый → красный по `queue.patience_warn_ratio`.
- Через `TextureProgressBar` с темой (не `_draw()` всего окна).

### 10.3. Вибро (единственная обратная связь — звука нет)

| Момент | Вызов |
|---|---|
| Кот зашёл | `Haptics.selection()` |
| Кот обслужен | `Haptics.impact()` |
| Кот ушёл грустный | `Haptics.selection()` (намеренно мягче — не наказывать за раздражитель) |
| Очередь полна (бейдж) | без вибро |

### 10.4. Визуальные якоря для скриншота

- Окно кофейни — **не серое**. Мягкий градиент, тёплые тона, декор виден по краям.
- Кот при входе — **отбрасывает лёгкую тень** на пол (`ColorRect` под спрайтом, modulate alpha).
- Слот бариста — **светлое пятно** на полу (луч света / коврик), не пустая иконка.

Это нужно, чтобы окно читалось как «диорама», а не как «ещё одна панель UI».

---

## 11. Edge cases

| Кейс | Поведение |
|---|---|
| Очередь полна, спавн тикает | `spawn_customer` эмитит `queue_full_rejected`, бейдж 1 сек, спавн-таймер сбрасывается (чтобы не спамить) |
| Кот ушёл, а его заказ игрок в этот момент тапает | `serve_customer` проверяет `state == "waiting"`, иначе no-op |
| Player закрывает игру с полной очередью | Очередь очищается, на старте — новая. Аналитика не считает это «потерей» |
| Бариста назначен, но не открыт в `Meta` | При загрузке `set_active_barista` игнорируется, `active_barista = ""` |
| Все слоты визуально заняты, но `queue.size() < capacity` (баг синхронизации) | `_spawn_visual_cat` ищет свободный слот по `cat.slot`, а не по индексу — исключаем рассинхрон |
| Expand окна во время анимации ухода | Анимация прерывается, кот мгновенно перемещается — не блокируем UX |
| `QueueFullRejected` без `customer_id` (-1) | `cafe_view._on_customer_left` фильтрует: `customer_id < 0` → только бейдж, не ищем визуального кота |
| iOS Simulator / `gl_compatibility` | Tween работает, `Haptics` — заглушка (плагин), эмодзи могут не рендериться — **используем `TextureRect` с PNG, не emoji-символы** |

---

## 12. Что НЕ трогаем

- **Не меняем** `Board` (`board.gd`, `item.gd`, `resources/item_data.gd`) — очередь полностью снаружи.
- **Не меняем** цепочки (`chains.gd`) — 3 цепочки как есть.
- **Не добавляем** звук (`AudioStreamPlayer`) — только вибро.
- **Не добавляем** автолоады — только расширяем `OrderManager` и `Config`.
- **Не трогаем** `analytics.gd` логику батча/ретрая — только `EVENTS`.
- **Не меняем** `resources/ui_theme.tres` радикально — только добавляем Type Variations / иконки.

---

## 13. Этапы

### MVP (рекомендую к коммиту первым)
- `Config` ключи (§6.1)
- `OrderManager`: `_queue`, `spawn_customer`, `serve_customer`, `_tick_patience`, сигналы (§6.3)
- `cafe_view` collapsed: слоты, Tween вход/выход, полоса терпения, эмоции (§6.4)
- `game.gd`: карточки заказов через `customer_id` (§6.6)
- Аналитика (§9)
- Вибро (§10.3)
- selftest сценарий (§6.8)
- **Без бариста** (слот не показываем, очередь = 5)

**Оценка:** 1.5–2 дня.

### v1.1 (бариста)
- `meta.gd`: `barista_perk` (§6.2)
- `OrderManager`: `set_active_barista`, перки (§6.3, §7)
- `cafe_view`: слот бариста, попап выбора
- `Haptics` на назначение
- Аналитика `barista_assigned`
- Иконки в `assets/ui/theme/` через `tools/build_ui_theme.gd`

**Оценка:** 1 день.

### v1.2 (полировка)
- expand окна → полноэкранный `cafe_view`
- тени под котами, свет на бариста
- бейдж `queue_full`
- фоновая анимация окна (декор, кофе-машина)

**Оценка:** 0.5–1 день.

---

## 14. Приёмка (что проверяем перед коммитом)

### Selftest
```bash
godot --headless --path . -- --selftest
# В логе: [selftest] queue_capacity OK
# [selftest] serve_customer OK
# [selftest] patience_timeout OK
# [selftest] barista_perk_queue_plus_1 OK
# [selftest] barista_perk_patience_plus_30 OK
# [selftest] rollback OK
```

### Ручной кор-луп
1. Запустить игру → над полем окно кофейни.
2. Через 20–45 сек кот входит (Tween 0.5с), полоса терпения зелёная.
3. На мердж-экране появилась карточка заказа с тем же котом.
4. Собрать сет, тапнуть карточку → кот в окне идёт к стойке, «!», уходит. `Haptics.impact`.
5. Довести очередь до 5 котов → следующий спавн заблокирован, бейдж «Полная очередь».
6. Дать коту дождаться таймаута → уходит грустный, `Haptics.selection`, карточка исчезает.
7. Назначить бариста с `queue_plus_1` → в окне видно 6 слотов.
8. Свернуть/развернуть окно → анимации не ломаются, коты на местах.

### Проверка регрессий
- `Board` merge/drag — не затронуты.
- Заказы (карточки) — работают как раньше, но с `customer_id`.
- Save/load — `active_barista` переживает рестарт.
- `gl_compatibility` + iOS Simulator — окно рендерится (заглушки вместо эмодзи — через PNG).

### Аналитика
- PostHog получает `customer_arrived`, `customer_served`, `customer_left_angry` в течение сессии.
- Снапшот (`player_level`, `coins`, `gems`, `energy`, `free_cells`) мержится в игровые события.

---

## 15. Риски и смягчение

| Риск | Смягчение |
|---|---|
| Портрет 720×1280 — окно съедает 180 px у борда | Сделать окно **сворачиваемым до 100 px** (только вход + стойка + бариста) тапом; полный вид — expand |
| Tween 60 раз в секунду на 5–6 котах — нагрузка на mobile | Один Tween на кота, не пересоздавать; полосу рисовать через `TextureProgressBar`, а не `_draw()` |
| Игрок не понимает, что кот и карточка — один персонаж | Визуальный якорь: цвет шарфа/шапки кота в окне = цвет карточки заказа. `cat_id` → общий `Color` в `art.gd` |
| Полная очередь раздражает | Не блокировать мердж; блокировать только спавн, бейдж 1 сек. Игрок сам решит, ждать или нет |
| Бариста выбран, но не даёт +5% | В попапе выбора бариста — **явно показать**: «+30% терпения (вместо +5% монет)» |
| Скрытая потеря заказа при таймауте | Полоса терпения видна; у `queue.patience_warn_ratio` — пульс полосы + кот переминается (Tween micro-shake) |

---

## 16. Критерии готовности (Definition of Done)

- [ ] `godot --headless --path . --import` — без ошибок.
- [ ] `godot --headless --path . -- --selftest` — `[selftest] ... OK` + `user://selftest_result.txt`.
- [ ] Ручной кор-луп из §14 проходит.
- [ ] Все новые числа — в `Config.values`, магических чисел в `order_manager.gd` / `cafe_view.gd` нет.
- [ ] Все новые события — в `Analytics.EVENTS`.
- [ ] Новые иконки — собраны через `tools/build_ui_theme.gd`, ссылки только на `assets/ui/theme/`.
- [ ] Комментарии — по-русски, коротко, «почему», а не «что».
- [ ] Нет `AudioStreamPlayer`, нет `get_parent()` в новой логике, нет новых автолоадов.
- [ ] Save через `SaveManager` (отложенная запись, атомарная, `.bak`).
- [ ] Скринкаст 5 секунд «кот заходит → заказ → обслуживание → уходит» приложен к PR.

---

Если хочешь — распишу **сигнатуру `_make_customer()`** и точную миграцию текущего `create_order()` (что искать в существующем `order_manager.gd`, что переименовать, как не сломать UI-карточки), чтобы правки были механическими.