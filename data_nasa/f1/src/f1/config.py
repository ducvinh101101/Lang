"""Read the job configuration and determine which months require NASA data."""

from dataclasses import asdict, dataclass
from datetime import date
from hashlib import sha256
import json
import math
from pathlib import Path
import re

from .archive import UNITS, compact
from .io import require

METRICS = {
    "T2M": ("temperature_c", 1981),
    "PRECTOTCORR": ("precipitation_mm_day", 1981),
    "WS10M": ("wind_speed_m_s", 1981),
    "ALLSKY_SFC_SW_DWN": ("solar_mj_m2_day", 1984),
}
RAIN_TOTAL = "precipitation_total_mm_derived"


@dataclass(frozen=True)
class Location:
    id: str
    latitude: float
    longitude: float


@dataclass(frozen=True)
class Config:
    start_month: str
    end_month: str
    as_of: str
    metrics: tuple[str, ...]
    locations: tuple[Location, ...]

    @property
    def key(self):
        return sha256(compact(asdict(self))).hexdigest()

    @property
    def months(self):
        first, last = int(self.start_month[:4]), int(self.end_month[:4])
        return tuple(f"{year:04d}-{month:02d}" for year in range(first, last + 1)
                     for month in range(1, 13)
                     if self.start_month <= f"{year:04d}-{month:02d}" <= self.end_month)

    @property
    def request_years(self):
        first_supported = min(METRICS[metric][1] for metric in self.metrics)
        years = [int(month[:4]) for month in self.months
                 if month < self.as_of[:7] and int(month[:4]) >= first_supported]
        return (years[0], years[-1]) if years else None

    @property
    def fields(self):
        fields = {METRICS[metric][0]: UNITS[metric] for metric in self.metrics}
        if "PRECTOTCORR" in self.metrics:
            fields[RAIN_TOTAL] = "mm"
        return fields


def read_config(path: Path):
    raw = json.loads(path.read_text(encoding="utf-8-sig"))
    start, end, as_of = (raw[key] for key in ("start_month", "end_month", "as_of"))
    for month in (start, end):
        require(isinstance(month, str) and re.fullmatch(r"\d{4}-\d{2}", month), "Use YYYY-MM for months")
        date.fromisoformat(month + "-01")
    require(start <= end, "start_month must be at or before end_month")
    require(isinstance(as_of, str) and re.fullmatch(r"\d{4}-\d{2}-\d{2}", as_of), "Use YYYY-MM-DD for as_of")
    require(date.fromisoformat(as_of) <= date.today(), "as_of must not be in the future")
    metrics = raw["metrics"]
    require(isinstance(metrics, list) and metrics
            and all(isinstance(metric, str) and metric in METRICS for metric in metrics)
            and len(set(metrics)) == len(metrics), "metrics must be a nonempty list of distinct POWER parameters")
    locations = []
    seen = set()
    require(isinstance(raw["locations"], list) and raw["locations"], "locations must be a nonempty list")
    for location in raw["locations"]:
        label, lat, lon = (location[key] for key in ("id", "latitude", "longitude"))
        require(isinstance(label, str) and re.fullmatch(r"[a-z][a-z0-9_-]*", label)
                and label not in seen, f"Invalid or duplicate location id: {label}")
        require(type(lat) in (int, float) and math.isfinite(lat) and -90 <= lat <= 90
                and type(lon) in (int, float) and math.isfinite(lon) and -180 <= lon <= 180,
                f"Invalid coordinates for {label}")
        seen.add(label)
        locations.append(Location(label, float(lat), float(lon)))
    return Config(start, end, as_of, tuple(metrics), tuple(locations))
