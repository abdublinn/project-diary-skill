#!/usr/bin/env bash
# project-diary SessionStart hook (macOS/Linux). Mirrors the .ps1 logic.
# Job: READ + SIZE CONTROL + FRESHNESS. Within limits — inject ДНЕВНИК.md in full.
# Over the limits (chars / full journal entries) — inject only the top part (Снимок,
# Осторожно, Ориентир, Ключевые вехи), the headers of the hidden journal entries and
# a directive to run «Ужатие». Always prints a short card of writing rules before the
# diary. Warns when «Снимок» is older than the last journal entry and when the diary
# has not been updated for more than STALE_DAYS. No diary up the tree but diaries in
# subfolders (umbrella folder) — lists them. Otherwise silent. Never break the session.

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

if [ -n "$diary" ] && [ ! -s "$diary" ]; then
  exit 0
fi

if command -v python3 >/dev/null 2>&1; then
  python3 - "$diary" "$PWD" "$(cd "$(dirname "$0")" && pwd)" <<'PY' || echo "Хук project-diary не сработал: найди ДНЕВНИК.md в рабочей папке или выше по дереву и прочитай его сам до первого действия."
import datetime, os, re, sys
sys.stdout.reconfigure(encoding="utf-8")
LIMIT_CHARS, LIMIT_ENTRIES, HEAD_CAP = 24000, 12, 12000
STALE_DAYS, HIDDEN_MAX, SUB_MAX, PROBE_MAX = 30, 20, 25, 600
SKIP = {"node_modules", "__pycache__", "venv", "_archived", "_extracted", "templates"}
try:  # карточка правил — один файл на оба хука, рядом со скриптом
    RULES = [open(os.path.join(sys.argv[3], "project-diary-rules-card.txt"), encoding="utf-8-sig").read().strip()]
except (OSError, IndexError):
    RULES = ["ПРАВИЛА ЗАПИСИ: файл карточки не найден — перед первой правкой дневника вызови Skill project-diary и следуй ему."]
p, start = sys.argv[1], sys.argv[2]


def subdirs(path):
    try:
        with os.scandir(path) as it:
            return sorted((e for e in it if e.is_dir() and not e.name.startswith(".") and e.name not in SKIP),
                          key=lambda e: e.name)
    except OSError:
        return []


if not p:
    # Umbrella folder: no diary here, but project diaries up to two levels below.
    base = os.path.abspath(start)
    if base in (os.path.expanduser("~"), os.path.abspath(os.sep)):
        sys.exit(0)
    found, probed, level1 = [], 0, []
    for d1 in subdirs(base):
        if probed >= PROBE_MAX:
            break
        probed += 1
        level1.append(d1.path)
        f = os.path.join(d1.path, "ДНЕВНИК.md")
        if os.path.isfile(f):
            found.append(f)
    for d1 in level1:
        if probed >= PROBE_MAX:
            break
        for d2 in subdirs(d1):
            if probed >= PROBE_MAX:
                break
            probed += 1
            f = os.path.join(d2.path, "ДНЕВНИК.md")
            if os.path.isfile(f):
                found.append(f)
    if not found:
        sys.exit(0)
    found.sort(key=os.path.getmtime, reverse=True)
    out = ["=== ДНЕВНИКИ ПОДПРОЕКТОВ (SessionStart-хук project-diary) ===",
           f"В папке {base} своего ДНЕВНИК.md нет, но в подпапках есть дневники проектов: {len(found)}.",
           "Когда станет ясно, в каком подпроекте идёт работа, прочитай его ДНЕВНИК.md ДО действий и веди его по скилу project-diary."]
    for f in found[:SUB_MAX]:
        day = datetime.date.fromtimestamp(os.path.getmtime(f)).isoformat()
        out.append(f"- {os.path.relpath(f, base)} (обновлён {day})")
    if len(found) > SUB_MAX:
        out.append(f"... и ещё {len(found) - SUB_MAX} более старых.")
    print("\n".join(out))
    sys.exit(0)

t = open(p, encoding="utf-8-sig").read()
chars = len(t)
hits = list(re.finditer(r"(?m)^###\s+(\d{4}-\d{2}-\d{2})[^\r\n]*", t))
entries = len(hits)
over = chars > LIMIT_CHARS or entries > LIMIT_ENTRIES
ms = re.search(r"Снимок[^\r\n]*?Обновлено:?\s*(\d{4}-\d{2}-\d{2})", t)
snap = ms.group(1) if ms else None
last = max((h.group(1) for h in hits), default=None)
fresh = max([d for d in (snap, last) if d], default=None)
if not fresh:
    mu = re.search(r"(?m)^updated:\s*(\d{4}-\d{2}-\d{2})", t)
    fresh = mu.group(1) if mu else None
arch = os.path.join(os.path.dirname(p), "ДНЕВНИК-архив.md")
out = ["=== ДНЕВНИК ПРОЕКТА (подтянут SessionStart-хуком) ===",
       f"Файл: {p} ({chars} знаков, полных записей журнала: {entries})"]
if os.path.exists(arch):
    out.append(f"Архив: {arch} — открывать только по правилу «Когда идти в архив» скила project-diary, искать запись по дате.")
out += ["Прочитай это ПЕРЕД действиями — здесь состояние проекта и важные вехи прошлых сессий.",
        "По ходу работы веди дневник по карточке ниже и скилу project-diary. Не на каждую правку."]
out += RULES
if snap and last and snap < last:
    out.append(f"!!! «Снимок» обновлён {snap}, а последняя запись журнала — {last}: верх дневника отстаёт. Сверь его с верхними записями журнала, при первой вехе перезапиши «Снимок».")
if fresh:
    try:
        age = (datetime.date.today() - datetime.date.fromisoformat(fresh)).days
    except ValueError:
        age = 0
    if age > STALE_DAYS:
        out.append(f"!!! Дневник не обновлялся {age} дн. (с {fresh}). «Следующий шаг» и сроки в «Снимке» могли устареть: до действий сверь их с фактом (свежие файлы проекта, владелец).")
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
    if entries:
        out.append("Заголовки записей журнала, которые не показаны (свежие решения и отмены — здесь; нужную запись прочитай в файле по дате):")
        out += ["  " + h.group(0).strip() for h in hits[:HIDDEN_MAX]]
        if entries > HIDDEN_MAX:
            out.append(f"  ... и ещё {entries - HIDDEN_MAX}.")
print("\n".join(out))
PY
elif [ -n "$diary" ]; then
  echo "=== ДНЕВНИК ПРОЕКТА (подтянут SessionStart-хуком; python3 не найден — без контроля размера) ==="
  echo "Файл: $diary"
  echo "-----8<----- первые 200 строк ДНЕВНИК.md -----8<-----"
  head -n 200 "$diary"
  echo "-----8<----- (полный файл: $diary) -----8<-----"
fi
exit 0
