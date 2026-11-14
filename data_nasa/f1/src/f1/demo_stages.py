"""Fetch, clean, validate and publish F1 datasets A–D."""

from collections import Counter
import csv
from dataclasses import asdict
from datetime import date
from hashlib import sha256
import io
import json
import statistics

from .archive import compact
from . import demo, disasters
from .io import download, require, save_raw


def fetch_demo(refresh):
    files = list(demo.source_files())
    for name, url in files:
        target = demo.ROOT / "raw" / name
        if refresh or not target.exists():
            content = download(url)
            require(bool(content.strip()) and not content.lstrip().startswith(b"<"),
                    f"{name}: empty or invalid response")
            if name.endswith(".json"):
                json.loads(content)
            save_raw(target, content)
    return len(files)


def products_from_raw():
    return {
        **{f"{demo.A_PROVINCES}/{place}": demo.climate(place) for place in demo.POINTS},
        **disasters.products(),
        **demo.yagi_products(),
        demo.B_HEAT_DAYS: demo.heat(),
        demo.D_GLOBAL_TEMP: demo.global_temperature(),
    }


def clean_bytes(products):
    return compact({stem: asdict(product) for stem, product in products.items()}) + b"\n"


def trend(years, values):
    pairs = [(year, value) for year, value in zip(years, values, strict=True) if value is not None]
    return 10 * statistics.linear_regression(*zip(*pairs)).slope if len(pairs) >= 2 else None


def crosschecks(products):
    global_rows = products[demo.D_GLOBAL_TEMP].records
    global_overlap = [row for row in global_rows if row["year"] >= 1981]
    slopes = {"global_c_per_decade": trend([row["year"] for row in global_overlap],
                                          [row["temperature_anomaly_c"] for row in global_overlap])}
    hot_rows = products[demo.B_HEAT_DAYS].records
    overlaps = {}
    for place in demo.POINTS:
        annual = products[f"{demo.A_PROVINCES}/{place}"].extra["t2m_annual"]
        slopes[place] = trend(demo.YEARS, annual)
        hottest = sorted(((y, t) for y, t in zip(demo.YEARS, annual, strict=True) if t is not None),
                         key=lambda pair: (-pair[1], pair[0]))[:10]
        hot = sorted((r for r in hot_rows if r["location_id"] == place and r["ge35"] is not None),
                     key=lambda r: (-r["ge35"], r["year"]))[:5]
        hottest_years = [y for y, _ in hottest]
        overlaps[place] = {"top_10_temperature": hottest_years, "top_5_ge35": [r["year"] for r in hot],
                           "overlap": sum(r["year"] in hottest_years for r in hot)}

    yagi = products[demo.C_YAGI].records
    matched = [row for row in yagi if row["ha_noi_rain_mm"] is not None and row["ha_noi_imerg_mm"] is not None]
    peak = None
    yagi_check = None
    if matched:
        peak = max(matched, key=lambda row: row["ha_noi_rain_mm"])
        imerg_peak = max(matched, key=lambda row: row["ha_noi_imerg_mm"])["date"]
        power = [row["ha_noi_rain_mm"] for row in matched]
        imerg = [row["ha_noi_imerg_mm"] for row in matched]
        correlation = statistics.correlation(power, imerg) if len(set(power)) > 1 and len(set(imerg)) > 1 else None
        yagi_check = {"power_peak": peak["date"], "imerg_peak": imerg_peak,
                      "peak_gap_days": abs((date.fromisoformat(peak["date"]) - date.fromisoformat(imerg_peak)).days),
                      "pearson_r": correlation}
    hanoi = products[f"{demo.A_PROVINCES}/ha_noi"].records
    return {
        "sample_checks": {
            "A": next(row for row in hanoi if row["period"] == "1988-02"),
            "B": products[demo.B_HEAT_DAYS].quality["sample_2025"], "C": peak,
            "D": [{"year": row["year"], "anomaly_c": row["temperature_anomaly_c"]}
                  for row in (global_rows[0], global_rows[-1])],
        },
        "temperature_trends_c_per_decade": slopes, "heat_year_overlap": overlaps, "yagi_crosscheck": yagi_check,
    }


def validate_demo(intermediate):
    products = products_from_raw()
    require(intermediate.read_bytes() == clean_bytes(products), "Clean output differs from raw; rerun clean")
    expected = {**{f"{demo.A_PROVINCES}/{place}": 585 for place in demo.POINTS},
                demo.B_HEAT_DAYS: 270, demo.C_YAGI: 15, demo.C_YAGI_GRID: 15 * 55 * 35,
                demo.D_GLOBAL_TEMP: 146,
                disasters.YAGI_IMPACT: len(disasters.TARGETS)}
    artifacts, report, credits, app_files, missing = {}, {}, [], [], {}
    for stem, product in products.items():
        rows, card = product.records, product.card
        require(bool(rows) and len(rows) == expected.get(stem, len(rows)), f"{stem}: unexpected row count")
        require(all(card.get(k) for k in ("dataset", "provider", "url", "accessed", "spatial", "temporal",
                                        "processing", "limitation_vi", "citation", "sources")),
                f"{stem}: incomplete data_card")
        json_data, csv_data = demo.render_pair(rows, product.keys, card, product.extra)
        if stem == demo.C_YAGI_GRID:
            json_data = demo.pack_rain_grid(product)
        json_file = stem + ".json"
        artifacts[json_file] = json_data
        artifacts[stem + ".csv"] = csv_data
        report[stem] = {"rows": len(rows), "json_bytes": len(json_data), "csv_bytes": len(csv_data), **product.quality}
        credits.append({"file": json_file, "nguon": card["dataset"], "link": card["url"],
                        "ngay_tai": card["accessed"], "ghi_cong": card["citation"]})
        missing[stem] = dict(Counter(field for row in rows for field, value in row.items() if value is None))
        app_files.append({"file": json_file, "bytes": len(json_data), "sha256": sha256(json_data).hexdigest()})
    catalog_names = {stem + ".json" for stem in (disasters.CATALOG, disasters.ANNUAL)}
    catalog_files = [item for item in app_files if item["file"] in catalog_names]
    demo_files = [item for item in app_files if item["file"] not in catalog_names]
    size = sum(item["bytes"] for item in demo_files)
    catalog_size = sum(item["bytes"] for item in catalog_files)
    require(size < 1_000_000, f"App JSON size reaches/exceeds 1 MB: {size}")
    with io.StringIO(newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(credits[0]))
        writer.writeheader()
        writer.writerows(credits)
        artifacts["credits.csv"] = stream.getvalue().encode()
    checks = {"paired_files": len(app_files), "gaps": {}, "json_bytes": size,
              "disaster_catalog_json_bytes": catalog_size, "app_json_files": demo_files,
              "disaster_catalog_json_files": catalog_files,
              "missing_values": {stem: counts for stem, counts in missing.items() if counts},
              "rain_flags": {stem: r["rain_flags"] for stem, r in report.items() if r.get("rain_flags")},
              **crosschecks(products)}
    return artifacts, checks, report


def run_demo(stage, work, output=None, refresh=False, fetch_missing=True):
    intermediate = work / "clean.json"
    if stage == "fetch" or stage == "run" and fetch_missing:
        print(f"fetch: {fetch_demo(refresh)} A–D raw files available")
    if stage in ("clean", "run"):
        products = products_from_raw()
        save_raw(intermediate, clean_bytes(products))
        print(f"clean: {sum(len(product.records) for product in products.values())} rows in {intermediate}")
    if stage in ("validate", "export", "run"):
        artifacts, checks, report = validate_demo(intermediate)
        save_raw(work / "validation.json", compact(checks) + b"\n")
        print(f"validate: {checks['paired_files']} A–D pairs; {checks['json_bytes']} JSON bytes")
        if stage in ("export", "run"):
            destination = output or demo.OUTPUT
            for name, content in artifacts.items():
                save_raw(destination / name, content)
            save_raw(demo.ROOT / "qa-report.json", compact(report) + b"\n")
            save_raw(demo.ROOT / "handoff-checks.json", compact(checks) + b"\n")
            print(f"export: {destination}")
