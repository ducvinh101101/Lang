"""Monthly NASA POWER archive; exact input coordinates, resumable HTTP cache."""
from __future__ import annotations

import argparse
import calendar
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import date, datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
PARAMETERS = ('T2M', 'PRECTOTCORR', 'WS10M', 'ALLSKY_SFC_SW_DWN')
ENDPOINT = 'https://power.larc.nasa.gov/api/temporal/monthly/point'
UNITS = {'T2M': 'C', 'PRECTOTCORR': 'mm/day', 'WS10M': 'm/s', 'ALLSKY_SFC_SW_DWN': 'MJ/m^2/day'}


def compact(value):
    return json.dumps(value, ensure_ascii=False, separators=(',', ':'), allow_nan=False).encode()


def load_locations(path):
    wards = json.loads(path.read_text())
    seen = set()
    for w in wards:
        if w['id'] in seen:
            raise ValueError(f"Duplicate ward code: {w['id']}")
        seen.add(w['id'])
        lat, lon = float(w['geo']['lat']), float(w['geo']['lon'])
        if not (-90 <= lat <= 90 and -180 <= lon <= 180):
            raise ValueError(f"Invalid coordinates: {w['id']}")
    return wards


def request_url(lat, lon, start, end, parameters=PARAMETERS):
    from urllib.parse import urlencode
    return ENDPOINT + '?' + urlencode(dict(parameters=','.join(parameters), community='AG',
        latitude=lat, longitude=lon, start=max(start, 1981), end=end, format='JSON'))


def fetch(lat, lon, start, end, cache, offline=False, refresh=False):
    url = request_url(lat, lon, start, end)
    key = hashlib.sha256(url.encode()).hexdigest()
    path = cache / (key + '.json')
    if path.exists() and not refresh:
        with path.open(encoding='utf-8') as f:
            wrapper = json.load(f)
        if wrapper['url'] != url:
            raise ValueError('Cache URL mismatch')
        return wrapper, path
    if offline:
        raise ValueError(f'Not cached: {lat},{lon}')
    for attempt in range(4):
        try:
            result = subprocess.run(['curl', '--noproxy', '*', '--fail-with-body', '--silent',
                '--show-error', '--connect-timeout', '20', '--max-time', '120', url],
                capture_output=True, check=True)
            data = json.loads(result.stdout)
            if not all(p in data.get('properties', {}).get('parameter', {}) for p in PARAMETERS):
                raise ValueError('Missing NASA parameter payload')
            for p in PARAMETERS:
                if data['parameters'][p]['units'] != UNITS[p]:
                    raise ValueError(f'Unexpected units for {p}: {data["parameters"][p]}')
            wrapper = {'url': url, 'fetched_at': datetime.now(timezone.utc).isoformat(), 'response': data}
            cache.mkdir(parents=True, exist_ok=True)
            temporary = path.with_suffix('.tmp')
            temporary.write_bytes(compact(wrapper))
            temporary.replace(path)
            return wrapper, path
        except (subprocess.CalledProcessError, ValueError) as exc:
            if attempt == 3:
                raise RuntimeError(f'NASA request failed: {lat},{lon}: {exc}') from exc
            time.sleep(2 ** (attempt + 1))


def normalize(data, start, end, as_of):
    values = data['properties']['parameter']
    fill = data['header'].get('fill_value', -999)
    rows = []
    for year in range(start, end + 1):
        for month in range(1, 13):
            key = f'{year:04d}{month:02d}'
            complete = (year, month) < (as_of.year, as_of.month)
            row = []
            for p in PARAMETERS:
                v = values[p].get(key)
                row.append(v if complete and isinstance(v, (int, float)) and math.isfinite(v) and v != fill else None)
            rain_total = round(row[1] * calendar.monthrange(year, month)[1], 4) if row[1] is not None else None
            rows.append([f'{year:04d}-{month:02d}', *row, rain_total])
    return rows


COLUMNS = ['month', 'temperature_c', 'precipitation_mm_day', 'wind_speed_m_s',
           'solar_mj_m2_day', 'precipitation_total_mm_derived']


def make_archive(metadata, locations, series):
    """Keep shared monthly series once while preserving every administrative code."""
    codes = [location['ward_code'] for location in locations]
    if len(codes) != len(set(codes)):
        raise ValueError('Duplicate ward code in output')
    for location in locations:
        if location['series_id'] not in series:
            raise ValueError('Location references a missing series')
    return dict(schema_version=1, metadata=metadata, columns=COLUMNS,
                locations=sorted(locations, key=lambda loc: loc['ward_code']),
                series={sid: series[sid] for sid in sorted(series)})


def archive_report(archive, national_locations, budget_mb=250):
    locations, series = archive['locations'], archive['series']
    if not locations:
        raise ValueError('Cannot export an empty selection')
    coverage = {}
    for index, column in enumerate(COLUMNS[1:5], start=1):
        months = [row[0] for rows in series.values() for row in rows if row[index] is not None]
        coverage[column] = dict(first_month=min(months) if months else None,
                               last_month=max(months) if months else None,
                               non_null_series_months=len(months))
    provinces = {}
    for loc in locations:
        code = loc['province_code']
        provinces.setdefault(code, [code, loc['province_name'], 0])[2] += 1
    size = len(compact(archive)) + 1
    estimate = round(size * national_locations / len(locations))
    return dict(archive['metadata'], locations=len(locations),
                provinces=[provinces[code] for code in sorted(provinces)],
                unique_request_coordinates=len({(loc['latitude'], loc['longitude']) for loc in locations}),
                unique_series=len(series),
                logical_monthly_rows=sum(len(series[loc['series_id']]) for loc in locations),
                coverage=coverage, json_bytes=size, national_locations=national_locations,
                estimated_national_json_bytes=estimate,
                estimate_note='Linear per-commune extrapolation; actual spatial deduplication differs by region.',
                national_offline_budget_bytes=budget_mb * 1024**2,
                fits_national_budget_estimate=estimate <= budget_mb * 1024**2)


def write_archive(output, archive, national_locations, budget_mb=250):
    report = archive_report(archive, national_locations, budget_mb)
    output.mkdir(parents=True, exist_ok=True)
    temporary = output / 'climate.build.json'
    temporary.write_bytes(compact(archive) + b'\n')
    temporary.replace(output / 'climate.json')
    (output / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    (output / 'errors.json').unlink(missing_ok=True)
    return report


def build(args):
    wards = load_locations(args.locations)
    all_count = len(wards)
    if args.provinces != 'all':
        selected = set(args.provinces.split(','))
        known = {w['parent']['id'] for w in wards}
        if selected - known:
            raise ValueError(f'Unknown province codes: {selected - known}')
        wards = [w for w in wards if w['parent']['id'] in selected]
    groups = {}
    for w in wards:
        groups.setdefault((float(w['geo']['lat']), float(w['geo']['lon'])), []).append(w)
    args.output.mkdir(parents=True, exist_ok=True)
    errors, completed = [], 0
    locations, series = [], {}
    metadata = dict(source='NASA POWER Monthly API', start_year=args.start_year,
        end_year=args.end_year, as_of=args.as_of.isoformat(), units=UNITS,
        spatial_method='NASA point request at supplied commune representative coordinates; no polygon average',
        missing='null; no imputation. Current/future months excluded.',
        admin_source='https://github.com/open-admin-data/vietnam-administrative-divisions',
        admin_sha256=hashlib.sha256(args.locations.read_bytes()).hexdigest(),
        admin_license='CC-BY-4.0', boundary_vintage='post-2025; applied to all historical months',
        sunny_days='not available from monthly radiation; not derived',
        disasters='separate event dataset, not inferred from climate')
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        pending = {pool.submit(fetch, lat, lon, args.start_year, args.end_year, args.cache,
                   args.offline, args.refresh): (lat,lon) for lat,lon in groups}
        for future in as_completed(pending):
            coord = pending[future]
            try:
                wrapper, path = future.result()
                rows = normalize(wrapper['response'], args.start_year, args.end_year, args.as_of)
                sid = hashlib.sha256(compact(rows)).hexdigest()
                series.setdefault(sid, rows)
                for w in groups[coord]:
                    locations.append(dict(ward_code=w['id'], ward_name=w['name']['local'],
                        province_code=w['parent']['id'], province_name=w['parent']['name']['local'],
                        latitude=coord[0], longitude=coord[1], series_id=sid,
                        source_url=wrapper['url'], fetched_at=wrapper['fetched_at'],
                        time_standard=wrapper['response']['header']['time_standard']))
            except Exception as exc:
                errors.append({'coordinates': coord, 'error': str(exc)})
            completed += 1
            if completed % 25 == 0 or completed == len(groups):
                print(f'{completed}/{len(groups)} coordinates; errors={len(errors)}', flush=True)
    if errors:
        (args.output/'errors.json').write_text(json.dumps(errors, ensure_ascii=False, indent=2))
        raise RuntimeError(f'{len(errors)} coordinates failed; cached successes retained; rerun to resume. Final archive not replaced.')
    archive = make_archive(metadata, locations, series)
    report = write_archive(args.output, archive, all_count, args.budget_mb)
    print(json.dumps({k: report[k] for k in ('locations', 'unique_series', 'json_bytes',
          'estimated_national_json_bytes', 'fits_national_budget_estimate')}, ensure_ascii=False), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--locations', type=Path, default=ROOT/'data/admin/all-ward.json')
    parser.add_argument('--provinces', default='01,24', help='Comma-separated province codes, or all')
    parser.add_argument('--start-year', type=int, default=1977)
    parser.add_argument('--end-year', type=int, default=2026)
    parser.add_argument('--as-of', type=date.fromisoformat, default=date.today())
    parser.add_argument('--cache', type=Path, default=ROOT/'data/monthly/cache')
    parser.add_argument('--output', type=Path, default=ROOT/'data/monthly/sample')
    parser.add_argument('--workers', type=int, choices=range(1,6), default=5)
    parser.add_argument('--budget-mb', type=int, default=250)
    parser.add_argument('--offline', action='store_true')
    parser.add_argument('--refresh', action='store_true')
    args = parser.parse_args()
    if args.start_year > args.end_year or args.end_year < 1981 or args.start_year < 1:
        parser.error('Require 1 <= start-year <= end-year and end-year >= 1981')
    if args.end_year > args.as_of.year:
        parser.error('end-year cannot exceed as-of year')
    if args.offline and args.refresh:
        parser.error('--offline and --refresh are mutually exclusive')
    build(args)


if __name__ == '__main__':
    main()
