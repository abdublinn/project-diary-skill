#!/usr/bin/env bash
# project-diary-precompact.sh — PreCompact hook (macOS/Linux). Mirrors the .ps1.
# Before context is compacted, nudge the model to record the current milestone
# in ДНЕВНИК.md while the work is still in context. The hook does NOT write —
# it injects a directive (additionalContext); the model writes per the skill.
# Over the limits (chars / full journal entries) -> also ask for «Ужатие».
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

command -v python3 >/dev/null 2>&1 || exit 0

python3 - "$diary" "$marker" <<'PY'
import json, re, sys
sys.stdout.reconfigure(encoding="utf-8")
LIMIT_CHARS, LIMIT_ENTRIES = 24000, 12
diary, marker = sys.argv[1], sys.argv[2]
if diary:
    try:
        t = open(diary, encoding="utf-8-sig").read()
    except OSError:
        t = ""
    chars = len(t)
    entries = len(re.findall(r"(?m)^###\s+\d{4}-\d{2}-\d{2}", t))
    msg = ("[project-diary] Контекст сейчас будет сжат — наработанное может потеряться.\n"
           f"Если в этой сессии была веха / нетривиальное решение / блокер и их ещё нет в ДНЕВНИК.md ({diary}) — ОБНОВИ его СЕЙЧАС, до сжатия, по правилам скила project-diary: "
           "«Снимок» перезаписать (штамп «Обновлено: дата[ · git sha]» + «Следующий шаг (сразу делать)» одной строкой); "
           "одну запись в «Свежий журнал» сверху, решения — с «почему». Вехи не было — ничего не пиши, дневник не мусорим.")
    if chars > LIMIT_CHARS or entries > LIMIT_ENTRIES:
        msg += (f"\nДневник за лимитами ({chars} знаков, полных записей {entries}; лимиты {LIMIT_CHARS} / {LIMIT_ENTRIES}) — "
                "после записи вехи выполни в этой сессии «Ужатие» по скилу: вырезанное — дословно в ДНЕВНИК-архив.md, важное — строками в «Ключевые вехи».")
elif marker == "1":
    msg = ("[project-diary] Контекст будет сжат. Похоже на проект, но ДНЕВНИК.md нет. Если работа нетривиальная и продолжительная — "
           "заведи ДНЕВНИК.md сейчас (скил project-diary), до сжатия. Разовая мелочь — игнорируй.")
else:
    sys.exit(0)
print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreCompact", "additionalContext": msg}}, ensure_ascii=False))
PY
exit 0
