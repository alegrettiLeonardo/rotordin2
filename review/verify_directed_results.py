"""Evaluate mathematical postconditions, not the native process return code alone."""
from pathlib import Path
import json, math, re, sys

def read_torque(case: Path) -> dict:
    text=(case/'stdout.txt').read_text(errors='replace')
    lines=text.splitlines(); marker=' Torsion Output Torque at Division (Nm)'
    if marker not in lines: raise ValueError(f'Missing torque table: {case}')
    rows=[]; started=False
    for line in lines[lines.index(marker)+1:]:
        try: values=[float(x.replace('D','E')) for x in line.split()]
        except ValueError:
            if started: break
            continue
        if len(values)<2:
            if started: break
            continue
        rows.append(values);started=True
    if not rows:raise ValueError(f'Empty torque table: {case}')
    if any(not math.isfinite(v) for row in rows for v in row):raise ValueError(f'Nonfinite values: {case}')
    return {'returncode':int((case/'rc.txt').read_text()),'rows':len(rows),
            'last_time_s':rows[-1][0],'last_torque_Nm':rows[-1][1],
            'nonzero_torque_rows':sum(row[1]!=0 for row in rows),
            'terminal_OK':bool(re.search(r'EVENT=END.*STATUS=OK', (case/'stderr.txt').read_text(errors='replace')))}

def main() -> int:
    out=Path(sys.argv[1]); results={};failures=[]
    for mode in ['release','debug']:
        folder=out/mode
        grid=(folder/'grid_current.log').read_text()
        match=re.search(r'^INDEPENDENT_GRID_FAILURES=(\d+)$',grid,re.M)
        if not match:raise ValueError(f'Missing grid summary: {mode}')
        count=int(match.group(1)); results[mode]={'scalar_mathematical_failures':count}
        if count:failures.append(f'{mode}: {count} scalar time-grid checks failed')
        for case in ['default_output','explicit_output','roundoff_end','roundoff_end_baseline_routine']:
            results[mode][case]=read_torque(folder/case)
            if results[mode][case]['returncode']!=0:failures.append(f'{mode}/{case}: native execution failed')
        default=results[mode]['default_output']; explicit=results[mode]['explicit_output']
        if abs(default['last_torque_Nm']-explicit['last_torque_Nm'])>1e-10:
            failures.append(f'{mode}: changing only output grid changes terminal torque')
        if explicit['nonzero_torque_rows']==0:failures.append(f'{mode}: explicit output control is unexpectedly zero')
        current=results[mode]['roundoff_end']; before=results[mode]['roundoff_end_baseline_routine']
        if abs(current['last_torque_Nm']-before['last_torque_Nm'])>1e-10:
            failures.append(f'{mode}: integer-ratio terminal state lost relative to routine-level control')
    result={'status':'FAIL' if failures else 'PASS','failures':failures,'results':results,
            'baseline_scope':'only tnuinteg restored from historical commit; other source objects current'}
    (out/'directed_summary.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2));return 1 if failures else 0
if __name__=='__main__':
    try:sys.exit(main())
    except Exception as exc:
        print(f'REVIEW_ERROR: {exc}',file=sys.stderr);sys.exit(2)
