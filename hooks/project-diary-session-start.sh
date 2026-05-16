#!/usr/bin/env bash
# project-diary SessionStart hook (macOS/Linux). Mirrors the .ps1 logic.
# Job: READING only — deterministically inject ДНЕВНИК.md into session context.
# Maintaining the diary is governed by the skill + CLAUDE.md rule (a hook
# cannot write). If a diary exists at/above the launch dir — print it; else
# stay silent (zero noise in trivial sessions). Never break the session.

dir="$PWD"
diary=""

while [ -n "$dir" ]; do
  if [ -f "$dir/ДНЕВНИК.md" ]; then
    diary="$dir/ДНЕВНИК.md"
    break
  fi
  parent="$(dirname "$dir")"
  if [ "$parent" = "$dir" ]; then
    break
  fi
  dir="$parent"
done

[ -z "$diary" ] && exit 0
[ -s "$diary" ] || exit 0

total="$(wc -l < "$diary" 2>/dev/null | tr -d ' ')"

echo "=== ДНЕВНИК ПРОЕКТА (подтянут SessionStart-хуком) ==="
echo "Файл: $diary"
echo "Прочитай это ПЕРЕД действиями — здесь состояние проекта и контекст прошлых сессий."
echo "По ходу веди дневник через скил project-diary (вехи / решения с «почему» / блокеры / конец сессии). Не на каждую правку."
echo "-----8<----- содержимое ДНЕВНИК.md -----8<-----"
head -n 200 "$diary"
if [ -n "$total" ] && [ "$total" -gt 200 ] 2>/dev/null; then
  echo "-----8<----- (показаны первые 200 строк; полный файл: $diary — дочитай при необходимости) -----8<-----"
else
  echo "-----8<----- конец ДНЕВНИК.md -----8<-----"
fi
exit 0
