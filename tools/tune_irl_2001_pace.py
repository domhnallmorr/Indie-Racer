"""Map Phoenix 2001 qualifying ratios onto the current 21.2-second fast benchmark.
Only pace and its provenance change; entry/grid order and driver ratings stay intact.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = 'https://en.wikipedia.org/wiki/2001_Pennzoil_Copper_World_Indy_200#Qualifying_classification'
# Position and best lap in seconds, matched by driver identity (not entry order).
QUALIFYING = {
    'Hornish': (2, 20.3619), 'JeffWard': (3, 20.4883),
    'Lazier': (6, 20.6966), 'Boat': (7, 20.7898),
    'Buhl': (8, 20.7955), 'Giaffone': (9, 20.8034),
    'Sharpe': (10, 20.8097), 'Calkins': (11, 20.8352),
    'Cheever': (12, 20.8501), 'Salazar': (13, 20.8547),
    'Dismore': (15, 20.8666), 'McGehee': (16, 20.9064),
    'Dare': (18, 21.2188), 'Unser': (23, 21.6883),
    'Hattori': (24, 21.7637),
}
FAST_TARGET = 21.2
FAST_QUALIFYING = QUALIFYING['Hornish'][1]

def main():
    path = ROOT / 'content/rosters/irl_2001/manifest.json'
    roster = json.loads(path.read_text(encoding='utf-8'))
    assert {entry['id'] for entry in roster['entries']} == set(QUALIFYING) | {'Beechler'}
    roster['pace_calibration'] = {
        'source': SOURCE,
        'event': 'Phoenix, 17 March 2001 qualifying',
        'method': 'icr2_lap_s = 21.2 * qualifying_time_s / 20.3619',
        'anchor_driver_id': 'Hornish',
        'anchor_target_s': FAST_TARGET,
        'anchor_qualifying_s': FAST_QUALIFYING,
        'notes': 'Preserves qualifying percentage gaps among roster entrants. Greg Ray is not in this roster. Beechler did not qualify at this event: use Salazar as an explicit teammate proxy. These are pace inputs, not guaranteed measured lap times; straight-speed limits, fuel and traffic still apply.',
    }
    for entry in roster['entries']:
        driver_id = entry['id']
        proxy = driver_id == 'Beechler'
        position, time_s = QUALIFYING['Salazar' if proxy else driver_id]
        entry['icr2_lap_s'] = round(FAST_TARGET * time_s / FAST_QUALIFYING, 6)
        entry['pace_reference'] = {
            'qualifying_position': None if proxy else position,
            'qualifying_time_s': None if proxy else time_s,
            'basis_time_s': time_s,
            'basis': 'teammate_proxy' if proxy else 'qualifying',
        }
        if proxy:
            entry['pace_reference']['proxy_driver_id'] = 'Salazar'
        print(f"{entry['driver_name']:20} {entry['icr2_lap_s']:.4f} s" + (' (estimated)' if proxy else ''))
    roster['description'] = '2001 IRL reference liveries with Phoenix 2001 qualifying-relative AI pace, anchored to a 21.2-second fastest target. Beechler uses a documented Salazar teammate estimate.'
    path.write_text(json.dumps(roster, indent=2) + '\n', encoding='utf-8')

if __name__ == '__main__':
    main()
