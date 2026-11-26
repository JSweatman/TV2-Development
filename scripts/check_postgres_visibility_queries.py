"""Execute the direct repository's actual queries inside the disposable proof DB.
Called only by test_disposable_bootstrap; not a service or production command.
"""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'backend/src'))
from repository import PostgresResolverRepository


def verify(sql):
    queries = []
    class Capture:
        def __enter__(self): return self
        def __exit__(self, *args): pass
        def cursor(self): return self
        def execute(self, query, params): queries.append((query, params))
        def fetchone(self): return None
        def fetchall(self): return []
    repo = PostgresResolverRepository('unused-local-capture')
    repo._connect = lambda: Capture()
    repo.get_listing('1', '700001', None)
    repo.prefix('1', '700001', None, 10)
    repo.prefix('1', '700001', 'news', 10)
    for visibility in ('private', 'restricted', 'invitation_only', 'public'):
        for query, params in queries:
            parts = query.split('%s')
            prepared = parts[0] + ''.join(f'${i}{part}' for i, part in enumerate(parts[1:], 1))
            literal = lambda value: 'NULL' if value is None else str(value) if isinstance(value, int) else "'" + value.replace("'", "''") + "'"
            commands = f"""BEGIN;
INSERT INTO listings(country_code,list_number,tldx,display_name,entity_type,visibility)
VALUES('1','700001',NULL,'SyntheticProbe','business','{visibility}'),
('1','700001','news','SyntheticProbe','business','{visibility}');
PREPARE captured AS {prepared};
EXECUTE captured({','.join(map(literal,params))});
ROLLBACK;
"""
            result = sql(commands)
            assert ('SyntheticProbe' in result) == (visibility == 'public'), (visibility, prepared)
    print('PASS actual direct-Postgres exact and both prefix query forms across four visibility values')
