[English](README.md) | [Русский](README_RU.md)
# SAO Utils Games Menu

![SAOU Games Menu Preview](assets/Preview.gif)

SAO Utils Games Menu - виджет-лаунчер в стиле SAO для SAO Utils 2 / NERvGear.
Версия 1.1.0 поставляется с уже включённой папкой `shortcuts/`: помести туда
`.lnk` или `.url`, и ярлыки появятся в системной папке `ALL`.

Виджет запускает игры через существующий Windows shortcut / URI flow и
закрывается через настроенное действие SAO Utils
`Hide Widget / Скрыть виджет -> Games Menu`.

## Структура Пакета

Release package уже содержит нужные для обычного использования папки:

```text
saou.games.menu/
|-- assets/
|-- folder-icons/
|-- qml/
|-- runtime/
|-- shortcuts/
|-- state/
|-- tools/
|-- user-assets/
|-- config.txt
|-- module.qml
`-- package.json
```

Для обычной установки используй уже включённую `saou.games.menu/shortcuts/`.
`runtime/`, `state/` и `tools/` - технические package-local папки для discovery
и хранения стабильных ID.

## Возможности

- Автоматическое обнаружение `.lnk` и `.url` из уже включённой папки `shortcuts/`.
- Стабильные числовые ID игр по launch identity, а не по имени файла ярлыка.
- Системная папка `ALL` со всеми найденными ярлыками.
- Пользовательские папки по numeric ID.
- Необязательный внешний `shortcutsDir` override для продвинутых сценариев.
- Пользовательские изображения из `user-assets/<CurrentShortcutBaseName>.png`.
- Пользовательские иконки папок из `folder-icons/<folderId>.png`.
- Поддержка Windows `.lnk`, Windows `.url` и legacy direct URI launch.
- Настраиваемое наследование subtitle через `syncSubtitle`.
- Анимация закрытия после крестика или запуска игры.

## Требования

- SAO Utils 2.
- NERvGear API 1.x.
- Qt 5 / Qt Quick 2.12 / Qt Quick Controls 2.12.
- Windows PowerShell и Windows Script Host, входящие в поддерживаемые установки Windows.
- Windows-ярлыки `.lnk` или `.url` для автоматического обнаружения.

## Установка

1. Скачай release ZIP.
2. Распакуй папку `saou.games.menu`.
3. Скопируй `saou.games.menu` в папку пакетов SAO Utils 2 / NERvGear.
4. Помести `.lnk` или `.url` в уже включённую в пакет папку `saou.games.menu/shortcuts/`.
5. Открой Games Menu. Уже существующие ярлыки обнаруживаются автоматически при старте.
6. Перезапусти SAO Utils 2, если пакет ещё не был загружен.

## Первичная Настройка

Games Menu использует NERvGear `ActionSource` для системного закрытия. Реальной
видимостью виджета должен управлять SAO Utils, поэтому один раз настрой действие
закрытия:

```text
ПКМ по Games Menu
-> Close Action...
-> Widget / Виджет
-> Hide Widget / Скрыть виджет
-> Games Menu
-> OK
```

Без этой настройки крестик и автоматическое закрытие после запуска игры не
смогут скрыть виджет. Для открытия меню кнопкой или плиткой SAO Utils используй:

```text
Show Widget / Показать виджет -> Games Menu
```

`Toggle Widget / Переключить виджет -> Games Menu` тоже можно использовать
после настройки Close Action.

## Конфигурация

Редактируй:

```text
saou.games.menu/config.txt
```

Для личных локальных настроек, которые не нужно коммитить, создай:

```text
saou.games.menu/config.local.txt
```

Загрузчик сначала читает `config.local.txt`. Если его нет, используется
`config.txt`.

В обычной конфигурации `shortcutsDir` не нужен. Если `shortcutsDir` отсутствует
или пустой, Games Menu сканирует:

```text
saou.games.menu/shortcuts/
```

Продвинутые пользователи могут переопределить папку ярлыков:

```text
shortcutsDir=C:\Games\Shortcuts
```

Windows-пути можно писать с обычными обратными слэшами.

## Полный Пример Конфига

```text
configVersion=3
startHidden=false
maxColumns=3
syncSubtitle=true

# Game metadata:
# item=<ID>|<Title>|<GlobalSubtitle>

item=1|Game|Game Subtitle
item=2|SnowRunner|OFF-ROAD SIMULATOR

folder=favorites|FAVORITES|4
    game=1
    game=2

folder=racing|RACING|2
    game=2|RACING GAME

# Optional advanced override:
# shortcutsDir=C:\Games\Shortcuts
```

ID назначаются автоматически после discovery. Обычно пользователю не нужно
придумывать ID для новых найденных игр вручную.

## Discovery И Stable ID

Помести `.lnk` или `.url` в уже включённую в пакет папку `shortcuts/`. Games
Menu сканирует её и создаёт карточку запуска для каждого найденного ярлыка.
При создании component выполняется один controlled initial discovery refresh,
поэтому уже существующие ярлыки появляются без нажатия Reload. После добавления,
удаления, переименования или изменения ярлыков позже нажми Reload в нижних
левых контролах sidebar.

Обычный workflow:

```text
Помести .lnk/.url в shortcuts/
Открой Games Menu
Ярлык появится в ALL
```

Например:

```text
saou.games.menu/shortcuts/SnowRunner.url
```

создаст карточку:

```text
SnowRunner
```

Во время discovery Games Menu определяет launch identity:

- `.url`: читает реальное значение `[InternetShortcut] URL=...` и нормализует его.
- `.lnk`: читает `TargetPath`, `Arguments` и `WorkingDirectory` через Windows shortcut API.

Эта launch identity получает стабильный числовой ID, который хранится здесь:

```text
saou.games.menu/state/items.json
```

State file хранит соответствие `launchKey -> numeric ID`. Это локальное
пользовательское состояние, оно игнорируется Git и не требует ручного
редактирования.

Когда найден новый launch identity, Games Menu назначает следующий numeric ID и
добавляет одну global metadata строку:

```text
item=<ID>|<CurrentShortcutBaseName>|Game Subtitle
```

Автоматически создаётся только global `item=` metadata. Games Menu не добавляет
игры в `FAVORITES`, `RACING` или другие пользовательские папки.

Literal `Game Subtitle` - это только подсказка пользователю. Она не
отображается на карточках и не считается explicit subtitle для `syncSubtitle`.
Замени её своим текстом, чтобы показать subtitle.

Переименование ярлыка меняет title, но сохраняет тот же ID, если launch target
остался тем же. Например, если `Zenless Zone Zero.url` и `ZZZ.url` содержат
`URL=steam://rungameid/2513410`, существующая строка обновится:

```text
item=1|Zenless Zone Zero|ACTION RPG
```

станет:

```text
item=1|ZZZ|ACTION RPG
```

Subtitle сохраняется, а folder membership остаётся прежним:

```text
game=1
```

Если два ярлыка имеют одинаковый видимый basename, но разные launch identities,
они получают разные numeric ID. Basename - это presentation data, а не identity
игры.

## Изображения

Для собственной картинки игры положи PNG сюда:

```text
saou.games.menu/user-assets/
```

Рекомендуемые параметры изображения игры:

- 1200 × 900 px
- соотношение сторон 4:3
- рекомендуется PNG

Имя PNG всё ещё совпадает с текущим basename ярлыка:

```text
shortcuts/SnowRunner.url
user-assets/SnowRunner.png
```

После переименования `SnowRunner.url` в `My Game.url` matching artwork name:

```text
user-assets/My Game.png
```

Если PNG отсутствует или Qt не смог его загрузить, карточка использует fallback:

```text
saou.games.menu/assets/placeholder.png
```

Кэширование изображения карточки отключено, поэтому замену
`user-assets/<CurrentShortcutBaseName>.png` можно подхватить после повторного
открытия или нажатия Reload.

## Папки

`ALL` - системная папка. Она существует всегда, не хранится в `config.txt` и
содержит все найденные `.lnk` и `.url`.

Пользовательские папки задаются через numeric ID:

```text
folder=<folderId>|<displayName>|<maxColumns>
    game=<ID>
    game=<ID>|<FolderSubtitle>
```

`folderId` - стабильный внутренний id. Он же используется для поиска иконки
папки. `displayName` - текст в sidebar, его можно менять без переименования
иконки.
`maxColumns` необязателен. Если его нет, папка использует глобальный
`maxColumns`. `ALL` всегда использует глобальный `maxColumns`.

Folder entries ссылаются на стабильный game ID. Они не хранят title, launch
target, shortcut path или image path. Title хранится один раз в global строке
`item=<ID>|<Title>|<GlobalSubtitle>` и наследуется всеми папками, где указан
`game=<ID>`.

Синхронизацией subtitle управляет:

```text
syncSubtitle=true
```

При `syncSubtitle=true` одно уникальное явное непустое описание для того же ID
наследуется между `ALL` и папками. Разные explicit subtitles считаются
намеренным различием: папка со своим subtitle сохраняет его, папки без subtitle
используют global `item=` subtitle если он есть, а `ALL` использует global
subtitle или остаётся пустым.

При `syncSubtitle=false` наследования нет. `ALL` использует только
`item=<ID>|<Title>|<GlobalSubtitle>`, а каждая папка использует только своё
`game=<ID>|<FolderSubtitle>`.

## Иконки Папок

Необязательные иконки папок лежат здесь:

```text
saou.games.menu/folder-icons/
```

Рекомендуемые параметры иконок папок:

- 512 × 512 px
- прозрачный PNG
- иконка должна занимать большую часть холста без больших пустых полей

Для:

```text
folder=racing|RACING|2
```

Games Menu ищет:

```text
folder-icons/racing.png
```

Для системной папки `ALL` Games Menu ищет:

```text
folder-icons/all.png
```

Если файла нет, пробует `folder-icons/default.png`. Если default PNG тоже нет,
sidebar использует минимальный QML fallback.

## Настройки

- `configVersion=3` - включает stable numeric ID model.
- `item=<ID>|<Title>|<GlobalSubtitle>` - global metadata найденной игры.
- `Game Subtitle` - placeholder для новых auto-added `item=` строк; он не
  отображается, пока пользователь не заменит его своим текстом.
- `folder=<folderId>|<displayName>|<maxColumns>` - объявляет пользовательскую
  папку и может переопределить глобальный `maxColumns` только для неё.
- `game=<ID>` - добавляет game ID в пользовательскую папку.
- `game=<ID>|<FolderSubtitle>` - добавляет game ID с subtitle только для этой папки.
- `syncSubtitle=true` - default; наследует одно уникальное explicit описание по ID.
- `syncSubtitle=false` - отключает наследование subtitles между `ALL` и папками.
- `shortcutsDir` - необязательный override внешней папки ярлыков. Оставь его
  отсутствующим или пустым для встроенной `shortcuts/`.
- `startHidden=true` - просит настроенное Close Action скрыть Games Menu после
  запуска SAO Utils.
- `maxColumns` - максимум карточек в одной строке. Фактическое число может быть
  меньше, если виджет узкий.

## Миграция v2

Basename-based `configVersion=2` был экспериментальной моделью во время
разработки v1.1.0. Текущий config v1.1.0 использует `configVersion=3`.

При discovery или Reload Games Menu пытается выполнить controlled v2-to-v3
migration только когда текущий найденный basename однозначно сопоставляется с
одним stable ID. Например:

```text
item=ULTRAKILL|FAST-PACED FPS
folder=favorites|FAVORITES
    game=ULTRAKILL|MY FAVORITE FPS
```

может стать:

```text
item=2|ULTRAKILL|FAST-PACED FPS
folder=favorites|FAVORITES
    game=2|MY FAVORITE FPS
```

Если v2 entry нельзя сопоставить однозначно, Games Menu не угадывает. Данные
остаются в виде закомментированной строки `# Unmigrated v2 ...`, а в console
пишется warning.

## Legacy Config Compatibility

Старый формат v1 всё ещё парсится как путь совместимости:

```text
game=Title|Shortcut|Image|Description|Accent|Id
```

Legacy-записи показываются после найденных ярлыков. Это не основной способ
настройки v1.1.0; для новых конфигов используй встроенную `shortcuts/` и
`folder=`.

После изменения `config.txt` нажми Reload; это перечитает папки, `item=`
metadata, shortcut discovery, автоматически созданные metadata строки, subtitle
resolution и пользовательские изображения без перезапуска SAO Utils.

## Обновление

Перед заменой файлов из нового release ZIP сохрани пользовательские данные:

- `saou.games.menu/config.txt`, если ты редактировал его напрямую.
- `saou.games.menu/config.local.txt`, если ты его создал.
- `saou.games.menu/shortcuts/`, потому что там могут лежать личные ярлыки.
- `saou.games.menu/state/`, потому что там лежат stable game ID mappings.
- `saou.games.menu/user-assets/`, потому что там лежат изображения игр.
- `saou.games.menu/folder-icons/`, потому что там лежат иконки папок.

После этого замени файлы пакета из нового release ZIP и верни сохранённые
пользовательские файлы. Полная ручная замена папки может перезаписать личные
ярлыки, stable IDs, изображения, иконки и конфиги.

## Решение Проблем

### Крестик Ничего Не Делает

Настрой действие закрытия:

```text
ПКМ по Games Menu -> Close Action... -> Widget / Виджет -> Hide Widget / Скрыть виджет -> Games Menu
```

### Ярлык Не Появился

Проверь, что файл лежит в уже включённой папке `saou.games.menu/shortcuts/`,
или во внешнем `shortcutsDir`, если ты его настроил. Файл должен заканчиваться
на `.lnk` или `.url`, затем нажми Reload в нижних левых контролах sidebar.

### Папка Пустая

Проверь, что каждая строка `game=` внутри папки использует numeric ID из
соответствующей строки `item=`:

```text
item=2|SnowRunner|OFF-ROAD SIMULATOR

folder=racing|RACING|2
    game=2
```

### Изображение Не Отображается

Проверь, что PNG лежит в `saou.games.menu/user-assets/`, а имя файла совпадает
с текущим basename ярлыка.

### Иконка Папки Не Отображается

Проверь, что PNG лежит в `saou.games.menu/folder-icons/` и назван по `folderId`,
например `racing.png`.

## Лицензия

Исходный код проекта распространяется под MIT License. См. `LICENSE`.

Репозиторные assets, пользовательские изображения, названия игр, торговые марки
и интеллектуальная собственность издателей не становятся автоматически частью
MIT-лицензии. См. `ASSETS_NOTICE.md`.
