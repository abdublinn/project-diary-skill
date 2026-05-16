# project-diary-session-start.ps1
# SessionStart hook: garantirovanno podtyagivaet DNEVNIK.md proekta v kontekst sessii.
# Zadacha hooka - tolko CHTENIE (determinirovannaya inektsiya). Vedenie dnevnika -
# na pravile v ~/.claude/CLAUDE.md + skile project-diary (hook pisat ne mozhet).
# Printsip: esli dnevnik est v korne proekta (ili vyshe po derevu) - vpechatat ego.
# Esli dnevnika net - molchat (nikakogo shuma v trivialnyh sessiyah).
# Lyuboy sboy hooka ne dolzhen lomat sessiyu.

$ErrorActionPreference = 'SilentlyContinue'

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

    $lines = $content -split "`r?`n"
    $cap = 200
    $truncated = $false
    if ($lines.Count -gt $cap) {
        $content = ($lines[0..($cap - 1)] -join "`n")
        $truncated = $true
    }

    Write-Output "=== ДНЕВНИК ПРОЕКТА (подтянут SessionStart-хуком) ==="
    Write-Output "Файл: $diary"
    Write-Output "Прочитай это ПЕРЕД действиями - здесь состояние проекта и контекст прошлых сессий."
    Write-Output "По ходу работы веди дневник через скил project-diary (вехи / решения с <почему> / блокеры / конец сессии). Не на каждую правку."
    Write-Output "-----8<----- содержимое ДНЕВНИК.md -----8<-----"
    Write-Output $content
    if ($truncated) {
        Write-Output "-----8<----- (показаны первые $cap строк; полный файл: $diary - дочитай при необходимости) -----8<-----"
    } else {
        Write-Output "-----8<----- конец ДНЕВНИК.md -----8<-----"
    }
}
catch {
    exit 0
}
