"""Summarize the per-physics-tick Texas observer and plot a selected incident.

python tools/analyze_texas_behavior.py builds/texas_behavior/baseline42
Optional: --car AI_sam_hornish_jr --time 25 --window 4
The thresholds flag investigation candidates; they are not safety assertions.
"""
from __future__ import annotations

import argparse
import io
import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd


def separated_peaks(frame, column, minimum, spacing=2.0, limit=12):
    selected = []
    for _, row in frame.loc[frame[column] >= minimum].sort_values(column, ascending=False).iterrows():
        if all(row.car != old.car or abs(row.time_s - old.time_s) >= spacing for old in selected):
            selected.append(row)
        if len(selected) >= limit:
            break
    columns = ["car", "time_s", column, "speed_mps", "reason", "state", "lane", "target_lane", "blocked", "line_error_m", "nearest_car", "nearest_gap_m", "side_correction_m"]
    return [{key: row[key] for key in columns} for row in selected]


def analyze(directory: Path, car=None, at=None, window=4.0):
    # Read a snapshot and discard a partial last row if the observer is still running.
    snapshot = (directory / "trace.csv").read_bytes()
    snapshot = snapshot[: snapshot.rfind(b"\n") + 1]
    data = pd.read_csv(io.BytesIO(snapshot), keep_default_na=False, low_memory=False)
    grouped = data.groupby("car", sort=False)
    data["accel_mps2"] = grouped.speed_mps.diff() * 60
    data["request_drop_mps"] = -grouped.request_mps.diff()
    data["target_jump_m"] = grouped.target_lateral_m.diff().abs()
    data["side_jump_m"] = grouped.side_correction_m.diff().abs()
    data["blocked_change"] = grouped.blocked.diff().abs().fillna(0)
    data["lane_choice_change"] = grouped.target_lane.diff().abs().fillna(0)
    data["speed_loss_1s_kph"] = (grouped.speed_mps.shift(60) - data.speed_mps) * 3.6
    active = data[(data.time_s >= 10) & (data["mode"] == 2)].copy()
    strong = active.accel_mps2 < -8
    # Count contiguous braking episodes per car, not overlapping one-second windows.
    active["strong"] = strong
    active["brake_start"] = strong & ~active.groupby("car").strong.shift(fill_value=False)
    big_jump = active.target_jump_m >= 0.5
    report = {
        "observed_seconds": float(data.time_s.max()),
        "cars": int(data.car.nunique()),
        "analysis_starts_after_green_s": 10,
        "max_tick_speed_drop_mps": float(-data.accel_mps2.min() / 60),
        "max_speed_loss_1s_kph": float(active.speed_loss_1s_kph.max()),
        "max_single_tick_request_drop_kph": float(active.request_drop_mps.max() * 3.6),
        "max_single_tick_target_jump_m": float(active.target_jump_m.max()),
        "target_jumps_ge_0_5m": int(big_jump.sum()),
        "jumps_with_blocked_toggle": int((big_jump & (active.blocked_change > 0)).sum()),
        "jumps_with_side_correction_change_ge_0_5m": int((big_jump & (active.side_jump_m >= 0.5)).sum()),
        "blocked_toggles": int(active.blocked_change.sum()),
        "lane_choice_changes": int((active.lane_choice_change > 0).sum()),
        "strong_braking_episode_count": int(active.brake_start.sum()),
        "strong_braking_time_car_seconds": float(strong.sum() / 60),
        "strong_braking_reasons": active.loc[strong, "reason"].value_counts().to_dict(),
        "worst_speed_losses": separated_peaks(active, "speed_loss_1s_kph", 5),
        "worst_target_jumps": separated_peaks(active, "target_jump_m", 0.5),
        "worst_request_drops": separated_peaks(active, "request_drop_mps", 2),
        "per_car": [],
    }
    for name, rows in active.groupby("car", sort=False):
        report["per_car"].append({"car": name, "max_speed_loss_1s_kph": float(rows.speed_loss_1s_kph.max()), "target_jumps": int((rows.target_jump_m >= 0.5).sum()), "blocked_toggles": int(rows.blocked_change.sum()), "lane_choice_changes": int((rows.lane_choice_change > 0).sum()), "strong_braking_s": float((rows.accel_mps2 < -8).sum() / 60)})
    (directory / "analysis.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    if car is None:
        worst = report["worst_target_jumps"] or report["worst_speed_losses"]
        if worst:
            car, at = worst[0]["car"], worst[0]["time_s"]
    if car is not None:
        selected = data[(data.car == car) & data.time_s.between(at - window, at + window)].copy()
        fig, axes = plt.subplots(4, 1, figsize=(12, 10), sharex=True, constrained_layout=True)
        fig.suptitle(f"Texas / {directory.name} / {car} / {at:.2f} s after green", fontsize=15)
        for field, label in [("speed_mps", "Actual"), ("request_mps", "Requested"), ("profile_mps", "Before traffic guard")]:
            axes[0].plot(selected.time_s, selected[field] * 3.6, label=label)
        axes[0].set_ylabel("Speed (km/h)")
        axes[1].plot(selected.time_s, selected.lateral_m, label="Car lateral position")
        axes[1].plot(selected.time_s, selected.target_lateral_m, label="Steering lookahead target")
        axes[1].plot(selected.time_s, selected.raw_target_lateral_m, "--", label="Target before side-room protection")
        axes[1].set_ylabel("Metres from road centre")
        axes[2].plot(selected.time_s, selected.lane, label="Current lane blend")
        axes[2].plot(selected.time_s, selected.target_lane, "--", label="Chosen lane")
        axes[2].plot(selected.time_s, selected.blocked, label="Lane move blocked")
        axes[2].set_ylabel("Lane / blocked")
        axes[3].plot(selected.time_s, selected.nearest_gap_m, label="Nearest car longitudinal gap")
        axes[3].plot(selected.time_s, selected.line_error_m, label="Tracking error")
        axes[3].axhline(9, color="grey", linestyle=":", label="9 m side-room cutoff")
        axes[3].axhline(-9, color="grey", linestyle=":")
        axes[3].set_ylabel("Metres")
        axes[3].set_xlabel("Seconds after green")
        for axis in axes:
            axis.axvline(at, color="#c73838", alpha=0.5)
            axis.grid(alpha=0.2)
            axis.legend(loc="upper right", fontsize=8)
        path = directory / f"incident_{car}_{at:.2f}.png"
        fig.savefig(path, dpi=150)
        plt.close(fig)
        selected.to_csv(path.with_suffix(".csv"), index=False)
        report["plot"] = str(path)
    print(json.dumps({key: value for key, value in report.items() if key not in ["per_car", "strong_braking_reasons"]}, indent=2))
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--car")
    parser.add_argument("--time", type=float)
    parser.add_argument("--window", type=float, default=4)
    parser.add_argument("--check", action="store_true", help="Require a completed capture without contacts, road departures or instantaneous speed collapse")
    args = parser.parse_args()
    if args.car is not None and args.time is None:
        parser.error("--car requires --time")
    report = analyze(args.directory, args.car, args.time, args.window)
    if args.check:
        summary = json.loads((args.directory / "summary.json").read_text())
        failures = []
        if not summary["green"] or abs(summary["seconds"] - report["observed_seconds"]) > 1/60:
            failures.append("capture did not finish")
        if summary["contacts"] or summary["edge_ticks"] or summary.get("wall_events", []):
            failures.append("car/static contact or road-limit violation")
        # The reference car's strongest commanded braking is 18 m/s² at 60 Hz.
        if report["max_tick_speed_drop_mps"] > .31:
            failures.append("speed dropped faster than the reference braking limit")
        if failures:
            raise SystemExit("TEXAS CAPTURE FAILED: " + "; ".join(failures))
        print("TEXAS CAPTURE PASSED: complete, no contacts or road departures, no instantaneous speed collapse")
