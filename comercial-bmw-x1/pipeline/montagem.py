# -*- coding: utf-8 -*-
"""Montagem do comercial BMW X1 — 16:9 master.
Gera clipes Ken Burns das fotos reais, junta com clipes IA, cartelas,
narração e trilha (regenerada com cortes exatos), mixa e exporta."""
import json, os, subprocess, sys

B = "/tmp/claude-0/-home-user-BeyondDreamsav/78ed0eab-b12b-59a0-bc8d-a7818570e628/scratchpad/bmw"
FOTOS = f"{B}/fotos"
MEDIA = "/home/user/BeyondDreamsav/comercial-bmw-x1/media"
CARDS = f"{B}/build/cards"
CLIPS = f"{B}/clips"
OUT = f"{B}/out"
FF = "ffmpeg"
FPS = 30
XF = 0.4  # crossfade

os.makedirs(CLIPS, exist_ok=True)
os.makedirs(OUT, exist_ok=True)


def _exists(dst):
    import os
    return os.path.exists(dst) and os.path.getsize(dst) > 100000

def run(cmd):
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stderr[-3000:])
        sys.exit(f"FALHOU: {cmd[:120]}")

def kb(src, dst, dur, z0, z1, tx=None, ty=None, precrop=None):
    """Ken Burns: zoom de z0 a z1 com alvo (tx,ty) em coords da origem."""
    if _exists(dst):
        print('skip', dst.split('/')[-1]); return
    frames = int(dur * FPS)
    vf = []
    if precrop:
        vf.append(precrop)
    zexpr = f"{z0}+({z1}-{z0})*on/{frames}"
    if tx is None:
        xe, ye = "iw/2-(iw/zoom)/2", "ih/2-(ih/zoom)/2"
    else:
        xe, ye = f"{tx}-(iw/zoom)/2", f"{ty}-(ih/zoom)/2"
    vf.append(
        f"zoompan=z='{zexpr}':x='{xe}':y='{ye}':d={frames}:s=1920x1080:fps={FPS}"
    )
    vf.append("format=yuv420p")
    run(f'{FF} -y -loop 1 -i "{src}" -vf "{",".join(vf)}" -t {dur} -r {FPS} '
        f'-c:v libx264 -preset fast -crf 16 -an "{dst}"')
    print("KB ok:", os.path.basename(dst))

def still(src, dst, dur):
    if _exists(dst):
        print('skip', dst.split('/')[-1]); return
    run(f'{FF} -y -loop 1 -i "{src}" -vf "scale=1920:1080,format=yuv420p" -t {dur} -r {FPS} '
        f'-c:v libx264 -preset fast -crf 16 -an "{dst}"')
    print("card ok:", os.path.basename(dst))

def norm(src, dst, dur):
    """Normaliza clipe IA para 1920x1080@30 sem audio, corta em dur."""
    if _exists(dst):
        print('skip', dst.split('/')[-1]); return
    run(f'{FF} -y -i "{src}" -vf "scale=1920:1080,fps={FPS},format=yuv420p" -t {dur} '
        f'-c:v libx264 -preset fast -crf 16 -an "{dst}"')
    print("norm ok:", os.path.basename(dst))

C43 = "crop=5712:3213:0:535"  # 4:3 -> 16:9 central

# ---------------- SEGMENTOS (ordem, arquivo, duração) ----------------
plan = [
    ("s1",   f"{CLIPS}/n_s1.mp4",  4.0),
    ("s2",   f"{CLIPS}/n_s2.mp4",  3.6),
    ("c1",   f"{CLIPS}/card_c1.mp4", 2.4),
    ("s3",   f"{CLIPS}/n_s3.mp4",  5.0),
    ("s4",   f"{CLIPS}/kb_s4.mp4", 4.4),
    ("s5a",  f"{CLIPS}/kb_s5a.mp4", 2.6),
    ("s5b",  f"{CLIPS}/kb_s5b.mp4", 2.6),
    ("s6a",  f"{CLIPS}/n_s6.mp4",  5.0),
    ("s6b",  f"{CLIPS}/kb_s6b.mp4", 2.0),
    ("s6c",  f"{CLIPS}/kb_s6c.mp4", 2.4),
    ("c2",   f"{CLIPS}/card_c2.mp4", 2.6),
    ("s7a",  f"{CLIPS}/n_s7a.mp4", 4.0),
    ("s7b",  f"{CLIPS}/n_s7b.mp4", 3.6),
    ("c3",   f"{CLIPS}/card_c3.mp4", 2.6),
    ("s8",   f"{CLIPS}/kb_s8.mp4", 4.4),
    ("s9",   f"{CLIPS}/kb_s9.mp4", 5.0),
    ("c4",   f"{CLIPS}/card_c4.mp4", 5.6),
    ("end",  f"{CLIPS}/card_end.mp4", 6.4),
]

def starts():
    """Início de cada segmento na timeline final (com xfades)."""
    t = 0.0
    table = {}
    for i, (name, _, dur) in enumerate(plan):
        table[name] = t
        t += dur - (XF if i < len(plan) - 1 else 0)
    return table, t

TABLE, TOTAL = starts()
print("timeline:", json.dumps({k: round(v, 2) for k, v in TABLE.items()}), "TOTAL", round(TOTAL, 2))

if "--plan-only" in sys.argv:
    with open(f"{B}/build/cuts.json", "w") as f:
        json.dump({"starts": TABLE, "total": TOTAL}, f)
    sys.exit(0)

# ---------------- 1) construir clipes ----------------
norm(f"{MEDIA}/s1.mp4",  f"{CLIPS}/n_s1.mp4", 4.0)
norm(f"{MEDIA}/s2.mp4",  f"{CLIPS}/n_s2.mp4", 3.6)
norm(f"{MEDIA}/s3.mp4",  f"{CLIPS}/n_s3.mp4", 5.0)
norm(f"{MEDIA}/s6.mp4",  f"{CLIPS}/n_s6.mp4", 5.0)
norm(f"{MEDIA}/s7a.mp4", f"{CLIPS}/n_s7a.mp4", 4.0)
norm(f"{MEDIA}/s7b.mp4", f"{CLIPS}/n_s7b.mp4", 3.6)

kb(f"{FOTOS}/IMG_1236.jpeg", f"{CLIPS}/kb_s4.mp4", 4.4, 1.0, 1.14)                      # frente garagem
kb(f"{FOTOS}/IMG_1237.jpeg", f"{CLIPS}/kb_s5a.mp4", 2.6, 1.05, 1.16, tx=2850, ty=1500)  # retrovisor carbono
kb(f"{FOTOS}/IMG_1218.jpeg", f"{CLIPS}/kb_s5b.mp4", 2.6, 1.0, 1.14, tx=3400, ty=1450)   # lanterna/ActiveFlex
kb(f"{FOTOS}/IMG_1188.jpeg", f"{CLIPS}/kb_s6b.mp4", 2.0, 1.05, 1.14, tx=3700, ty=2200)  # volante
kb(f"{FOTOS}/IMG_1186.jpeg", f"{CLIPS}/kb_s6c.mp4", 2.4, 1.08, 1.38, tx=2900, ty=2300)  # painel 111.400 km
kb(f"{FOTOS}/IMG_1216.jpeg", f"{CLIPS}/kb_s8.mp4", 4.4, 1.12, 1.0)                      # traseira 3/4 sol (zoom out)
kb(f"{FOTOS}/IMG_1234.jpeg", f"{CLIPS}/kb_s9.mp4", 5.0, 1.0, 1.10, precrop=C43)         # beauty garagem

still(f"{CARDS}/c1_h.png",  f"{CLIPS}/card_c1.mp4", 2.4)
still(f"{CARDS}/c2_h.png",  f"{CLIPS}/card_c2.mp4", 2.6)
still(f"{CARDS}/c3_h.png",  f"{CLIPS}/card_c3.mp4", 2.6)
still(f"{CARDS}/c4_h.png",  f"{CLIPS}/card_c4.mp4", 5.6)
still(f"{CARDS}/end_h.png", f"{CLIPS}/card_end.mp4", 6.4)

# ---------------- 2) concat com xfade ----------------
inputs = " ".join(f'-i "{p}"' for _, p, _ in plan)
fc = []
prev = "0:v"
offset = 0.0
for i in range(1, len(plan)):
    offset += plan[i - 1][2] - XF
    out = f"v{i}"
    fc.append(f"[{prev}][{i}:v]xfade=transition=fade:duration={XF}:offset={offset:.3f}[{out}]")
    prev = out
# selo "imagens reais" nos primeiros segundos
fc.append(f"[{len(plan)}:v]format=rgba,fade=in:st=0.8:d=0.6:alpha=1,fade=out:st=6.2:d=0.8:alpha=1[selo]")
fc.append(f"[{prev}][selo]overlay=0:0[final]")
filter_complex = ";".join(fc)
run(f'{FF} -y {inputs} -i "{CARDS}/selo_h.png" -filter_complex "{filter_complex}" '
    f'-map "[final]" -r {FPS} -c:v libx264 -preset medium -crf 17 -pix_fmt yuv420p "{OUT}/video_16x9_mudo.mp4"')
print("video mudo ok, total", TOTAL)

with open(f"{B}/build/cuts.json", "w") as f:
    json.dump({"starts": TABLE, "total": TOTAL}, f)
print("cuts.json salvo")
