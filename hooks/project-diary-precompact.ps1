# project-diary-precompact.ps1
# PreCompact hook: pered szhatiem konteksta tolkaet model zafiksirovat vehu v
# DNEVNIK.md, poka narabotannoe ne poteryano. Hook NE pishet sam - on vpechatyvaet
# direktivu (additionalContext), model pishet dnevnik po skilu project-diary.
# Esli dnevnik za limitami (znaki / polnye zapisi) - dobavlyaet direktivu "Uzhatie".
# Net dnevnika i net markera proekta - molchit. Sboy ne lomaet sessiyu.

$ErrorActionPreference = 'SilentlyContinue'

$LimitChars   = 24000
$LimitEntries = 12

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
        $chars = 0; $entries = 0
        $content = Get-Content -LiteralPath $diary -Encoding UTF8 -Raw
        if ($content) {
            $chars   = $content.Length
            $entries = ([regex]::Matches($content, '(?m)^###\s+\d{4}-\d{2}-\d{2}')).Count
        }
        $lines = @(
            "[project-diary] Контекст сейчас будет сжат — наработанное может потеряться.",
            "Если в этой сессии была веха / нетривиальное решение / блокер и они ещё не в ДНЕВНИК.md ($diary) — ОБНОВИ его СЕЙЧАС, до сжатия, по правилам скила project-diary:",
            "• «Снимок» перезаписать (штамп Обновлено: дата[ · git sha], заполнить «Следующий шаг (сразу делать)» одной строкой);",
            "• одну запись в «Свежий журнал» сверху, решения — с «почему».",
            "Если вехи не было — ничего не пиши (дневник не мусорим)."
        )
        if (($chars -gt $LimitChars) -or ($entries -gt $LimitEntries)) {
            $lines += "Дневник за лимитами ($chars знаков, полных записей $entries; лимиты $LimitChars / $LimitEntries) — после записи вехи выполни в этой сессии «Ужатие» по скилу: вырезанное — дословно в ДНЕВНИК-архив.md, важное — строками в «Ключевые вехи»."
        }
        Emit-Context ($lines -join "`n")
    }
    elseif ($marker) {
        Emit-Context "[project-diary] Контекст сейчас будет сжат. Похоже на проект, но ДНЕВНИК.md нет. Если работа нетривиальная и продолжительная — заведи ДНЕВНИК.md сейчас (скил project-diary), до сжатия, чтобы не потерять состояние. Для разовой мелочи — игнорируй."
    }
    # ни дневника, ни маркера — молчим
}
catch { exit 0 }
