# Обновление Windows Terminal и перенос нашего патча

Это инструкция для следующего обновления, **не отчёт о выполненной пересборке**.
Рабочая версия и восстановление описаны в [README.md](README.md).
Исходники Microsoft нужно получать отдельно: здесь хранится recovery-kit.

## 1. Сначала проверить официальный релиз

Открыть [релизы Microsoft](https://github.com/microsoft/terminal/releases) и
[#11522](https://github.com/microsoft/terminal/issues/11522), включая связанные PR.
Проверить **конкретный release tag**, а не только `main`, закрытый issue или
надпись «Latest»: GitHub отделяет stable от Preview/prerelease.
На проверке 15.09.2026 верхние релизы — Preview `v1.25.1912.0` и stable
`v1.24.11911.0`; #11522 открыт. При будущем обновлении проверить заново.

Read-only проверка через GitHub CLI:

```bash
rtk-run -- gh api 'repos/microsoft/terminal/releases?per_page=10' --jq '.[] | [.tag_name, .prerelease, .published_at] | @tsv'
rtk-run -- gh issue view 11522 --repo microsoft/terminal --comments
```

Сначала испытать **официальный x64 unpackaged ZIP без нашего патча** рядом с
рабочей сборкой. Распаковать в новую отдельную папку, создать `.portable` рядом
с EXE **до первого запуска**, перенести только копию нашего `settings.json` в
`settings/settings.json`. Запускать полный путь к новому `WindowsTerminal.exe`.
Убедиться по пути процесса, что проверяется нужная версия, а не старое окно.
Правила portable описаны у [Microsoft](https://learn.microsoft.com/en-us/windows/terminal/distributions).

- Новый официальный Terminal проходит проверки раздела 6: предпочесть его;
  наш C++-патч больше не нужен. Конфиг и обход Codex проверить отдельно.
- Лаг остался: перенести патч на выбранный tag по разделам 3–5.
- Изменился код, а результат неясен: сохранить рабочую сборку и исследовать
  конкретного кандидата. Не считать применение diff доказательством исправления.

## 2. Сохранить рабочее состояние

Перед тестами сохранить текущий JSON и проверить diff по инструкции README.
Рабочую папку `%LOCALAPPDATA%\Programs\WT-Layout-Fix-1.25.1912.0` оставить целой.
Тестовые копии получают отдельные папки и не используют общий `settings` через ссылку.

Для переноса вкладок/буферов позже, после сохранения работы и обычного выхода
из старого Terminal, сделать **локальную приватную копию всей папки `settings`**.
Она содержит тексты сессий: не добавлять её в Git/релизы. Для первого сравнения
достаточно одного JSON; состояние вкладок переносить отдельным этапом после тестов.
Старую копию state сохранить: новая версия может изменить формат, обратная
совместимость не обещана. Живые процессы агентов этим не сохраняются.

Обновление Terminal не требует `wsl --shutdown`, сброса BIOS или переустановки
дистрибутива. Закрывать рабочие окна нужно только в согласованное окно перехода.

## 3. Получить исходники и проверить патч

Наша историческая база: `v1.25.1912.0`, SHA
`1cea42d433253d95c4487a3037db48197b5e72f4`.
Патч: [patches/layout-fix.patch](patches/layout-fix.patch), исходный commit
`a34eea7b524f7516c68014a14bb94e215520e0fc`.
Это текстовый diff C++, **его нельзя применить к готовому EXE или MSIX**.

В WSL выбрать точный tag из Releases. Пример ниже воспроизводит старую базу;
при обновлении заменить `wt_tag` на уже выбранный новый tag. Исходники для
Windows/MSBuild разместить на NTFS, например `C:\Users\Pavel\Source`, не в UNC.

```bash
wt_tag='v1.25.1912.0'
wt_source="/mnt/c/Users/Pavel/Source/terminal-$wt_tag"
wt_patch='/home/pavelbe/Projects/windows-terminal-layout-fix/patches/layout-fix.patch'
```

Нужен новый отсутствующий каталог. Не выполнять clone поверх старого checkout:

```bash
test ! -e "$wt_source"
/home/pavelbe/.claude/bin/heavy-lock.sh --wait 600 -- git -c core.autocrlf=false clone --branch "$wt_tag" --single-branch --depth 1 https://github.com/microsoft/terminal.git "$wt_source"
```

При ошибке любой команды остановиться. Для агента HCA переменные в командах
Git/lock заменить проверенными **буквальными путями/tag** и выставить cwd исходников;
это шаблон для оператора, не способ обхода admission. Далее, отдельными командами:

```bash
rtk proxy git -C "$wt_source" rev-parse HEAD
rtk proxy git -C "$wt_source" describe --tags --exact-match
rtk proxy git -C "$wt_source" status --short
/home/pavelbe/.claude/bin/heavy-lock.sh --wait 600 -- git -C "$wt_source" submodule update --init --recursive
rtk proxy git -C "$wt_source" apply --check "$wt_patch"
```

Сверить HEAD с commit выбранного tag; `target_commitish: main` из release API
не является закреплённым SHA. До patch-check дерево должно быть чистым.

| Результат проверки | Следующее действие |
| --- | --- |
| `apply --check` успешен | Прочитать контекст трёх файлов, затем применить diff |
| Прямая проверка не прошла, `apply --reverse --check` прошёл | Такие изменения уже присутствуют; повторно не применять, проверить поведение |
| Обе проверки не прошли | Возможны рефакторинг, частичное исправление или другая база; вручную проверить каждый участок |

Команда применения — **только после успешной прямой проверки и чтения контекста**:

```bash
rtk proxy git -C "$wt_source" apply "$wt_patch"
rtk proxy git -C "$wt_source" diff --check
rtk proxy git -C "$wt_source" diff --stat
```

Не использовать `--reject`, игнорирование пробелов или автоматический `--3way`
для продавливания несовместимого патча. Сохранить исходные байты patch-файла:
в нём есть CRLF-контекст `TermControl.cpp`; не прогонять его через форматтер.

При ручном переносе сохранить **смысл**, а не номера строк:

1. `TerminalPage.h`: состояние `_updatingTerminalSettings` принадлежит странице.
2. `TerminalPage.cpp`: на время применения настроек всем вкладкам временно
   отложить `_updateThemeColors`; вернуть предыдущее состояние через scope guard.
   После цикла должно остаться штатное финальное обновление оформления.
   Обновления иконок, заголовков, ActionMap и вкладок должны сохраниться.
3. `TermControl.cpp`: `BackgroundBrush` уведомляет при смене объекта **или цвета**,
   включая SolidColorBrush и AcrylicBrush; одинаковый фон не создаёт лишних
   уведомлений. Не потерять изменения `TintColor`/`FallbackColor`.

Не переносить этот guard, если новый upstream уже заменил соответствующий путь.
После переноса сохранить новый diff относительно **нового upstream SHA**, точный
список файлов и SHA256 патча. Старый патч должен оставаться доступным в Git и
старом release. Успешный `git apply` проверяет контекст, не семантику и не сборку.

Отдельный кандидат 19.09.2026 добавляет
[patches/clipboard-image-paste.patch](patches/clipboard-image-paste.patch).
Он построен поверх `a34eea7` (уже с layout fix), commit `2d4c28b`.
На той же базе порядок: `layout-fix.patch`, затем проверка и применение
`clipboard-image-paste.patch`. При новом upstream сначала проверить его штатную
вставку снимков: второй патч может оказаться не нужен независимо от первого.
Clipboard-патч меняет paste handler, добавляет `ClipboardImage.h` и линковку WIC;
сохранить приоритет текста/CF_HDROP, background encoding после CloseClipboard,
уникальный CREATE_NEW-файл и удаление частичной записи при ошибке.
19.09.2026 владелец подтвердил в кандидате Ctrl+V для снимка PrintScreen и текста
в Codex. Повторные проверки Claude, файла из Explorer и десяти вкладок ещё
ожидаются; кандидат пока не назначен рабочим и не опубликован новым релизом.

## 4. Собрать на Windows

Прочитать `README.md`, `doc/building.md`, `.vsconfig` и build scripts **выбранного
tag**. [Официальная инструкция](https://github.com/microsoft/terminal/blob/main/doc/building.md)
на `main` — только указатель; требования будущей версии могут отличаться.
Базовый tag требует PowerShell 7+, VS 2022 с Desktop C++, UWP/v143 tools и
Windows SDK 22621; тестам нужен .NET Framework Targeting Pack.
См. [README базы](https://github.com/microsoft/terminal/blob/v1.25.1912.0/README.md).

Не принимать старые версии MSVC/SDK из receipt за требования нового релиза.
Для воспроизводимости записать фактические версии VS/MSBuild/MSVC/SDK/NuGet и
submodule SHA. Не обновлять зависимости сверх требований tag ради прохождения сборки.

Открыть **PowerShell 7 для Windows (`pwsh.exe`)**, перейти в checkout. Ниже отправная
точка для базы со `OpenConsole.slnx`; если структура изменилась, сначала адаптировать
команду по её build scripts. Полный прогон этих команд в этой docs-сессии не выполнялся.

```powershell
$ErrorActionPreference = 'Stop'
Set-Location 'C:\Users\Pavel\Source\terminal-v1.25.1912.0' # выбранный checkout
Import-Module .\tools\OpenConsole.psm1
Set-MsBuildDevEnvironment
& .\dep\nuget\nuget.exe restore .\OpenConsole.slnx
if ($LASTEXITCODE -ne 0) { throw 'Solution restore failed' }
& .\dep\nuget\nuget.exe restore .\dep\nuget\packages.config
if ($LASTEXITCODE -ne 0) { throw 'Shared packages restore failed' }
& msbuild.exe .\OpenConsole.slnx /t:Terminal\CascadiaPackage /p:Configuration=Release /p:Platform=x64 /p:AppxPackageSigningEnabled=false /m:2 /bl:terminal-release-x64.binlog
if ($LASTEXITCODE -ne 0) { throw 'Terminal build failed' }
```

Restore шаги разделены: [helper базы](https://github.com/microsoft/terminal/blob/v1.25.1912.0/tools/OpenConsole.psm1)
вызывает NuGet несколько раз перед MSBuild; важно не потерять раннюю ошибку.
Сборка `CascadiaPackage` не доказывает запуск unit tests. Построить и выполнить
подходящие тесты TerminalApp/Control/Settings Model из выбранного tag, фиксируя
каждый exit; отсутствующие DLL или непройденный запуск обозначать `NOT RUN`.
UIA-тесты управляют мышью: запускать только в отдельное согласованное окно.

Все clone/submodule/restore/build/test/package команды агента выполняются под
машинным heavy-lock, последовательно, с сохранением exit/log. Для Windows-фаз
использовать проверенный `.ps1` через `pwsh.exe -File` под внешним WSL lock;
не запускать второй build из GUI одновременно. Binlog держать локально: он
может содержать пути и параметры окружения. GitHub Actions не запускать.

Свой проверенный `.ps1` подготовить в локальной папке Windows и передавать
полный Windows-путь: действующая RemoteSigned может считать путь
`\\wsl.localhost\Ubuntu\...` удалённым и отказаться от неподписанного файла.
Не менять ExecutionPolicy ради запуска. Это не разрешение снимать защиту с
скачанного скрипта: его происхождение и требования подписи проверяются отдельно.

## 5. Получить полный portable-кандидат

Один собранный EXE недостаточен. Нужны согласованные DLL, XAML/PRI-ресурсы и
зависимости **той же сборки**. Не копировать старые DLL поверх нового релиза.
`OpenConsole.exe` — консольный хост, не приложение с вкладками.

В базе есть [New-UnpackagedTerminalDistribution.ps1](https://github.com/microsoft/terminal/blob/v1.25.1912.0/build/scripts/New-UnpackagedTerminalDistribution.ps1).
Проверить его параметры в новом tag. Для варианта AppX указать точные пути к
**своему** собранному Terminal MSIX/AppX и соответствующему Microsoft.UI.Xaml
AppX x64 из зависимостей сборки; не выбирать первый найденный файл.

```powershell
& {
    if ($PSVersionTable.PSVersion -lt [version]'7.4') { throw 'Use PowerShell 7.4+ for this packaging recipe' }
    $ErrorActionPreference = 'Stop'
    $PSNativeCommandUseErrorActionPreference = $true
    $terminalPackage = Read-Host 'Full path to the newly built Terminal .msix/.appx'
    $xamlPackage = Read-Host 'Full path to matching Microsoft.UI.Xaml x64 .appx'
    $makeAppx = Read-Host 'Full path to MakeAppx.exe from the selected Windows SDK'
    $staging = Read-Host 'New empty staging directory outside the live installation'
    if (Test-Path -LiteralPath $staging) { throw 'Use a new staging directory' }
    $result = @(& .\build\scripts\New-UnpackagedTerminalDistribution.ps1 -TerminalAppX $terminalPackage -XamlAppX $xamlPackage -MakeAppxPath $makeAppx -Destination $staging -PortableMode)
    if ($result.Count -ne 1 -or $result[0] -isnot [System.IO.FileInfo] -or $result[0].Extension -ne '.zip' -or $result[0].Length -le 0) {
        throw 'Packaging did not return one nonempty ZIP; do not use partial output'
    }
    $result[0]
}
```

Остановка на native-ошибке здесь обязательна и ограничена этим scriptblock:
профиль PowerShell не меняется. В исходной цепочке базы `Merge-PriFiles.ps1`
не проверяет exit `MakePri.exe new`; успешный последующий `tar` может затереть
ошибку. Один `$LASTEXITCODE` после внешнего `.ps1` проверяет только последний
native exit, а не все этапы. Поведение описано у Microsoft:
[`$LASTEXITCODE`](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_automatic_variables#lastexitcode),
[`$PSNativeCommandUseErrorActionPreference`](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_preference_variables#psnativecommanduseerroractionpreference).
При новом tag проверить всю цепочку helper-скриптов на локальные overrides и
обработку ошибок; наличие ZIP ещё не доказывает целостность его ресурсов.

Проверка 15.09.2026 на PowerShell 7.6.6: настоящий `Merge-PriFiles.ps1` базы с
подставной утилитой, возвращающей 23, продолжал выполнение в старом режиме;
следующий успешный native шаг давал 0. Новый режим остановил первый отказ;
контроль с exit 0 прошёл. Это изолированная проверка контракта ошибок, не
пересборка Terminal и не Windows UI smoke. Исторический ZIP не изменялся.

Если имеется только layout с `AppxManifest.xml`, у базового скрипта есть
`-TerminalLayout` вместо `-TerminalAppX`: он возвращает каталог во временной
папке, а не ZIP в `-Destination`. Проверить возвращённый путь и перенести
результат целиком в новую папку кандидата; не запускать долгоживущую копию из `%TEMP%`.
Если helper исчез/поменялся, заново определить поддержанный upstream packaging,
а не собирать неполный набор файлов вручную.

Распаковать результат отдельно, проверить `.portable`, скопировать только
актуальный JSON до первого запуска. Имя папки должно отражать новую версию,
например `WT-Layout-Fix-<version>`; старую папку не переименовывать и не затирать.

### Повторить текущую проверку clipboard-кандидата

Для существующего checkout v1.25.1912.0 с уже собранными зависимостями доступны
[build/Test-ClipboardImage.ps1](build/Test-ClipboardImage.ps1) и
[build/Package-ClipboardCandidate.ps1](build/Package-ClipboardCandidate.ps1).
Скопировать эти проверенные скрипты и `build/clipboard-image-smoke.cpp` в одну
локальную Windows-папку. Test компилирует **header из переданного SourceRoot**;
он не меняет буфер обмена. Опциональный `-ReadClipboard` дополнительно читает
текущий снимок и оставляет его PNG локально; при отсутствии bitmap возвращает ошибку.

```powershell
.\Test-ClipboardImage.ps1 -SourceRoot 'C:\Users\Pavel\Projects\terminal-layout-fix' -OutputDirectory 'C:\Users\Pavel\Diagnostics\clipboard-smoke-new'
```

После успешного smoke собрать `src\cascadia\WindowsTerminal\WindowsTerminal.vcxproj`
в VS developer shell: `/t:Build /p:Configuration=Release /p:Platform=x64`
и `/p:SolutionDir=<полный путь checkout с завершающим \>`; остановиться при
ненулевом `$LASTEXITCODE`. Для свежего checkout сначала нужны зависимости из
раздела 4; package helper их не собирает.

```powershell
.\Package-ClipboardCandidate.ps1 -SourceRoot 'C:\Users\Pavel\Projects\terminal-layout-fix' -SettingsFile 'C:\Users\Pavel\AppData\Local\Programs\WT-Layout-Fix-1.25.1912.0\settings\settings.json' -Destination 'C:\Users\Pavel\AppData\Local\Programs\WT-Clipboard-New'
```

OutputDirectory и Destination должны отсутствовать. Package повторно объединяет
точный список PRI этого tag через upstream helper с остановкой на native-ошибках,
копирует весь build layout и проверяет хеши копий, добавляет proxy/license/portable
marker и только JSON. Он не доказывает свежесть предшествующей сборки — её exit,
исходный diff и хеши нужно связать отдельным receipt. Для другого tag заново проверить
список ресурсов по `_WTPrepareUnpackagedLayoutForRun`, не переносить его вслепую.
Все test/build/package вызовы агента по-прежнему выполняются под heavy-lock.

## 6. Проверить кандидата до переключения

Для старой рабочей, новой официальной и новой патченной (если нужна) версий
использовать одинаковые копии JSON, одинаковые вкладки и объём вывода. Отличать
версию продукта от номера FileVersion; записать полный путь/PID фактического EXE.
Не считать новое окно доказательством нового процесса.

| Проверка | Критерий |
| --- | --- |
| 2 → 10 → 20 пустых CMD/PowerShell вкладок, затем Ubuntu | RU/EN не вызывает многосекундного стопа ввода |
| 10 одиночных смен с паузами, затем отдельная серия быстрых | Нет накопления зависаний; записать наблюдаемую максимальную паузу |
| Смена языка в Блокноте → возврат в Terminal; переходы вкладок | Нет прежнего зависания при смене раскладки |
| Обычная нагрузка и история вывода в рабочих вкладках | Результат сохраняется вне пустых тестовых вкладок |
| Цвет вкладки, light/dark, фон/acrylic/opacity, reload настроек | Цвета действительно обновляются и при обычном reload, и после смены языка |
| `+`, Ctrl+N; Ctrl+W на пустой вкладке с панелями | Новая Ubuntu в `~`; закрытие всей выбранной вкладки |
| Split, resize, drag tab, поиск и палитра | Нет потери панелей/фокуса и новых сбоев |
| Новый `codex`, `codex resume`, Claude | Набор и вставка `перевари тест`, латиница, Ctrl/Shift+Enter работают |
| Цифровая десятичная клавиша в Claude/Codex, Num Lock включён | RU — запятая, EN — точка; Ubuntu сохраняет `compatibility.kittyKeyboardMode: false` |
| Новый снимок PrintScreen/«Ножницы» → Ctrl+V в каждом TUI; отдельно файл из Explorer | Изображение прикрепляется; текстовая вставка и файловая вставка сохранены |
| Обычный выход и повторный запуск после сохранения работы | Возвращаются ожидаемые вкладки/панели; агенты запускаются заново |

Обход `CODEX_TUI_DISABLE_KEYBOARD_ENHANCEMENT=1` во время сравнения сохранять.
Его отмена — отдельный эксперимент после прохождения проверки; новая версия
Terminal не доказывает исправления Codex. Не отправлять тестовый ввод агентам.
Факт `build=0` не заменяет ни один ручной пункт этой таблицы.

## 7. Переключить запуск и оставить откат

Только после проверки кандидата сохранить работу, завершить нужные агенты и
обычно закрыть старые окна. Переносить копию private state при закрытом кандидате;
проверить восстановление ещё раз. При несовместимости оставить его чистое состояние
и исходный backup; не исправлять state вручную. Запустить и закрепить новый EXE.

**HCA требует отдельного обновления маршрута.** Сейчас `_wt_resolve_terminal()` в
`~/hca-system-v3/modules/zsh/terminal/81-wt-split-panes.zsh` содержит буквальный
`Programs/WT-Layout-Fix-1.25.1912.0`. Для нового portable изменить этот путь на
проверенную новую папку, синхронно обновить ожидаемый путь в
`tests/test-wt-commands.sh` и HCA runbook. Канал оставить `layout-fix`.
Не прятать новые бинарники в папке с номером старой версии.

Если выбран официальный **установленный** Preview/Stable, вместо portable-маршрута
задать `settings.windows_terminal_channel: preview` или `stable` в HCA
`config/workspaces.yaml`. У этих пакетов отдельные JSON: согласовать их настройки
через UI/проверенный diff. Сам ярлык на панели задач не меняет маршрутизацию HCA.

После целевой правки HCA запустить его `tests/test-wt-commands.sh` под heavy-lock,
затем в новой свободной Zsh `source ~/.zshrc` и `wt-doctor`.
Проверить `atreno`: одна вкладка, одна панель в выбранном Terminal, без лишних окон.

Откат: завершить только тестовые/новые сессии обычным способом, вернуть прежний
канал/путь HCA и ярлык на сохранённый EXE; использовать исходную копию settings.
Не загружать преобразованный новым релизом state в старую версию без проверки.
Windows/WSL перезагружать ради отката маршрута не требуется.

## 8. Зафиксировать новую резервную копию

Сохранить точный upstream tag/SHA, diff и его SHA256 (либо `patch not needed`),
версии инструментов, exits сборки/тестов и отдельный результат ручной проверки.
В private release включить весь runtime, лицензии, актуальный JSON и инструкцию;
не включать state, экранные буферы, дампы, трассы, credentials и binlog.
Новый тег/ZIP/SHA256 и manifest должны описывать **фактический новый архив**.
Перед публикацией проверить извлечение, список файлов, размеры и хеши.

`build/original-build-receipt.json` и `build/recovery-manifest.json` относятся
к историческому `layout-fix.1`: не менять их ради нового конфигурационного commit.
Для нового релиза сохранить отдельный receipt/manifest и обновить ссылки README.
Не перезаписывать опубликованный старый asset и не выдавать старую ручную проверку
за проверку нового релиза. Публикация Git-коммита не означает публикацию ZIP.
