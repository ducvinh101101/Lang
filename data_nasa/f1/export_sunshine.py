"""Supplement NASA radiation with monthly sunshine duration from Open-Meteo ERA5."""
import argparse
import calendar
from collections import defaultdict
from datetime import date, datetime, timedelta, timezone
import json
import hashlib
from pathlib import Path
import subprocess
from urllib.parse import urlencode


def aggregate(data, threshold=None):
    if data['daily_units']['sunshine_duration'] != 's':
        raise ValueError('Expected sunshine duration in seconds')
    grouped=defaultdict(dict)
    for day,seconds in zip(data['daily']['time'],data['daily']['sunshine_duration'],strict=True):
        if day in grouped[day[:7]]:
            raise ValueError('Duplicate day')
        grouped[day[:7]][day]=seconds
    monthly=[]
    for month,days in sorted(grouped.items()):
        year,m=map(int,month.split('-'))
        values=[s for s in days.values() if s is not None]
        complete=len(values)==calendar.monthrange(year,m)[1]
        monthly.append(dict(month=month,valid_days=len(values),complete=complete,
            sunshine_hours_total=round(sum(values)/3600,3) if complete else None,
            sunshine_hours_daily_mean=round(sum(values)/3600/len(values),3) if complete else None,
            sunny_days_custom_threshold=sum(s>=threshold*3600 for s in values) if complete and threshold is not None else None))
    return monthly


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lat',type=float,required=True)
    parser.add_argument('--lon',type=float,required=True)
    parser.add_argument('--start-date',type=date.fromisoformat,default=date(1977,1,1))
    parser.add_argument('--end-date',type=date.fromisoformat,default=date.today().replace(day=1) - timedelta(days=1))
    parser.add_argument('--sunny-day-hours',type=float,help='Explicit project definition: minimum sunshine hours per sunny day')
    parser.add_argument('--input',type=Path,help='Previously downloaded Open-Meteo daily JSON')
    parser.add_argument('--output',type=Path,default=Path(__file__).resolve().parents[1]/'local-private/archive/sunshine/hanoi.json')
    args=parser.parse_args()
    if not (-90<=args.lat<=90 and -180<=args.lon<=180) or args.start_date>args.end_date:
        parser.error('Invalid coordinates or dates')
    if args.sunny_day_hours is not None and not 0<args.sunny_day_hours<=24:
        parser.error('sunny-day-hours must be >0 and <=24')
    url='https://archive-api.open-meteo.com/v1/archive?'+urlencode(dict(latitude=args.lat,longitude=args.lon,
        start_date=args.start_date.isoformat(),end_date=args.end_date.isoformat(),daily='sunshine_duration',
        timezone='Asia/Ho_Chi_Minh',models='era5'))
    data=json.loads(args.input.read_text()) if args.input else json.loads(subprocess.run([
        'curl','--noproxy','*','--fail-with-body','--silent','--show-error','--max-time','180',url],capture_output=True,check=True).stdout)
    raw=json.dumps(data,ensure_ascii=False,separators=(',', ':')).encode()
    payload=dict(source='Open-Meteo Historical Weather / ERA5',source_url=url,
        daily_payload_sha256=hashlib.sha256(raw).hexdigest(),
        requested_coordinates=[args.lat,args.lon],returned_coordinates=[data['latitude'],data['longitude']],
        timezone=data['timezone'],processed_at=datetime.now(timezone.utc).isoformat(),
        sunny_day_threshold_hours=args.sunny_day_hours,
        note='Modelled sunshine duration, separate from NASA radiation. Custom sunny-day counts are not an official climatological classification.',
        monthly=aggregate(data,args.sunny_day_hours))
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.with_suffix('.daily.json').write_bytes(raw)
    args.output.write_text(json.dumps(payload,ensure_ascii=False,indent=2)+'\n')
    print(f'{len(payload["monthly"])} months: {args.output}')

if __name__=='__main__':
    main()
