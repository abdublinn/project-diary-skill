# project-diary-session-start.ps1
# SessionStart hook: garantirovanno podtyagivaet DNEVNIK.md proekta v kontekst sessii
# i KONTROLIRUET RAZMER. Vedenie dnevnika - na pravile v ~/.claude/CLAUDE.md + skile
# project-diary (hook pisat ne mozhet).
# V predelah limitov - vpechatyvaet dnevnik tselikom. Za predelami (znaki / chislo
# polnyh zapisey zhurnala) - tolko verh (Snimok, Ostorozhno, Orientir, Klyuchevye vehi)
# i direktivu "vypolni Uzhatie v etoy sessii". Net dnevnika - molchit.
# Lyuboy sboy hooka ne dolzhen lomat sessiyu.

$ErrorActionPreference = 'SilentlyContinue'

$LimitChars   = 24000
$LimitEntries = 12
$HeadCap      = 12000

try {
    try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

    $cur = (Get-Location).Path
    $diary = $null

    while (-not [string]::IsNullOrEmpty($cur)) {
        $candidate = Join-Path $cur 'ДНЕВНИК.md'
        if (Test-Path -LiteralPath $candidate) { $diary = $candidate; break }
        $parent = [System.IO.Path]::GetDirectoryName($cur)
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $cur) { break }
        $cur = $parent
    }

    if (-not $diary) { exit 0 }

    $content = Get-Content -LiteralPath $diary -Encoding UTF8 -Raw
    if ([string]::IsNullOrWhiteSpace($content)) { exit 0 }
    $content = $content.TrimStart([char]0xFEFF)

    $chars   = $content.Length
    $entries = ([regex]::Matches($content, '(?m)^###\s+\d{4}-\d{2}-\d{2}')).Count
    $over    = ($chars -gt $LimitChars) -or ($entries -gt $LimitEntries)

    $archive = Join-Path ([System.IO.Path]::GetDirectoryName($diary)) 'ДНЕВНИК-архив.md'

    Write-Output "=== ДНЕВНИК ПРОЕКТА (подтянут SessionStart-хуком) ==="
    Write-Output "Файл: $diary ($chars знаков, полных записей журнала: $entries)"
    if (Test-Path -LiteralPath $archive) {
        Write-Output "Архив: $archive - открывать только по правилу «Когда идти в архив» скила project-diary, искать запись по дате."
    }
    Write-Output "Прочитай это ПЕРЕД действиями - здесь состояние проекта и важные вехи прошлых сессий."
    Write-Output "По ходу работы веди дневник через скил project-diary (вехи / решения с «почему» / блокеры / конец сессии). Не на каждую правку."

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
    }
}
catch {
    exit 0
}
