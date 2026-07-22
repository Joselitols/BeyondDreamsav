# -*- coding: utf-8 -*-
from PIL import Image, ImageDraw, ImageFont
import os

B = "/tmp/claude-0/-home-user-BeyondDreamsav/78ed0eab-b12b-59a0-bc8d-a7818570e628/scratchpad/bmw"
FONT = os.path.join(B, "build", "Montserrat.ttf")
OUT = os.path.join(B, "build", "cards")
os.makedirs(OUT, exist_ok=True)

BG = (6, 6, 7)
FG = (245, 245, 245)
DIM = (168, 168, 172)
ACC = (200, 200, 205)

def font(size, weight=400):
    f = ImageFont.truetype(FONT, size)
    try:
        f.set_variation_by_axes([weight])
    except Exception:
        pass
    return f

def tracked(d, xy, text, f, fill, tracking=0.0, anchor_center_x=None):
    """Draw text with letter-spacing; tracking = extra px per char.
    If anchor_center_x is set, center the tracked block at that x."""
    widths = []
    for ch in text:
        bb = d.textbbox((0, 0), ch, font=f)
        widths.append(bb[2] - bb[0] if ch != ' ' else f.size * 0.32)
    total = sum(widths) + tracking * (len(text) - 1)
    x, y = xy
    if anchor_center_x is not None:
        x = anchor_center_x - total / 2
    for ch, w in zip(text, widths):
        if ch != ' ':
            d.text((x, y), ch, font=f, fill=fill)
        x += w + tracking
    return total

def line(d, x0, y, x1, color=(90, 90, 95), w=2):
    d.rectangle([x0, y, x1, y + w - 1], fill=color)

def make_card(name, W, H, painter):
    im = Image.new('RGB', (W, H), BG)
    d = ImageDraw.Draw(im)
    painter(d, W, H)
    im.save(os.path.join(OUT, name))
    print(name)

# ---------- C1: título ----------
def c1(d, W, H, s=1.0):
    cx = W / 2
    y0 = H * 0.40
    tracked(d, (0, y0 - 60 * s), "BMW X1", font(int(110 * s), 600), FG, tracking=26 * s, anchor_center_x=cx)
    tracked(d, (0, y0 + 78 * s), "xDrive28i", font(int(64 * s), 300), FG, tracking=18 * s, anchor_center_x=cx)
    line(d, cx - 150 * s, y0 + 190 * s, cx + 150 * s, (120, 120, 125), 2)
    tracked(d, (0, y0 + 220 * s), "ACTIVEFLEX", font(int(34 * s), 500), DIM, tracking=22 * s, anchor_center_x=cx)

# ---------- C2 / C3: specs ----------
def specs(itens):
    def p(d, W, H, s=1.0):
        cx = W / 2
        n = len(itens)
        block = 150 * s
        y = H / 2 - (n * block) / 2 + 20 * s
        for i, (big, small) in enumerate(itens):
            tracked(d, (0, y), big, font(int(56 * s), 500), FG, tracking=16 * s, anchor_center_x=cx)
            tracked(d, (0, y + 72 * s), small, font(int(26 * s), 300), DIM, tracking=10 * s, anchor_center_x=cx)
            y += block
    return p

c2p = specs([("COURO", "bancos em couro preto"),
             ("NAVEGAÇÃO", "central multimídia integrada"),
             ("AUTOMÁTICO", "câmbio com modo sport")])
c3p = specs([("xDRIVE", "tração integral"),
             ("2.0 TWINPOWER TURBO", "245 cv · xDrive28i"),
             ("ACTIVEFLEX", "etanol ou gasolina")])

# ---------- C4: CTA ----------
def c4(d, W, H, s=1.0):
    cx = W / 2
    y0 = H * 0.36
    tracked(d, (0, y0), "TEST DRIVE", font(int(64 * s), 600), FG, tracking=30 * s, anchor_center_x=cx)
    line(d, cx - 170 * s, y0 + 110 * s, cx + 170 * s, (120, 120, 125), 2)
    tracked(d, (0, y0 + 150 * s), "(11) 99846-1000", font(int(84 * s), 500), FG, tracking=8 * s, anchor_center_x=cx)
    tracked(d, (0, y0 + 280 * s), "LIGUE OU CHAME NO WHATSAPP", font(int(28 * s), 400), DIM, tracking=12 * s, anchor_center_x=cx)

# ---------- END ----------
def endc(d, W, H, s=1.0):
    cx = W / 2
    y0 = H * 0.34
    tracked(d, (0, y0), "BMW X1", font(int(84 * s), 600), FG, tracking=22 * s, anchor_center_x=cx)
    tracked(d, (0, y0 + 108 * s), "xDrive28i ActiveFlex", font(int(44 * s), 300), FG, tracking=10 * s, anchor_center_x=cx)
    line(d, cx - 150 * s, y0 + 190 * s, cx + 150 * s, (120, 120, 125), 2)
    tracked(d, (0, y0 + 226 * s), "(11) 99846-1000", font(int(56 * s), 500), FG, tracking=6 * s, anchor_center_x=cx)
    tracked(d, (0, y0 + 320 * s), "IMAGENS REAIS DO VEÍCULO", font(int(24 * s), 400), DIM, tracking=12 * s, anchor_center_x=cx)

# 16:9
make_card("c1_h.png", 1920, 1080, lambda d, W, H: c1(d, W, H, 1.0))
make_card("c2_h.png", 1920, 1080, lambda d, W, H: c2p(d, W, H, 1.0))
make_card("c3_h.png", 1920, 1080, lambda d, W, H: c3p(d, W, H, 1.0))
make_card("c4_h.png", 1920, 1080, lambda d, W, H: c4(d, W, H, 1.0))
make_card("end_h.png", 1920, 1080, lambda d, W, H: endc(d, W, H, 1.0))
# 9:16
make_card("c1_v.png", 1080, 1920, lambda d, W, H: c1(d, W, H, 0.82))
make_card("c2_v.png", 1080, 1920, lambda d, W, H: c2p(d, W, H, 0.82))
make_card("c3_v.png", 1080, 1920, lambda d, W, H: c3p(d, W, H, 0.82))
make_card("c4_v.png", 1080, 1920, lambda d, W, H: c4(d, W, H, 0.82))
make_card("end_v.png", 1080, 1920, lambda d, W, H: endc(d, W, H, 0.82))

# Selo "imagens reais" com alpha (canto inferior esquerdo)
for name, W, H in [("selo_h.png", 1920, 1080), ("selo_v.png", 1080, 1920)]:
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    f = font(26 if W > H else 24, 500)
    d.text((int(W * 0.045), int(H * 0.90)), "IMAGENS 100% REAIS DO VEÍCULO", font=f, fill=(255, 255, 255, 210))
    im.save(os.path.join(OUT, name))
    print(name)
