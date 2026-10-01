"""Provisional Texas clean-air calibration from September 26 player runs."""
import math


def calibrate(profile):
    # Retain the imported trace so recalibration is repeatable, not cumulative.
    imported = profile.setdefault('imported_speed_mps', profile['speed_mps'][:])
    low, high = min(imported), max(imported)
    speeds = [(387.0 + 12.0 * (speed-low)/(high-low))/3.6 for speed in imported]
    points = profile['reference_points']
    profile['speed_mps'] = speeds
    profile['reference_lap_s'] = sum(
        math.dist(points[i], points[i+1])/((speeds[i]+speeds[(i+1)%len(speeds)])*.5)
        for i in range(len(speeds)))
    profile['roster_reference_lap_s'] = 21.097133  # Greg Ray's roster anchor.
    profile['driver_pace_spread'] = 0.45
    profile['driver_speed_weighting'] = 'profile_range'
    profile['pace_calibration'] = {
        'basis': '2026-09-26 player runs: approximately 22.06 s, 383-390 km/h at 17 gal; player sixth still limiter-bound.',
        'method': 'Map imported LP speed shape to 387-399 km/h before fuel/driver scaling; retain 45% of roster-relative lap gaps.',
        'status': 'Provisional assisted-player gameplay calibration, not historical performance data.'}
    return profile
