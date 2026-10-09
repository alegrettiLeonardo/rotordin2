#!/usr/bin/env python3
"""Read only one completed exact-SHA campaign; write a separate metrics JSON.

No solver/test execution, repository edits, evidence edits, or recursive search.
Missing evidence is BLOCKED; inconsistent/failed evidence is FAIL. This is a
collector of observed qualification results, not a replacement physical oracle.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import sys

EXPECTED_COMMIT = '539134eaee209f6de1c0c91e705fe92a75a28412'
REPORT_KEYS = ['n_integrated','n_requested','n_published','complete','t_initial',
               't_final_requested','last_integrated_time','last_step','last_published_time']
GATES = ['REV01','REV02','completeness','no_false_success','physics','refinement','cli']


def finite_json_constant(value):
    raise ValueError('nonfinite JSON constant '+value)


class Evidence:
    def __init__(self, root):
        self.root = root
        self.files = {}
        self.missing = []
        self.errors = []

    def read(self, relative, json_value=False):
        path = self.root / relative
        if not path.is_file():
            self.missing.append(relative)
            return None
        raw = path.read_bytes()
        self.files[relative] = {'sha256': hashlib.sha256(raw).hexdigest(), 'bytes': len(raw)}
        try:
            text = raw.decode('utf-8')
            return json.loads(text, parse_constant=finite_json_constant) if json_value else text
        except (UnicodeError, ValueError) as exc:
            self.errors.append(relative+': '+str(exc))
            return None

    def require(self, condition, message):
        if not condition:
            self.errors.append(message)


def finite_number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def native_report(text):
    lines = text.splitlines()
    reports = [line.split()[1:] for line in lines if line.startswith('REPORT ')]
    if len(reports) != 1 or len(reports[0]) != len(REPORT_KEYS):
        raise ValueError('native REPORT missing, duplicate, or malformed')
    values = [int(x) for x in reports[0][:4]] + [float(x) for x in reports[0][4:]]
    if not all(math.isfinite(x) for x in values):
        raise ValueError('native REPORT contains nonfinite values')
    masks = [list(map(int, line.split()[1:])) for line in lines if line.startswith('FILLED')]
    if len(masks) != 1:
        raise ValueError('native FILLED missing or duplicate')
    rows = [[float(x) for x in line.split()[2:]] for line in lines if line.startswith('ROW ')]
    return dict(zip(REPORT_KEYS, values)), masks[0], rows


def summarize_mode(evidence, mode, expected):
    prefix = 'integrated/REV/'+mode+'/'
    summary = evidence.read(prefix+'summary.json', True)
    status = evidence.read(prefix+'status.json', True)
    rc = evidence.read(prefix+'returncode')
    source = evidence.read(prefix+'source_commit.txt')
    native = evidence.read(prefix+'native/native_summary.json', True)
    cli = evidence.read(prefix+'cli/cli_summary.json', True)
    if any(x is None for x in (summary,status,rc,source,native,cli)):
        return {'status':'BLOCKED','reason':'required mode evidence missing or unreadable'}
    evidence.require(summary.get('mode') == status.get('mode') == mode, mode+': mode identity')
    evidence.require(summary.get('source_commit') == status.get('source_commit') == source.strip() == expected,
                     mode+': exact source commit mismatch')
    evidence.require(status.get('id') == 'REV_TEMPORAL' and status.get('summary') == 'summary.json',
                     mode+': status contract mismatch')
    evidence.require(rc.strip() == '0' and summary.get('status') == status.get('status') == 'PASS',
                     mode+': failed native/CLI campaign status')
    evidence.require(summary.get('native') == native and summary.get('cli') == cli,
                     mode+': consolidated and individual summaries disagree')
    evidence.require(summary.get('gates') == status.get('gates') and
                     all(summary.get('gates',{}).get(key) == 'PASS' for key in GATES), mode+': gate mismatch/failure')
    evidence.require(native.get('baseline') is False and native.get('status') == cli.get('status') == 'PASS',
                     mode+': baseline mode or failed individual result')
    cases = native.get('cases',{})
    valid = [name for name in cases if '_invalid_' not in name]
    invalid = [name for name in cases if '_invalid_' in name]
    nonfinite = [name for name in cases if '_invalid_nonfinite_' in name]
    evidence.require(native.get('case_count') == len(cases) == 140 and len(valid) == 94 and len(invalid) == 46,
                     mode+': unexpected corpus count')
    evidence.require(len(nonfinite) == 28 and all(x.get('status') == 'PASS' for x in cases.values()),
                     mode+': missing nonfinite coverage or failed case')
    maxima = {}
    for name,case in cases.items():
        for metric,value in case.get('metrics',{}).items():
            if metric.endswith('_scaled_error') or metric in ('equilibrium_eta','energy_balance_scaled'):
                if not finite_number(value):
                    evidence.errors.append(mode+'/'+name+': nonfinite '+metric)
                    continue
                if metric not in maxima or value > maxima[metric]['value']:
                    maxima[metric] = {'value':value,'case':name}
    sequences = native.get('refinements',[])
    evidence.require(len(sequences) == 38 and all(item.get('status') == 'PASS' for item in sequences),
                     mode+': refinement sequence count/status')
    grouped_orders = {}
    for item in sequences:
        key = 'method'+str(item['method'])+'/'+item['metric']
        group = grouped_orders.setdefault(key, {'minimum_measured_order':None,'round_off_limited_pairs':0,'models':[]})
        group['models'].append(item['model'])
        for order in item.get('orders',[]):
            if order == 'ROUND_OFF_LIMIT':
                group['round_off_limited_pairs'] += 1
            elif finite_number(order):
                old = group['minimum_measured_order']
                group['minimum_measured_order'] = order if old is None else min(old,order)
            else:
                evidence.errors.append(mode+': invalid measured refinement order')
    fine = {}
    for method in (0,1):
        name = 'm'+str(method)+'_fine41'
        text = evidence.read(prefix+'native/'+name+'/stdout.txt')
        if text is None:
            continue
        try:
            report,mask,rows = native_report(text)
            evidence.require(report['n_integrated'] == 10 and report['n_requested'] == report['n_published'] == 41
                             and report['complete'] == 1 and len(mask) == 41 and all(x == 1 for x in mask)
                             and len(rows) == 41, mode+'/'+name+': counter/fill mismatch')
            evidence.require(all(len(row)>=5 and all(math.isfinite(x) for x in row[:5]) for row in rows),
                             mode+'/'+name+': nonfinite active output')
            metrics = cases[name]['metrics']
            fine[name] = {'status':cases[name]['status'],'counters_and_times':report,'actual_rows':len(rows),
                          'filled_rows':sum(mask),'last_time_q_v_a_load':rows[-1][:5],
                          'scaled_errors':{key:metrics[key] for key in ('q_scaled_error','v_scaled_error',
                          'a_dyn_scaled_error','load_scaled_error')},'equilibrium_eta':metrics['equilibrium_eta']}
        except (ValueError,KeyError,IndexError) as exc:
            evidence.errors.append(mode+'/'+name+': '+str(exc))
    cli_counts = {}
    for name in ('default_output','explicit_output','explicit_fine','explicit_coarse','explicit_incommensurate','roundoff_end'):
        text = evidence.read(prefix+'cli/'+name+'/stderr.txt')
        if text is None:
            continue
        lines = [line for line in text.splitlines() if line.startswith('RD_TORSION_TIME ')]
        if len(lines) != 1:
            evidence.errors.append(mode+'/'+name+': CLI time report missing/duplicate')
            continue
        record = dict(re.findall(r'([A-Z_]+)=\s*(\S+)',lines[0]))
        cli_counts[name] = record
    independence = native.get('publication_independence',[])
    comparisons = cli.get('comparisons',[])
    native_difference = [x['max_error'] for x in independence if finite_number(x.get('max_error'))]
    cli_difference = [x['max_scaled_difference'] for x in comparisons if finite_number(x.get('max_scaled_difference'))]
    return {'status':summary.get('status'),'source_commit':source.strip(),'gates':summary.get('gates'),
            'counts':{'native':len(cases),'valid':len(valid),'invalid':len(invalid),'nonfinite_inputs':len(nonfinite),
                      'cli':len(cli.get('cases',{})),'refinement_sequences':len(sequences),
                      'publication_independence':len(independence),'cli_comparisons':len(comparisons)},
            'observed_maxima':maxima,'minimum_orders_by_method_and_metric':grouped_orders,
            'fine41':fine,'cli_time_reports':cli_counts,
            'maximum_publication_independence_error':max(native_difference) if native_difference else None,
            'maximum_cli_common_time_difference':max(cli_difference) if cli_difference else None,
            'native_fill_control':native.get('native_fill_control'),
            'negative_fill_controls':native.get('negative_fill_controls'),'declared_criteria':native.get('criteria')}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('campaign',type=Path)
    parser.add_argument('output',type=Path)
    parser.add_argument('--expected-commit',default=EXPECTED_COMMIT)
    args = parser.parse_args()
    campaign = args.campaign.resolve()
    output = args.output.resolve()
    if output.is_relative_to(campaign):
        parser.error('output must be outside the read-only campaign directory')
    evidence = Evidence(campaign)
    for relative in ('integrated/source_commit.txt','integrated/source_commit.after.txt'):
        text = evidence.read(relative)
        if text is not None:
            evidence.require(text.strip() == args.expected_commit,relative+': wrong exact SHA')
    for relative in ('integrated/returncode.txt','integrated.returncode.txt','after-directed.returncode.txt'):
        text = evidence.read(relative)
        if text is not None:
            evidence.require(text.strip() == '0',relative+': nonzero return')
    directed = evidence.read('after_directed/directed_summary.json',True)
    aggregate = evidence.read('integrated/REV-gates.json',True)
    if directed is not None:
        evidence.require(directed.get('status') == 'PASS','original directed review failed')
    if aggregate is not None:
        evidence.require(aggregate.get('status') == 'PASS','integrated REV gate aggregate failed')
    modes = {}
    for mode in ('release','debug'):
        try:
            modes[mode] = summarize_mode(evidence,mode,args.expected_commit)
        except (KeyError,TypeError,ValueError) as exc:
            evidence.errors.append(mode+': malformed evidence: '+str(exc))
            modes[mode] = {'status':'FAIL','reason':str(exc)}
    status = 'FAIL' if evidence.errors else 'BLOCKED' if evidence.missing else 'PASS'
    result = {'id':'REV_FINAL_TEMPORAL_METRICS','status':status,'source_commit':args.expected_commit,
              'campaign':str(campaign),'scope':'Read-only collection from exact completed campaign; no solver/test execution',
              'modes':modes,'missing':evidence.missing,'errors':evidence.errors,'evidence_files':evidence.files,
              'limits':['Initial states are zero in the exercised public temporal interface.',
                        'Published acceleration satisfies dynamic equilibrium; it is not asserted equal to Hermite second derivative.',
                        'State references: exact free polynomials, augmented matrix exponential, and DOP853 for the declared natural cubic tabulated forcing.',
                        'No separate second scalar root/exponential implementation was executed.',
                        'Energy state error and integration-node trajectory balance are distinct metrics; arbitrary-output reconstruction balance is diagnostic.',
                        'Normalized error maxima use the scales declared by the test helper; effort metric covers oriented torque/stress fixture channels.',
                        'A02 three-node and A07 general rotation-ramp global gates remain NOT_QUALIFIED; missing historical ST41 remains BLOCKED.']}
    output.parent.mkdir(parents=True,exist_ok=True)
    temporary = output.with_suffix(output.suffix+'.tmp')
    temporary.write_text(json.dumps(result,indent=2,allow_nan=False)+'\n')
    temporary.replace(output)
    print(json.dumps({'status':status,'source_commit':args.expected_commit,'output':str(output),
                      'missing':len(evidence.missing),'errors':evidence.errors}))
    return 0 if status == 'PASS' else 2 if status == 'BLOCKED' else 1


if __name__ == '__main__':
    sys.exit(main())
