"""Execute actual SQL using Python's bundled SQLite driver; no third-party packages.
The modeling remains in R. Run after analysis.R: python run_sql_checks.py
"""
from pathlib import Path
import csv
import hashlib
import json
import sqlite3

ROOT = Path(__file__).resolve().parent

def main():
    db = sqlite3.connect(':memory:')
    source = ROOT/'data/SouthGermanCredit.asc'
    lines = source.read_text().splitlines()
    columns = lines[0].split()
    rows = [(i, *map(int,line.split())) for i,line in enumerate(lines[1:],1) if line.strip()]
    db.execute('CREATE TABLE loans (source_row_id INTEGER, '+', '.join('"'+c+'" INTEGER' for c in columns)+')')
    db.executemany('INSERT INTO loans VALUES ('+','.join('?' for _ in range(len(columns)+1))+')',rows)
    db.execute('CREATE TABLE splits (id INTEGER, split TEXT)')
    with (ROOT/'results/split_manifest.csv').open(newline='') as f:
        db.executemany('INSERT INTO splits VALUES (?,?)',[(int(r['id']),r['split']) for r in csv.DictReader(f)])
    db.commit()
    quality_sql = (ROOT/'sql/quality_checks.sql').read_text()
    results = list(db.execute(quality_sql))
    for query,output in [('quality_checks.sql','sql_quality_checks.csv'),('portfolio_profile.sql','sql_portfolio_profile.csv')]:
        cursor = db.execute((ROOT/'sql'/query).read_text())
        with (ROOT/'results'/output).open('w',newline='') as f:
            writer = csv.writer(f); writer.writerow([c[0] for c in cursor.description]); writer.writerows(cursor)
    # Verify controls reject bad inputs, in isolated transactions rolled back after each test.
    mutations = [
        ('missing_values','UPDATE loans SET hoehe=NULL WHERE source_row_id=1'),
        ('category_domains','UPDATE loans SET laufkont=99 WHERE source_row_id=1'),
        ('positive_numeric_values','UPDATE loans SET laufzeit=-1 WHERE source_row_id=1'),
        ('split_id_uniqueness','INSERT INTO splits SELECT * FROM splits LIMIT 1'),
        ('source_without_split','DELETE FROM splits WHERE id=1'),
    ]
    checks=[]
    for expected,statement in mutations:
        db.execute('SAVEPOINT injection')
        db.execute(statement)
        observed={name: failures for name,failures,status in db.execute(quality_sql)}
        assert observed[expected]>0, f'Control failed to detect injection: {expected}'
        db.execute('ROLLBACK TO injection'); db.execute('RELEASE injection')
        checks.append({'control':expected,'injected_fault_detected':True})
    assert list(db.execute(quality_sql)) == results
    provenance={'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
        'sqlite_version':sqlite3.sqlite_version,'controls':len(results),
        'fault_injection_checks':checks,'all_passed':all(r[2]=='PASS' for r in results)}
    (ROOT/'results/sql_execution.json').write_text(json.dumps(provenance,indent=2))
    for name,failures,status in results: print(f'{status}: {name} ({failures})')
    print(f'{len(checks)} injected-fault checks passed; data restored after each test.')
    if not provenance['all_passed']: raise SystemExit('SQL quality gate failed')
    db.close()

if __name__ == '__main__': main()
