#!/usr/bin/env bash
# project-diary SessionStart hook (macOS/Linux). Mirrors the .ps1 logic.
# Job: READ + SIZE CONTROL. Within limits — inject ДНЕВНИК.md in full. Over the
# limits (chars / full journal entries) — inject only the top part (Снимок,
# Осторожно, Ориентир, Ключевые вехи) plus a directive to run «Ужатие».
# No diary — stay silent. Never break the session.

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

if command -v python3 >/dev/null 2>&1; then
  python3 - "$diary" <<'PY'
import os, re, sys
sys.stdout.reconfigure(encoding="utf-8")
LIMIT_CHARS, LIMIT_ENTRIES, HEAD_CAP = 24000, 12, 12000
p = sys.argv[1]
t = open(p, encoding="utf-8-sig").read()
chars = len(t)
entries = len(re.findall(r"(?m)^###\s+\d{4}-\d{2}-\d{2}", t))
over = chars > LIMIT_CHARS or entries > LIMIT_ENTRIES
arch = os.path.join(os.path.dirname(p), "ДНЕВНИК-архив.md")
out = ["=== ДНЕВНИК ПРОЕКТА (подтянут SessionStart-хуком) ===",
       f"Файл: {p} ({chars} знаков, полных записей журнала: {entries})"]
if os.path.exists(arch):
    out.append(f"Архив: {arch} — открывать только по правилу «Когда идти в архив» скила project-diary, искать запись по дате.")
out += ["Прочитай это ПЕРЕД действиями — здесь состояние проекта и важные вехи прошлых сессий.",
        "По ходу работы веди дневник через скил project-diary (вехи / решения с «почему» / блокеры / конец сессии). Не на каждую правку."]
if not over:
    out += ["-----8<----- содержимое ДНЕВНИК.md -----8<-----", t, "-----8<----- конец ДНЕВНИК.md -----8<-----"]
else:
    m = re.search(r"(?m)^##\s[^\n]*[Жж]урнал", t)
    head = t[:m.start()] if m else t
    cut = len(head) > HEAD_CAP
    head = head[:HEAD_CAP]
    out += [f"!!! ДНЕВНИК ПЕРЕПОЛНЕН: {chars} знаков (лимит {LIMIT_CHARS}), полных записей {entries} (лимит {LIMIT_ENTRIES}).",
            "!!! В этой сессии выполни «Ужатие» по скилу project-diary: до начала задачи, если она не срочная, иначе сразу после первого ответа пользователю. Всё вырезанное — сначала дословно в ДНЕВНИК-архив.md, важное — строками в «Ключевые вехи».",
            "-----8<----- верх ДНЕВНИК.md (журнал не показан) -----8<-----", head,
            f"-----8<----- (обрезано на {HEAD_CAP} знаках; полный файл: {p}) -----8<-----" if cut
            else f"-----8<----- (журнал не показан; полный файл: {p}) -----8<-----"]
print("\n".join(out))
PY
else
  echo "=== ДНЕВНИК ПРОЕКТА (подтянут SessionStart-хуком; python3 не найден — без контроля размера) ==="
  echo "Файл: $diary"
  echo "-----8<----- первые 200 строк ДНЕВНИК.md -----8<-----"
  head -n 200 "$diary"
  echo "-----8<----- (полный файл: $diary) -----8<-----"
fi
exit 0
