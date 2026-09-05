"""Read-only, stdlib-only witness. Does not import or query controller code/state.

Independent observation path on one trusted host, NOT independent attestation.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sqlite3


def observe(path: Path) -> dict:
    db = sqlite3.connect(path.resolve().as_uri() + '?mode=ro', uri=True)
    try:
        db.execute('PRAGMA query_only=ON')
        db.execute('BEGIN')
        integrity = db.execute('PRAGMA integrity_check').fetchone()[0]
        requests = db.execute('SELECT id,token FROM requests ORDER BY id').fetchall()
        effects = db.execute('SELECT id,token,receipt FROM effects ORDER BY id').fetchall()
        rows = {'requests': requests, 'effects': effects}
        digest = hashlib.sha256(json.dumps(rows, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
        return {'integrity': integrity, 'request_count': len(requests),
                'effect_count': len(effects), 'rows_sha256': digest, 'rows': rows}
    finally:
        db.close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('database', type=Path)
    args = parser.parse_args()
    print(json.dumps(observe(args.database), sort_keys=True))
