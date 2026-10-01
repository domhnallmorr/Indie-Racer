"""Small read-only DAT/TRK/LP decoder for importing user-supplied circuits.

Format reference: https://github.com/skchow03/icr2tools (SK Chow).
Papyrus distances are 6000 units/foot; LP samples are 65536 units apart.
No archive programs or installation scripts are executed.
"""
import bisect
import math
import struct
import zipfile

UNIT = 0.3048 / 6000


def dat_member(data, wanted):
    count, = struct.unpack_from('<H', data)
    for i in range(count):
        p = 2 + i * 27
        size, = struct.unpack_from('<I', data, p + 2)
        name = data[p + 10:p + 23].split(b'\0')[0].decode('ascii')
        offset, = struct.unpack_from('<I', data, p + 23)
        if name.lower() == wanted.lower():
            if offset + size > len(data):
                raise ValueError('Truncated DAT member')
            return data[offset:offset + size]
    raise ValueError('Missing DAT member: ' + wanted)


class Track:
    def __init__(self, raw):
        a = struct.unpack('<' + 'i' * (len(raw) // 4), raw)
        _, version, self.length, nx, ns, ground_bytes, section_bytes = a[:7]
        if version != 1 or not 2 <= nx <= 10 or not 1 <= ns <= 10000:
            raise ValueError('Unsupported TRK header')
        self.dlats = a[7:7 + nx]
        offsets = [n // 4 for n in a[17:17 + ns]] + [section_bytes // 4]
        e = 17 + ns
        self.elevations = [[a[e + (i * nx + j) * 8:e + (i * nx + j + 1) * 8]
                            for j in range(nx)] for i in range(ns)]
        g = e + ns * nx * 8
        self.ground = [a[k:k + 3] for k in range(g, g + ground_bytes // 4, 3)]
        s = g + ground_bytes // 4
        self.sections = [a[s + offsets[i]:s + offsets[i + 1]] for i in range(ns)]
        self.starts = [sec[1] for sec in self.sections]
        right = next(i for i in range(nx - 1) if self.dlats[i] <= 0 < self.dlats[i + 1])
        f = -self.dlats[right] / (self.dlats[right + 1] - self.dlats[right])
        self.centers = [tuple(rows[right][k] + f * (rows[right + 1][k] - rows[right][k])
                              for k in (6, 7)) for rows in self.elevations]

    def section_at(self, distance):
        distance %= self.length
        i = max(0, bisect.bisect_right(self.starts, distance) - 1)
        return i, (distance - self.starts[i]) / self.sections[i][2]

    def start(self, i):
        sec = self.sections[i]
        if sec[0] == 1:
            return self.centers[i]
        theta = sec[3] * math.pi / 2**31 - math.pi / 2
        radius = self.centers[i][0]
        return sec[4] + radius * math.cos(theta), sec[5] + radius * math.sin(theta)

    def xy(self, distance, lateral=0):
        i, f = self.section_at(distance)
        sec = self.sections[i]
        heading = sec[3] * math.pi / 2**31
        if sec[0] == 1:
            a, b = self.start(i), self.start((i + 1) % len(self.sections))
            return (a[0] + f * (b[0] - a[0]) - lateral * math.sin(heading),
                    a[1] + f * (b[1] - a[1]) + lateral * math.cos(heading))
        end = self.sections[(i + 1) % len(self.sections)][3] * math.pi / 2**31
        sweep = (end - heading + math.pi) % math.tau - math.pi
        theta = heading - math.pi / 2 + sweep * f
        radius = self.centers[i][0] - lateral
        return sec[4] + radius * math.cos(theta), sec[5] + radius * math.sin(theta)


def read_archive(path):
    with zipfile.ZipFile(path) as archive:
        names = {name.upper(): name for name in archive.namelist()}
        dat = archive.read(names['TEXAS/TEXAS.DAT'])
        track = Track(dat_member(dat, 'texas.trk'))
        lines = {}
        for key, name in names.items():
            if key.endswith('.LP'):
                raw = archive.read(name)
                count, = struct.unpack_from('<i', raw)
                if len(raw) != 4 + count * 12:
                    raise ValueError('Invalid LP length: ' + name)
                lines[key.split('/')[-1][:-3].lower()] = [
                    struct.unpack_from('<iii', raw, 4 + 12 * i) for i in range(count)]
        return track, lines


if __name__ == '__main__':
    import sys
    track, lines = read_archive(sys.argv[1])
    print('Reference length (m):', track.length * UNIT)
    print('Cross sections (m):', [round(x * UNIT, 2) for x in track.dlats])
    for i, sec in enumerate(track.sections):
        print(i, 'curve' if sec[0] == 2 else 'straight', 's/m', round(sec[1] * UNIT, 1),
              'length/m', round(sec[2] * UNIT, 1), 'heading/deg', round(sec[3] * 180 / 2**31, 2),
              'start/m', [round(v * UNIT, 1) for v in track.start(i)],
              'ground', track.ground[sec[11]:sec[11] + sec[10]])
    for name, rows in lines.items():
        print(name, len(rows), 'lateral/m', min(r[2] for r in rows) * UNIT,
              max(r[2] for r in rows) * UNIT, 'speed/mps', min(r[0] for r in rows) * UNIT * 15,
              max(r[0] for r in rows) * UNIT * 15)
