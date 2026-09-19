# Windows Terminal Layout Fix

Приватная резервная копия исправленного **Windows Terminal Preview 1.25.1912.0,
Windows x64**: готовая portable-сборка, рабочие настройки и исходный патч.

**Владелец подтвердил 15.09.2026:** переключение RU/EN работает без прежних
зависаний с десятью вкладками; после настройки работает восстановление вкладок.
Это проверка на текущем компьютере, а не подтверждённая установка на чистую Windows.

**19.09.2026:** отдельно собран кандидат с Ctrl+V для снимков из буфера.
Он открыт как `WT-PASTE-TEST`; ручная проверка Codex/Claude ещё ожидается.
Рабочая сборка и опубликованный `layout-fix.1` пока остаются прежними.
Путь, поведение и проверки кандидата — ниже, в разделе про снимки.

Текущие настройки: [settings/settings.json](settings/settings.json).
Переход на следующий официальный релиз, перенос патча, сборка, проверка и откат:
[UPDATING.md](UPDATING.md). Патч C++, конфиг Terminal и обход ввода Codex в HCA
обновляются отдельно; новый официальный EXE сам наш патч не подхватит.

Правила работы агентов: [AGENTS.md](AGENTS.md). `CLAUDE.md` импортирует тот же
guide; отдельной копии правил для Claude нет.

## Быстро восстановить на другой Windows

1. Войти в GitHub под аккаунтом с доступом к этому приватному репозиторию.
2. Открыть [релиз layout-fix.1](https://github.com/pavelbe/windows-terminal-layout-fix/releases/tag/v1.25.1912.0-layout-fix.1).
   Скачать **WT-Layout-Fix-1.25.1912.0-win-x64.zip** и одноимённый **.zip.sha256**
   в папку «Загрузки». GitHub-файл «Source code (zip)» не содержит готовую программу.
   Также скачать актуальный [settings/settings.json](settings/settings.json)
   через **Download raw file** как `Downloads\WT-Layout-Fix-settings.json`.
   В старом ZIP нет последующих настроек Ctrl+N и Ctrl/Shift+Enter.
3. В обычном Windows PowerShell выполнить:

```powershell
$ErrorActionPreference = 'Stop'
$zip = Join-Path $env:USERPROFILE 'Downloads\WT-Layout-Fix-1.25.1912.0-win-x64.zip'
$config = Join-Path $env:USERPROFILE 'Downloads\WT-Layout-Fix-settings.json'
$null = Get-Content -LiteralPath $config -Raw -Encoding UTF8 | ConvertFrom-Json
$expected = ((Get-Content -LiteralPath ($zip + '.sha256') -Raw).Trim() -split '\s+')[0]
if ($expected -notmatch '^[a-fA-F0-9]{64}$') { throw 'Invalid checksum file' }
if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash -ine $expected) {
    throw 'Archive checksum mismatch'
}
$programs = Join-Path $env:LOCALAPPDATA 'Programs'
$terminal = Join-Path $programs 'WT-Layout-Fix-1.25.1912.0'
if (Test-Path -LiteralPath $terminal) {
    throw 'Destination already exists; keep it and extract this archive into a different folder'
}
Expand-Archive -LiteralPath $zip -DestinationPath $programs -ErrorAction Stop
Copy-Item -LiteralPath $config -Destination (Join-Path $terminal 'settings\settings.json')
& (Join-Path $terminal 'WindowsTerminal.exe')
```

4. Закрепить **это открытое окно** в панели задач. Запускать его ярлыком, без
   старого диагностического скрипта с десятью вкладками.
5. Проверить кнопку **+**, разделение панели, RU/EN с 10 вкладками и восстановление.

Распаковка в свой `%LOCALAPPDATA%` не требует регистрации MSIX. Portable-копия
не заменяет Store/Preview; системный выбор default terminal доступен packaged-версии,
а portable запускается своим EXE/ярлыком и командами HCA.
См. [типы поставки Microsoft](https://learn.microsoft.com/en-us/windows/terminal/distributions).
Это сборка x64; проверенная система — Windows 11, build 22631.6199.
Перенос на другую версию Windows ещё не проверен.

Если Windows сообщает об отсутствующем `VCRUNTIME140*.dll` или `MSVCP140*.dll`,
установить официальный [Microsoft Visual C++ Redistributable x64](https://aka.ms/vs/17/release/vc_redist.x64.exe).
Не скачивать отдельные DLL со случайных сайтов. Cascadia Code 11 можно установить
из [официального проекта шрифта](https://github.com/microsoft/cascadia-code), если
его нет в новой Windows; отсутствие шрифта и отсутствие runtime — разные случаи.

## Что переносится и что нужно отдельно

В архиве есть EXE/DLL, XAML/PRI-ресурсы, `.portable`, лицензия, патч, README,
исходный build receipt и **только** `settings/settings.json` из пользовательских данных.
Оригинальные runtime-файлы сверены с хешами receipt; полная ведомость архива находится
в [build/recovery-manifest.json](build/recovery-manifest.json).

**Ubuntu/WSL, проекты, HCA, Claude/Codex, авторизация и история сессий не входят.**
До замены системы их нужно сохранить отдельно. Конфиг ожидает дистрибутив с именем
`Ubuntu`; проверить его можно командой `wsl --list --verbose`. Если дистрибутива ещё
нет, временно открыть CMD через меню рядом с **+**. Не запускать `wsl --install`
поверх ожидаемого восстановления старого дистрибутива без отдельного плана.

На новой системе первая загрузка не восстановит старые вкладки: личный `state.json`
и экранные буферы намеренно не публикуются. Новые сеансы будут сохраняться после
обычного выхода. Сам файл настроек не восстанавливает процессы агентов.

Команды HCA `wt`, `atreno`, `wtc`, `wtd`, `wtw`, `wtp` и `wth` поддерживают эту
portable-копию. После восстановления HCA с коммитом `2b0e916` или новее в `config/workspaces.yaml`
должно быть `settings.windows_terminal_channel: "layout-fix"`. В свободной Zsh:

```zsh
source ~/.zshrc
wt-doctor
```

Doctor должен показать канал `layout-fix`, EXE в `Programs/WT-Layout-Fix-1.25.1912.0`
и конфиг `settings/settings.json` рядом с ним. Проект без числа открывает одну
новую вкладку с одной панелью в последнем активном окне этой сборки. Разделение
включается явным числом; именованные наборы сохраняют свою раскладку.
Перезагрузка Windows/WSL не нужна. Если файлы сборки отсутствуют, HCA завершает
команду с ошибкой, не переключаясь на установленный Preview или Stable.

При дублировании кириллицы в Codex 0.154.0 подтверждён отдельный обход:
`CODEX_TUI_DISABLE_KEYBOARD_ENHANCEMENT=1 codex`. Актуальный HCA применяет его
автоматически для `codex`/`cxr` внутри Windows Terminal/WSL. Владелец проверил
обычный запуск после `source ~/.zshrc`: набор, вставка и перенос строки работают.
Обход действует только на запускаемый Codex, включая `codex resume`; уже
работающие процессы и Claude он не меняет. Исходник маршрута —
`~/hca-system-v3/modules/zsh/claude/55-ai-ip-guard.zsh`.
Этот обход находится в HCA, а не в бинарном патче Terminal. На другой версии
Codex/Terminal повторите проверку кириллицы и Ctrl/Shift+Enter.

Эти уточнения дополняют README внутри первоначального ZIP `layout-fix.1`.
Сам архив и его SHA256 не изменялись; конфиг в Git новее архивного. При переносе используйте эту
актуальную инструкцию вместе с [runbook HCA](https://github.com/pavelbe/hca-system-v3/blob/main/docs/04-commands/windows-terminal-tabs-panels.md).

## Цифровая десятичная клавиша и снимки из буфера

В профиле Ubuntu с 16.09.2026 установлено
`"compatibility.kittyKeyboardMode": false`. В локальном Claude 2.1.273
обработчик Kitty-кода `57409` возвращает точку без учёта раскладки. Профиль
теперь использует обычный ввод; ожидается запятая в RU и точка в EN.
Это настройка профиля, а не изменение EXE или бинарного файла Claude.
Привязки Ctrl/Shift+Enter к LF и прежний обход Codex в HCA сохранены.
Владелец подтвердил: в Claude цифровая клавиша теперь даёт запятую в RU
и точку в EN.

Для снимка через PrintScreen/«Ножницы» в буфере находится изображение; копирование файла
в Explorer передаёт другой формат. Terminal отправляет пустую bracketed paste,
если текста/файла нет, после чего приложение может прочитать изображение само.
На этом ПК восстановлен отсутствовавший обработчик WSLInterop: до исправления
`powershell.exe` из WSL возвращал `Exec format error`, хотя запуск через `/init`
работал. После исправления обычный PowerShell и локальные `xclip`/`wl-paste`
снова читают форматы Windows clipboard. Владелец подтвердил вставку снимка
в Claude через Ctrl+V. В Codex 0.154.0 Ctrl+V ещё не вставляет снимок: Terminal
перехватывает сочетание и отправляет пустую вставку, а Codex не обрабатывает
её как запрос изображения. Его штатный image-paste обрабатывает Ctrl+V/Alt+V
как клавиатурное событие. Владелец сообщил, что Alt+V тоже не помог.
При отдельном чтении его снимка 1320×176 из WSL Windows успешно вернула PNG;
сам PrintScreen и доступ к изображению были подтверждены.
Перезапуск WSL/Terminal и агентских сессий не выполнялся.
Повторную диагностику interop вести по
[runbook HCA](https://github.com/pavelbe/hca-system-v3/blob/main/docs/04-commands/windows-terminal-tabs-panels.md#восстановление-interop-windows-11).

### Кандидат с универсальным Ctrl+V

Папка: `%LOCALAPPDATA%\Programs\WT-Layout-Fix-1.25.1912.0-clipboard-test`.
Запуск из Windows PowerShell:

```powershell
& "$env:LOCALAPPDATA\Programs\WT-Layout-Fix-1.25.1912.0-clipboard-test\WindowsTerminal.exe" -w new new-tab -p Ubuntu --title WT-PASTE-TEST --suppressApplicationTitle
```

В этой сборке текст и файл из Explorer проходят прежним путём. Если текста/пути
нет, а в буфере есть bitmap, Terminal копирует пиксели, освобождает буфер,
сохраняет PNG в `%TEMP%\wt-clipboard-{GUID}.png` и вставляет Windows-путь через
обычный механизм paste. Codex умеет преобразовывать такой путь в WSL и прикреплять
изображение. Снимок не заменяет содержимое системного буфера; сохранение выполняется
в фоне. Новое имя создаётся эксклюзивно, неполный файл при ошибке удаляется.
PNG остаётся после выхода из Terminal, чтобы приложение успело его прочитать;
старые снимки можно удалять из Temp после завершения работы с вложениями.
Это локальные пользовательские файлы, они не входят в Git/релиз.

Патч [clipboard-image-paste.patch](patches/clipboard-image-paste.patch) применяется
**после** `layout-fix.patch`; исходный commit `2d4c28b013b21280ca5978259ff1313dab716c6c`.
Сборка Release/x64 прошла: 0 ошибок, 72 предупреждения упаковки/ресурсов.
Native smoke проверил PNG roundtrip, пиксели/ориентацию, lifetime снимка,
повторную вставку и отказ записи. Это проверка helper, не автоматический тест
Ctrl+V в TUI; автоматический regression RED не воспроизведён.
Состав и хеши: [build/clipboard-candidate-20260919.json](build/clipboard-candidate-20260919.json).
Процесс и загруженная `TerminalApp.dll` проверены именно в папке кандидата.

Ручная приёмка: в `WT-PASTE-TEST` запустить обычный `codex`, сделать новый снимок
PrintScreen и нажать Ctrl+V; отдельно проверить текст и файл из Explorer. Повторить
в Claude, затем проверить RU/EN с десятью вкладками. **Результат пока ожидается.**
Кандидат не назначен рабочим: ярлык и команды HCA ведут в прежнюю папку.
Готовый ZIP нового кандидата пока не опубликован; исторический архив не изменён.

## Рабочие настройки

| Настройка | Поведение |
| --- | --- |
| Профиль по умолчанию | Ubuntu, `wsl.exe -d Ubuntu`, каталог `~` |
| `firstWindowPreference` | `persistedLayoutAndContent`: раскладка и вывод |
| `windowingBehavior` | `useAnyExisting`: повторное использование окна |
| Шрифт | Cascadia Code 11, ClearType |
| История вывода | штатные 9001 строк; старые 50000 не перенесены |
| Анимации, автоматические URL, bell | отключены |
| Копирование | обычный текст без форматирования |
| `Ctrl+C`, `Ctrl+V`, `Alt+Shift+D` | прежние привязки копирования, вставки, разделения |
| `Ctrl+W` | закрыть всю вкладку вместе с её панелями; Terminal перехватывает сочетание у приложения |
| `Ctrl+N` | новая вкладка профиля по умолчанию (Ubuntu), как кнопка **+** |
| `Ctrl+Enter`, `Shift+Enter` | `User.AgentNewline`: отправить LF (`\n`) приложению |
| `Ctrl+Shift+F`, `Ctrl+Shift+P` | стандартные поиск и палитра команд |

`Ctrl+Shift+Period` освобождён от подсказок Terminal, как в прежнем Preview.
Обычный Enter и Delete/Home/End в этом JSON не переназначены. Ctrl/Shift+Enter
отправляют LF; реакцию определяет приложение: в обычной оболочке это может
выполнить команду. Владелец подтвердил новую строку обоими сочетаниями в
Codex и Claude; это отдельная проверка от обхода дублирования кириллицы.
Сохранены работающие привязки, а не возвращены прежние defaults.
Ctrl+N/Ctrl+W перехватывает Terminal; проверки конфига пройдены, отдельного
подтверждения ручного нажатия этих двух сочетаний пока нет. Проверять на пустой
вкладке; `warning.confirmCloseAllTabs=false` отключает вопрос при закрытии окна.
Названия существующих профилей других WSL-дистрибутивов сохранены; их присутствие
в JSON не означает, что сами дистрибутивы перенесены.

Для восстановления одного окна закрывать **окно с нужными вкладками**, а не вкладки
по одной. Для нескольких окон использовать **Quit / Выход** в `Ctrl+Shift+P`.
Сначала сохранить работу и завершить агентов. Восстанавливаются панели и вывод,
но не живые программы.

## Исходный код и границы проверки

- Upstream: [microsoft/terminal, v1.25.1912.0](https://github.com/microsoft/terminal/tree/v1.25.1912.0).
- База: `1cea42d433253d95c4487a3037db48197b5e72f4`.
- Исходный локальный commit патча: `a34eea7b524f7516c68014a14bb94e215520e0fc`.
- [Полный патч](patches/layout-fix.patch) изменяет три файла: `TerminalPage.cpp`,
  `TerminalPage.h`, `TermControl.cpp`.
- [Сообщение Microsoft с полным diff и результатом проверки](https://github.com/microsoft/terminal/issues/11522#issuecomment-5680525120).
- При обновлении настроек промежуточные обновления оформления всего окна
  откладываются до уже существующего финального обновления. Уведомление
  `BackgroundBrush` посылается при изменении объекта/цвета, включая acrylic.
  Обработчик смены языка и привязки ввода в исходном коде не менялись.
- Сборка: Release/x64, VS Build Tools 2022 17.11.1, MSVC 14.41.34120,
  Windows SDK 10.0.22621.0. Исторический результат сборки: 0 ошибок, 70 предупреждений.
- Сравнение stock/fix с полностью одинаковым текущим конфигом и полный UI-регресс
  ещё не выполнены. Удвоение кириллицы в Codex наблюдалось в обеих сборках;
  проверенный обход в HCA описан выше, бинарный патч Terminal его не исправляет.

Для восстановления исходников: получить официальный репозиторий, выбрать точную
базу выше, проверить и применить `patches/layout-fix.patch` через `git apply --check`
и `git apply`. Затем следовать инструкции сборки именно этого upstream-тега.
В HCA все clone/build/dependency-команды выполнять через machine-global heavy lock.
Чистая пересборка по этому recovery-репозиторию не выполнялась; для быстрого
восстановления предназначен проверенный бинарный ZIP из релиза.

Существующий upstream checkout на этом ПК: `C:\Users\Pavel\Projects\terminal-layout-fix`
(`/mnt/c/Users/Pavel/Projects/terminal-layout-fix` из WSL). Он содержит C++-исходники;
этот recovery-репозиторий находится отдельно в `~/Projects/windows-terminal-layout-fix`.
Перед новой работой проверить Git именно выбранного checkout, не считать
сохранённый здесь build receipt доказательством его текущей чистоты.

`build/original-build-receipt.json` сохранён без изменений. Его хеш настроек
относится к тестовому конфигу **до** настройки повседневной работы.
`build/recovery-manifest.json` описывает только неизменённый архив `layout-fix.1`,
включая его тогдашний конфиг. Это не хеш текущего `settings/settings.json` из Git.

## Обновление резервной копии

Рабочий файл на этом ПК:
`%LOCALAPPDATA%\Programs\WT-Layout-Fix-1.25.1912.0\settings\settings.json`.
На 16.09.2026 сохранена его точная копия, включая перенос строки, Ctrl+N/Ctrl+W
и отключение Kitty-протокола в профиле Ubuntu.
После следующих настроек сначала проверить diff только этого JSON: там могут
появиться личные пути и commandline. Буферы, состояние и авторизация в Git не идут.

В WSL, из корня этого репозитория, после просмотра изменений:

```bash
cp /mnt/c/Users/Pavel/AppData/Local/Programs/WT-Layout-Fix-1.25.1912.0/settings/settings.json settings/settings.json
python3 -m json.tool settings/settings.json > /dev/null
cmp settings/settings.json /mnt/c/Users/Pavel/AppData/Local/Programs/WT-Layout-Fix-1.25.1912.0/settings/settings.json
rtk proxy git diff -- settings/settings.json
```

Снимок JSON можно сохранять отдельным коммитом без пересборки EXE и нового ZIP.
Если рабочий JSON уже совпадает с сохранённым, повторное копирование и коммит
конфига не нужны. Изменение инструкции также не требует нового manifest архива.
При создании нового бинарного архива нужен отдельный приватный релиз, SHA256,
ведомость фактических файлов и проверка кандидата. Старый релиз и его receipts
не перезаписывать. Полный порядок — [UPDATING.md](UPDATING.md).

Portable-сборка сама не получает обновления Store. Перед переходом на новый
upstream сначала проверить, исправлена ли проблема официально. GitHub Actions
в этом репозитории отключены.
