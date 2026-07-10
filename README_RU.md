[English](README.md) | [Русский](README_RU.md)

# SAO Utils Games Menu

SAO Utils Games Menu - виджет-лаунчер для быстрого запуска игр и программ через
Windows-ярлыки `.lnk` и `.url`.

## Возможности

- Автоматическое обнаружение `.lnk` и `.url` ярлыков.
- Запуск игр и программ из одного меню в стиле SAO.
- Пользовательские плитки и изображения игр.
- Пользовательские папки.
- Пользовательские иконки папок, включая системную папку `ALL`.
- Настройка количества колонок глобально и отдельно для папок.
- Названия игр и подписи через `config.txt`.
- Автоматические стабильные ID игр.
- Автоматические подсказки `# IN:` в `config.txt`.
- Параметр `startHidden`.
- Параметр `closeOnLaunch`.
- Reload для ярлыков, конфига и изображений игр без перезапуска SAO Utils.

## Preview

![SAO Utils Games Menu Preview](assets/Preview.gif)

## Требования

- SAO Utils 2 / NERvGear.
- Windows.
- Windows-ярлыки `.lnk` или `.url`.
- Windows PowerShell и Windows Script Host, которые входят в поддерживаемые версии Windows.

## Установка

1. Скачай release ZIP.
2. Распакуй папку `Packages` из архива в директорию приложения SAO Utils 2 / NERvGear.
3. Помести `.lnk` или `.url` файлы в уже включённую папку `Packages/saou.games.menu/shortcuts/`.
4. Один раз настрой действие закрытия:

```text
ПКМ по Games Menu
-> Close Action...
-> Widget / Виджет
-> Hide Widget / Скрыть виджет
-> Games Menu
-> OK
```

5. Открой Games Menu.

Если SAO Utils уже был запущен во время установки, перезапусти его один раз.

## Кастомизация

### Изображения Игр

Положи изображение игры сюда:

```text
saou.games.menu/user-assets/<ShortcutName>.png
```

Пример:

```text
shortcuts/SnowRunner.url
user-assets/SnowRunner.png
```

Имя PNG должно совпадать с именем ярлыка без `.lnk` или `.url`.

Рекомендуется: `1200 × 900 px`, соотношение сторон `4:3`, PNG.

### Иконки Папок

Положи иконку папки сюда:

```text
saou.games.menu/folder-icons/<folderId>.png
```

Для системной папки `ALL` можно использовать:

```text
saou.games.menu/folder-icons/all.png
```

Имя PNG должно совпадать с ID папки. Например, для `folder=racing|RACING`
используется `folder-icons/racing.png`.

Рекомендуется: `512 × 512 px`, прозрачный PNG. Иконка должна занимать большую
часть холста без больших пустых полей.

Если после замены PNG всё ещё показывается старая иконка папки, перезапусти SAO Utils.

### Папки

Папки настраиваются в `config.txt` через ID игр:

```text
item=2|SnowRunner|OFF-ROAD SIMULATOR

folder=racing|RACING|2
    game=2
```

Games Menu назначает ID автоматически после обнаружения ярлыков. Подсказки вроде
`# IN: RACING` создаются автоматически и являются только комментариями.

## Настройки

Редактируй:

```text
saou.games.menu/config.txt
```

Короткий пример:

```text
configVersion=3
startHidden=false
closeOnLaunch=true
maxColumns=3

item=1|L4D2|Left 4 Dead 2           # IN: FAVORITES, SHOOTER
item=2|Muse Dash|RHYTHM GAME        # IN: FAVORITES

folder=favorites|FAVORITES|4
    game=1
    game=2

folder=shooter|SHOOTER|3
    game=1

# Необязательная внешняя папка ярлыков:
# shortcutsDir=C:\Games\Shortcuts
```

Пользовательские параметры:

- `startHidden=true|false` - скрывать или показывать Games Menu при запуске SAO Utils.
- `closeOnLaunch=true|false` - закрывать Games Menu после запуска игры или оставлять открытым.
- `maxColumns=<number>` - глобальный максимум колонок с карточками.
- `item=<ID>|<Game Name>|<Game Subtitle>` - название и подпись игры.
- `folder=<folderId>|<DisplayName>|<MaxColumns>` - пользовательская папка и необязательный лимит колонок.
- `game=<ID>` - добавить игру в текущую папку.
- `shortcutsDir=<path>` - необязательная внешняя папка ярлыков для продвинутых сценариев.

Оставь `shortcutsDir` отсутствующим или пустым, чтобы использовать встроенную
папку `saou.games.menu/shortcuts/`.

Комментарии `# IN:` генерируются Games Menu. Они показывают, в каких папках
находится игра, и не требуют ручного редактирования.

## Обновление

Перед ручной заменой папки пакета сохрани пользовательские данные:

- `saou.games.menu/config.txt`
- `saou.games.menu/config.local.txt`, если ты его создал
- `saou.games.menu/shortcuts/`
- `saou.games.menu/state/`
- `saou.games.menu/user-assets/`
- `saou.games.menu/folder-icons/`

После этого замени файлы пакета и верни сохранённые пользовательские файлы.

## Решение Проблем

### Крестик Ничего Не Делает

Настрой:

```text
Close Action... -> Widget / Виджет -> Hide Widget / Скрыть виджет -> Games Menu
```

Games Menu должен закрываться через настроенное действие SAO Utils.

### Ярлык Не Появился

Проверь, что `.lnk` или `.url` лежит в `saou.games.menu/shortcuts/`, затем нажми
Reload в нижних левых контролах боковой панели.

### Изображение Игры Не Появилось

Проверь, что PNG лежит в `saou.games.menu/user-assets/`, а имя файла совпадает
с именем ярлыка без `.lnk` или `.url`.

### Иконка Папки Не Появилась

Проверь, что PNG лежит в `saou.games.menu/folder-icons/` и назван по ID папки,
например `racing.png`. Для `ALL` используй `all.png`.

Если ты заменил существующую иконку, а SAO Utils всё ещё показывает старую,
перезапусти SAO Utils.

### Изменения Конфига Не Видны

Нажми Reload в Games Menu. Если заменялась именно иконка папки и старая иконка
осталась в кэше, перезапусти SAO Utils.

## Дополнительно

### Структура Пакета

Обычная структура release ZIP:

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

Папки `shortcuts/`, `user-assets/`, `folder-icons/` и `state/` уже входят в
пакет, поэтому пользователю не нужно создавать их вручную.

### Стабильные ID Игр

Games Menu выдаёт каждому найденному ярлыку стабильный числовой ID. ID основан
на цели запуска ярлыка, а не только на видимом имени файла. Благодаря этому
игра остаётся в нужных папках даже после переименования ярлыка.

Локальное состояние ID хранится здесь:

```text
saou.games.menu/state/items.json
```

Это пользовательский локальный файл, он игнорируется Git.

### Миграция v2

Старый формат `configVersion=2`, основанный на именах ярлыков, был
экспериментальным во время разработки v1.1.0. Текущий формат использует
`configVersion=3`.

Если возможно, Games Menu переносит старые записи папок на числовые ID во время
Reload. Если старую запись нельзя сопоставить безопасно, она остаётся
закомментированной как unmigrated.

### Совместимость Со Старым Конфигом

Старый ручной формат игр всё ещё читается для совместимости:

```text
game=Title|Shortcut|Image|Description|Accent|Id
```

Для новых настроек используй ярлыки в `shortcuts/` и записи `item=`, `folder=`,
`game=`.

### Технические Заметки Об Обнаружении Ярлыков

Обнаружение ярлыков использует helper-скрипты из `saou.games.menu/tools/`.
PowerShell запускается через встроенный VBS wrapper, чтобы helper работал
скрыто. Runtime-файлы discovery записываются внутри папки `runtime/`.

## Лицензия

MIT. См. [LICENSE](LICENSE).
