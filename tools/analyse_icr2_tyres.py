"""Read-only tyre response trace for the identified DOS ICR2 executable.

Usage: python tools/analyse_icr2_tyres.py PATH_TO_INDYCAR.EXE
Requires Capstone; also supports tmp/icr2_analysis/vendor from the earlier review.
Does not execute or modify the original program. Addresses are build-specific.
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


def efficiency(load):
    """Exact positive-input arithmetic of 0x19690, including its lower clamp."""
    if not 0 <= load <= 32767:
        raise ValueError("Expected a nonnegative signed 16-bit wheel load")
    return max(5000, 64554 - 2950 * load // 1000 - 4915 * load * load // 10000000)


def analyse(path):
    data = path.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    if digest != EXPECTED_HASH:
        raise ValueError("Different executable build: trace addresses do not apply")
    mz = 0x26654
    header = mz + struct.unpack_from("<I", data, mz + 0x3C)[0]
    if data[header:header + 4] != b"LE\x00\x00":
        raise ValueError("Expected embedded LE application")
    u32 = lambda off: struct.unpack_from("<I", data, header + off)[0]
    objects = [struct.unpack_from("<6I", data, header + u32(0x40) + i * 24)
               for i in range(u32(0x44))]
    pages = mz + u32(0x80)
    page_size = u32(0x28)
    page_map = header + u32(0x48)
    for i in range(u32(0x14)):
        entry = data[page_map + i * 4:page_map + i * 4 + 4]
        if int.from_bytes(entry[:3], "big") != i + 1 or entry[3] != 0:
            raise ValueError("Unsupported LE page map")
    code_start = pages + (objects[0][3] - 1) * page_size
    data_start = pages + (objects[1][3] - 1) * page_size
    decoder = Cs(CS_ARCH_X86, CS_MODE_32)
    regions = {
        "car_profile_mass": (0x135E0, 0x13644),
        "fuel_quantity_and_mass": (0x13840, 0x138B0),
        "static_weight_and_distribution": (0x14C67, 0x14CD8),
        "running_mass": (0x16F4A, 0x16F75),
        "compound_factor_to_response": (0x167E8, 0x16825),
        "first_pair_drive_direction": (0x193AC, 0x19508),
        "second_pair_brake_direction": (0x19508, 0x195A4),
        "load_efficiency_callers": (0x15492, 0x154DD),
        "paired_transfer_and_four_loads": (0x15E94, 0x16111),
        "slip_table_interpolation": (0x19287, 0x19361),
        "wheel_pair_zero_combine_call": (0x17217, 0x172D2),
        "wheel_pair_two_combine_call": (0x173F3, 0x17425),
        "combined_response_and_load_scaling": (0x195A4, 0x19674),
        "ai_efficiency_adapter": (0x19674, 0x19690),
        "load_efficiency_polynomial": (0x19690, 0x196D9),
        "second_pair_load_adapter": (0x196DC, 0x19704),
    }
    traces = {}
    for name, (start, end) in regions.items():
        off = code_start + start - objects[0][1]
        traces[name] = [dict(address=hex(i.address), instruction=f"{i.mnemonic} {i.op_str}")
                        for i in decoder.disasm(data[off:off + end - start], start)]
    table = list(struct.unpack_from("<20H", data, data_start + 0x82D0))
    assert table == [0, 16000, 30000, 42000, 52000, 60000, 64000,
                     65535, 65535, 65535, 65535, 64000, 60000, 55000,
                     50000, 45000, 42000, 41000, 40000, 40000]
    assert efficiency(0) == 64554 and efficiency(2000) == 56688
    assert efficiency(4000) == 44890 and efficiency(10000) == 5000
    assert all(efficiency(i + 1) <= efficiency(i) for i in range(32767))
    return dict(
        source=str(path.resolve()), sha256=digest, le_header=hex(header),
        code_file_offset=hex(code_start), data_file_offset=hex(data_start), traces=traces,
        efficiency_formula="max(5000, 64554 - trunc(2950*L/1000) - trunc(4915*L*L/10000000))",
        efficiency_input="nonnegative signed 16-bit per-wheel load-like quantity, read unsigned by polynomial; SI conversion unverified",
        second_pair_adapter="L2 = low16(trunc(1100*L/1000)); efficiency(L2)",
        samples=[dict(internal_load=i, coefficient=efficiency(i),
                      fraction_of_zero_load=efficiency(i) / efficiency(0))
                 for i in [0, 1000, 2000, 3000, 4000, 5000, 6000, 8000, 10000]],
        slip_table_data_offset="0x82d0", slip_table_u16=table,
        slip_table_tail_to_peak=40000 / 65535,
        baseline_compound_factors=list(struct.unpack_from("<4H", data, data_start + 0x8574)),
        interpretation="Strong static evidence for load-dependent tyre response and separate post-peak slip falloff. Exact SI units, wheel identities and the complete force law remain unverified.",
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=Path)
    args = parser.parse_args()
    report = analyse(args.executable)
    destination = ROOT / "tmp/icr2_analysis/tyre_binary_trace.json"
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if hashlib.sha256(args.executable.read_bytes()).hexdigest() != report["sha256"]:
        raise RuntimeError("Source hash changed during inspection")
    print(f"Saved {destination}")
    print(report["interpretation"])
    print(f"Slip-table tail/peak: {report['slip_table_tail_to_peak']:.4%}")
