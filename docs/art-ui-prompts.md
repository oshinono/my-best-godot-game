# Промпты: UI — HUD, кнопки, панели, попапы

Промпты для генерации растрового UI (`Midjourney / SD / DALL·E / Flux`).
Промпты — по-английски, пояснения — по-русски: так их проще копировать, а
правила остаются читаемыми.

> **Этот файл заменяет §10 «UI-кит» из `docs/art-prompts.md`.** Там раздел был
> написан «на будущее», когда UI собирался из `ColorRect` и `StyleBox`. Сейчас
> новый HUD (`scripts/ui/game_hud.gd`) держит **15 слотов `Texture2D`**, и
> картинки нужны конкретные, под конкретные размеры. §10 в `art-prompts.md`
> оставлен как история; актуальные промпты — здесь.

---

## 1. Что уже есть и что генерируем

| Что | Статус | Где лежит |
|---|---|---|
| Иконки-символы (PNG) | ✅ готовы, генерировать НЕ надо | `assets/ui/hud/`, `assets/ui/buttons/` — маппинг в `docs/ui-icons.md` |
| HUD: значки, плашки, кнопки | ✅ 18 PNG | `assets/ui/hud/` |
| Кнопки попапов | ✅ 8 PNG | `assets/ui/buttons/` |
| Панели и карточки попапов | ✅ 5 PNG | `assets/ui/panels/` |
| Кафе: карточки, счётчики | ✅ 4 PNG | `assets/ui/cafe/` |

Иконки (шестерёнка, монета, кристалл, молния, подарок, тележка и т.д.)
уже существуют растровым артом и раскрашиваются кодом (`modulate`). Их
перегенерировать не нужно — **кроме случаев, когда нужен цветной значок с
подложкой** (крупные бейджи в плашках ресурсов, см. §5).

---

## 2. Общий стиль UI

К мастер-блоку из `docs/art-prompts.md` §1 добавляем UI-часть: чёткая
читаемость в мелком размере, одинаковый радиус скругления, никакого «стекла» и
тяжёлых теней — движок сам рисует тень/нажатие.

**UI style block (добавлять в конец каждого промпта):**

```
cozy casual mobile game ui element, 2d stylized, soft rounded shapes,
thick smooth dark-brown outline #4A3226, subtle inner bevel, gentle top light,
warm cozy palette (cream #F6E7D8, latte #E8C39E, caramel #C98A5E,
terracotta #E2946B, honey #F2C14E, sage #A8C0A0), flat clean shading,
centered, transparent background, high readability at small size,
no text, no numbers, no watermark, no frame
```

**Negative prompt:**

```
text, letters, numbers, watermark, signature, logo, photorealistic, 3d render,
harsh shadows, heavy drop shadow, glow, glass, metal gradient, noise, film grain,
gradient banding, blurry, low contrast, cluttered background, collage,
multiple objects, sticker sheet, frame border, perspective, isometric
```

**Правила, которые важнее промпта:**

1. **Никакого текста и цифр** — числа рисует шрифт Godot (`font_size_value`,
   `font_size_level`). Буквы на картинке всегда выглядят чужими.
2. **Одна картинка = один элемент.** Никаких «листов» с 9 кнопками: режем сам.
3. **Прозрачный фон**, объект по центру, поля по краям ~4–6% (кроме 9-slice,
   там поля заданы отдельно).
4. **Без запечённой тени** — `_bind_press()` уже делает tween-нажатие.
5. **Один стиль на все кнопки**: одинаковый радиус, одинаковая толщина обводки,
   один источник света сверху. Иначе HUD «рассыпается».

---

## 3. Технические требования

| Параметр | Значение |
|---|---|
| Формат | PNG-24 + alpha, lossless |
| Генерация | 1024 px, потом даунскейл до экспортного размера (не наоборот) |
| Экспортный размер | авторский px × **4** (см. ниже) — для ретины |
| Рабочая база | 1080×1920 (в ней заданы `Sizes` в `game_hud.gd`) |
| Экран проекта | 720×1280 → всё умножается на `ui_scale = 0.6667` |
| Импорт в Godot | `Filter: on`, `Mipmaps: off`, `Compress: Lossless`, `Fix Alpha Border: on` |
| 9-slice | `tex_bar_bg`: `nine_patch_margin = 20` (авторских) = 13 на экране |

**Почему ×4.** В Инспекторе размеры заданы в авторских px (например, кнопка
96×96), на экран она попадает как 64×64. При генерации удобно рисовать крупно:
экспорт 96×4 = **384 px**. Godot ужмёт сам, и на ретине будет резко.

**Порядок работы:** сгенерировать → вырезать объект с прозрачностью → сжать до
экспортного размера → сохранить под именем слота → положить в папку → назначить
текстуру (см. §9).

---

## 4. Верхний HUD — 7 слотов

Верхняя строка: бейдж уровня, три плашки ресурсов (энергия / монеты / гемы) с
кнопками «+», кнопка магазина.

| Слот | Файл | Авторский | На экране | Что это |
|---|---|---|---|---|
| `tex_level_badge` | `assets/ui/hud/level_badge.png` | 96×96 | 64×64 | подложка круглого бейджа уровня |
| `tex_bar_bg` | `assets/ui/hud/bar_bg.png` | 225×45 | 150×30 | 9-slice пилюля плашки |
| `tex_icon_energy` | `assets/ui/hud/icon_energy.png` | 69×69 | 46×46 | цветной значок «молния» |
| `tex_icon_coin` | `assets/ui/hud/icon_coin.png` | 69×69 | 46×46 | цветной значок «монета» |
| `tex_icon_gem` | `assets/ui/hud/icon_gem.png` | 69×69 | 46×46 | цветной значок «кристалл» |
| `tex_plus_badge` | `assets/ui/hud/plus_badge.png` | 33×33 | 22×22 | зелёный кружок «+» на плашке |
| `tex_shop` | `assets/ui/hud/shop.png` | 81×81 | 54×54 | кнопка магазина |

### 4.1 `level_badge.png` — бейдж уровня

Число уровня рисуется шрифтом поверх, по центру. Значит центр должен быть
чистым и контрастным (светлая «тарелка»), без звезды ровно в центре.

```
round game ui badge, honey-gold outer ring, cream center plate for a number,
thick dark-brown outline, subtle inner bevel, tiny coffee bean ornaments on the ring,
top light, button game ui, centered, transparent background,
no text, no numbers, no star in the center
```

### 4.2 `bar_bg.png` — плашка ресурса (9-slice!)

Тянется по ширине, режется по 20 px с каждого края (в экспорте ×4 — по 80 px).
Значит: **ровный центр без деталей**, скругления и обводка только по краям.
Внутри справа будет текст, слева — значок, поэтому центр — просто кремовое поле.

```
horizontal rounded pill ui panel, 9-slice friendly, cream #F6E7D8 center,
caramel #C98A5E border, thick smooth dark-brown outline, subtle top highlight,
flat uniform center with no details, cozy mobile game ui,
transparent background, no text, no icons, no shadow
```

> Пояснение: картинку режут на 9 частей по `nine_patch_margin`. Если в центре
> окажется блик или завитушка — она растянется в полосу и будет видно.

### 4.3 `icon_energy.png` / `icon_coin.png` / `icon_gem.png` — значки ресурсов

Это **отдельные цветные кружки-бейджи**, они торчат слева от плашки на половину
своего диаметра. Внутри — белая иконка, контур тёмно-коричневый, как у всего UI.

```
round game ui icon badge, honey-yellow gradient circle, white lightning bolt symbol,
thick dark-brown outline, subtle top light and inner bevel, centered,
transparent background, no text, no numbers, no shadow
```

```
round game ui icon badge, gold coin with a small star embossed, white icon area,
thick dark-brown outline, subtle top light and inner bevel, centered,
transparent background, no text, no numbers, no shadow
```

```
round game ui icon badge, magenta-pink gem with white facet highlights,
thick dark-brown outline, subtle top light and inner bevel, centered,
transparent background, no text, no numbers, no shadow
```

### 4.4 `plus_badge.png` — кнопка «+»

Маленькая кнопка на плашке энергии и гемов: открывает rewarded / покупку.
Рисуется поверх плашки в правом нижнем углу значка. Должна читаться в 22 px.

```
small round green ui button with a thick white plus sign, thick dark-brown outline,
soft top highlight, chunky mobile game style, centered, transparent background,
no text, no shadow
```

### 4.5 `shop.png` — кнопка магазина

Стоит справа от плашек. Ведёт в изометрическое кафе, сразу в каталог мебели.
По смыслу — «прилавок / витрина».

```
square chunky ui button with a cozy cafe shop front: striped awning,
small window and a tiny hanging sign, terracotta and cream palette,
thick dark-brown outline, soft top light, chunky mobile game style,
centered, transparent background, no text, no numbers, no shadow
```

---

## 5. Нижний HUD — 5 слотов

Нижняя строка слева: настройки и меню. Справа — большая кнопка play (`btn_play`),
ведёт в изо-кафе. Генераторы кнопкой больше не открываются: они живут
прямоугольниками прямо на поле (`scripts/board.gd`, `_draw_generators()`), поэтому
слотов `icon_inventory` и `btn_cards` в HUD нет. У маленьких кнопок (настройки и меню)
иконка — отдельная текстура (`px * 0.55`), а на `btn_play` арт нарисован целиком и
второй глиф не накладывается: слот `tex_icon_play` удалён из HUD.

| Слот | Файл | Авторский | На экране | Что это |
|---|---|---|---|---|
| `tex_btn_blue` | `assets/ui/buttons/btn_blue.png` | 96×96 | 64×64 | синяя круглая квадратная подложка |
| `tex_icon_settings` | `assets/ui/hud/icon_settings.png` | 96×96 | 53×53 | шестерёнка |
| `tex_icon_menu` | `assets/ui/hud/icon_menu.png` | 96×96 | 53×53 | «4 квадрата» / меню |
| `tex_btn_play` | `assets/ui/buttons/btn_play.png` | 144×126 | 96×84 | большая кнопка play (арт целиком) |
| `tex_notif_dot` | `assets/ui/hud/notif_dot.png` | 33×33 | 22×22 | красная точка уведомления |

> Иконки маленьких кнопок рисуются размером `px * 0.55` от кнопки, по центру.
> Поэтому файл глифа — квадратный, прозрачный, с полями ~10%. Кнопка `btn_play`
> рисуется одним файлом: глиф внутрь не подставляется.

### 5.1 `btn_blue.png` — подложка нижних кнопок

Одна подложка на обе маленькие кнопки (настройки, меню) — так ряд выглядит единым.

```
square chunky rounded ui button, soft sky-blue gradient #4AA3E8 to #2F86C8,
thick dark-brown outline, subtle inner bevel and top highlight, glossy but flat,
centered, transparent background, no text, no icons, no shadow
```

### 5.2 `icon_settings.png`

```
white gear icon, thick clean strokes, rounded teeth, centered,
transparent background, no text, no frame, no shadow
```

### 5.3 `icon_menu.png`

Меню открывает мета-попап (коты / декор / карта / день). Глиф — не «гамбургер»,
а 4 квадрата: читается и как меню, и как «коллекция».

```
white four rounded squares icon arranged in a 2x2 grid, thick clean strokes,
centered, transparent background, no text, no frame, no shadow
```

### 5.4 `icon_inventory.png`

⚠️ Кнопка убрана из HUD (в кафе ведёт ▶). Файл `assets/ui/hud/icon_inventory.png`
остался в репозитории, но код его больше не грузит.

```
white open cardboard box icon with a few small items peeking out,
thick clean strokes, rounded shapes, centered, transparent background,
no text, no frame, no shadow
```

### 5.5 `btn_cards.png` — подложка карточек

⚠️ Кнопка убрана из HUD. Файл `assets/ui/buttons/btn_cards.png` остался в репозитории,
но код его больше не грузит. Красная точка (`tex_notif_dot`) переехала на кнопку меню.

```
square chunky rounded ui button, soft magenta-pink gradient #C13FB5 to #9A2E92,
thick dark-brown outline, subtle inner bevel and top highlight, glossy but flat,
centered, transparent background, no text, no icons, no shadow
```

### 5.6 `btn_play.png` — кнопка «play»

Кнопка `btn_play` ведёт в изометрическое кафе (расстановка декора и магазин), поэтому
арт рисуется целиком, одним файлом: круглая подложка + кофе в одном кадре.

⚠️ Второй промпт (кофе-глиф) оставлен как история — слот `tex_icon_play` из HUD убран,
файл `assets/ui/hud/icon_play.png` лежит в репозитории, но код его не грузит.

```
large chunky rounded ui button, warm caramel #C98A5E to terracotta #E2946B gradient,
thick dark-brown outline, strong inner bevel, top highlight, soft bottom shade,
centered, transparent background, no text, no icons, no shadow
```

```
white coffee cup with latte art in a saucer, thick clean strokes, rounded shapes,
slight steam curl, centered, transparent background, no text, no frame, no shadow
```

### 5.7 `notif_dot.png`

```
small red notification dot, cream #F6E7D8 ring, thick dark-brown outline,
soft top highlight, centered, transparent background, no text, no shadow
```

---

## 6. Общие элементы попапов (этап 2)

Сейчас все попапы (`settings_popup`, `energy_popup`,
`meta_popup`, `cafe_view`) рисуют панели и кнопки через `StyleBox` в коде. Чтобы
перевести их на арт, нужен один набор из 9-slice текстур и переключение
`add_theme_stylebox_override` → `TextureRect`/`StyleBoxTexture`. Промпты ниже —
под этот шаг; они не блокируют HUD.

Размеры на экране (для масштаба): панель попапа ≈ 680×720…1160, строки кнопок
580×84, ключевые кнопки 560×88, карточки бустеров 185×80, карточка действия
520×(по контенту), кнопки 250×84 и 170×84.

### 6.1 Панель попапа (9-slice)

```
rounded rectangular ui panel for a mobile game popup, cream #F6E7D8 body,
caramel border, thick smooth dark-brown outline, subtle top highlight,
flat uniform center with no details, 9-slice friendly, transparent background,
no text, no icons, no shadow
```

### 6.2 Основная кнопка (9-slice)

```
horizontal chunky ui button for a mobile game popup, caramel gradient,
cream label area, thick dark-brown outline, subtle inner bevel,
flat uniform center, 9-slice friendly, transparent background,
no text, no shadow
```

### 6.3 Второстепенная кнопка (9-slice)

```
horizontal chunky ui button for a mobile game popup, soft sage green #A8C0A0,
cream label area, thick dark-brown outline, subtle inner bevel,
flat uniform center, 9-slice friendly, transparent background,
no text, no shadow
```

### 6.4 Опасная кнопка (сброс / удаление)

```
horizontal chunky ui button for a mobile game popup, muted terracotta red,
cream label area, thick dark-brown outline, subtle inner bevel,
flat uniform center, 9-slice friendly, transparent background,
no text, no shadow
```

### 6.5 Строка-карточка (генератор / пункт списка)

```
wide horizontal list card ui element for a mobile game, warm cream #F6E7D8,
soft rounded corners, thin caramel border, thick dark-brown outline,
subtle top highlight, empty left area for an icon, flat body,
transparent background, no text, no icons, no shadow
```

### 6.6 Карточка бустера (квадратная, 185×80)

```
compact horizontal booster card ui element for a mobile game, honey #F2C14E accent,
cream body, soft rounded corners, thick dark-brown outline, small icon plate on the left,
transparent background, no text, no icons, no shadow
```

### 6.7 Табы мета-попапа

Активный и неактивный — одна форма, разная заливка.

```
rounded tab button ui element for a mobile game, active state, caramel fill,
thick dark-brown outline, top highlight, transparent background, no text, no shadow
```

```
rounded tab button ui element for a mobile game, inactive state, muted cream fill,
thinner outline, flat, transparent background, no text, no shadow
```

### 6.8 Кнопка закрытия (X)

```
round close button ui element for a mobile game popup, cream circle,
white X glyph, thick dark-brown outline, top highlight,
transparent background, no text, no shadow
```

### 6.9 Затемнение фона

Не текстура: `ColorRect` с `alpha 0.55`. Если нужен «мягкий» вариант —


```
seamless soft vignette overlay, warm dark-brown #4A3226 edges, transparent center,
smooth falloff, no texture noise, no vignette rings
```

---

## 7. Кафе (изометрия)

Кафе — отдельный экран (`scripts/ui/cafe_view.gd`), рисуется кодом: пол, стены,
слоты декора и каталог мебели. Мебель и декор — см. `docs/art-decor-prompts.md`,
здесь только **обвязка**: карточка товара, счётчик монет, кнопка покупки.

### 7.1 Карточка товара в каталоге

```
vertical product card ui element for a cozy cafe shop, cream body,
rounded corners, caramel border, thick dark-brown outline, large empty image area on top,
small price strip at the bottom, transparent background, no text, no numbers, no icons, no shadow
```

### 7.2 Кнопка «Купить»

```
wide chunky ui button, honey-gold fill, cream label area, thick dark-brown outline,
subtle inner bevel, 9-slice friendly, transparent background, no text, no shadow
```

### 7.3 Счётчик монет (пилюля)

```
rounded coin counter pill ui element, cream body, caramel border,
thick dark-brown outline, small round gold coin plate on the left,
transparent background, no text, no numbers, no shadow
```

### 7.4 Верхняя панель кафе

```
wide rounded top bar ui element for a cozy cafe screen, cream body,
caramel border, thick dark-brown outline, flat center, 9-slice friendly,
transparent background, no text, no icons, no shadow
```

---

## 8. Карточки заказов и карточка действия

Карточка заказа (верх экрана) — кнопка высотой 112 px, внутри две иконки
предметов и награда. Карточка действия появляется по тапу на предмет: панель
520 px шириной, заголовок, подсказка и две кнопки (250×84 «продать»,
170×84 «отмена»).

```
horizontal order card ui element for a cozy merge game, warm cream #F6E7D8 body,
rounded corners, thick dark-brown outline, two small square item windows on the left,
round reward plate on the right, transparent background,
no text, no numbers, no icons baked in, no shadow
```

```
rounded popup panel for an item action dialog, cream body, caramel border,
thick dark-brown outline, flat center, transparent background,
no text, no buttons drawn inside, no shadow
```

---

## 9. Как подключить арт к коду

Сейчас `game_hud.gd` **не грузит PNG с диска**: он берёт слот из Инспектора, а
если слот пуст — цветную заглушку. Экспорты
`Texture2D` у `GameHUD` задать в Инспекторе нельзя, потому что HUD создаётся
из кода (`GAME_HUD.new()`).

Два рабочих варианта:

**А. Автозагрузка из `assets/ui/` — уже сделана.** Папки перечислены в
`Icons.ART_DIRS` (`hud/`, `buttons/`, `panels/`, `cafe/`), путь файла резолвит
`Icons.art_path(base)` — берёт первый
существующий `<dir><base>.png`; `GameHUD._load_ui()` зовёт его для каждого
пустого слота и подставляет арт, а если нет и его — цветную заглушку.

**Б. Сделать `game_hud.tscn`** с корнем `GameHUD` и один раз назначить 15
текстур в Инспекторе, а `game.gd` грузит сцену вместо `.new()`. Больше ручной
работы, зато художник видит результат без запуска.

Пока арт не готов — игра работает: пустые слоты дают цветные плашки
(синие/розовые/жёлтые квадраты). Это нормальное состояние, не баг.

---

## 10. Приоритет и чек-лист приёмки

**Порядок генерации (по влиянию на картинку):**

1. `level_badge`, `bar_bg`, `icon_energy/coin/gem` — верхняя строка, её видно всегда.
2. `btn_blue`, `btn_play` + два глифа — нижняя строка.
3. `shop`, `plus_badge`, `notif_dot` — мелочь, но без них ряд «недоделан».
4. Панель + основная/второстепенная кнопка из §6 — единый стиль попапов.
5. Кафе (§7) и карточки заказов (§8).

**Чек-лист «арт встал правильно»:**

- [ ] Все файлы лежат по путям из таблиц и совпадают имена со слотами.
- [ ] `bar_bg` тянется без мыла и без повторяющихся завитушек по центру.
- [ ] На бейдже уровня число читается при 28 px, ничего не перекрывает цифру.
- [ ] «+» на плашке читается в 22 px и не сливается с плашкой.
- [ ] Кнопки нижнего ряда визуально одного размера (подложка + глиф по центру).
- [ ] Красная точка не уезжает за кнопку меню.
- [ ] Нет запечённого текста/цифр ни на одном файле.
- [ ] Толщина обводки одинаковая у всех элементов (одна «кисть»).
- [ ] На реальном устройстве ничего не срезается вырезом/home-индикатором.

**Быстрая проверка в игре:** запустить проект, посмотреть верх и низ HUD;
нажать каждую кнопку: ⚙ настройки, ☰ мета-попап (коты / декор / карта / день),
▶ кафе, ⚡+ энергия, 💎+ покупка, бейдж уровня — только показ. Генераторы —
прямоугольники на поле: тап по открытому ставит предмет, по закрытому — подсказка.

---

## 11. Чек-лист наличия файлов (35/35 ✅)

Все растровые UI-элементы уже лежат в репозитории: это экспорты
пользовательского листа спрайтов (4x от проектных размеров, см.
`assets/ui/README.txt`). Код находит их через `Icons.ART_DIRS`.

### HUD — 18/18 ✅ → `assets/ui/hud/`

- [x] `assets/ui/hud/level_badge.png` — 96×96
- [x] `assets/ui/hud/level_badge_main.png` — 96×96
- [x] `assets/ui/hud/bar_bg.png` — 225×45 (9-slice 22)
- [x] `assets/ui/hud/bar_bg_short.png` — 225×45 (9-slice 22)
- [x] `assets/ui/hud/icon_energy.png` — 69×69
- [x] `assets/ui/hud/icon_energy_main.png` — 69×69
- [x] `assets/ui/hud/icon_coin.png` — 69×69
- [x] `assets/ui/hud/icon_coin_main.png` — 69×69
- [x] `assets/ui/hud/icon_gem.png` — 69×69
- [x] `assets/ui/hud/icon_gem_main.png` — 69×69
- [x] `assets/ui/hud/plus_badge.png` — 33×33
- [x] `assets/ui/hud/shop.png` — 81×81
- [x] `assets/ui/hud/icon_settings.png` — 96×96
- [x] `assets/ui/hud/icon_menu.png` — 96×96
- [x] `assets/ui/hud/icon_inventory.png` — 96×96
- [x] `assets/ui/hud/icon_play.png` — 76×37 ⚠️ HUD его больше не грузит (`tex_icon_play` удалён)
- [x] `assets/ui/hud/notif_dot.png` — 33×33
- [x] `assets/ui/hud/order_card.png` — 580×112 (9-slice 30)

### Кнопки — 8/8 ✅ → `assets/ui/buttons/`

- [x] `assets/ui/buttons/btn_blue.png` — 96×96
- [x] `assets/ui/buttons/btn_cards.png` — 46×44
- [x] `assets/ui/buttons/btn_play.png` — 144×126
- [x] `assets/ui/buttons/popup_primary_button.png` — 250×84 (9-slice 26)
- [x] `assets/ui/buttons/popup_secondary_button.png` — 250×84 (9-slice 26)
- [x] `assets/ui/buttons/popup_danger_button.png` — 250×84 (9-slice 26)
- [x] `assets/ui/buttons/tab_active.png` — 170×84
- [x] `assets/ui/buttons/tab_inactive.png` — 170×84

### Панели попапов — 5/5 ✅ → `assets/ui/panels/`

- [x] `assets/ui/panels/popup_panel.png` — 680×720 (9-slice 48)
- [x] `assets/ui/panels/popup_list_card.png` — 580×84 (9-slice 30)
- [x] `assets/ui/panels/popup_booster_card.png` — 185×80 (9-slice 26)
- [x] `assets/ui/panels/popup_close.png` — 111×31 (9-slice 14)
- [x] `assets/ui/panels/item_action_panel.png` — 520×300 (9-slice 40)

### Кафе — 4/4 ✅ → `assets/ui/cafe/`

- [x] `assets/ui/cafe/cafe_product_card.png` — 185×250 (9-slice 26)
- [x] `assets/ui/cafe/cafe_buy_button.png` — 250×84 (9-slice 26)
- [x] `assets/ui/cafe/cafe_coin_counter.png` — 225×45 (9-slice 22)
- [x] `assets/ui/cafe/cafe_top_bar.png` — 680×84 (9-slice 28)

> Мебель и предметы кафе — не здесь, а в `docs/art-decor-prompts.md`.
