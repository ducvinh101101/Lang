"""Download NASA POWER responses and cache them by request URL."""

from datetime import datetime, timezone
from hashlib import sha256
import json
import math

from .archive import UNITS, request_url
from .io import download, require, save_raw


def source_requests(config):
    years = config.request_years
    if years is not None:
        for point in config.locations:
            yield point, request_url(point.latitude, point.longitude, *years, config.metrics)


def raw_path(cache, url):
    return cache / (sha256(url.encode("utf-8")).hexdigest() + ".json")


def unique_keys(pairs):
    obj = dict(pairs)
    require(len(obj) == len(pairs), "Duplicate keys in NASA POWER response")
    return obj


def read_response(content, config, point):
    data = json.loads(content, object_pairs_hook=unique_keys)
    lon, lat = data["geometry"]["coordinates"][:2]
    # POWER can round the returned point coordinates to three decimal places.
    require(math.isclose(lon, point.longitude, rel_tol=0, abs_tol=0.00051)
            and math.isclose(lat, point.latitude, rel_tol=0, abs_tol=0.00051),
            f"{point.id}: coordinates differ from request")
    first, last = config.request_years
    header = data["header"]
    returned_end = datetime.strptime(header["end"], "%Y%m%d").date()
    require(header["start"] == f"{first:04d}0101" and first <= returned_end.year <= last
            and header["time_standard"] == "LST", f"{point.id}: unexpected POWER period or time standard")
    parameters = data["properties"]["parameter"]
    for metric in config.metrics:
        require(isinstance(parameters[metric], dict) and data["parameters"][metric]["units"] == UNITS[metric],
                f"{point.id}: unexpected POWER structure or unit for {metric}")
    return data


def fetch(config, cache, refresh=False):
    completed = set()
    for point, url in source_requests(config):
        if url in completed:
            continue
        path = raw_path(cache, url)
        if refresh or not path.exists():
            content = download(url)
            read_response(content, config, point)
            save_raw(path, content)
        completed.add(url)
    return len(completed)


def cached_response(cache, url, config, point):
    path = raw_path(cache, url)
    content = path.read_bytes()
    data = read_response(content, config, point)
    lon, lat = data["geometry"]["coordinates"][:2]
    source = {
        "url": url, "sha256": sha256(content).hexdigest(),
        "fetched_at": datetime.fromtimestamp(path.stat().st_mtime, timezone.utc).isoformat(),
        "returned_latitude": lat, "returned_longitude": lon,
        "returned_start": data["header"]["start"], "returned_end": data["header"]["end"],
    }
    return data, source
