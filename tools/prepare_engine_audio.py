"""Prepare only the engine loops referenced by IndyV8.sfx; originals stay untouched.

Standard library only. Run from any directory with Python 3.
"""
from array import array
import json
import math
from pathlib import Path
import re
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "IndycarV8"
DEST = ROOT / "content/vehicles/open_wheel/audio"


def prepare(path: Path) -> dict:
    with wave.open(str(path), "rb") as reader:
        assert reader.getsampwidth() == 2 and reader.getcomptype() == "NONE", path
        channels, rate = reader.getnchannels(), reader.getframerate()
        pcm = array("h", reader.readframes(reader.getnframes()))
    if sys.byteorder != "little":
        pcm.byteswap()
    # The engine is a point source outdoors; mono also prevents phase changes
    # when crossing between the cabin and exterior banks.
    mono = [sum(pcm[i:i + channels]) / (32768 * channels)
            for i in range(0, len(pcm), channels)]
    dc = sum(mono) / len(mono)
    mono = [x - dc for x in mono]
    # Overlap the last 12 ms onto the first 12 ms, then drop the duplicated
    # head. The seam now continues into the original waveform at both ends.
    overlap = min(round(rate * .012), len(mono) // 8)
    head = mono[:overlap]
    result = mono[overlap:]
    for i in range(overlap):
        t = i / (overlap - 1)
        t = t * t * (3 - 2 * t)
        result[-overlap + i] = result[-overlap + i] * (1 - t) + head[i] * t
    rms = math.sqrt(sum(x * x for x in result) / len(result))
    peak = max(abs(x) for x in result)
    # Match layer loudness without hard clipping or extreme noise amplification.
    gain = min(.22 / max(rms, 1e-8), .90 / max(peak, 1e-8), 4.0)
    output = array("h", (round(x * gain * 32767) for x in result))
    name = "_".join(path.relative_to(SOURCE).parts).lower()
    if sys.byteorder != "little":
        output.byteswap()
    with wave.open(str(DEST / name), "wb") as writer:
        writer.setparams((1, 2, rate, 0, "NONE", "not compressed"))
        writer.writeframes(output.tobytes())
    return {"file": name, "seconds": round(len(result) / rate, 3),
            "rms_db": round(20 * math.log10(rms * gain), 2),
            "peak": round(peak * gain, 4), "gain_db": round(20 * math.log10(gain), 2),
            "seam_step": round(abs(result[-1] - result[0]) * gain, 5)}


def main() -> None:
    text = (SOURCE / "IndyV8.sfx").read_text()
    paths = set()
    lookup = {str(p.relative_to(ROOT)).replace("\\", "/").lower(): p
              for p in SOURCE.rglob("*") if p.is_file()}
    for line in text.splitlines():
        match = re.match(r"VS_(?:INSIDE|OUTSIDE)_(?:POWER|COAST)_ENGINE_\d+=(.+)", line)
        if match:
            paths.add(lookup[match[1].strip().replace("\\", "/").lower()])
    DEST.mkdir(parents=True, exist_ok=True)
    report = [prepare(path) for path in sorted(paths)]
    print(json.dumps(report, indent=2))
    print(f"Prepared {len(report)} shared engine loops; source recordings unchanged.")


if __name__ == "__main__":
    main()
