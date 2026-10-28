# Иконки и арт интерфейса

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
