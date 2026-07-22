# -*- coding: utf-8 -*-
"""Trilha re-sincronizada aos cortes + narração posicionada + ducking + master."""
import json
import numpy as np
from scipy.signal import butter, sosfilt, resample_poly
from scipy.io import wavfile

B = "/tmp/claude-0/-home-user-BeyondDreamsav/78ed0eab-b12b-59a0-bc8d-a7818570e628/scratchpad/bmw"
MEDIA = "/home/user/BeyondDreamsav/comercial-bmw-x1/media"
SR = 48000

cuts = json.load(open(f"{B}/build/cuts.json"))
S = cuts["starts"]; TOTAL = cuts["total"]
N = int(SR * TOTAL)
t = np.arange(N) / SR
rng = np.random.default_rng(7)

def env_points(points):
    times = [p[0] for p in points]; vals = [p[1] for p in points]
    return np.interp(t, times, vals)

def sine(freq, phase=0.0):
    return np.sin(2 * np.pi * freq * t + phase)

def lp(x, fc, o=2):
    return sosfilt(butter(o, fc / (SR / 2), btype='low', output='sos'), x)

def hp(x, fc, o=2):
    return sosfilt(butter(o, fc / (SR / 2), btype='high', output='sos'), x)

# ---------- trilha ----------
c4 = S["c4"]; endt = S["end"]
drone_env = env_points([(0, 0), (3.5, .5), (S["c1"], .55), (S["s3"], .5), (S["c2"], .52),
                        (S["s7a"], .62), (S["s8"], .66), (c4, .34), (endt, .30), (endt + 2.5, .16), (TOTAL, 0)])
vib = 1 + 0.003 * np.sin(2 * np.pi * 0.11 * t)
drone = (sine(36.71) * .35 + sine(73.42 * vib) * .5 + sine(110.0 * vib, 1.1) * .32 +
         sine(146.83 * vib, 2.2) * .22 + lp(rng.standard_normal(N), 420, 3) * .06) * drone_env
drone = lp(drone, 900)

sh_env = env_points([(0, 0), (S["s3"], 0), (S["s4"], .05), (S["s6a"], .09), (S["s7a"], .11),
                     (S["s8"], .14), (c4 - .2, .2), (c4 + 2, .1), (endt, 0), (TOTAL, 0)])
trem = 0.6 + 0.4 * np.sin(2 * np.pi * 0.9 * t)
shimmer = hp((sine(587.33) * .4 + sine(880.0, .7) * .3 + sine(739.99, 1.9) * .3) * sh_env * trem * .35, 400)

pulse = np.zeros(N)
tt = S["s7a"]
while tt < c4:
    i0 = int(tt * SR); seg = int(0.28 * SR)
    if i0 + seg < N:
        te = np.arange(seg) / SR
        pulse[i0:i0 + seg] += np.sin(2 * np.pi * (52 * np.exp(-te * 9)) * te) * np.exp(-te * 16) * .3
    tt += 0.6

def impact(at, power=1.0, bright=0.0):
    out = np.zeros(N); i0 = int(at * SR); seg = min(int(1.6 * SR), N - i0 - 1)
    if seg <= 0: return out
    te = np.arange(seg) / SR
    boom = np.sin(2 * np.pi * (48 * np.exp(-te * 6.5)) * te) * np.exp(-te * 5.5)
    click = hp(rng.standard_normal(seg) * np.exp(-te * 38), 1200) * .12 * bright
    body = lp(rng.standard_normal(seg) * np.exp(-te * 11), 300) * .5
    out[i0:i0 + seg] += (boom + body + click) * power
    return out

imp = np.zeros(N)
for key, p, br in [("c1", .85, .5), ("s3", .5, .2), ("s4", .45, .2), ("s6a", .55, .3),
                   ("c2", .5, .3), ("s7a", .7, .4), ("c3", .5, .3), ("s8", .5, .2),
                   ("c4", 1.0, .7), ("end", .4, .1)]:
    imp += impact(S[key], p, br)

riser = np.zeros(N)
i0, i1 = int((c4 - 5) * SR), int(c4 * SR)
seg = i1 - i0; te = np.arange(seg) / SR; prog = te / te[-1]
nz = sosfilt(butter(2, 0.25, btype='high', output='sos'), rng.standard_normal(seg)) * (0.02 + 0.20 * prog ** 2)
tone = np.sin(2 * np.pi * (200 * (1 + 3 * prog ** 1.6)) * te) * 0.05 * prog
riser[i0:i1] = (nz + tone) * np.hanning(seg * 2)[:seg]

trilhaL = drone + shimmer + pulse + imp + riser
trilhaR = drone + np.roll(shimmer, int(0.011 * SR)) + pulse + imp + np.roll(riser, int(0.007 * SR))

def verb(x):
    y = np.copy(x)
    for d, g in [(0.0297, .28), (0.0371, .24), (0.0411, .21), (0.0437, .18)]:
        di = int(d * SR); buf = np.zeros_like(x); buf[di:] = x[:-di]; y += buf * g * .5
    return y

trilhaL += verb(trilhaL) * .25
trilhaR += verb(trilhaR) * .25
pk = max(np.abs(trilhaL).max(), np.abs(trilhaR).max())
trilhaL /= pk; trilhaR /= pk

# ---------- narração ----------
vo_sched = [
    ("vo1", S["s1"] + 0.7), ("vo2", S["s2"] + 0.3), ("vo3", S["s3"] + 0.5),
    ("vo4", S["s4"] + 0.3), ("vo5", S["s5a"] + 0.2), ("vo6", S["s6a"] + 0.3),
    ("vo7", S["s7a"] + 0.3), ("vo8", S["s8"] + 0.5), ("vo9", S["c4"] + 0.5),
]
vo = np.zeros(N)
for name, at in vo_sched:
    sr0, x = wavfile.read(f"{MEDIA}/{name}.wav")
    if x.dtype == np.int16:
        x = x.astype(np.float64) / 32768.0
    if x.ndim > 1:
        x = x.mean(axis=1)
    if sr0 != SR:
        x = resample_poly(x, SR, sr0)
    x = hp(x, 70)  # tira rumble
    i0 = int(at * SR)
    n = min(len(x), N - i0)
    vo[i0:i0 + n] += x[:n]
    print(name, "at", round(at, 2), "dur", round(len(x) / SR, 2))

vpk = np.abs(vo).max()
vo = vo / vpk * 0.85

# ---------- ducking ----------
env = np.abs(vo)
k = int(0.05 * SR)
kernel = np.ones(k) / k
env_s = np.convolve(env, kernel, mode='same')
env_s = np.maximum.reduce([np.roll(env_s, -int(0.08 * SR)), env_s])
gain = 1.0 - 0.62 * np.clip(env_s * 6, 0, 1)
gain = np.convolve(gain, np.ones(int(0.12 * SR)) / int(0.12 * SR), mode='same')

TRILHA_LVL = 0.42
mixL = trilhaL * gain * TRILHA_LVL + vo
mixR = trilhaR * gain * TRILHA_LVL + vo

pk = max(np.abs(mixL).max(), np.abs(mixR).max())
if pk > 0.94:
    mixL *= 0.94 / pk; mixR *= 0.94 / pk
master = np.stack([mixL, mixR], axis=1)
wavfile.write(f"{B}/audio/master.wav", SR, (master * 32767).astype(np.int16))
print("master.wav ok", round(TOTAL, 2), "s")
