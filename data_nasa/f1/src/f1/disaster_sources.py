"""Collect the public DMC catalog and the Vietnam subset of NASA SEDAC GDIS."""

import argparse
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
import csv
from datetime import date, datetime
from hashlib import sha256
from html import unescape
import io
import json
from pathlib import Path
import re
from urllib.parse import urljoin
from xml.etree import ElementTree
from zipfile import BadZipFile, ZipFile

from . import disasters
from .archive import compact
from .io import download, require, save_raw

DMC = "https://dmc.gov.vn"
DMC_PAGE = DMC + ("/Ajax.aspx?ctrl=/Modules/DMC/Web/ListDisasterContent"
                  "&keyword=&typeid=0&startdate=&enddate=&lang=vi-VN&cPage=")
GDIS_ZIP = ("https://cdn.cloud.prio.org/files/cffb60dc-5978-4eec-a1d2-14551067d84d/"
            "gdis-1960-2018-disasterlocations-csv.zip?inline=true")
GDIS_CITATION = "https://doi.org/10.7910/DVN/7UW1YK"
DESINVENTAR = "https://www.desinventar.net/DesInventar/download/DI_export_vnm.zip"
DESINVENTAR_PROFILE = "https://desinventar-api.undrr.org/DesInventar/country_profile.jsp?countrycode=vnm&lang=EN"
EONET_STORMS = ("https://eonet.gsfc.nasa.gov/api/v3/events?"
                "status=all&category=severeStorms&bbox=102.0,23.5,110.0,8.0")
GLIDE = ("https://www.glidenumber.net/glide/jsonglideset.jsp?"
         "level1=VNM&fromyear=1960&toyear={year}&number=5000")
PROJECT = Path(__file__).resolve().parents[2]
GLIDE_OUTPUT = PROJECT / "data" / "disasters" / "glide_vietnam.json"
DEFAULT_CACHE = PROJECT.parent / "local-private" / "f1-data" / "disaster-sources"
OUTPUT = PROJECT / "data" / "disasters" / "catalog_sources.json"
DMC_TYPE_FILTERS = (*range(1, 16), 63, 64, 65, 66, 67, 68, 74)

TYPES = {
    "bão": "typhoon", "áp thấp nhiệt đới": "tropical_depression", "lũ": "flood",
    "lũ lụt": "flood", "lũ quét": "flash_flood", "sạt lở đất": "landslide",
    "động đất": "earthquake", "cháy rừng": "wildfire", "hạn hán": "drought",
    "mưa lớn": "heavy_rain", "lốc xoáy": "tornado", "nắng nóng": "heat_wave",
    "mưa đá": "hail", "ngập lụt": "flood", "rét đậm, rét hại": "cold_wave",
    "xâm nhập mặn": "saltwater_intrusion", "lốc": "tornado", "lốc tố": "windstorm",
    "sạt lở đất do mưa lũ hoặc dòng chảy": "landslide", "sét": "lightning",
    "mưa dông kèm theo lốc, sét và mưa đá": "severe_thunderstorm", "giông": "thunderstorm",
    "lốc+ mưa đá": "severe_thunderstorm", "gió mùa": "monsoon", "không khí lạnh": "cold_wave",
    "nước dâng": "storm_surge", "rét hại": "cold_wave", "typhoon": "typhoon",
    "sụt lún đất do mưa lũ hoặc dòng chảy": "land_subsidence",
}


def plain(html):
    return " ".join(unescape(re.sub(r"<[^>]+>", " ", html)).split())


def read_dmc_page(content):
    html = content.decode("utf-8-sig")
    total = re.search(r'pages-number"[^>]*>\s*Hiển thị\s+\d+\s*-\s*\d+\s+trong\s+(\d+)', html)
    if total is None and "Chưa có thông tin nào" in html:
        return 0, []
    require(total is not None, "DMC page is missing the catalog total")
    rows = []
    for row in re.findall(r"<tr\b[^>]*>(.*?)</tr>", html, re.S | re.I):
        cells = re.findall(r"<td\b[^>]*>(.*?)</td>", row, re.S | re.I)
        if len(cells) != 6:
            continue
        link = re.search(r'href="([^"]*?-dis(\d+)\.html[^"]*)"', cells[1])
        if link is None:
            continue
        _, title, category, start, _, area = map(plain, cells)
        code = re.search(r"bão số\s+(\d+)", title, re.I)
        kind = TYPES.get(category.casefold(), "other")
        if kind == "typhoon" and title.casefold().startswith("lốc"):
            kind = "tornado"
        rows.append({
            "event_id": f"dmc-{link[2]}", "name": title, "type_original": category or None,
            "hazard_type": kind, "event_code": f"Bão số {int(code[1])}" if code else None,
            "start_date": dmc_date(start),
            "main_affected_area": area or None, "source_url": urljoin(DMC, unescape(link[1])),
            "source": "dmc",
        })
    return int(total[1]), rows


def dmc_date(value):
    return datetime.strptime(value, "%d/%m/%Y").date().isoformat() if value else None


def dmc_details(content, kind):
    text = plain(content.decode("utf-8-sig"))
    start = re.search(r"Thời gian bắt đầu\s*:\s*(\d{1,2}/\d{1,2}/\d{4})", text, re.I)
    details = {"start_date": dmc_date(start[1])} if start and int(start[1][-4:]) >= 1900 else {}
    wind = re.search(r"Cấp bão cao nhất\s*:\s*(\d+)", text, re.I)
    if kind == "typhoon" and wind and 6 <= int(wind[1]) <= 17:
        return {**details, "metric_name": "peak_sustained_wind_force", "metric_value": int(wind[1]),
                "metric_unit": "cấp gió"}
    magnitude = re.search(r"(?:độ lớn|cường độ)\s*(?:M\s*)?(?:=|:)?\s*(\d+(?:[.,]\d+)?)\b", text, re.I)
    if kind == "earthquake" and magnitude and 0 < float(magnitude[1].replace(",", ".")) <= 10:
        return {**details, "metric_name": "earthquake_magnitude", "metric_value": float(magnitude[1].replace(",", ".")),
                "metric_unit": "magnitude"}
    return details


def read_gdis(content):
    by_id = defaultdict(list)
    with ZipFile(io.BytesIO(content)) as archive:
        with archive.open("pend-gdis-1960-2018-disasterlocations.csv") as source:
            for row in csv.DictReader(io.TextIOWrapper(source, encoding="utf-8-sig")):
                if row["iso3"] == "VNM":
                    by_id[row["disasterno"]].append(row)
    require(bool(by_id), "No Vietnam records in GDIS")
    rows = []
    for code, locations in sorted(by_id.items()):
        first = locations[0]
        require(all((item["year"], item["disastertype"]) == (first["year"], first["disastertype"])
                    for item in locations), f"GDIS event {code} has conflicting metadata")
        areas = sorted({item["location"] for item in locations if item["location"] not in ("", "NA")})
        provinces = sorted({item["adm1"] for item in locations if item["adm1"] not in ("", "NA")})
        rows.append({
            "event_id": f"gdis-{code}", "event_code": code, "hazard_type": first["disastertype"],
            "type_original": first["disastertype"], "year": int(first["year"]),
            "main_affected_area": "; ".join(areas) or None, "provinces": "; ".join(provinces),
            "source_url": GDIS_CITATION, "source": "nasa_gdis", "source_record_count": len(locations),
        })
    return rows


def read_desinventar(content):
    by_event = defaultdict(list)
    with ZipFile(io.BytesIO(content)) as archive:
        root = ElementTree.fromstring(archive.read("DI_export_vnm.xml"))
    for item in root.findall("./fichas/TR"):
        row = {field.tag: (field.text or "").strip() for field in item}
        key = tuple(row[field] for field in ("serial", "evento", "fechano", "fechames", "fechadia"))
        by_event[key].append(row)
    require(bool(by_event), "DesInventar Vietnam has no records")
    result = []
    for (serial, category, year, month, day), locations in sorted(by_event.items()):
        require(bool(year and serial and category), "DesInventar record is missing event fields")
        start = None
        if int(month or 0) and int(day or 0):
            start = date(int(year), int(month), int(day)).isoformat()
        areas = {", ".join(dict.fromkeys(loc[k] for k in ("lugar", "name2", "name1", "name0") if loc[k]))
                 for loc in locations}
        provinces = sorted({loc["name0"] for loc in locations if loc["name0"]})
        keys = sorted(int(loc["clave"]) for loc in locations)
        result.append({
            "event_id": f"desinventar-{keys[0]}", "event_code": f"DesInventar {serial}",
            "hazard_type": TYPES.get(category.casefold(), "other"), "type_original": category,
            "year": int(year), "start_date": start,
            "date_basis": "source_event_date" if start else "source_year_only",
            "main_affected_area": "; ".join(sorted(areas - {""})) or None,
            "provinces": "; ".join(provinces), "source_url": DESINVENTAR_PROFILE,
            "source": "desinventar", "source_record_count": len(locations),
        })
    return result


def read_or_download(path, url, offline):
    if not path.exists():
        require(not offline, f"Missing cached source: {path}")
        save_raw(path, download(url))
    return path.read_bytes()


def list_dmc(directory, url, offline):
    first = read_or_download(directory / "page-1.html", url + "1", offline)
    total, rows = read_dmc_page(first)
    if total == 0:
        return total, rows
    require(bool(rows), "DMC first page contains no events")
    pages = (total + len(rows) - 1) // len(rows)

    def load_page(number):
        return read_dmc_page(read_or_download(directory / f"page-{number}.html", url + str(number), offline))

    with ThreadPoolExecutor(max_workers=4) as executor:
        for page_total, page_rows in executor.map(load_page, range(2, pages + 1)):
            require(page_total == total, "DMC catalog changed during retrieval")
            rows.extend(page_rows)
    require(len(rows) == total, f"DMC catalog count mismatch: expected {total}, read {len(rows)}")
    return total, rows


def collect(cache, offline, include_details=False, check_types=False):
    total, rows = list_dmc(cache / "dmc-pages", DMC_PAGE, offline)
    if check_types:
        for code in DMC_TYPE_FILTERS:
            url = DMC_PAGE.replace("typeid=0", f"typeid={code}")
            _, typed_rows = list_dmc(cache / "dmc-types" / str(code), url, offline)
            rows.extend(typed_rows)
    unique = {}
    for row in rows:
        previous = unique.setdefault(row["event_id"], row)
        require(previous == row, f"Conflicting DMC records: {row['event_id']}")
    first_listed_year = min(row["start_date"][:4] for row in unique.values() if row["start_date"])

    def load_detail(row):
        detail = cache / "dmc-details" / f"{row['event_id']}.html"
        if include_details and (row["hazard_type"] in ("typhoon", "earthquake") or not row["start_date"]):
            read_or_download(detail, row["source_url"], offline)
        if detail.exists():
            fields = dmc_details(detail.read_bytes(), row["hazard_type"])
            # Blank DMC listing dates can appear in detail as a placeholder 100 years earlier.
            if row["start_date"] or fields.get("start_date", "")[:4] < first_listed_year:
                fields.pop("start_date", None)
            row.update(fields)

    with ThreadPoolExecutor(max_workers=4) as executor:
        list(executor.map(load_detail, unique.values()))
    gdis = read_or_download(cache / "gdis-source.zip", GDIS_ZIP, offline)
    desinventar = read_or_download(cache / "desinventar-vnm.zip", DESINVENTAR, offline)
    eonet = read_or_download(cache / "eonet-storms.json", EONET_STORMS, offline)
    snapshot_date = date.fromtimestamp((cache / "dmc-pages" / "page-1.html").stat().st_mtime)
    return {"snapshot_date": snapshot_date.isoformat(), "dmc_listing_rows": total,
            "dmc_records": list(unique.values()), "gdis_records": read_gdis(gdis),
            "gdis_zip_sha256": sha256(gdis).hexdigest(),
            "desinventar_records": read_desinventar(desinventar),
            "desinventar_zip_sha256": sha256(desinventar).hexdigest(),
            "eonet_storms": json.loads(eonet)["events"], "eonet_sha256": sha256(eonet).hexdigest()}


def write_catalog(cache, offline, include_details=False, check_types=False, output=OUTPUT):
    try:
        document = collect(cache, offline, include_details, check_types)
    except (BadZipFile, ElementTree.ParseError) as exc:
        raise ValueError(f"Invalid disaster source archive: {exc}") from exc
    content = compact(document) + b"\n"
    disasters.products(content)
    save_raw(output, content)
    print(f"DMC: {len(document['dmc_records'])}; NASA GDIS: {len(document['gdis_records'])}; "
          f"DesInventar: {len(document['desinventar_records'])}; EONET: {len(document['eonet_storms'])}")


def read_glide(content):
    rows = []
    for item in json.loads(content)["glideset"]:
        require(re.fullmatch(r"\d{4}-\d{6}", item["number"]) is not None, f"Bad GLIDE number {item['number']}")
        rows.append({key: item[key] or None for key in (
            "glidenumber", "number", "event", "year", "month", "day", "location", "latitude", "longitude",
            "killed", "affected", "magnitude", "comments", "source")})
    require(bool(rows), "GLIDE returned no Vietnam records")
    return sorted(rows, key=lambda row: row["glidenumber"])


def write_glide(output=GLIDE_OUTPUT, today=None):
    """Snapshot the GLIDE list for Vietnam; GLIDE numbers reuse the EM-DAT number used by GDIS."""
    today = today or date.today()
    url = GLIDE.format(year=today.year)
    content = download(url)
    rows = read_glide(content)
    document = {"source": "GLIDEnumber.net (ADRC)", "url": url, "accessed": today.isoformat(),
                "response_sha256": sha256(content).hexdigest(), "records": rows}
    save_raw(output, compact(document) + b"\n")
    print(f"GLIDE: {len(rows)} Vietnam records -> {output}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", type=Path, default=DEFAULT_CACHE)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--offline", action="store_true")
    parser.add_argument("--details", action="store_true", help="Retrieve DMC storm and earthquake detail pages")
    parser.add_argument("--check-types", action="store_true", help="Cross-check DMC pagination using type filters")
    parser.add_argument("--glide", action="store_true", help="Only refresh the GLIDE snapshot used to date GDIS events")
    args = parser.parse_args()
    if args.glide:
        write_glide()
        return
    write_catalog(args.cache, args.offline, args.details, args.check_types, args.output)


if __name__ == "__main__":
    main()
