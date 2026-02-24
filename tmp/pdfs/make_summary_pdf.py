from pathlib import Path

out = Path('output/pdf/stronglifts-5x5-summary.pdf')
out.parent.mkdir(parents=True, exist_ok=True)

# Letter page
PAGE_W, PAGE_H = 612, 792
LEFT = 46
TOP = 748
LINE = 14

sections = [
    ("Stronglifts 5x5 App - Repo Summary", "title"),
    ("", "blank"),
    ("WHAT IT IS", "h"),
    ("A Garmin Connect IQ watch app named \"Stronglifts 5x5\" for Forerunner 245 that guides strength sessions on-watch.", "p"),
    ("It runs a workout-state flow (warmup/rest/work/choice/summary) and stores lift weights between sessions.", "p"),
    ("", "blank"),
    ("WHO IT'S FOR", "h"),
    ("Primary persona: A lifter using Stronglifts 5x5 who wants to run and log sets directly from a Garmin Forerunner 245.", "p"),
    ("", "blank"),
    ("WHAT IT DOES", "h"),
    ("- Provides built-in Workout A and Workout B exercise plans with set counts and per-exercise progression increments.", "b"),
    ("- Alternates workouts across sessions using last workout state.", "b"),
    ("- Tracks elapsed time per segment with 1-second UI refresh.", "b"),
    ("- Supports rest/work transitions and per-set effort choice (Easy or Hard).", "b"),
    ("- Lets users edit current lift weight during rest/work (hold UP, +/- 2.5 kg, save with LAP).", "b"),
    ("- Persists profile data (last workout and exercise weights) in Application.Storage.", "b"),
    ("- Creates and saves a strength-training ActivityRecording session with lap markers and exit options.", "b"),
    ("", "blank"),
    ("HOW IT WORKS (ARCHITECTURE)", "h"),
    ("- App bootstrap: Stronglifts5x5App creates StrongliftsMainView plus StrongliftsInputDelegate.", "b"),
    ("- Input path: InputDelegate maps LAP/UP/DOWN/BACK and UP-hold to view handlers.", "b"),
    ("- Control logic: StrongliftsStateMachine owns state, timers, progression, and exit/save/discard behavior.", "b"),
    ("- Domain logic: StrongliftsWorkoutLogic defines templates, alternation helper, and kg formatting.", "b"),
    ("- Persistence: StrongliftsStorage loads/saves profile key \"stronglifts_5x5_profile_v1\".", "b"),
    ("- Data flow: Key event -> state transition -> display model -> render; save path -> storage + activity save.", "b"),
    ("", "blank"),
    ("HOW TO RUN (MINIMAL)", "h"),
    ("1. Build: monkeyc -f monkey.jungle -o bin/Stronglifts5x5.prg -y ~/.ciq/developer_key.der", "p"),
    ("2. Start simulator: .../connectiq-sdk-mac-8.4.1-2026-02-03-e9f77eeaa/bin/ConnectIQ.app/.../simulator", "p"),
    ("3. Run: .../bin/monkeydo .../stronglifts-5x5/bin/Stronglifts5x5.prg fr245", "p"),
    ("", "blank"),
    ("NOT FOUND IN REPO", "h"),
    ("- Automated tests or CI setup.", "b"),
    ("- Release/distribution instructions beyond local simulator run.", "b"),
]


def wrap_line(text: str, max_chars: int):
    words = text.split(' ')
    lines = []
    cur = ''
    for w in words:
        if not cur:
            cur = w
            continue
        if len(cur) + 1 + len(w) <= max_chars:
            cur += ' ' + w
        else:
            lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


def esc(s: str) -> str:
    return s.replace('\\', '\\\\').replace('(', '\\(').replace(')', '\\)')

ops = []
y = TOP
for text, kind in sections:
    if kind == 'blank':
        y -= LINE - 4
        continue

    font = '/F1 10 Tf'
    max_chars = 94
    if kind == 'title':
        font = '/F2 14 Tf'
        max_chars = 70
    elif kind == 'h':
        font = '/F2 11 Tf'
        max_chars = 80
    elif kind == 'b':
        font = '/F1 9.7 Tf'
        max_chars = 98

    for part in wrap_line(text, max_chars):
        if y < 38:
            break
        ops.append('BT')
        ops.append(font)
        ops.append(f'1 0 0 1 {LEFT} {y} Tm')
        ops.append(f'({esc(part)}) Tj')
        ops.append('ET')
        y -= LINE

content = '\n'.join(ops).encode('latin-1', 'replace')

objs = []
objs.append(b"1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
objs.append(b"2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n")
objs.append(
    f"3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {PAGE_W} {PAGE_H}] /Resources << /Font << /F1 4 0 R /F2 5 0 R >> >> /Contents 6 0 R >>\nendobj\n".encode('ascii')
)
objs.append(b"4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n")
objs.append(b"5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>\nendobj\n")
objs.append(f"6 0 obj\n<< /Length {len(content)} >>\nstream\n".encode('ascii') + content + b"\nendstream\nendobj\n")

pdf = bytearray(b"%PDF-1.4\n")
offsets = [0]
for i, obj in enumerate(objs, start=1):
    offsets.append(len(pdf))
    pdf.extend(obj)

xref_pos = len(pdf)
pdf.extend(f"xref\n0 {len(objs)+1}\n".encode('ascii'))
pdf.extend(b"0000000000 65535 f \n")
for i in range(1, len(objs)+1):
    pdf.extend(f"{offsets[i]:010d} 00000 n \n".encode('ascii'))

pdf.extend(
    f"trailer\n<< /Size {len(objs)+1} /Root 1 0 R >>\nstartxref\n{xref_pos}\n%%EOF\n".encode('ascii')
)

out.write_bytes(pdf)
print(out)
