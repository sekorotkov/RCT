# RCT (Right Click Tools) for Updates

## How it looks

- Updates required for members:

![Updates required for members](screenshots/rct-01.png?raw=true "Updates required for the computer")

- Update compliance status:

![Update compliance status](screenshots/rct-03.png?raw=true "Update compliance status")

- Create SUG for Collection:

![Create SUG for Collection](screenshots/rct-04.png?raw=true "Create SUG for Collection")

# RCT (Right Click Tools) для работы с обновлениями

- New-RCTSUGByCollection
- Get-RCTUpdateSystemCompliance
- Remove-RCTUpdateFromSUG
- Get-RCTSUCompliance

## New-RCTSUGByCollection

Создаёт Группу обновлений (SUG), которые требуются на членах коллекции устройств. Выбираем группу, правой кнопкой / "Create SUG for Collection"

В группу не входят обновления из категории "Upgrades"

Формат имени для SUG можно задать параметром "-SUGNameTemplate [String]". Вместо {0},{1}…{5} подставляется, соответственно — Год / Месяц / Число / час / минута / секунда.

## Get-RCTUpdateSystemCompliance

Показывает состояние "Required" / "Installed" для конкретного обновления

Скрипт может выводит статус в результирующей таблице в двух режимах:

- Звёздочкой для каждого из состояний

- Один столбец с текстом Required / Installed.

Для включения второго режима добавьте параметр "-StatusInOneColumn" в вызов скрипта в xml файлах.

## Remove-RCTUpdateFromSUG

Удаляет выбранное обновление из всех SUG (Software Update Group).

При выделении папки (контейнера) с обновлениями, удаляет все обновления находящиеся в папке из всех SUG.

## Get-RCTSUCompliance

Показывает обновления требуемые для членов выбранной коллекции устройств.

В список не входят обновления из категории "Upgrades". По умолчанию исключаются обновления с Custom Severity ([-ExcludeCustomSeverity])

## Как установить

Скачиваем ZIP-файл. Разблокируем файл архива – Свойства / Разблокировать.

Распаковываем архив. Запускаем "install.bat" с повышением прав ("Запуск от имени администратора"). Батник скопирует файлы в папку с консолью и покажет результат.

Перезапускаем консоль — пользуемся.

Happy updates!
