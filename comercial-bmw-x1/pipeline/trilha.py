import numpy as np
from scipy.signal import butter, sosfilt
from scipy.io import wavfile

SR = 48000
DUR = 63.0
N = int(SR * DUR)
t = np.arange(N) / SR
rng = np.random.default_rng(7)

def env_points(points):
    """points: list of (time, value); linear interp over full length"""
    times = [p[0] for p in points]; vals = [p[1] for p in points]
    return np.interp(t, times, vals)

def sine(freq, phase=0.0):
    return np.sin(2*np.pi*freq*t + phase)

def lp(x, fc, order=2):
    sos = butter(order, fc/(SR/2), btype='low', output='sos')
    return sosfilt(sos, x)

def hp(x, fc, order=2):
    sos = butter(order, fc/(SR/2), btype='high', output='sos')
    return sosfilt(sos, x)

# ---------- DRONE (D root) ----------
drone_env = env_points([(0,0),(4,0.5),(7.5,0.55),(9.5,0.5),(31.5,0.5),(33.5,0.62),(47,0.68),(52,0.35),(57.5,0.30),(60,0.15),(63,0)])
vib = 1 + 0.003*np.sin(2*np.pi*0.11*t)
d2 = sine(73.42*vib) * 0.5
a2 = sine(110.0*vib, 1.1) * 0.32
d3 = sine(146.83*vib, 2.2) * 0.22
d1 = sine(36.71) * 0.35
breath = lp(rng.standard_normal(N), 420, 3) * 0.06
drone = (d1 + d2 + a2 + d3 + breath) * drone_env
drone = lp(drone, 900, 2)

# ---------- SHIMMER ----------
sh_env = env_points([(0,0),(9.5,0.0),(14.5,0.05),(23.5,0.08),(33.5,0.10),(42.5,0.13),(47,0.16),(52,0.20),(55,0.12),(57.5,0),(63,0)])
trem = 0.6 + 0.4*np.sin(2*np.pi*0.9*t)
shimmer = (sine(587.33)*0.4 + sine(880.0,0.7)*0.3 + sine(739.99,1.9)*0.3) * sh_env * trem * 0.35
shimmer = hp(shimmer, 400, 2)

# ---------- PULSE (100 bpm sub thump, 33.5-52) ----------
pulse = np.zeros(N)
beat = 60/100.0
tt = 33.5
while tt < 52.0:
    i0 = int(tt*SR); seg = int(0.28*SR)
    if i0+seg < N:
        te = np.arange(seg)/SR
        thump = np.sin(2*np.pi*(52*np.exp(-te*9))*te) * np.exp(-te*16)
        pulse[i0:i0+seg] += thump * 0.30
    tt += beat
pulse_env = env_points([(0,0),(33.5,0),(34,1),(51.5,1),(52,0),(63,0)])
pulse *= pulse_env

# ---------- IMPACTS ----------
def impact(at, power=1.0, bright=0.0):
    out = np.zeros(N)
    i0 = int(at*SR)
    seg = int(1.6*SR)
    if i0+seg >= N: seg = N-i0-1
    te = np.arange(seg)/SR
    boom = np.sin(2*np.pi*(48*np.exp(-te*6.5))*te) * np.exp(-te*5.5) * 1.0
    click = hp(rng.standard_normal(seg)*np.exp(-te*38), 1200, 2) * 0.12 * bright
    body = lp(rng.standard_normal(seg)*np.exp(-te*11), 300, 2) * 0.5
    out[i0:i0+seg] += (boom + body + click) * power
    return out

imp = np.zeros(N)
for at, p, b in [(7.5,0.85,0.5),(14.5,0.45,0.2),(23.5,0.45,0.2),(31.5,0.5,0.3),
                 (33.5,0.7,0.4),(40.5,0.5,0.3),(42.5,0.6,0.3),(47.0,0.5,0.2),
                 (52.0,1.0,0.7),(57.5,0.4,0.1)]:
    imp += impact(at, p, b)

# ---------- RISER (47-52) ----------
riser = np.zeros(N)
i0, i1 = int(47*SR), int(52*SR)
seg = i1-i0
te = np.arange(seg)/SR
prog = te/te[-1]
noise = rng.standard_normal(seg)
sos_sweep = butter(2, 0.25, btype='high', output='sos')
nz = sosfilt(sos_sweep, noise) * (0.02 + 0.20*prog**2)
tone = np.sin(2*np.pi*(200*(1+3*prog**1.6))*te) * 0.05 * prog
riser[i0:i1] = (nz + tone) * np.hanning(seg*2)[:seg]

# ---------- MIX ----------
mixL = drone*1.0 + shimmer*0.9 + pulse + imp + riser*0.9
mixR = drone*1.0 + np.roll(shimmer, int(0.011*SR))*0.9 + pulse + imp + np.roll(riser, int(0.007*SR))*0.9

# Light Schroeder-ish reverb via feedback delays
def verb(x):
    y = np.copy(x)
    for d, g in [(0.0297,0.28),(0.0371,0.24),(0.0411,0.21),(0.0437,0.18)]:
        di = int(d*SR)
        buf = np.zeros_like(x)
        buf[di:] = x[:-di]
        y += buf*g*0.5
    return y

mixL = mixL + verb(mixL)*0.25
mixR = mixR + verb(mixR)*0.25

peak = max(np.abs(mixL).max(), np.abs(mixR).max())
mixL = mixL/peak*0.45
mixR = mixR/peak*0.45
stereo = np.stack([mixL, mixR], axis=1)
wavfile.write("/tmp/claude-0/-home-user-BeyondDreamsav/78ed0eab-b12b-59a0-bc8d-a7818570e628/scratchpad/bmw/audio/trilha.wav", SR, (stereo*32767).astype(np.int16))
print("trilha.wav ok", stereo.shape)
