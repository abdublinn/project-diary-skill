#!/usr/bin/env bash
# project-diary-precompact.sh — PreCompact hook (macOS/Linux). Mirrors the .ps1.
# Before context is compacted, nudge the model to record the current milestone
# in ДНЕВНИК.md while the work is still in context. The hook does NOT write —
# it injects a directive (additionalContext); the model writes per the skill.
# No diary and no project marker -> stay silent. Never break the session.

dir="$PWD"; diary=""; marker=0
while [ -n "$dir" ]; do
  if [ -f "$dir/ДНЕВНИК.md" ]; then diary="$dir/ДНЕВНИК.md"; break; fi
  for m in .git .obsidian package.json pyproject.toml; do
    [ -e "$dir/$m" ] && marker=1
  done
  parent="$(dirname "$dir")"
  [ "$parent" = "$dir" ] && break
  dir="$parent"
done

emit() {
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$1" <<'PY'
import json, sys
print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreCompact",
      "additionalContext": sys.argv[1]}}, ensure_ascii=False))
PY
  else
    esc=$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk 'BEGIN{ORS="\\n"}{print}')
    printf '{"hookSpecificOutput":{"hookEventName":"PreCompact","additionalContext":"%s"}}' "$esc"
  fi
}

if [ -n "$diary" ]; then
  emit "[project-diary] Контекст сейчас будет сжат — наработанное может потеряться.
Если в этой сессии была веха / нетривиальное решение / блокер и их ещё нет в ДНЕВНИК.md ($diary) — ОБНОВИ его СЕЙЧАС, до сжатия, по правилам скила project-diary: «Снимок» перезаписать (штамп «Обновлено: дата[ · git sha]» + «Следующий шаг (сразу делать)» одной строкой); одну запись в «Журнал» сверху, решения — с «почему»; следить за потолком Журнала (≈12 вех / ≈150 строк → свернуть в Архив). Вехи не было — ничего не пиши, дневник не мусорим."
elif [ "$marker" = "1" ]; then
  emit "[project-diary] Контекст будет сжат. Похоже на проект, но ДНЕВНИК.md нет. Если работа нетривиальная и продолжительная — заведи ДНЕВНИК.md сейчас (скил project-diary), до сжатия. Разовая мелочь — игнорируй."
fi
exit 0
