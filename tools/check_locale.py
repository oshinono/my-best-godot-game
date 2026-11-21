"""Run from any directory: python3 tools/check_locale.py"""
import csv
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
with (root / 'locale/ui.csv').open(encoding='utf-8', newline='') as file:
    rows = csv.DictReader(file)
    assert rows.fieldnames == 'keys ru en zh hi es ar'.split()
    keys = set()
    for row in rows:
        key = row['keys']
        assert key not in keys and key == row['ru'], key
        keys.add(key)
        for value in row.values():
            assert value, key
            assert re.findall(r'%(?:%|[.\d]*[dfs])', value) == re.findall(r'%(?:%|[.\d]*[dfs])', key), key
for scene in (root / 'scenes').rglob('*.tscn'):
    for label in re.findall(r'^text = "([^"]+)"', scene.read_text(), re.M):
        assert not re.search('[А-Яа-яЁё]', label) or label in keys, (scene, label)
print(f'{len(keys)} translation keys OK')
