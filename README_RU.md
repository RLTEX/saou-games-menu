[English](README.md) | [Русский](README_RU.md)
# SAO Utils Games Menu

![SAOU Games Menu Preview](assets/Preview.gif)

SAO Utils Games Menu - виджет-лаунчер в стиле SAO для SAO Utils 2 / NERvGear.
Версия 1.1.0 поставляется с уже включённой папкой `shortcuts/`: помести туда
`.lnk` или `.url`, и ярлыки появятся в системной папке `ALL`.

Виджет по-прежнему запускает игры через существующий Windows shortcut / URI
путь и закрывается через настроенное действие SAO Utils
`Hide Widget / Скрыть виджет -> Games Menu`.

## Структура пакета

Release package уже содержит нужные для обычного использования папки:

```text
saou.games.menu/
├─ assets/
├─ folder-icons/
├─ qml/
├─ runtime/
├─ shortcuts/
├─ tools/
├─ user-assets/
├─ config.txt
├─ module.qml
└─ package.json
```

Для обычной установки используй уже включённую `saou.games.menu/shortcuts/`.
`runtime/` и `tools/` - технические папки пакета для совместимого механизма
обнаружения ярлыков.

## Возможности

- Интерфейс в стиле SAO для SAO Utils 2 / NERvGear.
- Автоматическое обнаружение `.lnk` и `.url` из уже включённой папки `shortcuts/`.
- Необязательный внешний `shortcutsDir` override для продвинутых сценариев.
- Системная папка `ALL` со всеми найденными ярлыками.
- Пользовательские папки по basename ярлыка.
- Sidebar папок с пользовательскими иконками.
- Динамические карточки через существующий `GameCard`.
- Пользовательские изображения игр из `user-assets/`.
- Поддержка Windows-ярлыков `.lnk`.
- Поддержка Windows-ярлыков `.url`.
- Legacy-поддержка прямых URI запуска, включая Steam URI вроде `steam://rungameid/1465360`.
- Оверлей запуска и состояние `LAUNCH FAILED`.
- Анимация закрытия после крестика или запуска игры.

## Требования

- SAO Utils 2.
- NERvGear API 1.x.
- Qt 5.
- Qt Quick 2.12.
- Qt Quick Controls 2.12.
- Windows PowerShell, входящий в поддерживаемые установки Windows.
- Windows-ярлыки `.lnk` или `.url` для автоматического обнаружения.

## Установка

1. Скачай release ZIP.
2. Распакуй папку `saou.games.menu`.
3. Скопируй `saou.games.menu` в папку пакетов SAO Utils 2 / NERvGear.
4. Помести `.lnk` или `.url` в уже включённую в пакет папку `saou.games.menu/shortcuts/`.
5. Перезапусти SAO Utils 2, если он уже был открыт.

## Первоначальная настройка

Games Menu использует NERvGear `ActionSource` для системного закрытия. Реальной
видимостью виджета должен управлять SAO Utils, поэтому один раз настрой
действие закрытия:

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

## Полный пример конфига

```text
configVersion=2
startHidden=false
maxColumns=3

folder=favorites|FAVORITES
    game=ZZZ
    game=NTE

folder=racing|RACING
    game=SnowRunner

folder=rhythm|RHYTHM
    game=Muse Dash

# Optional advanced override:
# shortcutsDir=C:\Games\Shortcuts
```

## Автоматическое обнаружение ярлыков

Помести `.lnk` или `.url` в уже включённую в пакет папку `shortcuts/`. Games
Menu сканирует эту папку и создаёт карточку запуска для каждого найденного
ярлыка.
Для совместимости с проверенным SAO Utils runtime discovery обновляется при
загрузке компонента виджета, при изменении `shortcutsDir` и при вызове
существующего hook анимации открытия. Live watcher директории не используется.

Например:

```text
saou.games.menu/shortcuts/SnowRunner.url
```

создаст карточку:

```text
SnowRunner
```

Launch target - реальный путь к ярлыку. Games Menu не записывает найденные игры
обратно в `config.txt`.

Если одновременно есть `SnowRunner.lnk` и `SnowRunner.url`, оба ярлыка
появятся в `ALL`. Для пользовательской папки строка `game=SnowRunner`
разрешается детерминированно: `.lnk` имеет приоритет перед `.url`, а виджет
пишет warning в console.

## Изображения

Для собственной картинки игры положи PNG сюда:

```text
saou.games.menu/user-assets/
```

Имя PNG должно совпадать с basename ярлыка:

```text
shortcuts/SnowRunner.url
user-assets/SnowRunner.png
```

Если PNG отсутствует или Qt не смог его загрузить, карточка использует fallback:

```text
saou.games.menu/assets/placeholder.png
```

## Папки

`ALL` - системная папка. Она существует всегда, не хранится в `config.txt` и
содержит все найденные `.lnk` и `.url`.

Пользовательские папки задаются так:

```text
folder=<folderId>|<displayName>
    game=<ShortcutBaseName>
```

`folderId` - стабильный внутренний id. Он же используется для поиска иконки
папки. `displayName` - текст в sidebar, его можно менять без переименования
иконки.

В `game=` внутри папки указывается только basename ярлыка. Не добавляй туда
полные пути, пути к изображениям или launch target.

## Иконки папок

Необязательные иконки папок лежат здесь:

```text
saou.games.menu/folder-icons/
```

Для:

```text
folder=racing|RACING
```

Games Menu ищет:

```text
folder-icons/racing.png
```

Если файла нет, пробует `folder-icons/default.png`. Если default PNG тоже нет,
sidebar использует минимальный QML fallback.

## Настройки

- `configVersion=2` - включает v1.1.0 auto discovery и folder config.
- `shortcutsDir` - необязательный override внешней папки ярлыков. Оставь его
  отсутствующим или пустым для встроенной `shortcuts/`.
- `startHidden=true` - просит настроенное Close Action скрыть Games Menu после
  запуска SAO Utils.
- `maxColumns` - максимум карточек в одной строке. Фактическое число может быть
  меньше, если виджет узкий.

## Legacy config compatibility

Старый формат v1 всё ещё парсится как путь совместимости:

```text
game=Title|Shortcut|Image|Description|Accent|Id
```

Legacy-записи показываются после найденных ярлыков. Это не основной способ
настройки v1.1.0; для новых конфигов используй встроенную `shortcuts/` и
`folder=`.

## Обновление

Перед заменой файлов из нового release ZIP сохрани пользовательские данные:

- `saou.games.menu/config.txt`, если ты редактировал его напрямую.
- `saou.games.menu/config.local.txt`, если ты его создал.
- `saou.games.menu/shortcuts/`, потому что там могут лежать личные ярлыки.
- `saou.games.menu/user-assets/`, потому что там лежат изображения игр.
- `saou.games.menu/folder-icons/`, потому что там лежат иконки папок.

После этого замени файлы пакета из нового release ZIP и верни свои сохранённые
пользовательские файлы. Полная ручная замена папки может перезаписать личные
ярлыки, изображения, иконки и конфиги.

## Решение проблем

### Крестик ничего не делает

Настрой действие закрытия:

```text
ПКМ по Games Menu -> Close Action... -> Widget / Виджет -> Hide Widget / Скрыть виджет -> Games Menu
```

### Ярлык не появился

Проверь, что файл лежит в уже включённой папке `saou.games.menu/shortcuts/`,
или во внешнем `shortcutsDir`, если ты его настроил. Файл должен заканчиваться
на `.lnk` или `.url`.

### Папка пустая

Проверь, что каждая строка `game=` внутри папки использует basename ярлыка без
расширения:

```text
game=SnowRunner
```

для `SnowRunner.lnk` или `SnowRunner.url`.

### Изображение не отображается

Проверь, что PNG лежит в `saou.games.menu/user-assets/`, а имя файла совпадает
с basename ярлыка.

### Иконка папки не отображается

Проверь, что PNG лежит в `saou.games.menu/folder-icons/` и назван по `folderId`,
например `racing.png`.

## Лицензия

Исходный код проекта распространяется под MIT License. См. `LICENSE`.

Репозиторные assets, пользовательские изображения, названия игр, торговые марки
и интеллектуальная собственность издателей не становятся автоматически частью
MIT-лицензии. См. `ASSETS_NOTICE.md`.
