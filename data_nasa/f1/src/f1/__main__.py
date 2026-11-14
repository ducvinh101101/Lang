"""Run individual stages or rebuild F1 A–D and monthly data end to end."""

import argparse
import json
from pathlib import Path
import subprocess
import sys

from . import demo, disaster_sources, vietnam
from .archive import compact
from .io import save_raw
from .clean import clean
from .config import read_config
from .demo_stages import run_demo
from .export import export
from .fetch import fetch
from .validate import validate

DEFAULT_WORK = Path(__file__).resolve().parents[3] / "local-private" / "f1-data" / "pipeline"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", choices=("collect", "fetch", "clean", "validate", "export", "run"))
    parser.add_argument("--profile", choices=("demo", "monthly", "a34", "vietnam"), default="monthly")
    parser.add_argument("--config", type=Path, help="Location and period settings for the monthly profile")
    parser.add_argument("--work-dir", type=Path, help="Working directory for the staged profiles")
    parser.add_argument("--source-cache", type=Path, help="Source cache for collect --profile demo")
    parser.add_argument("--output", type=Path, help="Output directory for the selected profile")
    parser.add_argument("--refresh", action="store_true", help="Download again during fetch or run")
    parser.add_argument("--offline", action="store_true", help="Run using only local inputs")
    parser.add_argument("--point", nargs=3, metavar=("ID", "LAT", "LON"),
                        help="Export one point using the Vietnam archive schema")
    args = parser.parse_args()
    staged = args.profile in ("monthly", "demo")
    if args.stage == "collect" and args.profile != "demo":
        parser.error("collect requires --profile demo")
    if args.source_cache and args.stage != "collect":
        parser.error("--source-cache requires collect")
    if not staged and args.stage != "run":
        parser.error("a34 and vietnam use the run stage")
    if args.refresh and (not staged or args.stage not in ("fetch", "run")):
        parser.error("--refresh is available for fetch or run with the demo and monthly profiles")
    if args.offline and (args.stage not in ("collect", "run") or args.refresh):
        parser.error("--offline requires collect or run and cannot be combined with --refresh")
    if args.work_dir and (not staged or args.stage == "collect"):
        parser.error("--work-dir applies to fetch, clean, validate, export or run with demo or monthly")
    if args.point and args.profile != "vietnam":
        parser.error("--point requires --profile vietnam")
    if args.output and args.stage not in ("export", "run"):
        parser.error("--output is available only for export and run")
    if args.profile == "monthly" and not args.config:
        parser.error("--config is required for the monthly profile")
    if args.profile != "monthly" and args.config:
        parser.error("--config is available only for the monthly profile")
    work = args.work_dir or DEFAULT_WORK
    fetch_missing = not args.offline
    try:
        if args.profile == "demo":
            if args.stage == "collect":
                disaster_sources.write_catalog(args.source_cache or disaster_sources.DEFAULT_CACHE,
                                               args.offline, include_details=True, check_types=True)
                return 0
            run_demo(args.stage, work / "demo", args.output, args.refresh, fetch_missing)
            return 0
        if args.profile == "a34":
            demo.expanded_climate(fetch_missing, args.output or demo.EXPANDED_A_OUTPUT)
            return 0
        if args.profile == "vietnam":
            output = args.output or vietnam.OUTPUT
            if args.point:
                label, lat, lon = args.point
                vietnam.online_point(label, float(lat), float(lon), fetch_missing, output)
            else:
                vietnam.build_packages(fetch_missing, output)
            return 0
        config = read_config(args.config)
        cache = work / "raw"
        job = work / "jobs" / config.key
        intermediate = job / "clean.json"
        if args.stage == "fetch" or (args.stage == "run" and fetch_missing):
            count = fetch(config, cache, args.refresh)
            print(f"fetch: {count} POWER requests available in {cache}")
        if args.stage in ("clean", "run"):
            document = clean(config, cache)
            save_raw(intermediate, compact(document) + b"\n")
            print(f"clean: {len(document['records'])} rows in {intermediate}")
        if args.stage in ("validate", "export", "run"):
            document = json.loads(intermediate.read_bytes())
            checks = validate(config, cache, document)
            save_raw(job / "validation.json", compact(checks) + b"\n")
            print(f"validate: {checks['rows']} rows verified")
            if args.stage in ("export", "run"):
                output = args.output or (job / "output")
                export(document, checks, output)
                print(f"export: {output / 'latest.json'}")
    except (OSError, ValueError, TypeError, KeyError, IndexError, OverflowError, subprocess.CalledProcessError) as exc:
        print(f"Pipeline {args.stage} failed: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
