# Арт-промпты — Cozy Merge Cafe

Промпты для генерации **набросков/плейсхолдеров** (Midjourney / SD / DALL·E / Flux). Стиль-блок клеится в конец каждого промпта. Тексты промптов — на английском (модели понимают лучше), пояснения — по-русски.

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

| Ур. | Предмет | Промпт (ядро) |
|---|---|---|
| 1 | Росток | `a tiny green sprout with two leaves in a small brown pot` |
| 2 | Бутон | `a closed flower bud on a green stem, soft pink` |
| 3 | Цветок | `a single open pastel flower with soft petals and a warm center` |
| 4 | Букет | `a small hand-tied bouquet of pastel flowers, wrapped in kraft paper` |
| 5 | Композиция | `a decorative floral arrangement in a ceramic vase, sage and terracotta flowers` |

---

## 6. Генераторы (3)

| Генератор | Промпт |
|---|---|
| Эспрессо-станция | `a cute retro espresso machine with a portafilter and steam wand, caramel and chrome, warm and friendly, game object icon` |
| Витрина выпечки | `a small glass display case full of croissants and cakes, warm wood frame, game object icon` |
| Цветочный горшок | `a terracotta flower pot with soil and a few green leaves, game object icon` |

---

## 7. Иконки (валюта, бустеры, UI-фигуры)

| Ассет | Промпт |
|---|---|
| Энергия | `a glowing yellow lightning bolt icon, rounded, honey gold, glossy, game icon` |
| Монета | `a shiny gold coin with a tiny coffee cup embossed, rounded edges, game icon` |
| Гем | `a faceted purple gemstone, plum and violet, sparkle highlight, game icon` |
| Сундук | `a small wooden treasure chest with brass fittings and soft golden glow, closed, game icon` |
| Таймер | `a round clock icon with a coffee bean as the hand, cream and espresso colors, game icon` |
| Копилка | `a cute ceramic piggy bank shaped like a cat, coin slot, pastel, game icon` |
| Rewarded | `a rounded play-button badge with a small film clapper, caramel and honey, game icon` |

---

## 8. Коты (12 персонажей)

Общий промпт: `a cute chibi cat character, full body, standing, <описание>, cozy cafe vibe, friendly smile, big expressive eyes, simple clean shapes, game character for a merge mobile game, transparent background`

| # | Имя | Роль | Описание |
|---|---|---|---|
| 1 | Мокко | бариста | `brown tabby cat barista wearing a small beige apron and a name tag` |
| 2 | Латте | официант | `cream-colored cat holding a small serving tray with a cup` |
| 3 | Слоён | пекарь | `orange ginger cat wearing a chef hat and holding a croissant` |
| 4 | Эспрессо | гость-критик | `dark coffee-colored cat with round glasses and a tiny notepad` |
| 5 | Мята | флорист | `white cat with green eyes wearing a flower crown, holding a bouquet` |
| 6 | Карамель | кассир | `calico cat wearing a small bow tie behind a tiny register` |
| 7 | Ваниль | кондитер | `fluffy white persian cat with a whisk and a frosting bag` |
| 8 | Пряник | уборщик | `chubby grey cat holding a small broom, slightly grumpy but cute` |
| 9 | Персик | гость | `peach-colored kitten sitting with a tiny cup, sleepy and content` |
| 10 | Шоколад | гость | `chocolate-brown cat with a tiny scarf reading a newspaper` |
| 11 | Тигр | менеджер | `bengal tabby cat wearing a vest and holding a clipboard` |
| 12 | Батон | талисман кофейни | `round loaf-shaped cat bread mascot with a tiny smile, warm and silly` |

---

## 9. Декор кофейни (12 предметов)

Общий хвост: `isometric top-down game object, cozy cafe interior piece, warm wood and pastel fabrics, cozy casual mobile game asset, 2D stylized illustration, soft rounded shapes, clean outlines, no text, no watermark`

| Ассет | Промпт (ядро) |
|---|---|
| Стол | `a small round wooden cafe table with a tiny vase` |
| Стул | `a cozy rounded wooden chair with a pastel cushion` |
| Диван | `a soft terracotta two-seat sofa with cream pillows` |
| Лампа | `a warm hanging pendant lamp with a soft glow` |
| Касса | `a vintage brass cash register on a wooden counter` |
| Стеллаж | `a tall wooden shelf filled with coffee bags and jars` |
| Растение | `a large potted monstera plant in a terracotta pot` |
| Коврик | `a round woven rug in cream and sage stripes` |
| Картина | `a small framed painting of a cat drinking coffee` |
| Витрина | `a curved glass pastry display case with cakes` |
| Вывеска | `a hanging wooden cafe sign with a cat and a coffee cup silhouette` |
| Терраса-кофе | `a tiny outdoor bistro set with a potted plant and a heater` |

---

## 10. UI-кит

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

- [ ] Style board + выбранный reference
- [ ] Style block зафиксирован
- [ ] 3 цепочки: 10 + 7 + 5 = 22 предмета
- [ ] 3 генератора
- [ ] 7 иконок (валюта/бустеры)
- [ ] 12 котов
- [ ] 12 предметов декора
- [ ] 6 UI-ассетов
- [ ] 3 фона
- [ ] Иконка приложения
- [ ] Импорт в Godot: размеры 512×512 (предметы), 1024×1024 (коты), фон по `--ar`

---

## 14. VFX / эффекты

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

- **Тайл столешницы:** 512×512, бесшовный, `seamless tileable wood table top, warm latte brown, subtle grain, soft vignette, top-down, 2D stylized`. ⚠️ При импорте в Godot — режим `Repeat`.
- **Рамка/бордюр поля:** `rounded rectangle frame, 9-slice friendly, caramel outline, soft inner shadow, transparent center`, 256×256 по углам, без текста.
- **Подложка клетки:** 128×128, `empty board cell, rounded square, subtle inset, light cream`, два состояния (обычная, подсвеченная при drag).

## 22. Туториальные указатели

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
- [ ] Тайл стола + рамка поля + подложка клетки
- [ ] Туториальные указатели (hand pointer 3 кадра, стрелка)
- [ ] Итого новых файлов: ~25 (не считая уже посчитанных в §13)
