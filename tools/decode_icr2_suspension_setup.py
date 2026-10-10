"""Decode confirmed shock fields only; all other STG fields remain raw.

Verified using INDYCAR.EXE read at 0x52C1C (128 bytes to data 0x3F470)
and shock-setter call at 0x52A88 (fields 0x3F4B0 + 4*corner).
Corner label table maps menu indices to RF, RR, LR, LF.
"""
from pathlib import Path
import argparse
import hashlib
import json
import struct

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("setup", type=Path)
args = parser.parse_args()
data = args.setup.read_bytes()
if len(data) != 128:
    raise ValueError("Expected 128-byte ICR2 setup")
shocks = dict(zip(("rf", "rr", "lr", "lf"), struct.unpack_from("<4i", data, 0x40)))
if not all(0 <= value <= 100 for value in shocks.values()):
    raise ValueError("Shock field outside confirmed range")
report = dict(source=str(args.setup.resolve()), sha256=hashlib.sha256(data).hexdigest(),
              shock_settings=shocks, confirmed_offsets=dict(zip(shocks, ("0x40", "0x44", "0x48", "0x4c"))),
              raw_i32=list(struct.unpack("<32i", data)), si_conversion_verified=False)
destination = Path(__file__).resolve().parents[1] / "tmp/icr2_analysis/indy_setup_suspension.json"
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps(report, indent=2))
