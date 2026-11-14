import csv
from copy import deepcopy
import json
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from src.f1.clean import clean, monthly_rain
from src.f1.config import Config, Location
from src.f1.export import export
from src.f1.fetch import fetch, raw_path, source_requests
from src.f1.validate import validate


class PowerPipelineTests(unittest.TestCase):
    def test_missing_data_and_export_match_source(self):
        config = Config("1980-12", "1981-06", "1981-06-15", ("T2M", "PRECTOTCORR"),
                        (Location("a", 21.03, 105.85), Location("b", 21.03, 105.85)))
        raw = {
            "geometry": {"coordinates": [105.85, 21.03]},
            "header": {"start": "19810101", "end": "19810630", "time_standard": "LST", "fill_value": -999},
            "parameters": {"T2M": {"units": "C"}, "PRECTOTCORR": {"units": "mm/day"}},
            "properties": {"parameter": {
                "T2M": {"198101": 18, "198102": -999, "198103": True, "198106": 27},
                "PRECTOTCORR": {"198101": 0, "198102": 1.25, "198103": -3},
            }},
        }
        with TemporaryDirectory() as directory:
            root = Path(directory)
            cache = root / "raw"
            with patch("src.f1.fetch.download", return_value=json.dumps(raw).encode()) as download:
                self.assertEqual(fetch(config, cache), 1)
                download.assert_called_once()
                fetch(config, cache)
                download.assert_called_once()
            doc = clean(config, cache)
            rows = doc["records"]
            self.assertEqual([row["status"]["temperature_c"] for row in rows[:7]], [
                "out_of_coverage", "ok", "missing_source", "invalid_source",
                "missing_source", "missing_source", "incomplete_period",
            ])
            self.assertEqual(rows[1]["values"]["precipitation_total_mm_derived"], 0)
            self.assertEqual(rows[2]["values"]["precipitation_total_mm_derived"], 35)
            self.assertIsNone(rows[3]["values"]["precipitation_total_mm_derived"])
            self.assertEqual(monthly_rain(1.25, "1984-02"), 36.25)
            checks = validate(config, cache, doc)
            self.assertEqual(checks["rows"], 14)
            output = root / "output"
            release = export(doc, checks, output)
            manifest = (output / "latest.json").read_bytes()
            self.assertEqual(release, export(doc, checks, output))
            with (release / "data.csv").open(encoding="utf-8", newline="") as stream:
                csv_rows = list(csv.DictReader(stream))
            self.assertEqual(csv_rows[1]["precipitation_mm_day"], "0")
            self.assertEqual(csv_rows[2]["temperature_c"], "")
            tampered = deepcopy(doc)
            tampered["records"][1]["values"]["temperature_c"] = 100
            with self.assertRaisesRegex(ValueError, "Wrong data"):
                validate(config, cache, tampered)
            self.assertEqual((output / "latest.json").read_bytes(), manifest)

            _, url = next(source_requests(config))
            raw_path(cache, url).write_bytes(json.dumps(raw, indent=2).encode())
            with self.assertRaisesRegex(ValueError, "source changed"):
                validate(config, cache, doc)

    def test_precoverage_months_need_no_download(self):
        config = Config("1983-12", "1983-12", "1984-01-01", ("ALLSKY_SFC_SW_DWN",),
                        (Location("a", 0, 0),))
        with TemporaryDirectory() as directory:
            cache = Path(directory)
            self.assertEqual(fetch(config, cache), 0)
            doc = clean(config, cache)
            self.assertEqual(doc["sources"], {"a": None})
            self.assertEqual(validate(config, cache, doc)["coverage"]["solar_mj_m2_day"], {"out_of_coverage": 1})


if __name__ == "__main__":
    unittest.main()
