"""Validate the delivery schema, calendar, source hashes and missing-data semantics."""

from collections import Counter
from dataclasses import asdict

from .io import require
from .clean import monthly_rain, monthly_value
from .config import METRICS, RAIN_TOTAL
from .fetch import cached_response, source_requests


def validate(config, cache, document):
    card = document["data_card"]
    require(document["schema_version"] == 1 and document["job_sha256"] == config.key
            and document["locations"] == [asdict(point) for point in config.locations],
            "Clean data does not match this configuration")
    require(card["provider"] == "NASA POWER" and card["dataset"] == "POWER Monthly point"
            and card["time_standard"] == "LST" and card["units"] == config.fields
            and (card["start_month"], card["end_month"], card["as_of"])
            == (config.start_month, config.end_month, config.as_of), "Unexpected data card")
    urls = {point.id: url for point, url in source_requests(config)}
    sources = document["sources"]
    require(set(sources) == {point.id for point in config.locations}, "Missing or extra source entries")
    months = config.months
    rows = document["records"]
    require(len(rows) == len(config.locations) * len(months), "Unexpected number of location-month rows")
    fields = set(config.fields)
    counts = {field: Counter() for field in fields}
    rows_iter = iter(rows)
    for point in config.locations:
        data, source = cached_response(cache, urls[point.id], config, point) if urls else (None, None)
        require(sources[point.id] == source, f"{point.id}: source changed after clean; rerun clean")
        parameters = data["properties"]["parameter"] if data else {}
        fill = data["header"].get("fill_value", -999) if data else -999
        for month in months:
            row = next(rows_iter)
            require((row["location_id"], row["month"]) == (point.id, month),
                    "Wrong, missing or duplicate calendar key")
            values, status = row["values"], row["status"]
            require(set(values) == set(status) == fields, "Missing or extra metrics in a row")
            for metric in config.metrics:
                field = METRICS[metric][0]
                expected_value, expected_status = monthly_value(parameters, fill, month, metric, config.as_of)
                require(values[field] == expected_value and type(values[field]) is type(expected_value)
                        and status[field] == expected_status, f"Wrong data at {point.id}/{month}/{field}")
            if RAIN_TOTAL in fields:
                rain = METRICS["PRECTOTCORR"][0]
                total = monthly_rain(values[rain], month)
                require(status[RAIN_TOTAL] == status[rain] and values[RAIN_TOTAL] == total
                        and type(values[RAIN_TOTAL]) is type(total), f"Wrong monthly rain total at {point.id}/{month}")
            for field in fields:
                counts[field][status[field]] += 1
    return {"locations": len(config.locations), "months_per_location": len(months), "rows": len(rows),
            "coverage": {field: dict(sorted(counts[field].items())) for field in config.fields}}
