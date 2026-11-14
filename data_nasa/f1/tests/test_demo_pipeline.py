import base64
from datetime import date
import gzip
import json
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from src.f1 import demo, demo_stages, disaster_sources, disasters

SOURCE = {"time_standard": "LST", "accessed": "2026-11-10"}


class DemoPipelineTests(unittest.TestCase):
    def test_disasters_keep_default_scores_and_unconfirmed_yagi_impacts_distinct(self):
        products = disasters.products()
        events = products[disasters.CATALOG].records
        by_id = {row["event_id"]: row for row in events}
        yagi = by_id[disasters.YAGI_ID]
        self.assertEqual((yagi["metric_value"], yagi["severity_1_10"]), (16, 9))
        self.assertEqual((yagi["nasa_event_id"], yagi["nasa_track_max_wind_kts"]),
                         (disasters.YAGI_EONET_ID, 130))
        nasa_rows = products[disasters.NASA_FIRST].records
        self.assertIn(yagi, nasa_rows)
        self.assertTrue(all(row["nasa_reference_url"] for row in nasa_rows))
        self.assertEqual(by_id["igp-3169"]["severity_1_10"], 3)
        self.assertEqual(by_id["igp-3169"]["severity_method"], "magnitude_rounded_v1")
        self.assertEqual(by_id["dmc-14377-lang-nu"]["related_event_id"], disasters.YAGI_ID)
        impacts = {row["province"]: row for row in products[disasters.YAGI_IMPACT].records}
        self.assertEqual(impacts["Hà Nội"]["gust_force"], 10)
        for province in ("Lâm Đồng", "Đà Nẵng"):
            self.assertEqual(impacts[province]["impact_status"], "not_confirmed_in_sources")
            self.assertIsNone(impacts[province]["reported_rain_mm"])

    def test_disaster_coverage_preserves_unknown_days_and_empty_years(self):
        rows = [
            {"year": 2022, "source": "nasa_gdis", "record_kind": "event_record", "hazard_type": "flood"},
            {"year": 2024, "source": "dmc", "record_kind": "event_record", "hazard_type": "typhoon"},
            {"year": None, "source": "dmc", "record_kind": "bulletin", "hazard_type": "typhoon"},
        ]
        by_year = {row["year"]: row for row in disasters.annual_summary(rows)}
        self.assertEqual(by_year[2023]["coverage_status"], "no_records_in_sources")
        self.assertEqual(by_year[None]["coverage_status"], "undated")

    def test_year_only_gdis_month_needs_glide_number_or_a_single_matching_record(self):
        def gdis(code, hazard, provinces):
            return {"event_id": f"gdis-{code}", "event_code": code, "year": int(code[:4]), "source": "nasa_gdis",
                    "hazard_type": hazard, "provinces": provinces, "start_date": None, "start_month": None,
                    "record_kind": "event_record", "date_basis": "source_year_only", "date_reference": None}

        def dated(event_id, hazard, provinces, start):
            return {"event_id": event_id, "year": int(start[:4]), "source": "desinventar", "hazard_type": hazard,
                    "provinces": provinces, "start_date": start, "record_kind": "event_record"}

        rows = [gdis("1997-0267", "storm", "Ca Mau"), gdis("1992-0061", "flood", "Hai Phong; Quang Ninh"),
                gdis("1993-0001", "flood", "Hue"), gdis("1994-0002", "flood", "Hue"),
                dated("di-1", "flash_flood", "Quảng Ninh", "1992-06-29"),
                dated("di-2", "flood", "Huế", "1993-07-01"), dated("di-3", "flood", "Huế", "1993-09-02"),
                dated("di-4", "flood", "Huế", "1994-01-01")]
        glide = [{"number": "1997-000267", "glidenumber": "ST-1997-000267-VNM", "event": "ST",
                  "year": 1997, "month": 11}]
        disasters.date_year_only(rows, glide)
        storm, single, ambiguous, placeholder = rows[:4]
        self.assertEqual((storm["start_month"], storm["date_basis"], storm["date_reference"]),
                         ("1997-11", "glide_same_emdat_number", "GLIDE ST-1997-000267-VNM"))
        self.assertEqual((single["start_month"], single["date_reference"]), ("1992-06", "di-1"))
        for row in (ambiguous, placeholder):  # two candidate months; 1 January placeholder
            self.assertEqual((row["start_month"], row["date_basis"]), (None, "source_year_only"))

    def test_published_disaster_files_match_sources(self):
        for stem, product in disasters.products().items():
            document, _ = demo.render_pair(product.records, product.keys, product.card, product.extra)
            published = (demo.OUTPUT / stem).with_suffix(".json").read_bytes().replace(b"\r\n", b"\n")
            self.assertEqual(document, published, f"{stem}: run python -m f1.disasters")

    def test_earthquake_detail_reads_magnitude_without_claiming_richter_scale(self):
        fields = disaster_sources.dmc_details("trận động đất có độ lớn 2,8 xảy ra".encode(), "earthquake")
        self.assertEqual(fields, {"metric_name": "earthquake_magnitude", "metric_value": 2.8,
                                  "metric_unit": "magnitude"})

    def test_a_keeps_missing_month_and_does_not_invent_yearly_total(self):
        periods = [f"2025{month:02d}" for month in range(1, 13)]
        fields = {"T2M": dict.fromkeys(periods, 20), "PRECTOTCORR": dict.fromkeys(periods, 0)}
        fields["PRECTOTCORR"]["202502"] = -999
        with patch.object(demo, "YEARS", (2025,)), patch.object(demo, "load", return_value=(fields, -999, SOURCE)):
            product = demo.climate("ha_noi")
        self.assertEqual(len(product.records), 13)
        self.assertEqual(product.records[0]["precipitation_total_mm"], 0)
        self.assertIsNone(product.records[1]["precipitation_total_mm"])
        self.assertIsNone(product.extra["rain_annual_mm"][0])

    def test_b_missing_day_leaves_annual_counts_null(self):
        keys = demo.dates(date(2025, 1, 1), date(2025, 12, 31))
        fields = {"T2M_MAX": dict.fromkeys(keys[:-1], 30)}
        with (patch.object(demo, "POINTS", {"ha_noi": (21.03, 105.85)}),
              patch.object(demo, "YEARS", (2025,)), patch.object(demo, "dates", return_value=keys),
              patch.object(demo, "load", return_value=(fields, -999, SOURCE))):
            product = demo.heat()
        self.assertEqual(product.records, [
            {"location_id": "ha_noi", "year": 2025, "ge35": None, "ge37": None, "ge39": None}
        ])

    def test_c_and_d_keep_calendar_rows_when_observations_are_missing(self):
        fields = {"PRECTOTCORR": {"20240901": 0}, "WS10M": {}}
        with patch.object(demo, "load", return_value=(fields, -999, SOURCE)):
            yagi = demo.yagi()
        self.assertEqual(len(yagi.records), 15)
        self.assertEqual(yagi.records[0]["ha_noi_rain_mm"], 0)
        self.assertIsNone(yagi.records[1]["ha_noi_rain_mm"])
        with TemporaryDirectory() as directory, patch.object(demo, "ROOT", Path(directory)):
            raw = Path(directory) / "raw"
            raw.mkdir()
            (raw / demo.D_RAW).write_text("Land-Ocean: Global Means\nYear,J-D\n1880,-.17\n2025,***\n", encoding="utf-8")
            global_temp = demo.global_temperature()
        self.assertEqual(len(global_temp.records), 146)
        self.assertEqual(global_temp.records[0]["temperature_anomaly_c"], -0.17)
        self.assertIsNone(global_temp.records[-1]["temperature_anomaly_c"])

    def test_rain_grid_packs_values_in_date_longitude_latitude_order(self):
        rows = [
            {"date": "2024-09-01", "longitude": 102.55, "latitude": 20.05, "precipitation_mm": 0},
            {"date": "2024-09-01", "longitude": 102.55, "latitude": 20.15, "precipitation_mm": None},
            {"date": "2024-09-01", "longitude": 102.65, "latitude": 20.05, "precipitation_mm": 2.3456},
            {"date": "2024-09-01", "longitude": 102.65, "latitude": 20.15, "precipitation_mm": 4.2},
        ]
        grid = demo.Product(rows, ("date", "longitude", "latitude"), {}, {}, {})
        document = json.loads(demo.pack_rain_grid(grid))
        self.assertEqual(document["dates"], ["2024-09-01"])
        self.assertEqual(document["longitudes"], [102.55, 102.65])
        self.assertEqual(document["latitudes"], [20.05, 20.15])
        packed = document["precipitation_mm"]
        self.assertEqual(packed["axis_order"], ["date", "longitude", "latitude"])
        self.assertEqual(packed["encoding"], "base64+gzip+json")
        self.assertEqual(json.loads(gzip.decompress(base64.b64decode(packed["values"]))), [0, None, 2.3456, 4.2])
        rows[1], rows[2] = rows[2], rows[1]
        with self.assertRaisesRegex(ValueError, "do not match grid order"):
            demo.pack_rain_grid(grid)

    def test_export_rejects_stale_clean_file_before_publishing(self):
        with TemporaryDirectory() as directory:
            work = Path(directory)
            (work / "clean.json").write_bytes(b"{}")
            output = work / "published"
            with patch.object(demo_stages, "products_from_raw", return_value={}):
                with self.assertRaisesRegex(ValueError, "differs from raw"):
                    demo_stages.run_demo("export", work, output)
            self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
