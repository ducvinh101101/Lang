"""Publish versioned JSON and CSV and switch the app manifest after validation."""

import csv
from hashlib import sha256
import io
from pathlib import Path
from tempfile import TemporaryDirectory

from .archive import compact
from .io import require, save_raw


def csv_bytes(document):
    fields = list(document["data_card"]["units"])
    columns = ["location_id", "month", *fields, *(field + "_status" for field in fields)]
    with io.StringIO(newline="") as stream:
        writer = csv.writer(stream, lineterminator="\n")
        writer.writerow(columns)
        for row in document["records"]:
            writer.writerow([row["location_id"], row["month"], *(row["values"][f] for f in fields),
                             *(row["status"][f] for f in fields)])
        content = stream.getvalue()
    reader = csv.reader(io.StringIO(content))
    require(next(reader) == columns, "CSV header mismatch")
    for row, cells in zip(document["records"], reader, strict=True):
        expected = [row["location_id"], row["month"],
                    *["" if row["values"][field] is None else str(row["values"][field]) for field in fields],
                    *(row["status"][field] for field in fields)]
        require(cells == expected, "CSV and app JSON differ")
    return content.encode("utf-8")


def export(document, checks, output):
    data = compact(document) + b"\n"
    revision = sha256(data).hexdigest()
    files = {"app.json": data, "data.csv": csv_bytes(document), "report.json": compact(checks) + b"\n"}
    releases = output / "releases"
    releases.mkdir(parents=True, exist_ok=True)
    release = releases / revision
    if not release.exists():
        with TemporaryDirectory(dir=output) as staging:
            bundle = Path(staging) / "bundle"
            bundle.mkdir()
            for name, content in files.items():
                (bundle / name).write_bytes(content)
            try:
                bundle.rename(release)
            except OSError:
                if not release.is_dir():
                    raise
    for name, content in files.items():
        require((release / name).read_bytes() == content, f"Release content differs for {name}")
    manifest = {
        "schema_version": 1, "revision": revision,
        "files": {name: {"path": f"releases/{revision}/{name}", "sha256": sha256(content).hexdigest()}
                  for name, content in files.items()},
    }
    save_raw(output / "latest.json", compact(manifest) + b"\n")
    return release
