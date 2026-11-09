# project-diary-session-start.ps1
# SessionStart hook: garantirovanno podtyagivaet DNEVNIK.md proekta v kontekst sessii,
# KONTROLIRUET RAZMER i SVEZHEST, i stavit pered dnevnikom korotkuyu kartochku pravil
# zapisi. Vedenie dnevnika - na pravile v ~/.claude/CLAUDE.md + skile project-diary
# (hook pisat ne mozhet).
# V predelah limitov - vpechatyvaet dnevnik tselikom. Za predelami (znaki / chislo
# polnyh zapisey zhurnala) - tolko verh (Snimok, Ostorozhno, Orientir, Klyuchevye vehi),
# zagolovki skrytyh zapisey i direktivu "vypolni Uzhatie v etoy sessii".
# Preduprezhdaet: Snimok starshe posledney zapisi; dnevnik ne obnovlyalsya > StaleDays.
# Net dnevnika vverh po derevu, no est dnevniki v podpapkah (papka-zontik) - perechislyaet ih.
# Inache molchit. Lyuboy sboy hooka ne dolzhen lomat sessiyu.

$ErrorActionPreference = 'SilentlyContinue'

$LimitChars   = 24000
$LimitEntries = 12
$HeadCap      = 12000
$StaleDays    = 30
$HiddenMax    = 20
$SubMax       = 25
$ProbeMax     = 600

function Write-Rules {
    # Karta pravil - odin fayl na oba huka (project-diary-rules-card.txt ryadom so skriptom).
    $card = $null
    try { $card = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'project-diary-rules-card.txt') -Encoding UTF8 -Raw } catch {}
    if ([string]::IsNullOrWhiteSpace($card)) {
        Write-Output 'ПРАВИЛА ЗАПИСИ: файл карточки не найден - перед первой правкой дневника вызови Skill project-diary и следуй ему.'
    } else {
        Write-Output $card.TrimStart([char]0xFEFF).TrimEnd()
    }
}

try {
    try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

    $start = (Get-Location).Path
    $cur = $start
    $diary = $null

    while (-not [string]::IsNullOrEmpty($cur)) {
        $candidate = Join-Path $cur 'ДНЕВНИК.md'
        if (Test-Path -LiteralPath $candidate) { $diary = $candidate; break }
        $parent = [System.IO.Path]::GetDirectoryName($cur)
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $cur) { break }
        $cur = $parent
    }

    if (-not $diary) {
        # Papka-zontik: svoego dnevnika net, no v podpapkah (do 2 urovney) est dnevniki proektov.
        $base  = $start.TrimEnd('\')
        $homeP = ([Environment]::GetFolderPath('UserProfile')).TrimEnd('\')
        $rootP = ([System.IO.Path]::GetPathRoot($start)).TrimEnd('\')
        if (($base -eq $homeP) -or ($base -eq $rootP)) { exit 0 }

        $skip   = @('node_modules', '__pycache__', 'venv', '_archived', '_extracted', 'templates')
        $found  = New-Object System.Collections.ArrayList
        $level1 = New-Object System.Collections.ArrayList
        $probed = 0

        foreach ($d1 in @(Get-ChildItem -LiteralPath $start -Directory)) {
            if ($probed -ge $ProbeMax) { break }
            if ($d1.Name.StartsWith('.') -or ($skip -contains $d1.Name)) { continue }
            $probed++
            [void]$level1.Add($d1)
            $f = Join-Path $d1.FullName 'ДНЕВНИК.md'
            if (Test-Path -LiteralPath $f) { [void]$found.Add((Get-Item -LiteralPath $f)) }
        }
        foreach ($d1 in $level1) {
            if ($probed -ge $ProbeMax) { break }
            foreach ($d2 in @(Get-ChildItem -LiteralPath $d1.FullName -Directory)) {
                if ($probed -ge $ProbeMax) { break }
                if ($d2.Name.StartsWith('.') -or ($skip -contains $d2.Name)) { continue }
                $probed++
                $f = Join-Path $d2.FullName 'ДНЕВНИК.md'
                if (Test-Path -LiteralPath $f) { [void]$found.Add((Get-Item -LiteralPath $f)) }
            }
        }
        if ($found.Count -eq 0) { exit 0 }

        $sorted = @($found | Sort-Object LastWriteTime -Descending)
        Write-Output '=== ДНЕВНИКИ ПОДПРОЕКТОВ (SessionStart-хук project-diary) ==='
        Write-Output "В папке $start своего ДНЕВНИК.md нет, но в подпапках есть дневники проектов: $($sorted.Count)."
        Write-Output 'Когда станет ясно, в каком подпроекте идёт работа, прочитай его ДНЕВНИК.md ДО действий и веди его по скилу project-diary.'
        $shown = 0
        foreach ($it in $sorted) {
            if ($shown -ge $SubMax) { break }
            $rel = $it.DirectoryName.Substring($base.Length).TrimStart('\')
            Write-Output ('- {0}\ДНЕВНИК.md (обновлён {1})' -f $rel, $it.LastWriteTime.ToString('yyyy-MM-dd'))
            $shown++
        }
        if ($sorted.Count -gt $SubMax) { Write-Output "... и ещё $($sorted.Count - $SubMax) более старых." }
        exit 0
    }

    $content = Get-Content -LiteralPath $diary -Encoding UTF8 -Raw
    if ([string]::IsNullOrWhiteSpace($content)) { exit 0 }
    $content = $content.TrimStart([char]0xFEFF)

    $chars     = $content.Length
    $entryHits = [regex]::Matches($content, '(?m)^###\s+(\d{4}-\d{2}-\d{2})[^\r\n]*')
    $entries   = $entryHits.Count
    $over      = ($chars -gt $LimitChars) -or ($entries -gt $LimitEntries)

    $snapDate = $null
    $ms = [regex]::Match($content, 'Снимок[^\r\n]*?Обновлено:?\s*(\d{4}-\d{2}-\d{2})')
    if ($ms.Success) { $snapDate = $ms.Groups[1].Value }
    $lastEntry = $null
    foreach ($x in $entryHits) {
        $d = $x.Groups[1].Value
        if ((-not $lastEntry) -or ([string]::CompareOrdinal($d, $lastEntry) -gt 0)) { $lastEntry = $d }
    }
    $freshest = $snapDate
    if ($lastEntry -and ((-not $freshest) -or ([string]::CompareOrdinal($lastEntry, $freshest) -gt 0))) { $freshest = $lastEntry }
    if (-not $freshest) {
        $mu = [regex]::Match($content, '(?m)^updated:\s*(\d{4}-\d{2}-\d{2})')
        if ($mu.Success) { $freshest = $mu.Groups[1].Value }
    }

    $archive = Join-Path ([System.IO.Path]::GetDirectoryName($diary)) 'ДНЕВНИК-архив.md'

    Write-Output "=== ДНЕВНИК ПРОЕКТА (подтянут SessionStart-хуком) ==="
    Write-Output "Файл: $diary ($chars знаков, полных записей журнала: $entries)"
    if (Test-Path -LiteralPath $archive) {
        Write-Output "Архив: $archive - открывать только по правилу «Когда идти в архив» скила project-diary, искать запись по дате."
    }
    Write-Output "Прочитай это ПЕРЕД действиями - здесь состояние проекта и важные вехи прошлых сессий."
    Write-Output "По ходу работы веди дневник по карточке ниже и скилу project-diary. Не на каждую правку."
    Write-Rules

    if ($snapDate -and $lastEntry -and ([string]::CompareOrdinal($snapDate, $lastEntry) -lt 0)) {
        Write-Output "!!! «Снимок» обновлён ${snapDate}, а последняя запись журнала - ${lastEntry}: верх дневника отстаёт. Сверь его с верхними записями журнала, при первой вехе перезапиши «Снимок»."
    }
    if ($freshest) {
        $fd = [datetime]::MinValue
        if ([datetime]::TryParseExact($freshest, 'yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$fd)) {
            $age = [int]((Get-Date).Date - $fd.Date).TotalDays
            if ($age -gt $StaleDays) {
                Write-Output "!!! Дневник не обновлялся $age дн. (с $freshest). «Следующий шаг» и сроки в «Снимке» могли устареть: до действий сверь их с фактом (свежие файлы проекта, владелец)."
            }
        }
    }

    if (-not $over) {
        Write-Output "-----8<----- содержимое ДНЕВНИК.md -----8<-----"
        Write-Output $content
        Write-Output "-----8<----- конец ДНЕВНИК.md -----8<-----"
    }
    else {
        $m = [regex]::Match($content, '(?m)^##\s[^\r\n]*[Жж]урнал')
        if ($m.Success) { $head = $content.Substring(0, $m.Index) } else { $head = $content }
        $cut = $false
        if ($head.Length -gt $HeadCap) { $head = $head.Substring(0, $HeadCap); $cut = $true }

        Write-Output "!!! ДНЕВНИК ПЕРЕПОЛНЕН: $chars знаков (лимит $LimitChars), полных записей $entries (лимит $LimitEntries)."
        Write-Output "!!! В этой сессии выполни «Ужатие» по скилу project-diary: до начала задачи, если она не срочная, иначе сразу после первого ответа пользователю. Всё вырезанное - сначала дословно в ДНЕВНИК-архив.md, важное - строками в «Ключевые вехи»."
        Write-Output "-----8<----- верх ДНЕВНИК.md (журнал не показан) -----8<-----"
        Write-Output $head
        if ($cut) {
            Write-Output "-----8<----- (обрезано на $HeadCap знаках; полный файл: $diary) -----8<-----"
        } else {
            Write-Output "-----8<----- (журнал не показан; полный файл: $diary) -----8<-----"
        }
        if ($entries -gt 0) {
            Write-Output "Заголовки записей журнала, которые не показаны (свежие решения и отмены - здесь; нужную запись прочитай в файле по дате):"
            $n = 0
            foreach ($x in $entryHits) {
                if ($n -ge $HiddenMax) { break }
                Write-Output ('  ' + $x.Value.Trim())
                $n++
            }
            if ($entries -gt $HiddenMax) { Write-Output "  ... и ещё $($entries - $HiddenMax)." }
        }
    }
}
catch {
    # Sboy huka ne lomaet sessiyu, no i ne molchit: model dolzhna znat, chto dnevnik ne podtyanut.
    try { Write-Output 'Хук project-diary не сработал: найди ДНЕВНИК.md в рабочей папке или выше по дереву и прочитай его сам до первого действия.' } catch {}
    exit 0
}
