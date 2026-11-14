"""Download the NASA GLC legacy snapshot and retain Vietnam events in 1977–2026."""
import argparse
import csv
from datetime import datetime, timezone
import hashlib
import io
import json
from pathlib import Path
import subprocess

URL = 'https://data.nasa.gov/docs/legacy/Global_Landslide_Catalog_Export/Global_Landslide_Catalog_Export_rows.csv'
ROOT = Path(__file__).resolve().parent


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, help='Local NASA CSV; omit to download')
    parser.add_argument('--output', type=Path, default=ROOT/'data/disasters')
    args=parser.parse_args()
    raw=args.input.read_bytes() if args.input else subprocess.run([
        'curl','--noproxy','*','--fail','--silent','--show-error','--max-time','120',URL],
        capture_output=True,check=True).stdout
    reader=csv.DictReader(io.StringIO(raw.decode('utf-8-sig')))
    if not {'country_code','event_date','event_id'}.issubset(reader.fieldnames or []):
        raise ValueError('Not a NASA GLC CSV')
    events=[]
    for row in reader:
        if row['country_code'] != 'VN':
            continue
        event_date=datetime.strptime(row['event_date'], '%m/%d/%Y %I:%M:%S %p').date()
        if 1977 <= event_date.year <= 2026:
            row['event_date_iso']=event_date.isoformat()
            events.append(row)
    events.sort(key=lambda r:(r['event_date_iso'],r['event_id']))
    args.output.mkdir(parents=True,exist_ok=True)
    (args.output/'nasa_glc_vietnam.json').write_text(json.dumps(events,ensure_ascii=False,indent=2)+'\n', encoding='utf-8')
    metadata=dict(source_url=URL, source_sha256=hashlib.sha256(raw).hexdigest(),
        processed_at=datetime.now(timezone.utc).isoformat(), event_count=len(events),
        first_event=events[0]['event_date_iso'] if events else None,
        last_event=events[-1]['event_date_iso'] if events else None,
        limitation='NASA GLC one-time legacy export, incomplete event reporting; landslides only. No report does not mean no disaster. Original historical admin labels preserved; not assigned to current wards.',
        update_source='https://gpm.nasa.gov/applications/landslides/coolr')
    (args.output/'metadata.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(metadata,ensure_ascii=False))

if __name__=='__main__':
    main()
