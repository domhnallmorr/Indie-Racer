"""Plot the conditional ICR2 load-sensitivity proposal against current physics."""
from pathlib import Path
import csv
import json
import statistics
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
from analyse_icr2_tyres import efficiency

ROOT = Path(__file__).resolve().parents[1]
report = json.loads((ROOT/'tmp/icr2_analysis/tyre_capacity_comparison.json').read_text())
comparison = report['capacity_comparison']
with open(comparison['telemetry'], newline='', encoding='utf-8') as stream:
    selected = [r for r in csv.DictReader(stream)
                if r['handling_model']=='wheel_contacts_rear_differential_v1'
                and 340<float(r['speed_kph'])<375
                and 12<abs(float(r['yaw_deg_s']))<30
                and abs(float(r['rear_slip_deg']))<8 and r['grounded']=='1']
scale = statistics.median(((7500+32*float(r['fuel_gal']))*110/256)
                          /(float(r['vehicle_mass_kg'])*9.81) for r in selected)
loads = np.arange(100., 12001., 25.)
current_mu = 1.65*np.maximum(2*loads/3500, .1)**(-.02)

def proposed_force(load, front):
    native = round(load*scale)
    curve_load = native*1100//1000 if front else native
    response = (efficiency(curve_load)*65535//65536)*58200//65536
    return (2*response*native//65536)/scale

front_force = np.array([proposed_force(load, True) for load in loads])
rear_force = np.array([proposed_force(load, False) for load in loads])
plt.rcParams.update({'font.family':'DejaVu Sans', 'font.size':11,
                     'axes.spines.top':False, 'axes.spines.right':False})
fig, axes = plt.subplots(1, 2, figsize=(13, 6.5))
fig.subplots_adjust(left=.07, right=.97, top=.77, bottom=.21, wspace=.24)
fig.suptitle('Proposed tyre load sensitivity', x=.07, y=.96, ha='left',
             fontsize=22, fontweight='bold', color='#172638')
fig.text(.07, .895, 'Grip efficiency falls as each tyre carries more vertical load.',
         fontsize=13, color='#445469')
colors = {'front':'#2563eb', 'rear':'#d97706', 'current':'#485568'}
for ax in axes:
    ax.grid(True, color='#e2e8f0', linewidth=.7)
    ax.set_axisbelow(True)
    ax.set_xlim(0, 12)
    ax.set_xlabel('Vertical load per tyre (kN)')
axes[0].plot(loads/1000, current_mu, '--', color=colors['current'], lw=2, label='Current model')
axes[0].plot(loads/1000, front_force/loads, color=colors['front'], lw=2.5, label='Proposed front')
axes[0].plot(loads/1000, rear_force/loads, color=colors['rear'], lw=2.5, label='Proposed rear')
axes[0].set_ylabel('Effective grip coefficient (peak force / vertical load)')
axes[0].set_ylim(.6, 1.85)
axes[0].set_title('Efficiency drop-off', loc='left', fontweight='bold', pad=14)
axes[1].plot(loads/1000, current_mu*loads/1000, '--', color=colors['current'], lw=2)
axes[1].plot(loads/1000, front_force/1000, color=colors['front'], lw=2.5)
axes[1].plot(loads/1000, rear_force/1000, color=colors['rear'], lw=2.5)
axes[1].set_ylabel('Pure lateral peak force per tyre (kN)')
axes[1].set_ylim(0, 20)
axes[1].set_title('Available cornering force', loc='left', fontweight='bold', pad=14)
for wheel, data in comparison['wheels'].items():
    load = data['load_n']
    is_front = wheel.startswith('f')
    force = proposed_force(load, is_front)
    color = colors['front' if is_front else 'rear']
    axes[0].scatter(load/1000, force/load, color=color, edgecolor='white', zorder=5, s=65)
    axes[0].annotate(f'{wheel.upper()}  {load/1000:.1f} kN', (load/1000, force/load),
                     xytext=(0, 17 if is_front else -25), textcoords='offset points',
                     ha='center', fontsize=9, color=color)
    axes[1].scatter(load/1000, force/1000, color=color, edgecolor='white', zorder=5, s=65)
fig.legend(*axes[0].get_legend_handles_labels(), loc='upper left',
           bbox_to_anchor=(.063, .89), ncol=3, frameon=False)
fig.text(.07, .115, 'Dots: median wheel loads from your Indy run (2,654 corner samples).',
         fontsize=10, color='#445469')
fig.text(.07, .045, 'Proposal uses the recovered ICR2 load curve, baseline compound 58200 and matched static weight.\n'
         'Native SI conversion remains unproven. This plots load sensitivity; post-slide falloff is a separate curve.',
         fontsize=9, color='#607086', linespacing=1.5)
out = ROOT/'docs/plots'
out.mkdir(parents=True, exist_ok=True)
for suffix in ['png', 'svg']:
    fig.savefig(out/f'proposed_tyre_load_dropoff.{suffix}', dpi=180, facecolor='white')
with (out/'proposed_tyre_load_dropoff.csv').open('w', newline='', encoding='utf-8') as stream:
    writer=csv.writer(stream)
    writer.writerow(['vertical_load_n','current_mu','proposed_front_mu','proposed_rear_mu',
                     'current_peak_n','proposed_front_peak_n','proposed_rear_peak_n'])
    writer.writerows(zip(loads,current_mu,front_force/loads,rear_force/loads,
                        current_mu*loads,front_force,rear_force))
print(f'Saved plots and curve data to {out}; normalization {scale:.6f} native load units/N')
