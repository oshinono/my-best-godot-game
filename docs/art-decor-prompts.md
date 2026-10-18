# Промпты для арта декора (4 ракурса)

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
