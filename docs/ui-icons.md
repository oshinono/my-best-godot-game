# Иконки UI

Иконки интерфейса — растровый арт (PNG). SVG-набор (`assets/ui/icons/*.svg`) из
проекта убран: одно растровое семейство, один источник размеров, ноль
растеризации в рантайме. Грузит и раскрашивает иконки `scripts/ui/icons.gd`
(класс `Icons`); файлы лежат в папках `Icons.ART_DIRS`
(`assets/ui/hud/`, `assets/ui/buttons/`, `assets/ui/panels/`, `assets/ui/cafe/`).

## Логические id → PNG

Код зовёт иконки по короткому id, а не по имени файла: таблица подмены —
`Icons.ICON_ART` в `scripts/ui/icons.gd`.

| id | файл арта | где в коде |
| --- | --- | --- |
| `coin` | `icon_coin.png` | бар HUD (`game_hud.gd`, `_make_bar(tex_icon_coin, Color("f2b01e"), false)`), продажа предмета (`game.gd`, `Icons.decorate(_action_sell, "coin", 32.0)`), покупка декора (`cafe_view.gd`, `Icons.decorate(buy, "coin", 24.0)` и `Icons.art("icon_coin_main", Vector2(45, 45))`), строка «купить можно в кофейне» (`meta_popup.gd`) |
| `gem` | `icon_gem.png` | бар HUD (`_make_bar(tex_icon_gem, Color("e0489b"), true)`) |
| `energy` | `icon_energy.png` | бар HUD (`_make_bar(tex_icon_energy, Color("ffc933"), true)`) |
| `plus` | `plus_badge.png` | плюсик у баров энергии и гемов (`game_hud.gd`, `_make_bar`) |
| `cart` | `shop.png` | магазин в изо-кафе (`cafe_view.gd`, кнопка покупки) |
| `gear` / `settings` | `icon_settings.png` | кнопка настроек в HUD |
| `menu` | `icon_menu.png` | кнопка мета-попапа в HUD |
| `play` | `btn_play.png` | большая кнопка игры в HUD |

## Как это работает

- **Размеры.** Проектные размеры арта — в `Icons.ART` (база 720×1280),
  фактические PNG нарисованы в 4× и ужимаются кодом (`ART_SCALE = 4.0`).
- **Имена файлов.** `icon_coin.png` и `icon_coin_main.png` — два варианта
  одного символа (обычный и «главный» для баров HUD). HUD грузит `*_main.png`.
- **Пропорции.** Растягивать арт по одной оси нельзя: `Icons.fit()`
  вписывает текстуру в целевой прямоугольник с сохранением аспекта и
  округлением до целых пикселей.
- **Размеры по умолчанию** для мелких иконок:
  `Icons.SIZES = {"chip": 32.0, "button": 36.0, "small": 22.0}`.
- **Цвет.** PNG рисуется как есть; `modulate` у `Icons.rect()` может тонировать
  белую графику (`Icons.DEFAULT_TINT = Color("4A3A2E")`).
- **Текст вместо иконки.** Там, где подходящего PNG нет, иконка просто не
  рисуется: `Icons.rect()` создаёт невидимый узел, `Icons.decorate()` оставляет
  кнопку с одним текстом. Звёзды редкости (`Icons.stars()`) рисуются текстом
  `★`, а не картинкой.

## Как добавить иконку

1. положить PNG в одну из папок `Icons.ART_DIRS` по требованиям `Icons.ART`
   (проектный размер × 4, прозрачный фон, без обрезки по краям);
2. дописать базовое имя в `Icons.ICON_ART` (id → файл) или в `Icons.ART`
   (размер) и в `Icons.USED_ART` — иначе иконку не проверит селфтест и она
   легко потеряется при чистке;
3. дописать строку в таблицу выше.

## Проверка

`Icons.available()` перечисляет базовые имена арта, для которых файл реально
найден. Селфтест игры (`SELFTEST := true` в `scripts/game.gd`) проверяет, что
каждый арт из `Icons.USED_ART` существует и загружается в текстуру: в консоль
уходит `[selftest] icons: OK` или `FAILED`. В рантайме о проблемах сообщает
предупреждение `[Icons] нет арта %s`.
