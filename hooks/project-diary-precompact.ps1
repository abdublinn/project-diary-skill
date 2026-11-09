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
        $card = $null
        try { $card = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'project-diary-rules-card.txt') -Encoding UTF8 -Raw } catch {}
        if ([string]::IsNullOrWhiteSpace($card)) { $card = 'Правила записи — в скиле project-diary (файл карточки не найден).' }
        $lines = @(
            "[project-diary] Контекст сейчас будет сжат — наработанное может потеряться.",
            "Определи режим для ДНЕВНИК.md ($diary) по карточке ниже и, если это режим 2 или 3, обнови дневник СЕЙЧАС, до сжатия. Режим 1 (состояние не изменилось) — ничего не пиши.",
            $card.TrimStart([char]0xFEFF).TrimEnd()
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
catch {
    Emit-Context "[project-diary] Хук не сработал. Перед сжатием контекста сам найди ДНЕВНИК.md проекта и, если состояние изменилось, обнови его по скилу project-diary."
    exit 0
}
