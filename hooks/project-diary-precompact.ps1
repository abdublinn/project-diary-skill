# project-diary-precompact.ps1
# PreCompact hook: pered szhatiem konteksta tolkaet model zafiksirovat vehu v
# DNEVNIK.md, poka narabotannoe ne poteryano. Hook NE pishet sam - on vpechatyvaet
# direktivu (additionalContext), model pishet dnevnik po skilu project-diary.
# Net dnevnika i net markera proekta - molchit. Sboy ne lomaet sessiyu.

$ErrorActionPreference = 'SilentlyContinue'

function Emit-Context($text) {
    try {
        $obj = [pscustomobject]@{
            hookSpecificOutput = [pscustomobject]@{
                hookEventName     = 'PreCompact'
                additionalContext = $text
            }
        }
        $json = $obj | ConvertTo-Json -Compress -Depth 5
        try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
        [Console]::Out.Write($json)
    } catch {}
}

try {
    $cur = (Get-Location).Path
    $diary = $null
    $marker = $false
    $probe = $cur
    while (-not [string]::IsNullOrEmpty($probe)) {
        if (Test-Path -LiteralPath (Join-Path $probe 'ДНЕВНИК.md')) { $diary = (Join-Path $probe 'ДНЕВНИК.md'); break }
        foreach ($m in @('.git', '.obsidian', 'package.json', 'pyproject.toml')) {
            if (Test-Path -LiteralPath (Join-Path $probe $m)) { $marker = $true }
        }
        $parent = [System.IO.Path]::GetDirectoryName($probe)
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $probe) { break }
        $probe = $parent
    }

    if ($diary) {
        Emit-Context (@(
            "[project-diary] Контекст сейчас будет сжат — наработанное может потеряться.",
            "Если в этой сессии была веха / нетривиальное решение / блокер и они ещё не в ДНЕВНИК.md ($diary) — ОБНОВИ его СЕЙЧАС, до сжатия, по правилам скила project-diary:",
            "• «Снимок» перезаписать (штамп Обновлено: дата[ · git sha], заполнить «Следующий шаг (сразу делать)» одной строкой);",
            "• одну запись в «Журнал» сверху, решения — с «почему»; следить за потолком Журнала (≈12 вех / ≈150 строк, переполнение свернуть в Архив).",
            "Если вехи не было — ничего не пиши (дневник не мусорим)."
        ) -join "`n")
    }
    elseif ($marker) {
        Emit-Context "[project-diary] Контекст сейчас будет сжат. Похоже на проект, но ДНЕВНИК.md нет. Если работа нетривиальная и продолжительная — заведи ДНЕВНИК.md сейчас (скил project-diary), до сжатия, чтобы не потерять состояние. Для разовой мелочи — игнорируй."
    }
    # ни дневника, ни маркера — молчим
}
catch { exit 0 }
