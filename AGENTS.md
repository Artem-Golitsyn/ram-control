# AGENTS.md — RAM Control

Документ для ИИ-разработки. Это источник правды по технической части. Пользовательская инструкция — `README.md`. Не откатывай формулы памяти, локализацию и ограничения платформы «для простоты».

## Продукт

- Отображаемое имя: **RAM Control**
- Каталог репозитория: `RamControl-app`
- Xcode-проект: `RAMControl.xcodeproj`
- Таргет и схема: `RAMControl`
- Модуль Swift: `RAMControl` (`PRODUCT_MODULE_NAME`). Пробел в имени модуля запрещён.
- Продукт: `RAM Control.app` (`PRODUCT_NAME` = `RAM Control`)
- Исполняемый файл: `RAM Control.app/Contents/MacOS/RAM Control`
- Bundle ID: `app.ramcontrol.RAMControl`
- Тесты: таргет `RAMControlTests`, bundle ID `app.ramcontrol.RAMControlTests`, `@testable import RAMControl`
- Версия: `MARKETING_VERSION` 1.3, `CURRENT_PROJECT_VERSION` 1
- Категория: `public.app-category.utilities`

Это агент меню-бара, не обычное приложение с окном и Dock.

## Платформа

- macOS 14.0+ (`MACOSX_DEPLOYMENT_TARGET`, `INFOPLIST_KEY_LSMinimumSystemVersion`)
- Только arm64. `ARCHS = arm64`, `EXCLUDED_ARCHS = x86_64`, `ONLY_ACTIVE_ARCH = NO`
- Swift 6.0, `SWIFT_STRICT_CONCURRENCY = complete`
- SwiftUI, AppKit точечно (`NSApplication`, `NSWorkspace`, окна настроек)
- App Sandbox **выключен** (`ENABLE_APP_SANDBOX = NO`). Не включай его и не добавляй entitlements: `host_statistics64` и `SMAppService.mainApp` вызываются напрямую
- Подпись локальной сборки: `CODE_SIGNING_ALLOWED=NO` в `xcodebuild`, затем `codesign --force --sign -`
- `LSUIElement = YES`
- В `AppDelegate.applicationDidFinishLaunching` обязательно `NSApp.setActivationPolicy(.accessory)`
- `applicationShouldTerminateAfterLastWindowClosed` возвращает `false`
- Сторонние пакеты, CocoaPods, SPM-зависимости, серверы и shell ради статистики RAM запрещены

## Дерево исходников

Группы в проекте — `PBXFileSystemSynchronizedRootGroup`. Новый `.swift` в `RAMControl/` или `RAMControlTests/` подхватывается без правки `project.pbxproj`.

```text
RAMControl/
├── App/
│   ├── RAMControlApp.swift      # @main, MenuBarExtra(.window) + Settings
│   └── AppDelegate.swift
├── Models/
│   ├── MemoryStats.swift        # MemorySampleInput, MemoryStats, MemoryPressureState
│   ├── MemoryThresholds.swift   # пороги и ThresholdCommit
│   └── MemoryHistory.swift      # HistoryWindow, кольцо замеров, полосы графика
├── Services/
│   ├── MemoryMonitor.swift      # единственные Mach/sysctl вызовы
│   ├── MemoryCalculator.swift   # чистая математика
│   └── LaunchAtLoginManager.swift
├── ViewModels/
│   └── MemoryViewModel.swift    # один цикл обновления, UserDefaults
├── Views/
│   ├── MenuBarLabel.swift
│   ├── MemoryPopoverView.swift
│   ├── MemoryUsageBar.swift
│   ├── MemoryHistoryChart.swift # линия 1px, цвет замера заморожен, сетка 5×мин/макс
│   ├── PressureStyle.swift
│   └── SettingsView.swift
├── Utilities/
│   ├── ByteFormatter.swift      # GB/GiB и RefreshInterval
│   ├── Constants.swift
│   └── Localization.swift       # AppLanguage и L10n
└── Resources/Assets.xcassets/
    ├── AccentColor.colorset
    └── AppIcon.appiconset
RAMControlTests/
├── MemoryCalculatorTests.swift
├── ByteFormatterTests.swift
└── MemoryHistoryTests.swift
icon.png                         # мастер иконки, 1254×1254
build.sh
README.md
AGENTS.md
```

`build/` и `dist/` в `.gitignore`. В git их не класть.

## Сборка, тесты, релиз

```bash
./build.sh
xcodebuild -project RAMControl.xcodeproj -scheme RAMControl \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/TestDerivedData \
  test CODE_SIGNING_ALLOWED=NO ENABLE_APP_SANDBOX=NO
```

`build.sh` печатает абсолютный путь к `RAM Control.app` и завершается с ненулевым кодом при ошибке (`set -euo pipefail`).

Релизный архив: `dist/RAM-Control-1.3.zip`. В корне zip лежит `RAM Control.app`, не каталог `dist`. Собирать через `ditto -c -k --keepParent`, чтобы сохранить подпись и симлинки.

`TEST_HOST` содержит пробелы:

```text
$(BUILT_PRODUCTS_DIR)/RAM Control.app/Contents/MacOS/RAM Control
```

Схему `RAMControl` не переименовывай в имя с пробелом: `xcodebuild -scheme` должен оставаться `RAMControl`. `BuildableName` схемы — `RAM Control.app`.

## Интерфейс

Две сцены и ничего больше:

1. `MenuBarExtra` со стилем `.window`. Метка — только доступная память, один знак после точки и единица: `18.4 GB` или `18.4 GiB`. При ошибке или `total == 0` — «—», не ноль и не выдуманное число. Цвет метки не настраивается: это обычный цвет текста меню.
2. `Settings`. Открытие: кнопка в панели активирует приложение, вызывает `openSettings()`, затем `SettingsWindowOpener.orderFront()`, потому что accessory-приложение иначе не выводит окно настроек на передний план.

Панель (`Constants.popoverWidth` = 300):

- заголовок Memory / Память и бейдж состояния. Цвет бейджа совпадает с цветом полосы
- крупно Available и числа строк от Available до Swap всегда `PressureStyle.valueColor` (`NSColor.systemGray`). Переключателя цвета нет
- строка Physical RAM
- `MemoryUsageBar`: доля Used. Цвет полосы всегда палитра состояния; при отсутствии данных — `accentColor`
- подписи Used и Available
- `MemoryHistoryChart`, если график включён. Время горизонтальное: правый край — сейчас, история заполняется влево. Высота — занятые байты, шкала от минимума до максимума видимых замеров. Линия толщиной 1 pt, без заливки. `MemoryGraphBlend` записывается в замер в момент чтения и больше не пересчитывается, в том числе после смены порогов. Между соседними замороженными цветами переход остаётся градиентом. Пауза длиннее `maxConnectionGap` (20 с) разрывает линию. Сетка серым пунктиром: 5 вертикальных линий на возрастах `window/5 … window` с подписью длительности, две горизонтальные — минимум и максимум занятой памяти. Окно 1 / 3 / 5 / 10 минут, по умолчанию 5
- строки Available, Used, Active, Inactive, Wired, Compressed, Purgeable, Swap Used
- Settings… и Quit (`terminate`)

Строки «Обновлено» на панели нет. Настроек «Цветовая индикация» и «Цвет значений памяти» нет.

Цвет полосы и бейджа (`PressureStyle.panelColor`):

| Состояние | Условие | Цвет |
|---|---|---|
| `.normal` | `available / total > warning` | `NSColor.systemGray` |
| `.warning` | `available / total > critical` | `.yellow` |
| `.critical` | иначе | `.red` |
| `.unavailable` | нет данных, `total == 0` или пороги невалидны | бейдж `.primary`, полоса `accentColor` |

Сравнение долей — целочисленное `numerator * 100 > denominator * percent` (`MemoryCalculator.ratioGreaterThan`). При переполнении — `Double`. Деления на ноль нет. Граница не входит в более спокойную зону: ровно 30% при warning 30 — это Warning, не Normal.

Настройки, ширина `Constants.settingsWidth` = 520:

- Кнопка Reset Settings стоит в правом верхнем углу содержимого (`safeAreaInset` сверху). Подсказки под ней нет
- General: автозапуск, интервал 0.2 / 0.5 / 1 / 2 / 5 / 10 с
- Appearance: язык, GB или GiB, показ графика, период графика. Период недоступен, пока график выключен. Цветовой индикации и цвета значений в настройках нет
- Memory Thresholds: Warning по умолчанию 30, Critical 15. Оба в 1...99, critical строго меньше warning. Невалидная пара не сохраняется. Кламп 1...99 даёт `.savedClamped`, нарушение порядка — `.rejected`
- About, две строки и ничего больше:
  - EN: `Version: RAM Control version [CFBundleShortVersionString]`
  - RU: `Версия: RAM Control версия [CFBundleShortVersionString]`
  - EN: `Author: Голицын Артем (2026)`
  - RU: `Автор: Голицын Артем (2026)`
- Reset Settings сбрасывает интервал, график, период графика, единицы, язык и пороги. Автозапуск не трогает. История графика в памяти не стирается: это не настройка
- Отдельной нижней секции с автором нет. Имя автора — `L10n.authorCredit` = `Голицын Артем (2026)`. Не переводить и не транслитерировать. Подписи Author / Автор локализуются вокруг этой константы

## Локализация

Язык по умолчанию — английский (`AppLanguage.english`, raw `en`). Русский — `ru`. Имена в пикере всегда `English` и `Русский`.

Не заводи `Localizable.strings` и не включай `SWIFT_EMIT_LOC_STRINGS`. Все пользовательские строки идут через `L10n.text` / узкие хелперы в `Localization.swift`. Новая строка:

1. Кейс в `L10nKey`.
2. Ветки `english` и `russian`.
3. Вызов из View с `viewModel.language`, чтобы `@Observable` перерисовал экран.

`MemoryPressureState.title(language:)`, `RefreshInterval.label(language:)` и `HistoryWindow.label(language:)` без языка не существуют. Сообщения порогов — `ThresholdNotice`, не готовая английская строка. Ошибки монитора и автозапуска показываются через `userMessage(language:)`. `errorDescription` оставлен английским для логов.

`strerror` / `mach_error_string` не переводятся. Локализуется только обёртка.

Единицы `GB` и `GiB` не переводятся: это символы `MemoryUnit`. Подписи интервала 0.2 и 0.5 всегда с точкой, не с запятой.

## UserDefaults

Регистрация дефолтов — `Constants.registerDefaults`. Сброс удаляет ключи из `DefaultsKey.all` и выставляет свойства заново.

| Ключ | Свойство | По умолчанию |
|---|---|---|
| `refreshIntervalSeconds` | `refreshInterval` | `1000` (1 с). В файле — миллисекунды. Старые `1`, `2`, `5`, `10` читаются как секунды |
| `memoryUnit` | `unit` | `GB` |
| `warningThresholdPercent` | `thresholds.warningPercent` | `30` |
| `criticalThresholdPercent` | `thresholds.criticalPercent` | `15` |
| `appLanguage` | `language` | `en` |
| `memoryGraphEnabled` | `historyGraphEnabled` | `true` |
| `memoryGraphMinutes` | `historyWindow` | `5` |

`didStart` закрывает запись в `init`, иначе `didSet` затрёт загруженные значения. Автозапуск в UserDefaults не дублируется: источник истины — `SMAppService.mainApp.status == .enabled`.

## Память

`MemoryMonitor.readSample()` — единственная точка `sysctlbyname`, `host_page_size`, `host_statistics64`, `sysctl(VM_SWAPUSAGE)`. Она `nonisolated` и вызывается из `Task.detached`. Ошибка — `Result.failure`, статистика обнуляется, в UI не остаётся прошлое значение как будто оно свежее (`stats = nil`).

Источники:

| Величина | Источник |
|---|---|
| Total | `sysctlbyname("hw.memsize")` |
| Размер страницы | `host_page_size(mach_host_self())`. `0` — ошибка |
| free, active, inactive, wire, purgeable, speculative, compressor, internal, external | `vm_statistics64` через `HOST_VM_INFO64` |
| Swap Used | `xsw_usage.xsu_used` из MIB `{CTL_VM, VM_SWAPUSAGE}` |

`HOST_VM_INFO64_COUNT` Swift не импортирует. Счётчик элементов: `MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride`.

`swapped_count` и `swap_count` в этой структуре — счётчики страниц, не байты. В UI их не подставлять вместо `xsu_used`.

`speculative_count` уже входит в `free_count`. К free его не прибавлять. В калькуляторе speculative и external намеренно читаются и отбрасываются (`_ = (...)`), чтобы формула не «улучшилась» обратно в наивную сумму.

`purgeable_count` не отдельный пул. Сумма `free + inactive + purgeable` дважды считает страницы и может дать Available больше Total.

Формула в `MemoryCalculator.makeStats`:

```text
appPages        = max(0, internal_page_count - purgeable_count)
appMemory       = appPages * pageSize
wired           = wire_count * pageSize
compressed      = compressor_page_count * pageSize
occupied        = appMemory + wired + compressed     # насыщающее сложение
used            = min(total, occupied)
available       = total - used                       # насыщающее вычитание
```

`used` в модели всегда равен `total - available`. Active, Inactive, Wired, Compressed и Purgeable в Used не складываются: это сырые строки панели. Compressed — футпринт `compressor_page_count`, не `total_uncompressed_pages_in_compressor`.

`pagesToBytes` возвращает `nil` при `pageSize == 0` и `UInt64.max` при переполнении. Отрицательных значений нет: типы беззнаковые, вычитание зажимается в 0.

Логи пишутся в stderr и `Logger(subsystem: "app.ramcontrol.RAMControl", category: "Memory")` только когда текст изменился.

## Цикл обновления

Один `Task` в `RefreshTaskStore`. `replace` отменяет предыдущий под `NSLock`. Второй таймер не создавать. `Timer.publish` не использовать.

Интервал читается в момент `restartMonitoring()`. Смена интервала отменяет цикл и запускает один новый. Сон не порождает новый цикл: `Task.sleep` приостанавливается системой, а `SystemEventBridge` на `NSWorkspace.didWakeNotification` и `screensDidWakeNotification` вызывает один `refreshNow()`. `willTerminate` останавливает цикл.

`refreshNow` увеличивает `refreshGeneration`. Результат применяется, только если поколение совпало и задача не отменена. Присвоение `stats` происходит на `@MainActor`.

Успешный замер с `total > 0` дописывается в `MemoryHistory` на том же цикле. Второго таймера для графика нет. Буфер только в памяти, не в UserDefaults: хранение 10 минут, потолок `MemoryHistory.maxSamples`. Ошибка чтения и `total == 0` точку не добавляют и не рисуют нули. `visibleSamples` отдаёт замеры окна как есть, от старых к новым. Значение уже нарисованной точки не заменяется более новым замером.

`MemoryViewModel` — `@MainActor` и `@Observable`. `RefreshTaskStore` и `SystemEventBridge` — `@unchecked Sendable` с `NSLock`, потому что обработчики уведомлений приходят не из Swift Concurrency.

## Автозапуск

`LaunchAtLoginManager` на главном акторе. `SMAppService.mainApp.register()` / `unregister()`. Если статус уже `.enabled`, повторный `register` не вызывается. `.notRegistered` и `.notFound` при выключении — успех. После `register` статусы `.requiresApproval`, `.notFound` и `.notRegistered` становятся `LaunchAtLoginError` и показываются в настройках.

Регистрация из DerivedData обычно падает. Это не баг формулы. Для проверки нужна копия в `/Applications`.

## Иконка

Мастер — корневой `icon.png`. В бандл попадает набор в `RAMControl/Resources/Assets.xcassets/AppIcon.appiconset`. В обоих конфигурациях таргета задано `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`.

После замены `icon.png` перегенерируй размеры:

```bash
DIR="RAMControl/Resources/Assets.xcassets/AppIcon.appiconset"
sips -z 16 16 icon.png --out "$DIR/icon_16x16.png"
sips -z 32 32 icon.png --out "$DIR/icon_16x16@2x.png"
sips -z 32 32 icon.png --out "$DIR/icon_32x32.png"
sips -z 64 64 icon.png --out "$DIR/icon_32x32@2x.png"
sips -z 128 128 icon.png --out "$DIR/icon_128x128.png"
sips -z 256 256 icon.png --out "$DIR/icon_128x128@2x.png"
sips -z 256 256 icon.png --out "$DIR/icon_256x256.png"
sips -z 512 512 icon.png --out "$DIR/icon_256x256@2x.png"
sips -z 512 512 icon.png --out "$DIR/icon_512x512.png"
sips -z 1024 1024 icon.png --out "$DIR/icon_512x512@2x.png"
```

В метку меню-бара иконку не добавлять: там только текст доступной памяти.

## Формат байтов

`ByteFormatter.string` всегда даёт ровно один знак после точки и точку, не запятую. GB — делитель `1_000_000_000`, GiB — `1_073_741_824`. Округление half away from zero на первом знаке, целочисленно, через `roundedTenths`. Менять это на `String(format:)` или `Measurement` нельзя: тесты фиксируют границы `1.0` / `1.1` и `UInt64.max`.

## Тесты

Живая машина не является оракулом. `MemoryCalculator` и `ByteFormatter` проверяются синтетическими `MemorySampleInput`.

Обязательные случаи, которые нельзя ослабить:

- страницы 16384 и 4096
- `pageSize == 0` → `nil`
- насыщение умножения
- Available по формуле Activity Monitor, speculative не увеличивает Available
- `purgeable > internal` обнуляет app memory
- `used == total - available` и `available <= total`
- пороги: выше warning, между critical и warning, ниже critical, ровно на границе, `total == 0`, невалидная пара не выбирает полосу
- GB/GiB, ноль, малые значения, точка как разделитель
- интервал: миллисекунды `200/500/1000/2000/5000/10000` и старые секунды `1/2/5/10`; подписи `0.2 seconds` и `0.2 секунды`
- график: замеры окна сохраняют `usedBytes` и записанный `blend`, идут слева направо, сейчас — правый край (`horizontalPosition` 1), край окна — левый (0), шкала высоты от минимума к максимуму, плоский ряд в середине, пауза больше 20 с рвёт линию, пять вертикальных делений `window/5 … window`, подписи `1 min` / `5 мин` / `12 с`, цвет в середине между critical и warning жёлтый, на critical и ниже красный, на warning и выше серый, буфер старше 10 минут и будущее дальше 2 секунд выкидываются
- язык по умолчанию `en`, `ru` отдаёт «Память», `L10n.authorCredit` равен `Голицын Артем (2026)`, русская строка автора — `Автор: Голицын Артем (2026)`, русская строка версии — `Версия: RAM Control версия [версия]`

## Чего не делать

- Не вызывать `vm_stat`, `top`, `memory_pressure`, `sysctl` через `Process`
- Не суммировать Active + Inactive + Wired + Compressed в Used
- Не прибавлять `speculative_count` к free и весь `purgeable_count` к Available
- Не показывать нули, если системный вызов вернул ошибку
- Не запускать второй цикл обновления из панели, настроек или обработчика сна
- Не блокировать MainActor вызовом Mach
- Не включать sandbox и не добавлять сеть
- Не возвращать иконку в Dock
- Не хардкодить английский в `Text("...")` для новых строк интерфейса
- Не менять `L10n.authorCredit`: байт в байт `Голицын Артем (2026)`
- Не подменять bundle id без причины: автозапуск и настройки привязаны к `app.ramcontrol.RAMControl`
