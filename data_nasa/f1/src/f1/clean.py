"""Normalize POWER observations into a fixed monthly calendar with explicit missing states."""

import calendar
from dataclasses import asdict
import math

from .config import METRICS, RAIN_TOTAL
from .fetch import cached_response, source_requests

NONNEGATIVE = {"PRECTOTCORR", "WS10M", "ALLSKY_SFC_SW_DWN"}


def calendar_status(month, metric, as_of):
    if month >= as_of[:7]:
        return "incomplete_period"
    if int(month[:4]) < METRICS[metric][1]:
        return "out_of_coverage"
    return None


def observation(value, fill, metric):
    if value is None or type(value) in (int, float) and value in (-999, fill):
        return None, "missing_source"
    if (type(value) not in (int, float) or not math.isfinite(value)
            or metric in NONNEGATIVE and value < 0):
        return None, "invalid_source"
    return value, "ok"


def monthly_value(parameters, fill, month, metric, as_of):
    excluded = calendar_status(month, metric, as_of)
    if excluded:
        return None, excluded
    return observation(parameters[metric].get(month.replace("-", "")), fill, metric)


def monthly_rain(rate, month):
    if rate is None:
        return None
    year, month_number = map(int, month.split("-"))
    return round(rate * calendar.monthrange(year, month_number)[1], 4)


def clean(config, cache):
    records, sources = [], {}
    urls = {point.id: url for point, url in source_requests(config)}
    months = config.months
    for point in config.locations:
        data, sources[point.id] = cached_response(cache, urls[point.id], config, point) if urls else (None, None)
        parameters = data["properties"]["parameter"] if data else {}
        fill = data["header"].get("fill_value", -999) if data else -999
        for month in months:
            values, status = {}, {}
            for metric in config.metrics:
                field = METRICS[metric][0]
                values[field], status[field] = monthly_value(parameters, fill, month, metric, config.as_of)
            if "PRECTOTCORR" in config.metrics:
                rain = METRICS["PRECTOTCORR"][0]
                values[RAIN_TOTAL] = monthly_rain(values[rain], month)
                status[RAIN_TOTAL] = status[rain]
            records.append({"location_id": point.id, "month": month, "values": values, "status": status})
    return {
        "schema_version": 1, "job_sha256": config.key,
        "data_card": {
            "provider": "NASA POWER", "dataset": "POWER Monthly point",
            "time_standard": "LST", "start_month": config.start_month, "end_month": config.end_month,
            "as_of": config.as_of, "units": config.fields,
        },
        "locations": [asdict(point) for point in config.locations],
        "sources": sources, "records": records,
    }
