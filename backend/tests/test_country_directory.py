import json
import re
from pathlib import Path
from test_api import client

ROOT = Path(__file__).resolve().parents[1]


def test_complete_itu_geographic_directory_and_existing_namespaces():
    rows = client.get('/v1/countries').json()
    assert len(rows) == 243
    assert len({row['iso2'] for row in rows}) == len(rows)
    assert all(re.fullmatch(r'[1-9][0-9]{0,2}', row['nid']) for row in rows)
    by_iso = {row['iso2']: row for row in rows}
    for iso, nid in {'GB':'44', 'DE':'49', 'BR':'55', 'AU':'61', 'ZA':'27',
                     'NZ':'64', 'ZW':'263', 'KE':'254', 'XK':'383', 'AC':'247',
                     'AX':'358', 'AS':'1', 'GG':'44', 'YT':'262', 'VA':'39', 'KZ':'7', 'US':'1', 'CA':'1', 'JM':'1', 'JP':'81', 'IN':'91'}.items():
        assert by_iso[iso]['nid'] == nid
    assert by_iso['US']['default_language_tag'] == 'en-US'
    assert by_iso['GB']['default_language_tag'] is None
    assert not {'800','808','870','878','881','882','883','888','979','997'} & {row['nid'] for row in rows}


def test_seed_matches_catalog_without_mutating_existing_rows():
    rows = json.loads((ROOT/'data/country_namespaces.json').read_text())
    sql = (ROOT/'sql/004_country_directory.sql').read_text()
    for row in rows:
        escaped = row['country_name'].replace("'", "''")
        assert f"('{row['iso2']}', '{escaped}', '{row['nid']}'," in sql
    assert 'WHERE existing.iso2 = seed.iso2' in sql
    assert 'ON CONFLICT DO NOTHING' in sql
    assert not re.search(r'\b(UPDATE|DELETE|GRANT|REVOKE|ALTER)\b', sql)


def test_workbook_reconciliation_is_complete_without_invented_namespaces():
    import csv
    doc = ROOT.parent/'docs'
    with (doc/'COUNTRY_WORKBOOK_RECONCILIATION.csv').open() as stream:
        rows = list(csv.DictReader(stream))
    assert [int(row['row']) for row in rows] == list(range(1, 281))
    assert sum(row['status'] == 'excluded-service' for row in rows) == 14
    assert sum(row['status'] == 'review' for row in rows) == 9
    assert rows[134]['nid'] == '7'
    assert rows[1]['nid'] == '358'
    assert rows[4]['nid'] == '1'
    assert rows[271]['nid'] == '39'
    notes = json.loads((doc/'COUNTRY_LANGUAGE_NOTES.json').read_text())
    assert notes['countries']['KZ'][0]['languages'] == 'Kazakh, Russian'
    # Human-language descriptions are deliberately not injected into API tags.
    catalog = json.loads((ROOT/'data/country_namespaces.json').read_text())
    assert all(row['default_language_tag'] is None for row in catalog
               if row['iso2'] not in {'US','CA','FR','JP','IN'})
