# Арт-промпты — Cozy Merge Cafe

Промпты для генерации **набросков/плейсхолдеров** (Midjourney / SD / DALL·E / Flux). Стиль-блок клеится в конец каждого промпта. Тексты промптов — на английском (модели понимают лучше), пояснения — по-русски.

> **Что игра реально подхватывает.** Код грузит файлы только из трёх мест: предметы цепочек `assets/items/<chain>/<chain>_<level>.png` (§3–§5), иконку приложения (§12) и растровый UI-арт (35 PNG — HUD, кнопки, панели, кафе), который код ищет по папкам `Icons.ART_DIRS`: `assets/ui/hud/`, `assets/ui/buttons/`, `assets/ui/panels/`, `assets/ui/cafe/` (§10, `docs/art-ui-prompts.md`). Декор (§9) живёт в `docs/art-decor-prompts.md`, UI (HUD, кнопки, панели попапов) — в `docs/art-ui-prompts.md`. Всё остальное — §6, §8, §11, §14, §16, §21, §22 — задел на будущее: под эти файлы кода пока нет, на экране плейсхолдеры.

---

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

## 6. Генераторы (3)

⚠️ Спрайтов генераторов код пока не грузит: генераторы — три прямоугольника прямо на поле (`scripts/board.gd`, `_draw_generators()`), в них название цепочки и цена в ⚡ (у закрытого — требуемый уровень). Это задел — рисовать, когда появится место под спрайт станции.

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

Файлы (задел): `assets/cats/<id>.png`, 1024×1024, прозрачный фон. ⚠️ Спрайты котов код пока не грузит — в альбоме сейчас иконка `cat`.

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

## 9. Декор кофейни

Переехало в отдельный документ: **`docs/art-decor-prompts.md`**. Там актуальная таблица — 27 предметов из `scripts/data/meta.gd` (`DECOR`): 14 с четырьмя ракурсами (`_S`/`_W`/`_N`/`_E`, изометрия 2:1) и 13 одиночных, с путями `assets/decor/<id>/<id>_<dir>.png` и техническими требованиями.

Старый список из 12 предметов устарел: кассы, вывески и «терраса-кофе» в игре нет.

---

## 10. UI-кит

> **Актуальные промпты UI — в отдельном файле: `docs/art-ui-prompts.md`.** Здесь
> раздел оставлен как история: HUD теперь держит 15 слотов `Texture2D`
> (`scripts/ui/game_hud.gd`), и размеры у кнопок/плашек конкретные. Панели и
> кнопки попапов всё ещё рисуются `StyleBox` в коде — это этап 2 из нового файла.

| Ассет | Промпт |
|---|---|
| Плитка поля | `a rounded square game board tile, soft cream color, subtle bevel, subtle wood grain, game ui` |
| Панель (9-slice) | `a rounded rectangular ui panel, cream and caramel, soft border, cozy mobile game ui, flat` |
| Кнопка основная | `a rounded chunky button, caramel gradient, cream label area, soft inner highlight, mobile game ui` |
| Кнопка второстепенная | `a rounded chunky button, sage green, flat, mobile game ui` |
| Карточка заказа | `a rounded card with a small window for item icons and a coin reward area, warm cream, mobile game ui` |
| Бейдж монет | `a rounded pill badge with a coin icon and a cream number area, mobile game ui` |

Для UI проси **плоско** (`flat ui, no gradient noise, no drop shadow`) и без текста — числа рисуем шрифтом в Godot.

---

## 11. Фоны

⚠️ Код фоны не грузит: и поле, и кофейня рисуют `ColorRect`. Задел.

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

- [x] Style board + выбранный reference (§2)
- [x] Style block зафиксирован
- [x] 3 цепочки: 10 + 7 + 5 = 22 предмета → `assets/items/<chain>/<chain>_<level>.png` — готовы все (кофе, выпечка, цветы)
- [x] Иконки UI (§7) — растровый арт в `assets/ui/hud/` и `assets/ui/buttons/`, генерировать не надо
- [x] Иконка приложения (§12) — уже в `assets/icons/`
- [ ] 12 котов по id из §8 → `assets/cats/<id>.png` (⚠️ код пока не грузит)
- [ ] Декор: 27 предметов по `docs/art-decor-prompts.md` → `assets/decor/<id>/`
- [ ] 3 генератора (§6, ⚠️ код пока не грузит)
- [x] Растровый UI-арт (§10) — 35 PNG в `assets/ui/{hud,buttons,panels,cafe}/`, код ищет по `Icons.ART_DIRS`; спека — `docs/art-ui-prompts.md` §11
- [ ] 3 фона (§11, ⚠️ кода нет)
- [ ] Импорт в Godot: PNG с альфой; предметы 512×512 (на доске спрайт занимает 2/3 клетки, текстура грузится до 256), коты и декор 1024×1024, фон по `--ar`

Листы из генераций режутся на отдельные PNG инструментом `tools/split_sheet.gd` — по непрозрачным областям, без ресайза: `godot --headless --script tools/split_sheet.gd -- --sheet <лист> --out <папка> --prefix <цепочка>`.

Порядок для минимального играбельного набора: кофе, выпечка, цветы — **готово**; дальше коты → декор.

---

## 14. VFX / эффекты

⚠️ Кода VFX в проекте нет (`assets/vfx/` пуст) — это задел.

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
game logo wordmark "Cozy Merge Cafe", cozy casual mobile game lettering,
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

## 23. Обновлённый чек-лист MVP

- [ ] 6 VFX (burst, sparkle, coin, dust, level up, order complete)
- [ ] 5 иконок бустеров
- [ ] Спрайт-лист эмоций кота (6)
- [ ] Логотип (горизонт + квадрат + монохром)
- [ ] Выбранный финальный стиль (A/B/C/D)
- [ ] 5 стор-скриншотов + оверлеи
- [ ] Креативы: rewarded-иконка, story 9:16, 2 баннера
- [x] Тайл стола + рамка поля + подложка клетки (`assets/ui/board/`, подключены в `scripts/board.gd`)
- [ ] Туториальные указатели (hand pointer 3 кадра, стрелка)
- [ ] Итого новых файлов: ~25 (не считая уже посчитанных в §13)

---

## 24. Чек-лист наличия файлов

Отмечай `[x]`, когда файл реально лежит в репозитории. Сейчас отмечено то, что уже есть.
Имена для задела (§6, §11, §14–§22) закреплены здесь: код их пока не грузит, но кладём по этим путям.

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

### Растровый UI-арт (§10) — 35/35 ✅

`assets/ui/hud/` — 18, `assets/ui/buttons/` — 8, `assets/ui/panels/` — 5,
`assets/ui/cafe/` — 4. Полный список с размерами и кромками 9-slice —
`docs/art-ui-prompts.md` §11; код находит файлы через `Icons.ART_DIRS`.

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

### Генераторы (§6) — 0/3

- [ ] `assets/generators/espresso.png` — Эспрессо-станция
- [ ] `assets/generators/pastry_case.png` — Витрина выпечки
- [ ] `assets/generators/flower_pot.png` — Цветочный горшок

### Коты (§8) — 0/12

- [ ] `assets/cats/mocha.png` — Мокко (Бариста)
- [ ] `assets/cats/latte.png` — Латте (Официант)
- [ ] `assets/cats/bublik.png` — Бублик (Пекарь)
- [ ] `assets/cats/tiramisu.png` — Тирамису (Гость)
- [ ] `assets/cats/espresso.png` — Эспрессо (Старший бариста)
- [ ] `assets/cats/choco.png` — Шоко (Кондитер)
- [ ] `assets/cats/mimi.png` — Мими (Гость-критик)
- [ ] `assets/cats/flora.png` — Флора (Садовник)
- [ ] `assets/cats/caramel.png` — Карамель (Шеф-пекарь, epic)
- [ ] `assets/cats/mochi.png` — Моти (Дегустатор, epic)
- [ ] `assets/cats/velvet.png` — Бархат (Инспектор уюта, epic)
- [ ] `assets/cats/star.png` — Звёздочка (Легенда кафе, epic)

### Фоны (§11) — 0/3

- [ ] `assets/backgrounds/cafe_interior.png` (`--ar 3:4`)
- [ ] `assets/backgrounds/main_menu.png` (`--ar 3:4`)
- [ ] `assets/backgrounds/shop.png` (`--ar 3:4`)

### VFX (§14) — 0/6

- [ ] `assets/vfx/merge_burst.png` — 8 кадров, 256×256
- [ ] `assets/vfx/sparkle.png` — 6 кадров, 128×128
- [ ] `assets/vfx/coin_fly.png` — 6 кадров, 128×128
- [ ] `assets/vfx/dust.png` — 6 кадров, 128×128
- [ ] `assets/vfx/level_up.png` — 8 кадров, 512×512
- [ ] `assets/vfx/order_complete.png` — 8 кадров, 256×256

### Иконки бустеров (§15) — 0/5

- [ ] `assets/ui/boosters/hammer.png` — Хаммер
- [ ] `assets/ui/boosters/shuffle.png` — Шафл
- [ ] `assets/ui/boosters/magnet.png` — Магнит
- [ ] `assets/ui/boosters/slot_plus.png` — Слот +1
- [ ] `assets/ui/boosters/sell.png` — Продажа

### Эмоции кота (§16) — 0/1 лист

- [ ] `assets/cats/emotions_sheet.png` — 6 кадров, 1024×1024, сетка 3×2

### Логотип (§17) — 0/3

- [ ] `assets/branding/wordmark.png` — горизонтальный (растровый черновик — `assets/wordmark.jpg`)
- [ ] `assets/branding/logo_square.png` — квадратный
- [ ] `assets/branding/logo_mono.png` — монохром

### Альтернативные стили (§18) — 0/3

- [ ] `assets/style_a.png` — flat vector
- [ ] `assets/style_b.png` — гуашь
- [ ] `assets/style_c.png` — clay (рабочий канон — `assets/style.png`)

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

### Тайл и бордюр поля (§21) — 0/4

- [ ] `assets/ui/board/table_tile_512.png` — бесшовный (Repeat)
- [ ] `assets/ui/board/board_frame.png` — 9-slice, 256×256
- [ ] `assets/ui/board/cell_bg.png` — 128×128
- [ ] `assets/ui/board/cell_bg_active.png` — подсветка при drag

### Туториальные указатели (§22) — 0/4

- [ ] `assets/ui/tutorial/hand_pointer_1.png` — стук
- [ ] `assets/ui/tutorial/hand_pointer_2.png` — тап
- [ ] `assets/ui/tutorial/hand_pointer_3.png` — уход
- [ ] `assets/ui/tutorial/arrow_hint.png` — стрелка 256×256
