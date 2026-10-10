"""Compare recovered pure-lateral tyre capacity with recorded Godot wheel loads.

The mapping matches static weight, not a proven native-newton conversion.
This is an offline capacity comparison, not a driving replay or gameplay change.
"""
from pathlib import Path
import argparse
import csv
import hashlib
import json
import math
import statistics
import sys
from analyse_icr2_tyres import analyse, efficiency

sys.path.insert(0,str(Path(__file__).resolve().parent/'fixtures'))
from icr2_integer_core import IntegerCore


def lateral_peak(load, compound=58200):
    # Pure lateral, no longitudinal request. Plateau is 65535/65536.
    response=((efficiency(load)*65535)//65536*compound)//65536
    return ((response*load*2)>>16)&65535


def compare(executable, telemetry):
    report=analyse(executable)
    binary=executable.read_bytes()
    core=IntegerCore(binary,int(report['code_file_offset'],16),int(report['data_file_offset'],16))
    # Confirm reconstructed polynomial, pair adapter, and final force multiplication
    # against isolated instructions extracted freshly from the identified binary.
    for load in [0,1,500,1000,2000,4000,6000,10000,16000,25000,32767]:
        assert core.run(0x19690,{'eax':load})==efficiency(load)
    for load in [0,500,2000,6000,25000]:
        assert core.run(0x196DC,{'eax':load})==efficiency(load*1100//1000)
    for load in [500,1000,2000,4000,6000,8000]:
        for compound in [55100,56700,58200]:
            response=((efficiency(load)*65535)//65536*compound)//65536
            core.memory(0x25E90,2,65535) # lateral direction ratio
            core.memory(0x25E92,2,0)     # longitudinal direction ratio
            core.memory(0x25E94,2,1)    # lateral sign
            core.memory(0x25E8A,2,1)    # longitudinal sign
            core.run(0x195A4,{'eax':response,'edx':0,'ebx':load,'ecx':efficiency(load)},(0x80000,0x80002))
            assert core.memory(0x80000,2)==lateral_peak(load,compound)
            assert core.memory(0x80002,2)==0
    with telemetry.open(newline='',encoding='utf-8') as stream: rows=list(csv.DictReader(stream))
    selected=[r for r in rows if r['handling_model']=='wheel_contacts_rear_differential_v1'
              and 340<float(r['speed_kph'])<375 and 12<abs(float(r['yaw_deg_s']))<30
              and abs(float(r['rear_slip_deg']))<8 and r['grounded']=='1']
    if not selected:raise ValueError('No qualifying cornering samples')
    comparisons={}
    for corner in ['fl','fr','rl','rr']:
        values=[]
        for r in selected:
            # Native mass is dry 7500/7550 + fuel 32 units per gallon. The chosen
            # profiles are compared at the SAME physical mass as the recording.
            mass=float(r['vehicle_mass_kg']); fuel=float(r['fuel_gal']); load=float(r[corner+'_load_n'])
            native_mass=7500+32*fuel
            native_static_weight=native_mass*110/256
            units_per_n=native_static_weight/(mass*9.81)
            native_load=max(0,round(load*units_per_n))
            curve_load=native_load*1100//1000 if corner.startswith('f') else native_load
            coefficient=efficiency(curve_load)
            response=((coefficient*65535)//65536*58200)//65536
            peak_native=(2*response*native_load)>>16
            peak_n=peak_native/units_per_n
            demand=math.hypot(float(r[corner+'_fx_n']),float(r[corner+'_fy_n']))
            values.append(dict(load_n=load,internal_load=native_load,
                               current_peak_n=float(r[corner+'_peak_n']),candidate_peak_n=peak_n,
                               current_usage=float(r[corner+'_usage']),capacity_ratio=peak_n/max(float(r[corner+'_peak_n']),1),
                               force_to_candidate_peak=demand/max(peak_n,1)))
        comparisons[corner]={k:statistics.median(v[k] for v in values) for k in values[0]}
    report['capacity_comparison']=dict(telemetry=str(telemetry.resolve()),samples=len(selected),
        mapping='Same static physical weight: L_native = Fz_N * ((7500 + 32*fuel_gal)*110/256)/(recorded_mass_kg*9.81)',
        compound_factor=58200,assumptions=['matched physical mass, not proven SI units','indices 0/1 treated as rear from driven torque/stagger paths; 2/3 as front','pure lateral plateau, no braking/drive share','fresh baseline compound response; temperature/wear/surface factors are not reconstructed'],
        wheels=comparisons)
    report['isolated_instruction_checks']='Polynomial, second-pair adapter and pure-lateral final force output agree with the bounded instruction interpreter.'
    if hashlib.sha256(executable.read_bytes()).hexdigest()!=report['sha256']:
        raise RuntimeError('Source hash changed during inspection')
    return report


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('executable',type=Path)
    parser.add_argument('telemetry',type=Path)
    args=parser.parse_args()
    result=compare(args.executable,args.telemetry)
    destination=Path(__file__).resolve().parents[1]/'tmp/icr2_analysis/tyre_capacity_comparison.json'
    destination.parent.mkdir(parents=True,exist_ok=True)
    destination.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(result['isolated_instruction_checks'])
    print(json.dumps(result['capacity_comparison'],indent=2))
