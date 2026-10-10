"""Read-only stagger trace for the inspected DOS ICR2 build.

Run: python tools/analyse_icr2_stagger.py PATH_TO_INDYCAR.EXE
Needs capstone (the review's copy in tmp/icr2_analysis/vendor is also supported).
Addresses are build-specific, so a different binary fails explicitly.
"""
from pathlib import Path
import argparse
import hashlib
import json
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tmp/icr2_analysis/vendor"))
from capstone import Cs, CS_ARCH_X86, CS_MODE_32

EXPECTED_HASH = "83ccee7341b31ce2fdebfb453dfaaf443c1e80687693e6ba4b71a71dd8256267"


def analyse(path):
    data = path.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    if digest != EXPECTED_HASH:
        raise ValueError("Different executable build: these trace addresses do not apply")
    mz = 0x26654
    header = mz + struct.unpack_from("<I", data, mz + 0x3C)[0]
    if data[header:header + 4] != b"LE\x00\x00":
        raise ValueError("Expected embedded LE executable")
    u32 = lambda offset: struct.unpack_from("<I", data, header + offset)[0]
    pages = mz + u32(0x80)
    objects = []
    for index in range(u32(0x44)):
        values = struct.unpack_from("<6I", data, header + u32(0x40) + index * 24)
        objects.append(dict(size=values[0], base=values[1], first_page=values[3], pages=values[4]))
    page_size = u32(0x28)
    # This build has consecutive ordinary LE pages (no iterated/zero pages).
    page_map = header + u32(0x48)
    for index in range(u32(0x14)):
        entry = data[page_map + index * 4:page_map + index * 4 + 4]
        if int.from_bytes(entry[:3], "big") != index + 1 or entry[3] != 0:
            raise ValueError("Unsupported nonconsecutive LE page map")
    code_start = pages + (objects[0]["first_page"] - 1) * page_size
    data_start = pages + (objects[1]["first_page"] - 1) * page_size
    decoder = Cs(CS_ARCH_X86, CS_MODE_32)
    regions = {
        "signed_stagger_setter_getter": (0x13A58, 0x13A95),
        "stagger_menu_more_less": (0x6949C, 0x694CA),
        "running_paired_split": (0x16D14, 0x16E3B),
        "paired_split_into_tyre_combine": (0x17150, 0x172D2),
    }
    traces = {}
    for name, (start, end) in regions.items():
        begin = code_start + start - objects[0]["base"]
        traces[name] = [dict(address=hex(i.address), instruction=f"{i.mnemonic} {i.op_str}")
                        for i in decoder.disasm(data[begin:begin + end - start], start)]
    # Exact 16-bit arithmetic for the observed split, while keeping its physical
    # meaning unknown. No conversion to metres/newtons is made.
    def split(base, setting):
        adjustment = ((base * setting) >> 16) & 0xFFFF
        plus = ((base + adjustment + 0x8000) % 0x10000) - 0x8000
        minus = ((base - adjustment + 0x8000) % 0x10000) - 0x8000
        return [plus >> 1, minus >> 1]
    result = dict(
        source=str(path.resolve()), sha256=digest, embedded_mz=hex(mz), le_header=hex(header),
        code_start=hex(code_start), initialized_data_start=hex(data_start),
        objects=objects, traces=traces,
        wheel_index_mapping=list(struct.unpack_from("<4I", data, data_start + 0x8944)),
        observed_stagger_range=[-1000, 1000], observed_menu_step=100,
        split_examples=[dict(base=10000, setting=s, outputs=split(10000, s)) for s in [-1000, 0, 1000]],
        interpretation="Signed stagger changes two inputs to tyre-combination arithmetic. Physical units, wheel identity, and circumference interpretation remain unverified.",
        prototype="Independent physical hypothesis: symmetric RR-minus-RL circumference difference, with a shared rear shaft; not an ICR2 conversion.",
    )
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=Path)
    args = parser.parse_args()
    report = analyse(args.executable)
    destination = ROOT / "tmp/icr2_analysis/stagger_binary_trace.json"
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"Saved {destination}")
    print(report["interpretation"])
