# SAO Utils Games Menu

SAO Utils Games Menu - настраиваемый виджет-лаунчер игр для SAO Utils 2 /
NERvGear. Он показывает анимированное меню в стиле SAO, строит карточки игр из
конфига пользователя, запускает ярлыки или URI запуска, а затем закрывается
через настроенное действие SAO Utils.

## Возможности

- Интерфейс в стиле SAO для SAO Utils 2 / NERvGear.
- Настройка игр без редактирования QML.
- Динамические карточки игр.
- Вертикально прокручиваемая сетка с `maxColumns`.
- Пользовательские изображения игр из `user-assets/`.
- Поддержка Windows-ярлыков `.lnk`.
- Поддержка Windows-ярлыков `.url`.
- Поддержка прямых URI запуска, включая Steam URI вроде `steam://rungameid/1465360`.
- Оверлей запуска и состояние `LAUNCH FAILED`.
- Анимация закрытия после крестика или запуска игры.

## Требования

- SAO Utils 2.
- NERvGear API 1.x.
- Qt 5.
- Qt Quick 2.12.
- Qt Quick Controls 2.12.
- Windows-ярлыки или URI запуска для игр.

## Releases

Для обычного использования скачивай готовый ZIP из GitHub Releases. Клонировать
репозиторий имеет смысл в основном для разработки или правки виджета.

## Установка

1. Скачай release ZIP.
2. Распакуй папку `saou.games.menu`.
3. Скопируй `saou.games.menu` в папку пакетов SAO Utils 2 / NERvGear.
4. Перезапусти SAO Utils 2, если он уже был открыт.

## Первоначальная настройка

Games Menu использует NERvGear `ActionSource` для системного закрытия. Реальной
видимостью виджета должен управлять SAO Utils, поэтому один раз нужно настроить
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
смогут скрыть виджет. Это обязательный шаг настройки текущей архитектуры, а не
ошибка.

Чтобы открывать меню кнопкой или плиткой SAO Utils, настрой действие:

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

Windows-пути можно писать с обычными обратными слэшами:

```text
shortcutsDir=C:\Games\Shortcuts
```

## Полный пример конфига

```text
shortcutsDir=C:\Games\Shortcuts
startHidden=false
maxColumns=3

game=Game|Game.lnk|game.png|GAME DESCRIPTION
game=SnowRunner|SnowRunner.url|snowrunner.png|SNOWRUNNER
game=SnowRunner URI|steam://rungameid/1465360|snowrunner.png|SNOWRUNNER
```

## Формат строки игры

```text
game=Title|Shortcut|Image|Description|Accent|Id
```

Обязательные поля:

- `Title` - заголовок карточки.
- `Shortcut` - `.lnk`, `.url`, абсолютный путь или прямой URI запуска.
- `Image` - имя файла из `user-assets/` или поддерживаемый явный путь.

Необязательные поля:

- `Description` - текст снизу карточки. При наведении заменяется на `LAUNCH  >`.
- `Accent` - цвет hover-рамки и нижней линии, например `#74DFFF`.
- `Id` - внутренний id. Если не указан, создаётся из `Title`.

Примеры:

```text
game=Game|Game.lnk|game.png|GAME DESCRIPTION
game=SnowRunner|SnowRunner.url|snowrunner.png|SNOWRUNNER
game=SnowRunner|steam://rungameid/1465360|snowrunner.png|SNOWRUNNER
```

Если `Shortcut` равен `Game`, виджет добавит `.lnk` и запустит `Game.lnk`.
Если значение уже заканчивается на `.lnk`, заканчивается на `.url` или является
прямым URI вроде `steam://rungameid/1465360`, оно остаётся без изменений.

## Изображения

Обычно картинки игр нужно класть сюда:

```text
saou.games.menu/user-assets/
```

В конфиге указывай только имя файла:

```text
game=Game|Game.lnk|game.png|GAME DESCRIPTION
```

Будет использован файл:

```text
saou.games.menu/user-assets/game.png
```

Если изображения нет, путь неверный или Qt не смог загрузить файл, карточка
использует fallback:

```text
saou.games.menu/assets/placeholder.png
```

## Настройки

- `shortcutsDir` - папка с ярлыками игр. Относительные имена ярлыков ищутся в
  этой папке.
- `startHidden=true` - просит настроенное Close Action скрыть Games Menu после
  запуска SAO Utils.
- `maxColumns` - максимум карточек в одной строке. Фактическое число может быть
  меньше, если виджет узкий.

## Обновление

Перед заменой файлов из нового release ZIP сохрани пользовательские данные:

- `saou.games.menu/config.txt`, если ты редактировал его напрямую.
- `saou.games.menu/config.local.txt`, если ты его создал.
- `saou.games.menu/user-assets/`, потому что там лежат твои изображения игр.

После этого замени файлы пакета из нового release ZIP. Проект не сохраняет
перезаписанные файлы автоматически при ручном обновлении, поэтому копию своих
файлов нужно держать отдельно до замены папки.

## Решение проблем

### Крестик ничего не делает

Настрой действие закрытия:

```text
ПКМ по Games Menu -> Close Action... -> Widget / Виджет -> Hide Widget / Скрыть виджет -> Games Menu
```

### Steam-игра не запускается

Проверь имя `.url` файла в `shortcutsDir` или используй прямой Steam URI:

```text
game=SnowRunner|steam://rungameid/1465360|snowrunner.png|SNOWRUNNER
```

### Изображение не отображается

Проверь, что файл лежит в `saou.games.menu/user-assets/`, а имя в `config.txt`
совпадает полностью. Простые имена файлов автоматически ищутся внутри
`user-assets/`.

### Ярлык игры не найден

Проверь `shortcutsDir` и имя файла ярлыка. `.lnk` добавляется только если не
указано расширение или launch URI. `.url` и `steam://...` остаются без
изменений.

## Лицензия

Исходный код проекта распространяется под MIT License. См. `LICENSE`.

Репозиторные assets, пользовательские изображения, названия игр, торговые марки
и интеллектуальная собственность издателей не становятся автоматически частью
MIT-лицензии. См. `ASSETS_NOTICE.md`.
