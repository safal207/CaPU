"""Read-only effect observer; does not import controller or receipt code."""
import json
from pathlib import Path
import sqlite3
import sys


def observe(path):
    db = sqlite3.connect(Path(path).resolve().as_uri() + '?mode=ro', uri=True)
    try:
        rows = db.execute('SELECT operation,attempt FROM effects ORDER BY id').fetchall()
        closed = db.execute('SELECT operation,attempt FROM closed ORDER BY operation,attempt').fetchall()
        return {'integrity': db.execute('PRAGMA integrity_check').fetchone()[0],
                'effect_count': len(rows), 'effect_rows': rows, 'closed_rows': closed,
                'request_count': db.execute('SELECT COUNT(*) FROM calls').fetchone()[0]}
    finally:
        db.close()

if __name__ == '__main__':
    print(json.dumps(observe(sys.argv[1]), sort_keys=True))
