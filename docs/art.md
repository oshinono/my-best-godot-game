# Арт и UI — Sweetie Cat's Cafe

Один документ вместо четырёх. Часть 1 — промпты ассетов (предметы, генераторы, коты, декор, иконка приложения),
часть 2 — промпты растрового UI, часть 3 — декор в 4 ракурсах, часть 4 — иконки и тема интерфейса.
Нумерация разделов — своя внутри каждой части.

---

Промпты для генерации **набросков/плейсхолдеров** (Midjourney / SD / DALL·E / Flux). Стиль-блок клеится в конец каждого промпта. Тексты промптов — на английском (модели понимают лучше), пояснения — по-русски.

> **Что игра реально подхватывает.** `assets/items/<chain>/<chain>_<level>.png` (§3–§5), `assets/generators/gen_*.png` (§6), `assets/cats/<id>.png` (§8), `assets/vfx/<имя>_<N>.png` (§14), `assets/ui/board/` (§21), растровый UI-арт (35 PNG, `Icons.ART_DIRS` — `assets/ui/{hud,buttons,panels,cafe}/`, часть 2), 14 предметов декора с ракурсами (часть 3), иконка приложения (§12) — через `assets/icons/`.
> **Не грузится кодом** (лежит или ещё нет): фоны (§11), эмоции кота (§16), логотип (§17), стор-скриншоты и креативы (§19–§20), туториальные указатели (§22). Бустеры подключаются в `settings_popup.gd`. Актуальные статусы и TODO — `docs/art-todo.md`, список готовых файлов — §24.

---

# Часть 1. Промпты ассетов

## 1. Стиль-гайд

- **Тип:** 2D casual mobile game, stylized, не реализм.
- **Формы:** мягкие, скруглённые, читаемый силуэт.
- **Обводка:** чистая, средней толщины, тёмно-коричневая (`#4A3226`), не чёрная.
- **Свет:** мягкий верхний, лёгкая cel-тень, тёплый.
- **Фон ассетов:** прозрачный, объект по центру, без текста и рамок.
- **Читаемость:** ассет должен читаться на 128 px.
- **Ракурс:** предметы — 3/4 сверху; интерьеры — 2.5D сверху (top-down isometric-ish).

### Палитра

| Роль | HEX |
|---|---|
| Крем | `#F6E7D8` |
| Кофе с молоком | `#E8C39E` |
| Карамель | `#C98A5E` |
| Кофе | `#8A5A3B` |
| Эспрессо | `#4A3226` |
| Шалфей | `#A8C0A0` |
| Терракота | `#E2946B` |
| Мёд | `#F2C14E` |
| Слива | `#7C6A8A` |
| Хайлайт | `#FFFFFF` |

### Мастер-стиль-блок (в конец любого промпта)

```
cozy casual mobile game asset, 2D stylized illustration, soft rounded shapes,
clean bold dark-brown outlines, subtle cel shading, warm palette
(cream #F6E7D8, latte #E8C39E, caramel #C98A5E, espresso #4A3226),
soft top light, centered composition, transparent background,
high readability at small size, no text, no watermark, no frame
```

### Негативный промпт (общий)

```
text, letters, numbers, watermark, signature, logo, photorealistic, 3d render,
cluttered background, harsh shadows, drop shadow frame, collage, grid lines,
multiple objects, blurry, low contrast, realistic human hands, scary, gritty
```

### Технические советы

1. Сначала сгенерируй **style board** (раздел 2), потом добавляй его как image reference для всех предметов — так держится единый стиль.
2. Предметы: `--ar 1:1`. Интерьеры: `--ar 3:4`. Иконка: `--ar 1:1`.
3. Генерируй в 1024, финал — downscale до 256/512 с прозрачным фоном.
4. Держи **один seed** на цепочку — уровни будут «одной семьёй».
5. ⚠️ Для коммерческого релиза генерации на ИИ проверь лицензию выбранной модели; для MVP-плейсхолдеров — ок.

---

## 2. Style board (сделать первым)

```
A 3x3 grid style exploration board for a cozy cat cafe merge mobile game,
each cell shows one item: coffee bean, croissant, latte cup with latte art,
cake slice, flower bouquet, cute cat barista, coin, gem, energy bolt,
same art style across all cells, flat pastel background,
cozy casual mobile game asset, 2D stylized illustration, soft rounded shapes,
clean bold dark-brown outlines, subtle cel shading, warm palette, no text, no watermark
```

Выбери 1–2 лучших варианта → зафиксируй как reference.

---

## 3. Цепочка «Кофе» (10 предметов)

Файлы: `assets/items/coffee/coffee_<level>.png`, уровни 1–10. `.jpg` документирован и поддерживается, но проходит через вырезание фона (`scripts/data/art.gd`), поэтому финал лучше в PNG с альфой.

Общий хвост для всех: тот же мастер-стиль-блок.

| Ур. | Предмет | Промпт (ядро) |
|---|---|---|
| 1 | Зелёное зерно | `a single green coffee bean, smooth oval, pale sage green, tiny highlight` |
| 2 | Обжаренное зерно | `a single roasted coffee bean, deep brown, glossy, visible crease` |
| 3 | Смолотый кофе | `a small paper scoop of ground coffee, dark brown crumbly pile` |
| 4 | Таблетка (тампер) | `a round pressed coffee puck in a portafilter basket, dark brown, metal ring` |
| 5 | Эспрессо | `a small white espresso cup with rich crema, tiny saucer` |
| 6 | Капучино | `a takeaway-style cappuccino mug with thick foam, caramel dusting` |
| 7 | Латте | `a tall latte glass with milk layers and a simple heart latte art` |
| 8 | Флэт-уайт | `a flat white in a small ceramic cup with a clean white dot latte art` |
| 9 | Кофейный сет | `a cafe tray with a latte and a small cake slice, warm and inviting` |
| 10 | Сигнатурный напиток | `an ornate signature coffee drink in a fancy glass, caramel drizzle, gold sparkle, premium look` |

Пример полного промпта для ур. 7:

```
a tall latte glass with milk layers and a simple heart latte art,
cozy casual mobile game asset, 2D stylized illustration, soft rounded shapes,
clean bold dark-brown outlines, subtle cel shading, warm palette
(cream #F6E7D8, latte #E8C39E, caramel #C98A5E, espresso #4A3226),
soft top light, centered composition, transparent background,
high readability at small size, no text, no watermark, no frame
```

---

## 4. Цепочка «Выпечка» (7 предметов)

Файлы: `assets/items/pastry/pastry_<level>.png`, уровни 1–7. **Готово:** `pastry_1.png`…`pastry_7.png` уже в репозитории.

| Ур. | Предмет | Промпт (ядро) |
|---|---|---|
| 1 | Тесто | `a small ball of raw dough on a floured surface, pale cream color` |
| 2 | Заготовка круассана | `a rolled triangular croissant dough piece, unbaked, pale` |
| 3 | Круассан | `a golden baked butter croissant, flaky layers, glossy` |
| 4 | Маффин | `a blueberry muffin in a paper cup, domed top, warm gold` |
| 5 | Чизкейк | `a slice of cheesecake with berry topping on a small plate` |
| 6 | Слоёный торт | `a layered sponge cake slice with cream, neat layers` |
| 7 | Многоярусный торт | `a small two-tier celebration cake with cream piping and berries` |

---

## 5. Цепочка «Цветы» (5 предметов в MVP)

Файлы: `assets/items/flowers/flowers_<level>.png`, уровни 1–5. **Готово:** `flowers_1.png`…`flowers_5.png` уже в репозитории.

| Ур. | Предмет | Промпт (ядро) |
|---|---|---|
| 1 | Росток | `a tiny green sprout with two leaves in a small brown pot` |
| 2 | Бутон | `a closed flower bud on a green stem, soft pink` |
| 3 | Цветок | `a single open pastel flower with soft petals and a warm center` |
| 4 | Букет | `a small hand-tied bouquet of pastel flowers, wrapped in kraft paper` |
| 5 | Композиция | `a decorative floral arrangement in a ceramic vase, sage and terracotta flowers` |

---

## 6. Генераторы (3) — ✅ есть, код грузит

Спрайты лежат в `assets/generators/gen_<chain>.png` и грузятся `scripts/item.gd`
(`GEN_ART_DIR`); если файла нет — рисуется заглушка. Лист-исходник — `assets/generators/_src/`.

| Генератор | Промпт |
|---|---|
| Эспрессо-станция | `a cute retro espresso machine with a portafilter and steam wand, caramel and chrome, warm and friendly, game object icon` |
| Витрина выпечки | `a small glass display case full of croissants and cakes, warm wood frame, game object icon` |
| Цветочный горшок | `a terracotta flower pot with soil and a few green leaves, game object icon` |

---

## 7. Иконки — растровый арт (SVG в проекте больше нет)

Иконки UI — только PNG: `assets/ui/hud/icon_*.png`, `plus_badge.png`, `shop.png`, `btn_play.png`, `notif_dot.png`, `level_badge_main.png`. SVG-набор из `assets/ui/icons/` больше не используется.

Логические id маппятся на PNG в `scripts/ui/icons.gd`:
`ICON_ART` = `coin→icon_coin`, `gem→icon_gem`, `energy→icon_energy`, `plus→plus_badge`, `cart→shop`, `gear/settings→icon_settings`, `menu→icon_menu`, `play→btn_play`; всё остальное (`gift`, `cat`, `home`, `star`, `check`, `reroll`, `hammer`, `shuffle`, `magnet`, …) рисуется текстом.

Как добавить иконку: положить `<имя>.png` в папку из `Icons.ART_DIRS`, дописать имя в `Icons.ART` (и в `Icons.USED_ART`, если её должен проверять selftest); `[selftest] icons` валидирует именно `USED_ART`. Сундук, таймер и копилка из старых промптов в игре не используются: сундук рисуется кодом в карточках награды.

---

## 8. Коты (12 персонажей)

Общий промпт: `a cute chibi cat character, full body, standing, <описание>, cozy cafe vibe, friendly smile, big expressive eyes, simple clean shapes, game character for a merge mobile game, transparent background`

Список сверен с `scripts/data/meta.gd` (`CATS`): id, имя и роль должны совпадать один в один — имя и роль показываются в альбоме котов.

Файлы: `assets/cats/<id>.png`, ~240–320 px по стороне, прозрачный фон. Исходник-лист — `assets/cats/_src/`, нарезан `tools/split_sheet.gd` (≈4× к показу 64–80 px; ресайз не нужен, Godot скейлит импортом). Код грузит их в альбом котов (`CatCard` → `Art.cat_texture`); если файла нет — буква имени / «?». В окне кофейни (§26 GDD) портреты ещё не показываются.

Нарезка листа-исходника (порядок кусков = reading order, имена по `CATS`):

```bash
godot --headless --script tools/split_sheet.gd -- \
  --sheet "assets/cats/_src/Kawaii Café Cat Sticker Sheet.png" --out assets/cats --min-size 24 \
  --names mocha,latte,bublik,tiramisu,espresso,choco,mimi,flora,caramel,mochi,velvet,star
```

| id | Имя | Роль | Описание |
|---|---|---|---|
| `mocha` | Мокко | Бариста | `brown tabby cat barista wearing a small beige apron and a name tag` |
| `latte` | Латте | Официант | `cream-colored cat holding a small serving tray with a coffee cup` |
| `bublik` | Бублик | Пекарь | `orange ginger cat wearing a chef hat and holding a fresh croissant` |
| `tiramisu` | Тирамису | Гость | `peach-cream kitten sitting with a tiny cup, sleepy and content` |
| `espresso` | Эспрессо | Старший бариста | `dark coffee-colored cat in a smart apron, confident pose, holding a portafilter` |
| `choco` | Шоко | Кондитер | `chocolate-brown cat with a whisk and a piping bag, dusted with cocoa` |
| `mimi` | Мими | Гость-критик | `small grey cat with round glasses and a tiny notepad, inspecting a latte` |
| `flora` | Флора | Садовник | `white cat with green eyes wearing a flower crown, holding a small potted plant` |
| `caramel` | Карамель | Шеф-пекарь | `calico cat in a tall chef hat, holding a two-tier celebration cake` |
| `mochi` | Моти | Дегустатор | `fluffy white cat with pink ears, tasting a spoon of cream, delighted` |
| `velvet` | Бархат | Инспектор уюта | `plush grey cat holding a clipboard, wearing a soft knitted scarf` |
| `star` | Звёздочка | Легенда кафе | `elegant cream cat with tiny gold star accents, sparkling eyes, celebrity aura` |

`caramel`, `mochi` и `star` выпадают только из котового сундука (редкость epic) — рисуй их наряднее остальных.

---

## 9–10. Декор и UI-кит — переехали

Декор — **часть 3** этого документа: 27 предметов из `scripts/data/meta.gd` (`DECOR`) — все 27 готовы: 14 с четырьмя ракурсами (`_S`/`_W`/`_N`/`_E`, изометрия 2:1) и 13 одиночных (`_S`). Пути: `assets/decor/<id>_<dir>.png`.
UI-кит — **часть 2**, раздел удалён как устаревший.

Старый список из 12 предметов устарел: кассы, вывески и «терраса-кофе» в игре нет.

---


## 11. Фоны

⚠️ Код фоны не грузит: и поле, и кофейня рисуют `ColorRect`. Лежат 2 из 3:
`assets/backgrounds/main_menu_storefront.png`, `assets/backgrounds/shop_background.png`.
`cafe_interior.png` нет.

| Ассет | Промпт |
|---|---|
| Интерьер кофейни | `2.5D top-down cozy cat cafe interior, wooden floor, warm pendant lights, tables with cats, huge window with soft daylight, portrait composition, cozy casual mobile game background, 2D stylized illustration, warm palette, no text` `--ar 3:4` |
| Главное меню | `a cozy cat cafe storefront exterior at golden hour, warm lights inside, plants, a cat silhouette in the window, portrait, 2D stylized mobile game background, no text` `--ar 3:4` |
| Магазин | `a warm wooden shop shelf background with soft bokeh and pastel gradient, portrait, clean area at top and bottom for ui, 2D stylized mobile game background, no text` `--ar 3:4` |

⚠️ Для интерьера сразу режь на слои: пол/стены (фон), мебель (отдельные объекты). Иначе декор не переставить.

---

## 12. Иконка приложения

```
a cute brown tabby cat barista holding a latte cup with latte art,
inside a rounded square icon with a warm caramel-to-cream gradient background,
bold readable shape, cozy casual mobile game icon, 2D stylized illustration,
soft rounded shapes, clean outlines, no text, no watermark, no frame
```

Итог: держи один стиль-блок, один style board, один seed на цепочку — и наброски сложатся в единый гейм-арт.

---

## 13. Чек-лист ассетов MVP

Состояние — по файлам в `assets/` и по коду, который их грузит (`✅ код грузит`).

- [x] Style board + выбранный reference (§2)
- [x] Style block зафиксирован
- [x] 3 цепочки: 10 + 7 + 5 = 22 предмета → `assets/items/<chain>/<chain>_<level>.png` — ✅ код грузит
- [x] Иконки UI (§7) — растровый арт в `assets/ui/hud/` и `assets/ui/buttons/` — ✅
- [x] Иконка приложения (§12) — новый исходник `icon.png` (1254²) в корне, производные пересобраны `tools/gen_icons.gd` — ✅
- [x] 12 котов → `assets/cats/<id>.png` — ✅ код грузит (альбом котов; окно кофейни ждёт §26 GDD)
- [x] 3 генератора (§6) → `assets/generators/gen_*.png` — ✅ код грузит
- [x] VFX (§14) → `assets/vfx/<имя>_<N>.png`, 6 анимаций — файлы есть, показ отключён
- [x] Тайл стола, рамка, подложки клеток → `assets/ui/board/` — ✅ `scripts/board.gd`
- [x] Растровый UI-арт (часть 2) — 35 PNG в `assets/ui/{hud,buttons,panels,cafe}/` — ✅ `Icons.ART_DIRS`
- [x] Иконки кофейни: 5 PNG в `assets/ui/cafe/`, сборщик экспортирует в `assets/ui/theme/`
- [x] Декор: 27 из 27 предметов (56 файлов с ракурсами + 13 одиночных) — ✅ код грузит
- [ ] 3 фона (§11) — 2 из 3 лежат (`main_menu_storefront`, `shop_background`), код не грузит
- [x] Иконки бустеров (§15) — исходники подключены к кнопкам настроек
- [ ] Спрайт-лист эмоций кота (§16) — 0/1
- [ ] Логотип / брендинг (§17) — 0/3
- [ ] Стор-скриншоты (§19) и креативы (§20) — 0/9
- [ ] Туториальные указатели (§22) — 0/4
- [ ] Аудио — `assets/audio/{music,sfx}/` пусты, SFX и лупы нужны до релиза (GDD §15)

Листы из генераций режутся на отдельные PNG инструментом `tools/split_sheet.gd` — по непрозрачным областям, без ресайза: `godot --headless --script tools/split_sheet.gd -- --sheet <лист> --out <папка> --prefix <цепочка>`. Исходники-листы держим в `assets/<тип>/_src/` (из экспорта исключены).

Порядок для минимального играбельного набора: предметы → генераторы → VFX → коты → UI — **готово**. Что генерить дальше и в каком порядке — §23. Какие именно файлы — §24.

---

## 14. VFX / эффекты — ✅ есть и подключены

6 покадровых анимаций, 42 кадра, в `assets/vfx/<имя>_<N>.png`; грузит
`scripts/ui/fx_layer.gd` (прогрев при старте, `VFX_FPS` = 18). Листы-исходники —
`assets/vfx/_src/`.

| Анимация | Кадров | Где играет |
|---|---|---|
| `burst` | 8 | слияние, level up |
| `ring` | 8 | слияние |
| `check` | 8 | заказ выполнен |
| `coins` | 6 | монеты за заказ (зациклена) |
| `sparkle` | 6 | гем-дроп / подсветка |
| `smoke` | 6 | продажа/удаление предмета |

Отдельный стиль: **без тёмной обводки**, ярче и «светлее» предметов — так эффект читается поверх ассета.

Стиль-блок для VFX (клеить в конец промпта):

```
game VFX sprite, 2D stylized, bright saturated colors, soft glow, no dark outlines,
transparent background, centered, animation frames stacked in a uniform grid,
clean shapes, high readability at small size, no text, no watermark
```

Негатив: `dark outline, heavy black border, text, watermark, background scene, drop shadow frame, photorealistic, extra objects, blurry`.

| Эффект | Кадров | Размер | Ключевые слова |
|---|---|---|---|
| Burst слияния | 8 | 256×256 | `merge burst, radial star flash, warm sparks` |
| Sparkle | 6 | 128×128 | `soft sparkle twinkle, caramel highlights` |
| Coin fly | 6 | 128×128 | `golden coin spin trail, small two-coin cluster` |
| Dust (продажа/снос) | 6 | 128×128 | `soft puff cloud, warm beige dust` |
| Level up | 8 | 512×512 | `level up rings, expanding circle, confetti bits, honey gold` |
| Order complete | 8 | 256×256 | `checkmark pop, gentle starburst, sage green accent` |

Тех-совет: проси `sprite sheet, 8 frames, horizontal strip` и режь на кадры сам. В Godot — `AnimatedSprite2D` для коротких, `GPUParticles2D` для искр/конфетти.

## 15. Иконки бустеров

1:1, 256×256, стиль-блок UI-иконок (без фона-сцены).

```
[icon] booster icon for cozy casual mobile game, rounded square plate with soft cream
background, bold shape, 2D stylized, soft rounded shapes, clean outlines, no text, no watermark
```

- **Хаммер** — `small wooden hammer with caramel handle, tiny sparkle`.
- **Шафл** — `two circular arrows in latte brown, small item tile in the middle`.
- **Магнит** — `U-shaped horseshoe magnet in terracotta, pulling a coffee bean`.
- **Слот +1** — `order card with a plus sign, small golden badge`.
- **Продажа** — `coin stack with a small downward arrow`.

## 16. Эмоции кота (спрайт-лист)

⚠️ Задел: эмоции пока рисуются иконками/текстом, спрайт-листа в коде нет.

Один спрайт-лист на 6 кадров, 1024×1024 (сетка 3×2), база — кот-барista из §12.

```
6 cat emotions sprite sheet, cozy casual mobile game, 2D stylized illustration,
soft rounded shapes, clean bold dark-brown outlines, warm palette,
frames: happy, excited, sleepy, waiting (impatient), sad, love (heart eyes),
same character, consistent size and pose anchor, plain transparent background,
no text, no watermark
```

Использование: happy — заказ принят; excited — заказ выполнен; sleepy — нет энергии; waiting — заказ давно висит; sad — отказ; love — покупка/daily.

## 17. Логотип и вордмарк

```
game logo wordmark "Sweetie Cat's Cafe", cozy casual mobile game lettering,
rounded friendly chunky letters, warm caramel-to-cream gradient, small coffee cup and
cat paw accents, subtle drop shadow, 2D stylized, flat colors, isolated on transparent
background, no extra text, no watermark, high readability at small size
```

Требования: горизонтальная версия и квадратная (под иконку), монохром-версия для тёмного фона, читаемость в 100 px. ⚠️ Для финального лого — векторизация (Illustrator/Figma), не растровый набросок.

## 18. Альтернативные стили (A/B/C)

Сделай по одному тестовому ассету (напр. «Эспрессо») в трёх подачах и выбери:

- **A — Flat vector:** `flat vector illustration, minimal shading, geometric shapes, pastel warm palette`.
- **B — Hand-painted (гуашь):** `hand-painted gouache texture, visible brush strokes, warm cozy tones, soft edges`.
- **C — Clay/пластилин:** `clay / plasticine 3D-ish look, soft rounded volumes, tiny fingerprints, warm studio light`.
- **D (база) — Cel-shaded 2D:** текущий канон из §1.

Критерии выбора: читаемость в 128 px, скорость производства (масштабируемость на 60+ ассетов), ремонтопригодность (можно ли дорисовать новый предмет в том же стиле), стоимость.

## 19. Стор-скриншоты

5 штук, вертикальные 1290×2796 (iPhone) и пересбор под Android. Оверлеи — отдельный слой текста в Figma, не в промпте.

1. **Хук:** поле с плотной доской в момент слияния + кот доволен → заголовок «Собирай и сливай».
2. **Заказы:** карточка заказа и монеты → «Выполняй заказы котов».
3. **Мета:** кофейня с мебелью → «Обустрой свою кофейню».
4. **Коллекция:** альбом с 12 котами → «Открой всех котов».
5. **Награда:** daily reward + сундук → «Заходи каждый день».

Правила: первый кадр = суть игры без текста; 1 мысль на кадр; крупный текст ≤5 слов; без фейкового геймплея (реджект).

## 20. Рекламные креативы

- **Rewarded (превью в UI):** маленькая иконка play + монеты, 512×512, `simple flat icon, play badge, coin reward, cream background`.
- **Story-версия 9:16 (1080×1920):** 3 кадра «до/действие/после» с крупным предметом и котом — для соцсетей.
- **Баннер-банк:** 1200×628 (заголовок + иконка + кот), 1080×1080 (квадрат для Meta).
- ⚠️ Не использовать чужие логотипы и не обещать награду, которой нет.

## 21. Тайл фона поля и бордюр

Арт поля подключён и лежит в `assets/ui/board/`: `wood_table_tile_512.png`,
`board_cell_normal_128.png`, `board_cell_drag_highlight_128.png`,
`field_frame_512.png`. Грузит `scripts/board.gd` (`_load_board_art()`); если файла
нет — падаем на прежние `draw_rect`.

- **Тайл столешницы:** 512×512, бесшовный, `seamless tileable wood table top, warm latte brown, subtle grain, soft vignette, top-down, 2D stylized`. ✅ `wood_table_tile_512.png` ужимается до 256 px (`Board.BOARD_TILE_MAX`) и рисуется с тайлингом — режим `Repeat` в импорте не нужен.
- **Рамка/бордюр поля:** `rounded rectangle frame, 9-slice friendly, caramel outline, soft inner shadow, transparent center`, 256×256 по углам, без текста. ✅ `field_frame_512.png`; 9-slice режет `Board._draw_nine_slice()`, margin — `FRAME_MARGIN_RATIO = 0.215` от стороны текстуры.
- **Подложка клетки:** 128×128, `empty board cell, rounded square, subtle inset, light cream`, два состояния (обычная, подсвеченная при drag). ✅ `board_cell_normal_128.png` + `board_cell_drag_highlight_128.png`.

## 22. Туториальные указатели

⚠️ Задел: туториальных указателей в коде нет.

- **Hand pointer:** 256×256, `cute cartoon finger pointing, cream skin, dark-brown outline, soft shadow`, 3 кадра (стук/тап/уход).
- **Ghost-предмет:** полупрозрачный силуэт для «перетащи сюда» (можно получить из самого ассета с alpha 40%).
- **Стрелка-подсказка:** 256×256, `rounded arrow, honey gold, subtle bounce`.

## 23. TODO на генерацию — вынесен

Сводный чек-лист «что генерить и в каком порядке» живёт отдельно: **`docs/art-todo.md`**. Здесь — только промпты (§15–§22) и список готовых файлов (§24).

Вкратце: бустеры (3) → туториал (4) → эмоции кота → фон кофейни → лого (3) → стор (5) → креативы (4); звук — блокер релиза.

---

## 24. Чек-лист наличия файлов

Отмечай `[x]`, когда файл реально лежит в репозитории. Сейчас отмечено то, что уже есть.
Имена закреплены здесь: совпадающие с кодом пути помечены «код грузит», остальное — задел (пути держим заранее, чтобы ассеты встали без правок кода).

### Предметы цепочек (§3–§5) — 22/22 ✅

- [x] `assets/items/coffee/coffee_1.png` — Зелёное зерно
- [x] `assets/items/coffee/coffee_2.png` — Обжаренное зерно
- [x] `assets/items/coffee/coffee_3.png` — Смолотый кофе
- [x] `assets/items/coffee/coffee_4.png` — Таблетка (тампер)
- [x] `assets/items/coffee/coffee_5.png` — Эспрессо
- [x] `assets/items/coffee/coffee_6.png` — Капучино
- [x] `assets/items/coffee/coffee_7.png` — Латте
- [x] `assets/items/coffee/coffee_8.png` — Флэт-уайт
- [x] `assets/items/coffee/coffee_9.png` — Кофейный сет
- [x] `assets/items/coffee/coffee_10.png` — Сигнатурный напиток
- [x] `assets/items/pastry/pastry_1.png` — Тесто
- [x] `assets/items/pastry/pastry_2.png` — Заготовка круассана
- [x] `assets/items/pastry/pastry_3.png` — Круассан
- [x] `assets/items/pastry/pastry_4.png` — Маффин
- [x] `assets/items/pastry/pastry_5.png` — Чизкейк
- [x] `assets/items/pastry/pastry_6.png` — Слоёный торт
- [x] `assets/items/pastry/pastry_7.png` — Многоярусный торт
- [x] `assets/items/flowers/flowers_1.png` — Росток
- [x] `assets/items/flowers/flowers_2.png` — Бутон
- [x] `assets/items/flowers/flowers_3.png` — Цветок
- [x] `assets/items/flowers/flowers_4.png` — Букет
- [x] `assets/items/flowers/flowers_5.png` — Композиция

### Растровый UI-арт (часть 2) — 35/35 ✅

`assets/ui/hud/` — 18, `assets/ui/buttons/` — 8, `assets/ui/panels/` — 5,
`assets/ui/cafe/` — 4. Полный список с размерами и кромками 9-slice —
часть 2, §11; код находит файлы через `Icons.ART_DIRS`.

### Иконки UI (§7) — растровый арт ✅ (SVG в проекте больше нет)

Логические id (`coin`, `energy`, `plus`, `cart`, …) маппятся на PNG через
`Icons.ICON_ART`; проверку ведёт `Icons.USED_ART` в `[selftest] icons`.
Папки: `assets/ui/hud/`, `assets/ui/buttons/`.

- [x] `assets/ui/hud/icon_coin_main.png`
- [x] `assets/ui/hud/icon_energy_main.png`
- [x] `assets/ui/hud/icon_gem_main.png`
- [x] `assets/ui/hud/icon_coin.png`
- [x] `assets/ui/hud/icon_energy.png`
- [x] `assets/ui/hud/icon_gem.png`
- [x] `assets/ui/hud/plus_badge.png`
- [x] `assets/ui/hud/notif_dot.png`
- [x] `assets/ui/hud/level_badge_main.png`
- [x] `assets/ui/hud/shop.png`
- [x] `assets/ui/buttons/btn_play.png`
- [x] `assets/ui/hud/icon_settings.png`
- [x] `assets/ui/hud/icon_menu.png`

### Иконка приложения (§12) — ✅

- [x] `assets/icons/icon_1024.png` (и производные `icon_40/58/60/76/80/87/114/120/128/136/152/167/180/192/432/512.png`, `window_512.png`, `bg_432.png`, `fg_432.png`)

### Генераторы (§6) — 3/3 ✅ (код грузит)

- [x] `assets/generators/gen_coffee.png` — Эспрессо-станция
- [x] `assets/generators/gen_pastry.png` — Витрина выпечки
- [x] `assets/generators/gen_flowers.png` — Цветочный горшок

### Коты (§8) — 12/12 (из листа `_src`, имена по порядку кусков)

- [x] `assets/cats/mocha.png` — Мокко (Бариста)
- [x] `assets/cats/latte.png` — Латте (Официант)
- [x] `assets/cats/bublik.png` — Бублик (Пекарь)
- [x] `assets/cats/tiramisu.png` — Тирамису (Гость)
- [x] `assets/cats/espresso.png` — Эспрессо (Старший бариста)
- [x] `assets/cats/choco.png` — Шоко (Кондитер)
- [x] `assets/cats/mimi.png` — Мими (Гость-критик)
- [x] `assets/cats/flora.png` — Флора (Садовник)
- [x] `assets/cats/caramel.png` — Карамель (Шеф-пекарь, epic)
- [x] `assets/cats/mochi.png` — Моти (Дегустатор, epic)
- [x] `assets/cats/velvet.png` — Бархат (Инспектор уюта, epic)
- [x] `assets/cats/star.png` — Звёздочка (Легенда кафе, epic)

### Декор (§часть 3) — 27/27 ✅ (код грузит)

Всё грузит `cafe_view.gd` через `Meta.decor_sprite()`: 14 предметов с 4 ракурсами
и 13 одиночных (`_S`, сетка и `rot` — из `Meta.DECOR`). Заглушка-ромб больше не рисуется.

- [x] `assets/decor/bush_S.png` — куст
- [x] `assets/decor/floor_lamp_S.png` — торшер
- [x] `assets/decor/flower_bed_S.png` — клумба
- [x] `assets/decor/fountain_S.png` — фонтан
- [x] `assets/decor/garland_S.png` — гирлянда
- [x] `assets/decor/painting_S.png` — картина
- [x] `assets/decor/plant_S.png` — растение в горшке
- [x] `assets/decor/planter_S.png` — кашпо
- [x] `assets/decor/round_table_S.png` — круглый стол
- [x] `assets/decor/rug_S.png` — ковёр
- [x] `assets/decor/terrace_table_S.png` — стол на террасе
- [x] `assets/decor/tree_S.png` — дерево
- [x] `assets/decor/umbrella_S.png` — зонт

### Фоны (§11) — 2/3 (код не грузит)

- [ ] `assets/backgrounds/cafe_interior.png` (`--ar 3:4`)
- [x] `assets/backgrounds/main_menu_storefront.png`
- [x] `assets/backgrounds/shop_background.png`

### VFX (§14) — 6 анимаций / 42 кадра ✅ (код грузит)

- [x] `assets/vfx/burst_1..8.png` — слитие, level up
- [x] `assets/vfx/ring_1..8.png` — слитие
- [x] `assets/vfx/check_1..8.png` — заказ выполнен
- [x] `assets/vfx/coins_1..6.png` — летящие монеты
- [x] `assets/vfx/sparkle_1..6.png` — гем/подсветка
- [x] `assets/vfx/smoke_1..6.png` — продажа/удаление

Имена в файлах — `<анимация>_<N>.png`, грузит `scripts/ui/fx_layer.gd`; старые
имена из промптов (`merge_burst`, `coin_fly`, `dust`, `level_up`, `order_complete`)
не используются.

### Иконки бустеров (§15) — 3/3, подключены в настройках

- [x] `assets/ui/boosters/hammer.png` — Хаммер
- [x] `assets/ui/boosters/shuffle.png` — Шафл
- [x] `assets/ui/boosters/magnet.png` — Магнит
- [x] Кнопки загружают PNG из `scripts/ui/settings_popup.gd`.
- НЕ нужно: `slot_plus`, `sell` — таких бустеров в игре нет (`settings_popup.gd` = hammer/shuffle/magnet).

### Эмоции кота (§16) — лист и кадры есть, код пока не использует

- [x] `assets/cats/emotions_sheet.png` — исходный лист 6 кадров, сетка 3×2
- [x] `assets/cats/emotion_happy.png`, `emotion_excited.png`, `emotion_sleepy.png`, `emotion_waiting.png`, `emotion_sad.png`, `emotion_love.png` — нарезанные кадры 512×512

### Логотип (§17) — 0/3

- [ ] `assets/branding/wordmark.png` — горизонтальный (растровый черновик — `assets/wordmark.jpg`)
- [ ] `assets/branding/logo_square.png` — квадратный
- [ ] `assets/branding/logo_mono.png` — монохром

### Альтернативные стили (§18) — закрыто: канон `assets/style.png`

- [x] `assets/style.png` — рабочий канон (cel-shaded 2D, §1)
- Сравнение A/B/C не делаем — стиль выбран; промпты остались только как справка.

### Стор-скриншоты (§19) — 0/5

- [ ] `assets/store/shot_1_hook.png` — хук (1290×2796)
- [ ] `assets/store/shot_2_orders.png` — заказы
- [ ] `assets/store/shot_3_meta.png` — кофейня
- [ ] `assets/store/shot_4_collection.png` — коты
- [ ] `assets/store/shot_5_reward.png` — daily/сундук

### Рекламные креативы (§20) — 0/4

- [ ] `assets/creatives/rewarded_512.png`
- [ ] `assets/creatives/story_9x16.png` (1080×1920)
- [ ] `assets/creatives/banner_1200x628.png`
- [ ] `assets/creatives/banner_1080.png`

### Тайл и бордюр поля (§21) — 4/4 ✅ (код грузит)

- [x] `assets/ui/board/wood_table_tile_512.png` — бесшовный (Repeat)
- [x] `assets/ui/board/field_frame_512.png` — 9-slice-исходник; в игре берётся
  `assets/ui/theme/field_frame.png` (собран `tools/build_ui_theme.gd`)
- [x] `assets/ui/board/board_cell_normal_128.png` — 128×128
- [x] `assets/ui/board/board_cell_drag_highlight_128.png` — подсветка при drag

### Туториальные указатели (§22) — 4/4, нарезаны; код пока не использует

- [x] `assets/ui/tutorial/hand_pointer_1.png` — стук
- [x] `assets/ui/tutorial/hand_pointer_2.png` — тап
- [x] `assets/ui/tutorial/hand_pointer_3.png` — уход
- [x] `assets/ui/tutorial/arrow_hint.png` — стрелка


---

# Часть 2. Растровый UI

Промпты для генерации растрового UI (`Midjourney / SD / DALL·E / Flux`).
Промпты — по-английски, пояснения — по-русски: так их проще копировать, а
правила остаются читаемыми.

> Раньше UI собирался из `ColorRect` и `StyleBox`. Сейчас новый HUD
> (`scripts/ui/game_hud.gd`) держит **15 слотов `Texture2D`**, и картинки нужны
> конкретные, под конкретные размеры. Устаревший раздел «UI-кит» из части 1 удалён.

---

## 1. Что уже есть и что генерируем

| Что | Статус | Где лежит |
|---|---|---|
| Иконки-символы (PNG) | ✅ готовы, генерировать НЕ надо | `assets/ui/hud/`, `assets/ui/buttons/` — маппинг в часть 4 |
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

К мастер-блоку из части 1, §1 добавляем UI-часть: чёткая
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
текстуру (см. §9 части 2).

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
слоты декора и каталог мебели. Мебель и декор — см. часть 3,
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

> Мебель и предметы кафе — не здесь, а в части 3.


---

# Часть 3. Декор в 4 ракурсах
Раздел для предметов, которые в игре можно **поворачивать** (поле `rot: true`
в `scripts/data/meta.gd`). Им нужно 4 картинки: `_N`, `_E`, `_S`, `_W`.
Предметам без поворота (ковёр, фонтан, дерево, куст и т.д.) хватает 1 картинки.

## Тех. требования (одинаковые для всех)

- PNG с альфой, обрезан по контенту, **без тени** (тень рисует код).
- Формат кадра: квадрат **1024×1024** (в рантайме ужимаем до ~384 px).
- **Одна точка опоры**: нижний край/ножки предмета всегда на одной и той же
  линии канваса во всех 4 кадрах, центр — по горизонтали. Иначе предмет
  «прыгает» при повороте.
- Все 4 кадра — один и тот же предмет: тот же размер, тот же ракурс камеры,
  тот же свет, та же палитра. Меняется **только поворот вокруг вертикальной оси**.
- Камера НЕ двигается: изометрия 2:1 (диметрия), ортографично, наклон ~26.57°,
  без перспективы.

## Порядок ракурсов (поварот по часовой стрелке)

Порядок кадров — 90° по часовой стрелке, если смотреть сверху:

| Файл | Поворот | Что видно |
|---|---|---|
| `<id>_S.png` | 0° | фасад смотрит вниз, в сторону зрителя |
| `<id>_W.png` | 90° | фасад ушёл влево (виден правый бок) |
| `<id>_N.png` | 180° | видно спину предмета |
| `<id>_E.png` | 270° | фасад ушёл вправо (виден левый бок) |

> Сделано: `SPRITE_DIRS` в `scripts/data/meta.gd` = `["S","W","N","E"]`,
> поэтому `rot = 0` (дефолт при постановке) показывает **фасад к зрителю**,
> а арт рисуется ровно как в таблице выше.

## Общий префикс промпта (вставлять в каждый)

```
cozy stylized cartoon game asset, isometric 2:1 dimetric view, orthographic
camera, elevation 26.57 degrees, no perspective, single object centered,
soft rounded shapes, thick soft dark-brown outline, hand-painted flat shading
with gentle gradient, warm palette (cream #E8D6BE, caramel #B58C63,
walnut #8E6C4C, terracotta #C05621), matte finish, clean silhouette,
transparent background, no ground shadow, no text, no watermark
```

## Суффикс ракурса (по одному на кадр)

```
_S: front facade facing toward the viewer, bottom edge of the object on canvas bottom
_W: same object rotated 90 degrees clockwise around its vertical axis, front facade now facing screen-left
_N: same object rotated 180 degrees, we see its back
_E: same object rotated 270 degrees, front facade now facing screen-right
```

## Негатив (одинаковый)

```
photorealistic, 3d render, glossy plastic, perspective distortion, fisheye,
two objects, duplicate, cropped edges, ground shadow, cast shadow, text, logo,
signature, watermark, busy background, blurry, melted geometry, extra legs,
asymmetric mirroring, different scale between views
```

## Предметы с 4 ракурсами (14 шт.)

| id | Название | Габарит | Комната | Что важно нарисовать (различие ракурсов) |
|---|---|---|---|---|
| `sofa` | Диван | 2×1 | Зал | 3-местный, подлокотники, подушки. Со спины — глухая спинка без подушек. |
| `armchair` | Кресло | 1×1 | Зал | Высокая спинка, подлокотники. Профили узкие, спинка видна «ребром». |
| `chair` | Стул | 1×1 | Зал | Спинка + 4 ножки, сиденье. Сзади — только спинка и ножки. |
| `bookshelf` | Полка | 1×1 | Зал | Открытые полки с книгами (разноцветные корешки). Сзади — сплошная стенка. |
| `counter` | Стойка | 3×1 | Зал | Длинная барная стойка, глянцевая столешница. Торцы видны «в ширину 1». |
| `fireplace` | Камин | 2×1 | Зал | Кирпичный портал, тёмная топка с огнём спереди. Сзади — глухая кладка. |
| `espresso_machine` | Кофемашина | 1×1 | Кухня | Металл, портал для чашки спереди, труба сверху. Сзади — кожух без портала. |
| `display_case` | Витрина | 2×1 | Кухня | Стеклянная витрина с полками и выпечкой **внутри**, выпечка видна сквозь стекло с 4 сторон. |
| `fridge` | Холодильник | 1×1 | Кухня | Двухдверный, ручка с одной стороны. В профиль видно, с какой стороны ручка. |
| `prep_table` | Стол | 2×1 | Кухня | Рабочий стол, доска и полка снизу. Спинка/задняя панель сплошная. |
| `oven` | Печь | 1×1 | Кухня | Чёрное стекло дверцы, ручка, крутилки сверху. Сзади — глухой корпус. |
| `shelf` | Стеллаж | 1×1 | Кухня | Полки с банками и утварью. Сзади — сплошная стенка. |
| `wicker_chair` | Кресло | 1×1 | Терраса | Плетёное, полупрозрачное плетение — сквозь спинку просвечивает. |
| `bench` | Скамья | 2×1 | Сад | Садовая скамья со спинкой из реек. Сзади — те же рейки. |

Промпт на предмет: `[префикс] + [описание из таблицы] + [суффикс ракурса] + [негатив]`.

Пример целиком:

```
cozy stylized cartoon game asset, isometric 2:1 dimetric view, orthographic
camera, elevation 26.57 degrees, no perspective, single two-seat cafe sofa with
high backrest, two armrests and two cushions, centered, soft rounded shapes,
thick soft dark-brown outline, hand-painted flat shading with gentle gradient,
warm palette (cream #E8D6BE, caramel #B58C63, walnut #8E6C4C, terracotta #C05621),
matte finish, clean silhouette, transparent background, no ground shadow,
no text -- same object rotated 180 degrees, we see its back
--no photorealistic, 3d render, glossy plastic, perspective distortion,
ground shadow, text, watermark, background, different scale
```

## Пути файлов

```
assets/decor/sofa/sofa_N.png        assets/decor/sofa/sofa_E.png
assets/decor/sofa/sofa_S.png        assets/decor/sofa/sofa_W.png
assets/decor/armchair/armchair_{N,E,S,W}.png
assets/decor/chair/chair_{N,E,S,W}.png
assets/decor/bookshelf/bookshelf_{N,E,S,W}.png
assets/decor/counter/counter_{N,E,S,W}.png
assets/decor/fireplace/fireplace_{N,E,S,W}.png
assets/decor/espresso_machine/espresso_machine_{N,E,S,W}.png
assets/decor/display_case/display_case_{N,E,S,W}.png
assets/decor/fridge/fridge_{N,E,S,W}.png
assets/decor/prep_table/prep_table_{N,E,S,W}.png
assets/decor/oven/oven_{N,E,S,W}.png
assets/decor/shelf/shelf_{N,E,S,W}.png
assets/decor/wicker_chair/wicker_chair_{N,E,S,W}.png
assets/decor/bench/bench_{N,E,S,W}.png
```

Код сам подхватит файлы (`DATA.decor_sprite(id, rot)`), пока файла нет —
рисуется серая заглушка-ромб с подписью.

## Без 4 ракурсов (13 шт., по 1 картинке)

`round_table`, `rug`, `floor_lamp`, `plant`, `painting`, `terrace_table`,
`umbrella`, `planter`, `garland`, `flower_bed`, `fountain`, `tree`, `bush`.
Путь тот же, файл `<id>_S.png` (или любой один — код берёт ракурс 0).

## Порядок рисования

1. Пилот: **зал в 4 ракурсах** (sofa, armchair, chair, bookshelf, counter, fireplace)
   — проверяем вид в изо-сцене до того, как рисовать остальные 8.
2. Кухня (6), терраса (1), сад (1).
3. Тринадцать одиночных.

---

## Чек-лист наличия файлов (69)

Отмечай `[x]`, когда файл лежит в `assets/decor/`. Сейчас **69 из 69**: 56 файлов
14 предметов с ракурсами + 13 одиночных; код грузит через `Meta.decor_sprite`.

Файлы лежат плоско: `assets/decor/<id>_<S|W|N|E>.png` (старый вариант с папкой на id
тоже поддерживается кодом). Листы-исходники — `assets/decor/_src/`.

### С 4 ракурсами (14 предметов × 4 = 56) — 56/56 ✅

- [x] `assets/decor/sofa_S.png`, `sofa_W.png`, `sofa_N.png`, `sofa_E.png` — Диван
- [x] `assets/decor/armchair_S.png`, `armchair_W.png`, `armchair_N.png`, `armchair_E.png` — Кресло
- [x] `assets/decor/chair_S.png`, `chair_W.png`, `chair_N.png`, `chair_E.png` — Стул
- [x] `assets/decor/bookshelf_S.png`, `bookshelf_W.png`, `bookshelf_N.png`, `bookshelf_E.png` — Полка
- [x] `assets/decor/counter_S.png`, `counter_W.png`, `counter_N.png`, `counter_E.png` — Стойка
- [x] `assets/decor/fireplace_S.png`, `fireplace_W.png`, `fireplace_N.png`, `fireplace_E.png` — Камин
- [x] `assets/decor/espresso_machine_S.png`, `espresso_machine_W.png`, `espresso_machine_N.png`, `espresso_machine_E.png` — Кофемашина
- [x] `assets/decor/display_case_S.png`, `display_case_W.png`, `display_case_N.png`, `display_case_E.png` — Витрина
- [x] `assets/decor/fridge_S.png`, `fridge_W.png`, `fridge_N.png`, `fridge_E.png` — Холодильник
- [x] `assets/decor/prep_table_S.png`, `prep_table_W.png`, `prep_table_N.png`, `prep_table_E.png` — Стол
- [x] `assets/decor/oven_S.png`, `oven_W.png`, `oven_N.png`, `oven_E.png` — Печь
- [x] `assets/decor/shelf_S.png`, `shelf_W.png`, `shelf_N.png`, `shelf_E.png` — Стеллаж
- [x] `assets/decor/wicker_chair_S.png`, `wicker_chair_W.png`, `wicker_chair_N.png`, `wicker_chair_E.png` — Кресло плетёное
- [x] `assets/decor/bench_S.png`, `bench_W.png`, `bench_N.png`, `bench_E.png` — Скамья

### Одиночные (13 предметов, файл `<id>_S.png`)

- [x] `assets/decor/round_table_S.png` — Круглый стол
- [x] `assets/decor/rug_S.png` — Ковёр
- [x] `assets/decor/floor_lamp_S.png` — Торшер
- [x] `assets/decor/plant_S.png` — Растение
- [x] `assets/decor/painting_S.png` — Картина (`wall: true`)
- [x] `assets/decor/terrace_table_S.png` — Стол террасы
- [x] `assets/decor/umbrella_S.png` — Зонт
- [x] `assets/decor/planter_S.png` — Кашпо
- [x] `assets/decor/garland_S.png` — Гирлянда (`wall: true`)
- [x] `assets/decor/flower_bed_S.png` — Клумба
- [x] `assets/decor/fountain_S.png` — Фонтан
- [x] `assets/decor/tree_S.png` — Дерево
- [x] `assets/decor/bush_S.png` — Куст


---

# Часть 4. Иконки и тема интерфейса
Интерфейс рисуется растровым артом (PNG) через единую тему
`res://resources/ui_theme.tres` (Project Settings → GUI → Theme → Custom).

## Откуда берётся арт

- **Исходники** — экспорт листа спрайтов в 4×: `assets/ui/hud/`,
  `assets/ui/buttons/`, `assets/ui/panels/`, `assets/ui/cafe/`. В игре они не
  используются и в сборку не попадают (`exclude_filter` в `export_presets.cfg`).
- **Рантайм-арт** — `assets/ui/theme/`: поля срезаны, размеры приведены к базе
  720×1280. Его и тему собирает `tools/build_ui_theme.gd` (запуск — в шапке
  скрипта). Сцены и скрипты ссылаются только на эту папку.
- **Поле** — `assets/ui/board/` (столешница, клетки, рамка), грузит `scripts/board.gd`.

## Где какие иконки

| PNG (`assets/ui/theme/`) | где |
| --- | --- |
| `icon_coin_main`, `icon_gem_main`, `icon_energy_main` | плашки ресурсов HUD (`scenes/ui/game_hud.tscn`) |
| `icon_coin`, `icon_gem`, `icon_energy` | тосты и полёты (`game.gd`), меню действий, магазин мебели, ежедневная награда (`daily_tile.gd`), экран энергии |
| `icon_settings`, `icon_menu`, `icon_inventory`, `btn_play`, `notif_dot`, `level_badge_main` | кнопки HUD |
| `shop` | кнопка магазина мебели в кофейне (`scenes/ui/cafe_ui.tscn`) |
| `order_card` | карточка заказа (`scenes/ui/order_card.tscn`) |

Фоны кнопок, попапов и карточек — StyleBoxTexture в вариациях темы
(`PrimaryButton`, `PopupFrame`, `ListCard`, …), а не отдельные иконки.

## Как добавить иконку

1. Положить исходник (4×, прозрачный фон) в одну из папок-исходников.
2. Добавить его в `tools/build_ui_theme.gd` и пересобрать арт и тему.
3. Ссылаться из сцены/скрипта на `assets/ui/theme/<имя>.png`.

## Проверка

Селфтест (`scripts/dev/selftest.gd`, только debug и `dev/selftest/enabled` / `--selftest`) проверяет, что
тема загружена, ключевые вариации на месте и их текстуры разобрались, а иконки
ресурсов грузятся: в лог уходит `[selftest] icons: OK` или `FAILED`.
