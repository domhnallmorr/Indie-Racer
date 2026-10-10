"""Static suspension trace for the identified DOS ICR2 build; never executes it.

Usage: python tools/analyse_icr2_suspension.py PATH_TO_INDYCAR.EXE
Requires Capstone, including the existing tmp/icr2_analysis/vendor copy.
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
        raise ValueError("Different executable build; trace addresses do not apply")
    mz = 0x26654
    header = mz + struct.unpack_from("<I", data, mz + 0x3C)[0]
    if data[header:header + 4] != b"LE\0\0":
        raise ValueError("Expected embedded LE application")
    u32 = lambda off: struct.unpack_from("<I", data, header + off)[0]
    objects = [struct.unpack_from("<6I", data, header + u32(0x40) + i * 24)
               for i in range(u32(0x44))]
    page_size = u32(0x28)
    for i in range(u32(0x14)):
        entry = data[header + u32(0x48) + i * 4:header + u32(0x48) + i * 4 + 4]
        if int.from_bytes(entry[:3], "big") != i + 1 or entry[3] != 0:
            raise ValueError("Unsupported LE page map")
    pages = mz + u32(0x80)
    code_start = pages + (objects[0][3] - 1) * page_size
    data_start = pages + (objects[1][3] - 1) * page_size
    decoder = Cs(CS_ARCH_X86, CS_MODE_32)
    regions = {
        "shock_setter_getter_and_adjacent_coefficient_setter": (0x13C94, 0x13D80),
        "aggregate_suspension_coefficients": (0x18BC4, 0x18C87),
        "stateful_transfer_and_four_nonnegative_loads": (0x15E94, 0x16111),
        "subsequent_corner_displacement_like_outputs": (0x16111, 0x163F9),
        "shock_menu_increment_decrement": (0x68124, 0x6816C),
        "shock_menu_corner_labels": (0x68250, 0x6828D),
        "setup_buffer_application": (0x52980, 0x52AC3),
        "setup_read_128_bytes": (0x52BF0, 0x52C70),
    }
    traces = {}
    for name, (start, end) in regions.items():
        off = code_start + start - objects[0][1]
        traces[name] = [dict(address=hex(i.address), instruction=f"{i.mnemonic} {i.op_str}")
                        for i in decoder.disasm(data[off:off + end - start], start)]
    labels = [data[data_start + off:data_start + off + 20].split(b"\0")[0].decode("ascii")
              for off in (0x5E88, 0x5E94, 0x5EA0, 0x5EAC)]
    assert labels == ["RF Shock", "RR Shock", "LR Shock", "LF Shock"]
    text = "\n".join(t["instruction"] for t in traces["shock_setter_getter_and_adjacent_coefficient_setter"])
    assert "call 0x18bc4" in text and "[ebp*8 + 0x8762]" in text
    return dict(source=str(path.resolve()), sha256=digest, code_file_offset=hex(code_start),
                data_file_offset=hex(data_start), labels=labels, traces=traces,
                shock_setting_range=[0, 100], menu_step=5,
                setting_to_internal_coefficient="clamp(2047 + trunc(setting*2048/100), 2047, 4095)",
                interpretation="Shock settings feed aggregate coefficients used by persistent load-transfer states and four clipped tyre loads. Corner displacement-like outputs are also present. This does not establish a full spring/damper travel solver, SI units, unsprung mass, or road-height coupling.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=Path)
    args = parser.parse_args()
    report = analyse(args.executable)
    destination = ROOT / "tmp/icr2_analysis/suspension_binary_trace.json"
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if hashlib.sha256(args.executable.read_bytes()).hexdigest() != report["sha256"]:
        raise RuntimeError("Source hash changed during inspection")
    print(f"Saved {destination}")
    print(report["interpretation"])
