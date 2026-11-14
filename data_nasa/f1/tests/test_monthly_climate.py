import json
from datetime import date
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from src.f1.archive import PARAMETERS, normalize, make_archive, write_archive, request_url, load_locations, build, UNITS


class MonthlyTests(unittest.TestCase):
    def test_missing_annual_and_incomplete_month(self):
        values = {p: {'198001': -999, '198002': 0, '198013': 100,
                      '198101': 2, '198102': 9} for p in PARAMETERS}
        data = {'header': {'fill_value': -999}, 'properties': {'parameter': values}}
        rows = normalize(data, 1980, 1981, date(1981, 2, 28))
        self.assertEqual(len(rows), 24)
        self.assertEqual(rows[0], ['1980-01', None, None, None, None, None])
        self.assertEqual(rows[1], ['1980-02', 0, 0, 0, 0, 0])
        self.assertEqual(rows[12][-1], 62)
        self.assertIsNone(rows[13][1])
        self.assertFalse(any(r[0].endswith('-13') for r in rows))

    def test_leap_year_rainfall(self):
        data = {'header': {}, 'properties': {'parameter': {p: {'202402': 2} for p in PARAMETERS}}}
        self.assertEqual(normalize(data, 2024, 2024, date(2025, 1, 1))[1][-1], 58)

    def test_json_roundtrip_preserves_shared_series_and_ward_codes(self):
        locations = [dict(ward_code=code, series_id='s', province_code='01',
                          province_name='Hà Nội', latitude=21, longitude=105)
                     for code in ('00002', '00001')]
        series = {'s': [['2024-01', 20, 0, None, 10, 0]]}
        archive = make_archive({}, locations, series)
        with tempfile.TemporaryDirectory() as d:
            report = write_archive(Path(d), archive, 2)
            restored = json.loads((Path(d)/'climate.json').read_text(encoding='utf-8'))
            self.assertEqual(restored, archive)
            self.assertEqual(report['logical_monthly_rows'], 2)
            self.assertEqual(report['json_bytes'], (Path(d)/'climate.json').stat().st_size)
            self.assertEqual(restored['locations'][0]['ward_code'], '00001')
            self.assertIsNone(restored['series']['s'][0][3])
            self.assertEqual({p.suffix for p in Path(d).iterdir()}, {'.json'})

    def test_missing_series_rejected(self):
        with self.assertRaises(ValueError):
            make_archive({}, [dict(ward_code='00001', series_id='absent')], {})

    def test_export_from_json_cache_without_network(self):
        import hashlib
        from types import SimpleNamespace
        from unittest.mock import patch
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            wards = root/'wards.json'
            wards.write_text(json.dumps([dict(id='00001', name={'local': 'Xã mẫu'},
                parent={'id': '01', 'name': {'local': 'Hà Nội'}}, geo={'lat': '21', 'lon': '105'})]))
            cache = root/'cache'; cache.mkdir()
            url = request_url(21.0, 105.0, 2024, 2024)
            response = {'header': {'time_standard': 'LST', 'fill_value': -999},
                        'properties': {'parameter': {p: {'202402': 2} for p in PARAMETERS}}}
            (cache/(hashlib.sha256(url.encode()).hexdigest()+'.json')).write_text(json.dumps(
                dict(url=url, fetched_at='2026-11-09', response=response)))
            args = SimpleNamespace(locations=wards, provinces='all', output=root/'out',
                start_year=2024, end_year=2024, as_of=date(2025,1,1), workers=1,
                cache=cache, offline=True, refresh=False, budget_mb=250)
            with patch('src.f1.archive.subprocess.run', side_effect=AssertionError('Unexpected network')):
                build(args)
            result=json.loads((args.output/'climate.json').read_text(encoding='utf-8'))
            rows=result['series'][result['locations'][0]['series_id']]
            self.assertEqual(len(rows),12)
            self.assertEqual(rows[1][-1],58)

    def test_request_clips_unavailable_early_years(self):
        self.assertIn('start=1981',request_url(21,105,1977,2026))

    def test_duplicate_admin_code_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'wards.json'
            w={'id':'01','geo':{'lat':'21','lon':'105'}}
            p.write_text(json.dumps([w,w]))
            with self.assertRaises(ValueError):
                load_locations(p)

if __name__ == '__main__':
    unittest.main()
