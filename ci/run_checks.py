"""Execute both workflows in a fresh directory without any bundled results."""
import argparse
import csv
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--rscript', default='Rscript')
    args = parser.parse_args()
    evidence = ROOT/'ci-results'
    evidence.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='credit-risk-ci-',dir=evidence) as temporary:
        clean = Path(temporary)
        assert clean.resolve().parent == evidence.resolve()
        for script in ROOT.glob('*.R'):
            shutil.copy2(script, clean/script.name)
        shutil.copy2(ROOT/'run_sql_checks.py',clean/'run_sql_checks.py')
        for directory in ('data','sql'):
            shutil.copytree(ROOT/directory,clean/directory)
        assert not (clean/'results').exists()
        try:
            for name, command in [('r_analysis',[args.rscript,'analysis.R']),
                                  ('sql_controls',[sys.executable,'run_sql_checks.py'])]:
                completed = subprocess.run(command,cwd=clean,capture_output=True,text=True,errors='replace')
                log = completed.stdout+completed.stderr
                (evidence/(name+'.log')).write_text(log,encoding='utf-8')
                print(log)
                if completed.returncode:
                    raise RuntimeError(f'{name} failed with exit code {completed.returncode}')
            outputs = clean/'results'
            sql_result = json.loads((outputs/'sql_execution.json').read_text())
            assert sql_result['all_passed'] and sql_result['controls']==12
            assert len(sql_result['fault_injection_checks'])==5
            assert all(x['injected_fault_detected'] for x in sql_result['fault_injection_checks'])
            with (outputs/'robustness_runs.csv').open(newline='') as f:
                assert len(list(csv.DictReader(f)))==150
            for name in ('project_summary','monitoring','explainability','robustness','decision_sensitivity'):
                file = outputs/(name+'.png')
                assert file.stat().st_size>1000 and file.read_bytes()[:8]==b'\x89PNG\r\n\x1a\n'
            (evidence/'verification.json').write_text(json.dumps({
                'status':'passed','fresh_results':True,'sql_controls':12,
                'fault_injections':5,'robustness_model_rows':150,'generated_charts':5},indent=2))
            print('PASS: clean-input R + SQL execution and output verification.')
        finally:
            if (clean/'results').exists():
                shutil.copytree(clean/'results',evidence/'results',dirs_exist_ok=True)

if __name__ == '__main__':
    main()
