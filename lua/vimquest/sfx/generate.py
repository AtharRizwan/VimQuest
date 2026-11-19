# Synthesizes VimQuest's 8-bit sound effects as WAV files (standard library only)
import math
import os
import random
import struct
import wave

SR = 22050
OUT = os.path.dirname(os.path.abspath(__file__))
random.seed(7)


def note(name):
    names = {'C': -9, 'D': -7, 'E': -5, 'F': -4, 'G': -2, 'A': 0, 'B': 2}
    semis = names[name[0]] + (1 if '#' in name else 0) - (1 if name[1] == 'b' else 0)
    return 440 * 2 ** ((semis + (int(name[-1]) - 4) * 12) / 12)


def osc(kind, phase, duty=0.5):
    p = phase % 1.0
    if kind == 'square':
        return 1.0 if p < duty else -1.0
    if kind == 'triangle':
        return 4 * p - 1 if p < 0.5 else 3 - 4 * p
    if kind == 'saw':
        return 2 * p - 1
    return math.sin(2 * math.pi * p)


def tone(freq, dur, kind='square', vol=0.5, attack=0.003, release=0.04, duty=0.5, vibrato=(0, 0)):
    n = int(SR * dur)
    out, phase = [], 0.0
    for i in range(n):
        t = i / SR
        f = freq(t) if callable(freq) else freq
        if vibrato[0]:
            f *= 1 + vibrato[1] * math.sin(2 * math.pi * vibrato[0] * t)
        phase += f / SR
        e = min(1.0, t / attack) if attack else 1.0
        e *= min(1.0, (dur - t) / release) if release else 1.0
        out.append(osc(kind, phase, duty) * vol * e)
    return out


def noise(dur, vol=0.5, smooth=0.0, attack=0.002, decay=None):
    n = int(SR * dur)
    out, prev = [], 0.0
    for i in range(n):
        t = i / SR
        prev = prev * smooth + random.uniform(-1, 1) * (1 - smooth)
        e = min(1.0, t / attack) if attack else 1.0
        e *= math.exp(-t / decay) if decay else min(1.0, (dur - t) / 0.03)
        out.append(prev * vol * e)
    return out


def sweep(f0, f1, dur, curve=1.0):
    return lambda t: f0 + (f1 - f0) * (min(t / dur, 1.0) ** curve)


def cat(*parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


def silence(dur):
    return [0.0] * int(SR * dur)


def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]


def echo(sig, delay=0.12, fb=0.4, times=3):
    d = int(SR * delay)
    out = sig + [0.0] * (d * times)
    for k in range(1, times + 1):
        g = fb ** k
        for i, s in enumerate(sig):
            out[i + d * k] += s * g
    return out


def melody(notes, kind='square', vol=0.35, duty=0.5, gap=0.0):
    return cat(*[cat(tone(note(n) if isinstance(n, str) else n, d, kind, vol, duty=duty), silence(gap)) for n, d in notes])


def save(name, sig, peak=0.8):
    m = max(1e-9, max(abs(s) for s in sig))
    scale = peak / m
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, s * scale)) * 32767)) for s in sig))


# Interface
save('blip', tone(1250, 0.018, 'square', 0.12, release=0.01, duty=0.25), 0.15)
save('tick', tone(900, 0.03, 'square', 0.2, release=0.015, duty=0.25), 0.25)
save('select', melody([('E5', 0.06), ('B5', 0.12)], vol=0.3, duty=0.25), 0.4)
save('page', tone(sweep(420, 640, 0.05), 0.05, 'triangle', 0.4), 0.35)
save('ok', melody([('C6', 0.045), ('E6', 0.045), ('G6', 0.1)], 'triangle', 0.5), 0.5)
save('error', mix(tone(140, 0.16, 'square', 0.3, duty=0.3), tone(147, 0.16, 'square', 0.3, duty=0.3)), 0.4)

# Movement and pickups
save('step', noise(0.03, 0.5, smooth=0.85, decay=0.01), 0.18)
save('bonk', mix(tone(sweep(320, 70, 0.14), 0.14, 'square', 0.4), noise(0.06, 0.3, smooth=0.7, decay=0.02)), 0.5)
save('coin', cat(tone(note('B5'), 0.07, 'square', 0.35, duty=0.25, release=0.005), tone(note('E6'), 0.32, 'square', 0.35, duty=0.25, release=0.3)), 0.45)
save('snap', mix(noise(0.05, 0.9, smooth=0.0, decay=0.012), tone(sweep(200, 50, 0.15), 0.15, 'sine', 0.7)), 0.7)
save('squeak', tone(lambda t: 2200 + 900 * math.sin(t * 40), 0.16, 'sine', 0.35, vibrato=(30, 0.04)), 0.35)
save('splash', mix(noise(0.55, 0.6, smooth=0.6, decay=0.18), *[cat(silence(0.05 + 0.07 * k), tone(sweep(700 + 120 * k, 1300, 0.04), 0.04, 'sine', 0.25)) for k in range(5)]), 0.55)

# Progress
save('objective', melody([('C5', 0.06), ('E5', 0.06), ('G5', 0.06), ('C6', 0.18)], vol=0.3, duty=0.25), 0.45)
save('fanfare', echo(cat(
    melody([('G5', 0.1), ('C6', 0.1), ('E6', 0.1), ('G6', 0.16), ('E6', 0.08), ('G6', 0.5)], vol=0.3, duty=0.25),
), 0.14, 0.25, 2), 0.5)
save('victory', echo(mix(
    melody([('C5', 0.16), ('C5', 0.08), ('C5', 0.08), ('G5', 0.3), ('E5', 0.16), ('G5', 0.16), ('C6', 0.7)], vol=0.3, duty=0.25),
    melody([('E4', 0.16), ('E4', 0.08), ('E4', 0.08), ('B4', 0.3), ('G4', 0.16), ('B4', 0.16), ('E5', 0.7)], 'triangle', vol=0.35),
), 0.16, 0.25, 2), 0.55)

# Mystery
save('rune', echo(mix(
    cat(*[tone(note(n), 0.16, 'sine', 0.35, vibrato=(6, 0.01), release=0.12) for n in ['A4', 'C5', 'E5', 'A5', 'C6', 'E6']]),
    tone(note('A3'), 1.0, 'triangle', 0.2, attack=0.2, release=0.5),
), 0.18, 0.45, 4), 0.5)
save('whisper', [s * (0.5 + 0.5 * math.sin(i / SR * 2 * math.pi * 1.7)) for i, s in enumerate(noise(1.6, 0.5, smooth=0.93, attack=0.4, decay=0.9))], 0.3)
save('door', mix(
    tone(lambda t: 70 + 25 * math.sin(t * 9) + random.uniform(-8, 8), 0.9, 'saw', 0.35, attack=0.05, release=0.2),
    cat(silence(0.85), noise(0.2, 0.8, smooth=0.8, decay=0.06)),
), 0.55)

# Horror and danger
save('static', [s * (1 if random.random() > 0.3 else 0.2) for s in noise(0.22, 0.7, smooth=0.1, decay=0.12)], 0.35)
save('heartbeat', cat(
    tone(sweep(70, 40, 0.09), 0.09, 'sine', 0.9, release=0.06), silence(0.13),
    tone(sweep(60, 35, 0.11), 0.11, 'sine', 0.8, release=0.08),
), 0.75)
save('scare', mix(
    tone(sweep(note('A4'), note('A5'), 0.9, 0.5), 0.9, 'saw', 0.4, attack=0.005, release=0.3, vibrato=(11, 0.03)),
    tone(sweep(note('Eb5'), note('Eb6'), 0.9, 0.5), 0.9, 'saw', 0.4, attack=0.005, release=0.3, vibrato=(13, 0.03)),
    tone(sweep(60, 30, 0.9), 0.9, 'square', 0.4, release=0.4),
    noise(0.5, 0.5, smooth=0.2, decay=0.15),
), 0.75)
save('caught', mix(
    tone(sweep(900, 90, 0.6, 0.6), 0.6, 'saw', 0.4, vibrato=(18, 0.08), release=0.2),
    noise(0.35, 0.4, smooth=0.3, decay=0.12),
), 0.7)
save('clock', mix(noise(0.012, 0.8, smooth=0.0, decay=0.004), tone(2400, 0.012, 'sine', 0.3)), 0.35)
save('whoosh', [s for s in noise(0.75, 0.7, smooth=0.9, attack=0.2, decay=0.25)], 0.5)

# Battle
save('hit', mix(noise(0.3, 0.8, smooth=0.4, decay=0.09), tone(sweep(260, 45, 0.28), 0.28, 'square', 0.5)), 0.7)
save('zap', cat(tone(sweep(200, 1600, 0.12, 2), 0.12, 'square', 0.35, duty=0.3), tone(sweep(1600, 300, 0.18), 0.18, 'square', 0.3, duty=0.3)), 0.5)
save('giggle', cat(*[cat(tone(sweep(1300, 1700, 0.06), 0.06, 'square', 0.25, duty=0.2), silence(0.05)) for _ in range(4)]), 0.35)

# Act II
save('bong', echo(mix(*[tone(110 * k, 1.6, 'sine', 0.5 / k, attack=0.005, release=1.4) for k in (1, 2.4, 3, 4.2)]), 0.3, 0.35, 2), 0.6)
save('clang', mix(*[tone(f0, 0.5, 'sine', 0.4, attack=0.001, release=0.45) for f0 in (523, 1189, 1873, 2711)], noise(0.04, 0.6, decay=0.01)), 0.55)

# Title theme: a looping chiptune in A minor (lead, arpeggio, bass, drums)
BPM = 112
E8 = 60 / BPM / 2
lead = [
    'E5:2 A5:2 G5:1 E5:1 C5:2', 'D5:2 C5:1 A4:1 C5:4', 'E5:2 G5:2 C6:2 B5:1 G5:1', 'A5:3 G5:1 D5:4',
    'E5:2 A5:2 B5:1 C6:1 B5:2', 'A5:2 F5:2 C6:3 A5:1', 'G#5:2 B5:2 E5:2 G#5:2', 'B5:6 R:2',
    'F5:3 E5:1 D5:2 A4:2', 'C5:3 B4:1 A4:4', 'A4:2 C5:2 F5:2 E5:1 D5:1', 'D5:3 B4:1 G4:4',
    'A4:1 C5:1 E5:1 A5:1 G5:2 E5:2', 'F5:1 A5:1 C6:1 A5:1 G5:2 F5:2', 'E5:2 G#5:2 B5:2 D6:2', 'C6:2 B5:1 G#5:1 A5:4',
]
chords = ['A3 C4 E4', 'F3 A3 C4', 'C4 E4 G4', 'G3 B3 D4', 'A3 C4 E4', 'F3 A3 C4', 'E3 G#3 B3', 'E3 G#3 B3',
          'D3 F3 A3', 'A3 C4 E4', 'F3 A3 C4', 'G3 B3 D4', 'A3 C4 E4', 'F3 A3 C4', 'E3 G#3 B3', 'A3 C4 E4']


def fit(sig, dur):
    n = int(SR * dur)
    return (sig + [0.0] * n)[:n]


def bar_lead(bar):
    out = []
    for tok in bar.split():
        n, k = tok.split(':')
        d = E8 * int(k)
        out += silence(d) if n == 'R' else tone(note(n), d, 'square', 0.3, attack=0.004, release=0.05, duty=0.25, vibrato=(5, 0.006))
    return out


def bar_rest(chord):
    ns = [note(n) for n in chord.split()]
    arp = cat(*[tone(ns[i % 3] * 2, E8 / 2, 'square', 0.08, release=0.02, duty=0.125) for i in range(16)])
    bass = cat(*[tone(ns[0] / 2 * (2 if i % 2 else 1), E8, 'triangle', 0.45, release=0.03) for i in range(8)])
    kick = tone(sweep(110, 40, 0.12), 0.12, 'sine', 0.6, release=0.05)
    hat = noise(0.03, 0.12, decay=0.01)
    drums = cat(*[fit(kick if i in (0, 4) else hat if i % 2 else [], E8) for i in range(8)])
    return mix(arp, bass, drums)


save('theme', cat(*[fit(mix(bar_lead(l), bar_rest(c)), E8 * 8) for l, c in zip(lead, chords)]), 0.32)


# Chapter music: each song is 8 bars of (lead in eighths, chord) plus an arrangement
KICK = tone(sweep(110, 40, 0.12), 0.12, 'sine', 0.6, release=0.05)
DRUMS = {
    'k': KICK,
    'h': noise(0.03, 0.12, decay=0.01),
    's': mix(noise(0.12, 0.3, smooth=0.3, decay=0.04), tone(190, 0.06, 'triangle', 0.2)),
    't': mix(noise(0.01, 0.5, decay=0.003), tone(2600, 0.015, 'sine', 0.2)),
    'a': mix(*[tone(f0, 0.25, 'sine', 0.15, attack=0.001, release=0.24) for f0 in (880, 1980, 3100)]),
}


def song(name, bpm, bars, lead='square', duty=0.25, lead_vol=0.3, vib=(5, 0.006), arp='up', arp_vol=0.07,
         bass='pulse', bass_wave='triangle', drums='', pad=0.0, wet=None, peak=0.2):
    e8 = 60 / bpm / 2
    out = []
    for line, chord in bars:
        ns = [note(n) for n in chord.split()]
        mel = []
        for tok in line.split():
            n, k = tok.split(':')
            d = e8 * int(k)
            ring = 0.25 if lead == 'sine' else 0.05
            mel += silence(d) if n == 'R' else tone(note(n), d, lead, lead_vol, attack=0.004, release=min(d, ring), duty=duty, vibrato=vib)
        layers = [mel]
        if arp == 'up':
            layers.append(cat(*[tone(ns[i % 3] * 2, e8 / 2, 'square', arp_vol, release=0.02, duty=0.125) for i in range(16)]))
        elif arp == 'broken':
            layers.append(cat(*[tone(ns[i] * 2, e8, 'triangle', arp_vol * 2, release=0.05) for i in (0, 2, 1, 2, 0, 2, 1, 2)]))
        elif arp == 'music':
            layers.append(cat(*[tone(ns[i] * 4, e8, 'sine', arp_vol * 1.5, release=e8 * 0.9) for i in (0, 1, 2, 1, 0, 1, 2, 1)]))
        if bass == 'pulse':
            layers.append(cat(*[tone(ns[0] / 2 * (2 if i % 2 else 1), e8, bass_wave, 0.4, release=0.03) for i in range(8)]))
        elif bass == 'walk':
            layers.append(cat(*[tone(ns[i] / 2, e8 * 2, bass_wave, 0.4, release=0.06) for i in (0, 1, 2, 1)]))
        elif bass == 'gallop':
            layers.append(cat(*[tone(ns[0] / 2, e8 / 2, bass_wave, 0.4 if i % 4 != 1 else 0.0, release=0.02) for i in range(16)]))
        elif bass == 'drone':
            layers.append(tone(ns[0] / 2, e8 * 8, bass_wave, 0.4, attack=0.3, release=0.4))
        if pad:
            layers.append(mix(*[tone(f * (1 + 0.002 * i), e8 * 8, 'triangle', pad, attack=0.4, release=0.5) for i, f in enumerate(ns)]))
        if drums:
            step = e8 * 8 / len(drums)
            layers.append(cat(*[fit(DRUMS.get(d, []), step) for d in drums]))
        out += fit(mix(*layers), e8 * 8)
    if wet:
        # Fold the echo tail back onto the start so the loop stays seamless
        n = len(out)
        tail = echo(out, *wet)
        out = [a + (tail[i + n] if i + n < len(tail) else 0.0) for i, a in enumerate(tail[:n])]
    save(name, out, peak)


# Act I
song('bgm_cave', 96, [
    ('E4:3 G4:1 F#4:4', 'E3 G3 B3'), ('R:2 B3:2 E4:2 D4:2', 'C3 E3 G3'), ('E4:3 G4:1 A4:2 B4:2', 'A2 C3 E3'), ('A4:2 G4:2 F#4:4', 'B2 D#3 F#3'),
    ('G4:3 A4:1 B4:4', 'E3 G3 B3'), ('C5:2 B4:2 A4:2 G4:2', 'C3 E3 G3'), ('F#4:3 G4:1 A4:2 F#4:2', 'A2 C3 E3'), ('D#4:6 R:2', 'B2 D#3 F#3'),
], duty=0.125, lead_vol=0.25, arp='broken', arp_vol=0.05, bass='drone', drums='k.k.............', pad=0.05)
song('bgm_river', 124, [
    ('F#5:2 A5:2 D6:2 A5:2', 'D4 F#4 A4'), ('B5:2 A5:1 G5:1 F#5:4', 'G3 B3 D4'), ('E5:2 F#5:2 G5:2 A5:2', 'A3 C#4 E4'), ('F#5:3 E5:1 D5:4', 'D4 F#4 A4'),
    ('D5:1 E5:1 F#5:2 G5:2 B5:2', 'G3 B3 D4'), ('A5:2 F#5:2 D5:2 F#5:2', 'D4 F#4 A4'), ('G5:2 E5:2 C#5:2 E5:2', 'A3 C#4 E4'), ('D5:6 R:2', 'D4 F#4 A4'),
], duty=0.5, lead_vol=0.22, drums='k.h.s.h.', wet=(0.18, 0.25, 2))
song('bgm_bugs', 152, [
    ('A4:1 A4:1 C5:1 A4:1 D#5:1 E5:1 C5:1 A4:1', 'A3 C4 E4'), ('G4:1 G4:1 A#4:1 G4:1 C#5:1 D5:1 A#4:1 G4:1', 'G3 A#3 D4'),
    ('F4:1 F4:1 G#4:1 F4:1 B4:1 C5:1 G#4:1 F4:1', 'F3 G#3 C4'), ('E4:1 F4:1 F#4:1 G4:1 G#4:1 A4:1 A#4:1 B4:1', 'E3 G#3 B3'),
    ('A4:1 A4:1 C5:1 A4:1 D#5:1 E5:1 C5:1 A4:1', 'A3 C4 E4'), ('G4:1 G4:1 A#4:1 G4:1 C#5:1 D5:1 A#4:1 G4:1', 'G3 A#3 D4'),
    ('A4:1 C5:1 E5:1 A5:1 G#5:1 A5:1 E5:1 C5:1', 'A3 C4 E4'), ('D5:1 C5:1 B4:1 A4:1 G#4:2 E4:2', 'E3 G#3 B3'),
], duty=0.125, lead_vol=0.25, vib=(14, 0.01), arp='none', drums='khskkhsh')
song('bgm_bridge', 116, [
    ('G4:2 B4:2 D5:3 B4:1', 'G3 B3 D4'), ('C5:2 E5:2 G5:3 E5:1', 'C4 E4 G4'), ('D5:2 F#5:1 E5:1 D5:2 C5:2', 'D4 F#4 A4'), ('B4:3 A4:1 G4:4', 'G3 B3 D4'),
    ('E5:2 D5:2 C5:2 B4:2', 'C4 E4 G4'), ('A4:2 B4:2 C5:2 D5:2', 'A3 C4 E4'), ('E5:3 F#5:1 G5:2 F#5:2', 'D4 F#4 A4'), ('G5:6 R:2', 'G3 B3 D4'),
], arp='broken', bass='walk', drums='k.s.k.sk')
song('bgm_tower', 100, [
    ('C5:2 F5:2 A5:2 B5:2', 'F3 A3 C4'), ('C6:4 A5:4', 'G3 B3 D4'), ('G5:2 E5:2 C5:2 E5:2', 'C4 E4 G4'), ('F5:6 R:2', 'F3 A3 C4'),
    ('A5:2 B5:2 C6:2 E6:2', 'F3 A3 C4'), ('D6:3 C6:1 B5:4', 'G3 B3 D4'), ('A5:2 G5:2 E5:2 G5:2', 'A3 C4 E4'), ('F5:6 R:2', 'F3 A3 C4'),
], lead='sine', lead_vol=0.35, bass='drone', pad=0.06, wet=(0.28, 0.4, 3))
song('bgm_library', 72, [
    ('E5:4 R:4', 'A3 C4 Eb4'), ('D#5:2 E5:2 R:4', 'A3 C4 E4'), ('C5:4 B4:4', 'F3 Ab3 B3'), ('R:8', 'E3 G#3 B3'),
    ('A4:2 C5:2 Eb5:4', 'A3 C4 Eb4'), ('D5:4 R:2 C5:2', 'D3 F3 Ab3'), ('B4:6 R:2', 'E3 G#3 D4'), ('R:4 G#4:4', 'E3 G#3 B3'),
], lead='sine', lead_vol=0.3, vib=(6, 0.012), arp='none', bass='drone', pad=0.07, wet=(0.35, 0.5, 4), peak=0.18)
song('bgm_throne', 144, [
    ('C5:2 C5:1 Eb5:1 G5:2 F5:1 Eb5:1', 'C3 Eb3 G3'), ('D5:2 D5:1 F5:1 Ab5:2 G5:1 F5:1', 'Ab2 C3 Eb3'),
    ('Eb5:2 Eb5:1 G5:1 Bb5:2 Ab5:1 G5:1', 'Eb3 G3 Bb3'), ('B4:2 D5:2 F5:2 G5:2', 'G2 B2 D3'),
    ('C6:2 Bb5:2 G5:2 Eb5:2', 'C3 Eb3 G3'), ('Ab5:2 G5:2 F5:2 D5:2', 'Ab2 C3 Eb3'),
    ('G5:1 F5:1 Eb5:1 D5:1 Eb5:1 F5:1 G5:1 B5:1', 'G2 B2 D3'), ('C6:4 G5:2 R:2', 'C3 Eb3 G3'),
], bass='gallop', bass_wave='square', drums='k.h.s.h.k.k.s.h.')

# Act II
song('bgm_mirrors', 92, [
    ('F#5:2 B5:2 D6:2 C#6:2', 'B3 D4 F#4'), ('B5:4 F#5:4', 'G3 B3 D4'), ('E5:2 G5:2 B5:2 A5:2', 'E3 G3 B3'), ('F#5:6 R:2', 'F#3 A#3 C#4'),
    ('D6:2 C#6:2 B5:2 A5:2', 'B3 D4 F#4'), ('G5:2 A5:2 B5:2 D6:2', 'G3 B3 D4'), ('C#6:2 B5:2 A#5:2 C#6:2', 'F#3 A#3 C#4'), ('B5:6 R:2', 'B3 D4 F#4'),
], lead='sine', lead_vol=0.3, arp='music', bass='drone', wet=(0.3, 0.45, 3))
song('bgm_clock', 120, [
    ('A4:1 R:1 E5:1 R:1 A4:1 R:1 E5:1 R:1', 'A3 C4 E4'), ('G4:1 R:1 D5:1 R:1 G4:1 R:1 D5:1 R:1', 'G3 B3 D4'),
    ('F4:1 R:1 C5:1 R:1 F4:1 A4:1 C5:1 F5:1', 'F3 A3 C4'), ('E5:2 D5:2 C5:2 B4:2', 'E3 G#3 B3'),
    ('A5:1 R:1 G5:1 R:1 F5:1 R:1 E5:1 R:1', 'A3 C4 E4'), ('D5:1 E5:1 F5:1 G5:1 A5:2 R:2', 'D3 F3 A3'),
    ('B4:1 C5:1 D5:1 E5:1 F5:1 G#5:1 A5:1 B5:1', 'E3 G#3 B3'), ('A5:4 R:4', 'A3 C4 E4'),
], duty=0.5, lead_vol=0.22, drums='k...t...k...t...')
song('bgm_forge', 104, [
    ('D4:2 D4:1 F4:1 A4:2 G4:2', 'D3 F3 A3'), ('F4:2 E4:1 D4:1 C4:4', 'Bb2 D3 F3'), ('D4:2 D4:1 F4:1 A4:2 C5:2', 'D3 F3 A3'), ('Bb4:3 A4:1 G4:4', 'G2 Bb2 D3'),
    ('A4:2 C5:2 D5:2 F5:2', 'D3 F3 A3'), ('E5:2 D5:2 C5:2 A4:2', 'C3 E3 G3'), ('Bb4:2 A4:2 G4:2 E4:2', 'A2 C#3 E3'), ('D4:6 R:2', 'D3 F3 A3'),
], duty=0.5, arp='none', bass_wave='saw', drums='k..ak.a.')
song('bgm_golem', 148, [
    ('E4:1 E4:1 F4:1 E4:1 G4:1 E4:1 A4:1 G4:1', 'E3 G3 B3'), ('F4:2 E4:1 D4:1 E4:4', 'F3 A3 C4'),
    ('E5:1 E5:1 F5:1 E5:1 G5:1 E5:1 B5:1 A5:1', 'E3 G3 B3'), ('G5:2 F5:2 E5:2 D5:2', 'D3 F3 A3'),
    ('C5:2 D5:2 E5:2 F5:2', 'C3 E3 G3'), ('G5:2 A5:2 B5:2 C6:2', 'D3 F3 A3'),
    ('B5:1 A5:1 G5:1 F5:1 E5:1 D5:1 C5:1 B4:1', 'F3 A3 C4'), ('E5:6 R:2', 'E3 G3 B3'),
], bass='gallop', bass_wave='square', drums='k.h.s.hkk.h.s.h.', wet=(0.2, 0.3, 2))
song('bgm_archive', 106, [
    ('Bb4:1 D5:1 F5:1 D5:1 G5:2 F5:2', 'Bb3 D4 F4'), ('Eb5:2 D5:2 C5:4', 'Eb3 G3 Bb3'), ('F5:1 A5:1 C6:1 A5:1 Bb5:2 A5:2', 'F3 A3 C4'), ('G5:3 F5:1 D5:4', 'G3 Bb3 D4'),
    ('Bb4:1 D5:1 F5:1 Bb5:1 A5:2 G5:2', 'Bb3 D4 F4'), ('Ab5:2 G5:2 F5:2 Eb5:2', 'Ab3 C4 Eb4'), ('D5:2 Eb5:2 F5:2 A5:2', 'F3 A3 C4'), ('Bb5:6 R:2', 'Bb3 D4 F4'),
], arp='broken', bass='walk', drums='k.h.s.hh')
song('bgm_study', 88, [
    ('A4:2 C5:2 F5:3 E5:1', 'F3 A3 C4'), ('D5:2 C5:2 Bb4:4', 'Bb2 D3 F3'), ('G4:2 Bb4:2 E5:3 D5:1', 'C3 E3 G3'), ('C5:6 R:2', 'F3 A3 C4'),
    ('A4:2 C5:2 F5:2 A5:2', 'D3 F3 A3'), ('G5:2 F5:2 D5:4', 'Bb2 D3 F3'), ('E5:2 G5:2 Bb5:2 G5:2', 'C3 E3 G3'), ('F5:6 R:2', 'F3 A3 C4'),
], lead='triangle', lead_vol=0.4, arp='broken', arp_vol=0.05, bass='walk', drums='k...s...', pad=0.04)
song('bgm_void', 56, [
    ('R:4 E5:4', 'E3 B3 E4'), ('F5:6 R:2', 'F3 C4 F4'), ('R:8', 'E3 B3 E4'), ('B4:4 C5:4', 'F3 C4 F4'),
    ('R:2 G5:6', 'C3 G3 C4'), ('F5:4 E5:4', 'F3 C4 F4'), ('R:8', 'E3 B3 E4'), ('D#5:6 R:2', 'B2 F#3 B3'),
], lead='sine', lead_vol=0.25, vib=(4, 0.015), arp='none', bass='drone', pad=0.1, wet=(0.45, 0.55, 4), peak=0.18)

# Bonus chapters: calm lo-fi so you can think while you work
song('bgm_scribe', 84, [
    ('E5:2 G5:2 B5:3 A5:1', 'C4 E4 B4'), ('G5:2 E5:2 C5:4', 'A3 C4 G4'), ('F5:2 A5:2 C6:3 A5:1', 'D4 F4 C5'), ('G5:3 F5:1 D5:4', 'G3 B3 F4'),
    ('E5:1 G5:1 B5:2 D6:2 B5:2', 'C4 E4 B4'), ('A5:4 G5:2 E5:2', 'A3 C4 G4'), ('F5:2 E5:2 D5:2 C5:2', 'D4 F4 C5'), ('B4:4 R:4', 'G3 B3 F4'),
], lead='triangle', lead_vol=0.35, arp='broken', arp_vol=0.04, bass='walk', drums='k..hs.h.', pad=0.04, peak=0.16)
song('bgm_tree', 90, [
    ('B4:2 D5:2 F#5:2 D5:2', 'G3 B3 F#4'), ('E5:2 G5:2 B5:4', 'E3 G3 D4'), ('C5:2 E5:2 G5:2 B5:2', 'C4 E4 B4'), ('A5:3 F#5:1 D5:4', 'D4 F#4 A4'),
    ('G5:2 F#5:2 E5:2 D5:2', 'G3 B3 F#4'), ('B4:2 D5:2 G5:4', 'E3 G3 D4'), ('E5:2 G5:2 C6:2 B5:2', 'C4 E4 B4'), ('A5:6 R:2', 'D4 F#4 A4'),
], lead='triangle', lead_vol=0.35, arp='music', arp_vol=0.04, bass='walk', drums='k.h.s.h.', peak=0.16)
song('bgm_finders', 96, [
    ('F5:1 A5:1 C6:2 A5:2 F5:2', 'D4 F4 C5'), ('B4:2 D5:2 F5:4', 'G3 B3 F4'), ('E5:2 G5:2 B5:2 G5:2', 'C4 E4 B4'), ('C#5:2 E5:2 G5:2 A5:2', 'A3 C#4 G4'),
    ('D6:2 C6:2 A5:2 F5:2', 'D4 F4 C5'), ('G5:2 F5:2 D5:2 B4:2', 'G3 B3 F4'), ('C5:2 E5:2 G5:2 B5:2', 'C4 E4 B4'), ('A5:6 R:2', 'A3 C#4 G4'),
], duty=0.5, lead_vol=0.2, arp='none', bass='walk', drums='k.hhs.hh', pad=0.04, peak=0.16)
song('bgm_windows', 110, [
    ('B4:2 E5:2 G5:2 B5:2', 'E3 G3 B3'), ('A5:2 G5:2 F#5:4', 'C4 E4 G4'), ('D5:2 G5:2 B5:2 D6:2', 'G3 B3 D4'), ('C#6:3 B5:1 A5:4', 'D4 F#4 A4'),
    ('B5:2 G5:2 E5:2 G5:2', 'E3 G3 B3'), ('C6:2 B5:2 A5:2 G5:2', 'C4 E4 G4'), ('F#5:2 A5:2 D6:2 C6:2', 'D4 F#4 A4'), ('B5:6 R:2', 'B3 D#4 F#4'),
], duty=0.125, lead_vol=0.22, arp_vol=0.05, bass='pulse', drums='k.h.s.h.', peak=0.16)

print('generated', len([f for f in os.listdir(OUT) if f.endswith('.wav')]), 'sounds in', OUT)
