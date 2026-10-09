"""Full CLI publication regression; decks originate in the supplied review.

Only RSSTP varies among the principal five controls. State/torque/stress/load
agreement is checked at every shared printed physical time, including tf.
Independent absolute physical oracles are in rev_temporal_oracle.py.
"""
import json
from pathlib import Path
import re
import subprocess
import sys
import numpy as np

HEADINGS={'load':'Input Interpolated Torque (Nm)', 'angle':'Total Angular Displacement (rad)',
          'division_angle':'Angular Displacement at division (rad)',
          'torque':'Torsion Output Torque at Division (Nm)',
          'stress':'Torsion Output Shear Stress at div.(rad/s) x (Pa)'}

def valid_diagnostics(stderr,rows,steps,final_time):
    issues=[]
    ok_events=re.findall(r'^.*TORSION_TRANSIENT.*EVENT=END.*STATUS=OK\s*$',stderr,re.M)
    if len(ok_events)!=1:issues.append('valid CLI requires exactly one transient END OK')
    if re.search(r'TORSION_TRANSIENT.*EVENT=END.*STATUS=FAIL',stderr):
        issues.append('valid CLI emitted transient END FAIL')
    records={}
    for prefix in ('RD_TORSION_TIME','RD_TORSION_PRODUCT'):
        lines=[line for line in stderr.splitlines() if line.startswith(prefix+' ')]
        if len(lines)!=1:
            issues.append(prefix+' missing/duplicate final report');continue
        records[prefix]=dict(re.findall(r'([A-Z_]+)=\s*(\S+)',lines[0]))
        if records[prefix].get('COMPLETE')!='T':issues.append(prefix+' incomplete')
        if stderr.rfind(lines[0])>stderr.rfind(ok_events[0] if ok_events else '\0'):
            issues.append(prefix+' completion reported after END OK')
    expected={
      'RD_TORSION_TIME':dict(INTEGRATED=steps,REQUESTED=rows,PUBLISHED=rows,VALID_ROWS=rows,VALID_CHANNELS=7*rows),
      'RD_TORSION_PRODUCT':dict(VALID_ROWS=rows,VALID_CHANNELS=3*rows)}
    for prefix,wanted in expected.items():
        record=records.get(prefix,{})
        for key,value in wanted.items():
            try:actual=int(record.get(key,''))
            except ValueError:actual=None
            if actual!=value:issues.append(prefix+' '+key+' disagrees with requested case')
    for key in ('LAST_INTEGRATED','LAST_PUBLISHED'):
        try:actual=float(records.get('RD_TORSION_TIME',{}).get(key,''))
        except ValueError:actual=float('inf')
        if not np.isfinite(actual) or abs(actual-final_time)>2e-10:
            issues.append('RD_TORSION_TIME '+key+' differs from tf or is nonfinite')
    return issues

def tables(text):
    result={};lines=text.splitlines()
    for key,heading in HEADINGS.items():
        indices=[i for i,line in enumerate(lines) if line.strip()==heading]
        if len(indices)!=1:raise ValueError('missing/duplicate table '+key)
        rows=[]
        for line in lines[indices[0]+1:]:
            try: row=[float(word.replace('D','E')) for word in line.split()]
            except ValueError:
                if rows:break
                continue
            if len(row)<2:
                if rows:break
                continue
            rows.append(row)
        a=np.asarray(rows)
        if a.ndim!=2 or not len(a) or not np.all(np.isfinite(a)):raise ValueError('invalid table '+key)
        result[key]=a
    return result

def trans(text,**values):
    lines=text.splitlines();index=next(i for i,line in enumerate(lines) if line.startswith('TRANS ITSTP'))+1
    fields=lines[index].split()
    for key,value in values.items():fields[{'h':1,'hs':2,'t0':4,'tf':5}[key]]=format(value,'.12g')
    if any(len(x)>10 for x in fields):raise ValueError('fixed width input field exceeded')
    lines[index]=''.join(x.ljust(10) for x in fields)
    return '\n'.join(lines)+'\n'

def main():
    binary,fixtures,out=map(Path,sys.argv[1:4]);out.mkdir(parents=True)
    base=(fixtures/'explicit_output.txt').read_text()
    cases={name:(fixtures/(name+'.txt')).read_text() for name in ('default_output','explicit_output','roundoff_end')}
    cases.update(explicit_fine=trans(base,hs=.00025),explicit_coarse=trans(base,hs=.002),
                 explicit_incommensurate=trans(base,hs=.0013))
    # Same physical experiment translated by a representable large time origin;
    # its milliseconds must remain distinct in the printed time column.
    shifted=trans(base,h=.001,hs=.001,t0=1e6,tf=0)
    shifted=shifted.replace('0 .004 .008 .012 .016','1000000 1000000.004 1000000.008 1000000.012 1000000.016')
    cases['translated_text']=shifted
    cases['invalid_negative_output']=trans(base,hs=-.001)
    results={};parsed={};failures=[]
    expected={'default_output':65,'explicit_output':17,'roundoff_end':30,'explicit_fine':65,
              'explicit_coarse':9,'explicit_incommensurate':14,'translated_text':17}
    for name,deck in cases.items():
        folder=out/name;folder.mkdir();(folder/'input.txt').write_text(deck)
        proc=subprocess.run([str(binary.resolve()),'-std','-n'],input=deck,text=True,capture_output=True,timeout=40,cwd=folder)
        for filename,data in [('stdout.txt',proc.stdout),('stderr.txt',proc.stderr),('returncode',str(proc.returncode)+'\n')]:
            (folder/filename).write_text(data)
        issues=[]
        success=bool(re.search(r'TORSION_TRANSIENT.*EVENT=END.*STATUS=OK',proc.stderr))
        if name.startswith('invalid'):
            if proc.returncode==0 or success:issues.append('invalid CLI input did not fail closed')
            if re.search(r'TORSION_TRANSIENT.*PERCENT=\s*100',proc.stderr):issues.append('invalid CLI emitted 100 percent')
            if re.search(r'^RD_TORSION_(?:TIME|PRODUCT).*COMPLETE=T',proc.stderr,re.M):
                issues.append('invalid CLI marked a product complete')
        else:
            if proc.returncode!=0:issues.append('CLI process failed')
            want=1000000.016 if name=='translated_text' else (.29 if name=='roundoff_end' else .016)
            issues.extend(valid_diagnostics(proc.stderr,expected[name],29 if name=='roundoff_end' else 16,want))
            try:
                data=tables(proc.stdout);parsed[name]=data
                for key,a in data.items():
                    if len(a)!=expected[name]:issues.append(key+' row count')
                    if np.any(np.diff(a[:,0])<=0):issues.append(key+' collapsed/nonincreasing printed time')
                    if abs(a[-1,0]-want)>2e-10:issues.append(key+' missing requested final time')
                if not np.any(data['torque'][1:,1:]!=0):issues.append('nonzero forcing produced allzero torque')
                if not np.allclose(data['load'][:,1:],.001,rtol=1e-12,atol=1e-15):issues.append('initial/subsequent applied torque wrong')
            except Exception as exc:issues.append(str(exc))
        results[name]=dict(status='FAIL' if issues else 'PASS',returncode=proc.returncode,issues=issues)
        failures.extend(name+': '+issue for issue in issues)
    comparisons=[]
    control=parsed.get('explicit_output')
    for name in ('default_output','explicit_fine','explicit_coarse','explicit_incommensurate'):
        for key in HEADINGS:
            item=dict(case=name,channel=key,status='FAIL',common_rows=0,max_scaled_difference=None)
            if control is not None and name in parsed:
                errs=[]
                for row in control[key]:
                    right=parsed[name][key];matches=right[np.abs(right[:,0]-row[0])<=2e-14]
                    if len(matches)==1:
                        # Six printed decimals in engineering notation give
                        # seven-to-nine significant digits. Shared values from
                        # unchanged nodal states should print identically.
                        errs.append(float(np.max(np.abs(matches[0,1:]-row[1:]))/max(1.,float(np.max(np.abs(row[1:]))))))
                item.update(common_rows=len(errs),max_scaled_difference=max(errs) if errs else None)
                if len(errs)>=2 and max(errs)<=1e-12:item['status']='PASS'
            comparisons.append(item)
            if item['status']!='PASS':failures.append(name+'/'+key+' shared-time mismatch')
    result=dict(status='FAIL' if failures else 'PASS',cases=results,comparisons=comparisons,failures=failures,
                scope='CLI publication/constitutive chain regression; independent physical references in native companion')
    (out/'cli_summary.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2));return int(bool(failures))

if __name__=='__main__':sys.exit(main())
