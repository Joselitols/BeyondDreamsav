# -*- coding: utf-8 -*-
"""Montagem 9:16 — Ken Burns verticais das fotos originais + cartelas verticais.
Mesma timeline e mesmo master de audio do 16:9."""
import json, os, subprocess, sys
from PIL import Image

B = "/tmp/claude-0/-home-user-BeyondDreamsav/78ed0eab-b12b-59a0-bc8d-a7818570e628/scratchpad/bmw"
FOTOS = f"{B}/fotos"
CARDS = f"{B}/build/cards"
CLIPS = f"{B}/clips"
OUT = f"{B}/out"
FF = "ffmpeg"
FPS = 30
XF = 0.4

def _exists(dst):
    return os.path.exists(dst) and os.path.getsize(dst) > 100000

def run(cmd):
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stderr[-2500:])
        sys.exit(f"FALHOU: {cmd[:120]}")

def dims(src):
    with Image.open(src) as im:
        return im.size

def kbv(src, dst, dur, z0, z1, cx, ty=None):
    """Ken Burns vertical: precrop 9:16 centrado em cx, depois zoompan."""
    if _exists(dst):
        print('skip', os.path.basename(dst)); return
    W, H = dims(src)
    cw = int(H * 9 / 16)
    if cw > W:  # imagem ja é mais estreita que 9:16
        cw = W
    x0 = max(0, min(int(cx - cw / 2), W - cw))
    frames = int(dur * FPS)
    zexpr = f"{z0}+({z1}-{z0})*on/{frames}"
    if ty is None:
        xe, ye = "iw/2-(iw/zoom)/2", "ih/2-(ih/zoom)/2"
    else:
        txc = int(cx - x0)
        xe, ye = f"{txc}-(iw/zoom)/2", f"{ty}-(ih/zoom)/2"
    vf = (f"crop={cw}:{H}:{x0}:0,"
          f"zoompan=z='{zexpr}':x='{xe}':y='{ye}':d={frames}:s=1080x1920:fps={FPS},"
          f"format=yuv420p")
    run(f'{FF} -y -loop 1 -i "{src}" -vf "{vf}" -t {dur} -r {FPS} '
        f'-c:v libx264 -preset fast -crf 16 -an "{dst}"')
    print("KBv ok:", os.path.basename(dst))

def panv(src, dst, dur, x_from, x_to):
    """Pan lateral vertical via crop com expressão temporal."""
    if _exists(dst):
        print('skip', os.path.basename(dst)); return
    W, H = dims(src)
    cw = int(H * 9 / 16)
    xa = max(0, min(x_from - cw // 2, W - cw))
    xb = max(0, min(x_to - cw // 2, W - cw))
    vf = (f"crop={cw}:{H}:x='{xa}+({xb}-{xa})*t/{dur}':y=0,"
          f"scale=1080:1920,format=yuv420p")
    run(f'{FF} -y -loop 1 -i "{src}" -vf "{vf}" -t {dur} -r {FPS} '
        f'-c:v libx264 -preset fast -crf 16 -an "{dst}"')
    print("PANv ok:", os.path.basename(dst))

def still(src, dst, dur):
    if _exists(dst):
        print('skip', os.path.basename(dst)); return
    run(f'{FF} -y -loop 1 -i "{src}" -vf "scale=1080:1920,format=yuv420p" -t {dur} -r {FPS} '
        f'-c:v libx264 -preset fast -crf 16 -an "{dst}"')
    print("cardv ok:", os.path.basename(dst))

plan = [
    ("s1",  f"{CLIPS}/v_s1.mp4",  4.0),
    ("s2",  f"{CLIPS}/v_s2.mp4",  3.6),
    ("c1",  f"{CLIPS}/vcard_c1.mp4", 2.4),
    ("s3",  f"{CLIPS}/v_s3.mp4",  5.0),
    ("s4",  f"{CLIPS}/v_s4.mp4",  4.4),
    ("s5a", f"{CLIPS}/v_s5a.mp4", 2.6),
    ("s5b", f"{CLIPS}/v_s5b.mp4", 2.6),
    ("s6a", f"{CLIPS}/v_s6a.mp4", 5.0),
    ("s6b", f"{CLIPS}/v_s6b.mp4", 2.0),
    ("s6c", f"{CLIPS}/v_s6c.mp4", 2.4),
    ("c2",  f"{CLIPS}/vcard_c2.mp4", 2.6),
    ("s7a", f"{CLIPS}/v_s7a.mp4", 4.0),
    ("s7b", f"{CLIPS}/v_s7b.mp4", 3.6),
    ("c3",  f"{CLIPS}/vcard_c3.mp4", 2.6),
    ("s8",  f"{CLIPS}/v_s8.mp4", 4.4),
    ("s9",  f"{CLIPS}/v_s9.mp4", 5.0),
    ("c4",  f"{CLIPS}/vcard_c4.mp4", 5.6),
    ("end", f"{CLIPS}/vcard_end.mp4", 6.4),
]

kbv(f"{FOTOS}/IMG_1233.jpeg", f"{CLIPS}/v_s1.mp4", 4.0, 1.0, 1.14, cx=2450)
kbv(f"{FOTOS}/IMG_1239.jpeg", f"{CLIPS}/v_s2.mp4", 3.6, 1.05, 1.16, cx=2856)
kbv(f"{FOTOS}/IMG_1198.jpeg", f"{CLIPS}/v_s3.mp4", 5.0, 1.0, 1.12, cx=3250)
kbv(f"{FOTOS}/IMG_1195.jpeg", f"{CLIPS}/v_s4.mp4", 4.4, 1.0, 1.12, cx=1606)
kbv(f"{FOTOS}/IMG_1237.jpeg", f"{CLIPS}/v_s5a.mp4", 2.6, 1.05, 1.16, cx=2850)
kbv(f"{FOTOS}/IMG_1218.jpeg", f"{CLIPS}/v_s5b.mp4", 2.6, 1.0, 1.14, cx=3300)
kbv(f"{FOTOS}/IMG_1190.jpeg", f"{CLIPS}/v_s6a.mp4", 5.0, 1.0, 1.15, cx=2950)
kbv(f"{FOTOS}/IMG_1188.jpeg", f"{CLIPS}/v_s6b.mp4", 2.0, 1.05, 1.14, cx=3650)
kbv(f"{FOTOS}/IMG_1186.jpeg", f"{CLIPS}/v_s6c.mp4", 2.4, 1.1, 1.42, cx=2900, ty=2300)
panv(f"{FOTOS}/IMG_1192.jpeg", f"{CLIPS}/v_s7a.mp4", 4.0, 1500, 3400)
kbv(f"{FOTOS}/IMG_1193.jpeg", f"{CLIPS}/v_s7b.mp4", 3.6, 1.14, 1.0, cx=2850)
kbv(f"{FOTOS}/IMG_1216.jpeg", f"{CLIPS}/v_s8.mp4", 4.4, 1.12, 1.0, cx=3000)
kbv(f"{FOTOS}/IMG_1234.jpeg", f"{CLIPS}/v_s9.mp4", 5.0, 1.0, 1.10, cx=2450)

still(f"{CARDS}/c1_v.png",  f"{CLIPS}/vcard_c1.mp4", 2.4)
still(f"{CARDS}/c2_v.png",  f"{CLIPS}/vcard_c2.mp4", 2.6)
still(f"{CARDS}/c3_v.png",  f"{CLIPS}/vcard_c3.mp4", 2.6)
still(f"{CARDS}/c4_v.png",  f"{CLIPS}/vcard_c4.mp4", 5.6)
still(f"{CARDS}/end_v.png", f"{CLIPS}/vcard_end.mp4", 6.4)

inputs = " ".join(f'-i "{p}"' for _, p, _ in plan)
fc = []
prev = "0:v"
offset = 0.0
for i in range(1, len(plan)):
    offset += plan[i - 1][2] - XF
    fc.append(f"[{prev}][{i}:v]xfade=transition=fade:duration={XF}:offset={offset:.3f}[v{i}]")
    prev = f"v{i}"
fc.append(f"[{len(plan)}:v]format=rgba,fade=in:st=0.8:d=0.6:alpha=1,fade=out:st=6.2:d=0.8:alpha=1[selo]")
fc.append(f"[{prev}][selo]overlay=0:0[final]")
run(f'{FF} -y {inputs} -i "{CARDS}/selo_v.png" -filter_complex "{";".join(fc)}" '
    f'-map "[final]" -r {FPS} -c:v libx264 -preset medium -crf 17 -pix_fmt yuv420p "{OUT}/video_9x16_mudo.mp4"')
print("video 9x16 mudo ok")
