"""Kiểm tra pipeline/import_data_nasa.py (nhập dữ liệu từ kho data_nasa vào app)."""
import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "pipeline"))
sys.path.insert(0, str(ROOT / "tests"))
import import_data_nasa as imp  # noqa: E402

needs_data = pytest.mark.skipif(not imp.DATA_NASA.exists(), reason="chưa có kho data_nasa")


def test_fold_chiu_loi_ma_hoa_va_khong_dau():
    assert imp.fold("Thừa Thiên-Huế") == "thuathienhue"
    assert imp.fold("Quang Ngai") == imp.fold("Quảng Ngãi")
    assert imp.fold("Đắk Lắk") == "daklak"


def test_dinh_vi_tinh_cu():
    table = imp.old_province_centroids()
    assert len(table) >= 63
    # lỗi mã hoá trong nguồn: "Thừa Thi n-Huế", "Y n Bái"
    hue = imp.locate("Thừa Thi n-Huế", table)
    assert hue and abs(hue[0][1] - 16.4) < 0.6 and abs(hue[0][2] - 107.5) < 0.8
    yb = imp.locate("Y n Bái", table)
    assert yb and yb[0][0] == "Yên Bái"
    # mô tả dài vẫn tìm ra các tỉnh
    names = {p[0] for p in imp.locate("Trên đất liền khu vực các tỉnh Lào Cai, Yên Bái, Hà Giang", table)}
    assert {"Lào Cai", "Yên Bái", "Hà Giang"} <= names
    assert imp.locate("Biển Đông", table) == []


@needs_data
def test_f1_danh_muc_thien_tai():
    d = imp.build_f1()
    recs = d["records"]
    assert len(recs) > 250
    for r in recs:
        assert r["points"], r["id"]
        assert 1 <= r["severity"] <= 5
        assert r["kind"] in imp.NAME_VI
        assert len(r["date"]) == 10


@needs_data
def test_f1_khi_hau_34_tinh():
    c = imp.build_climate34()
    assert len(c["places"]) == 34
    for p in c["places"]:
        n = (p["y1"] - p["y0"] + 1) * 12
        assert len(p["t"]) == n and len(p["r"]) == n
        assert all(x is not None for x in p["t"])


@needs_data
def test_f2_gop_su_that_chay_lai_khong_doi(tmp_path, monkeypatch):
    src = imp.APP_DATA / "planets_nasa.json"
    work = tmp_path / "data"
    work.mkdir()
    (work / "planets_nasa.json").write_text(src.read_text(encoding="utf-8"), encoding="utf-8")
    monkeypatch.setattr(imp, "APP_DATA", work)
    a = imp.merge_f2()
    first = (work / "planets_nasa.json").read_text(encoding="utf-8")
    b = imp.merge_f2()
    assert a == b > 50
    assert (work / "planets_nasa.json").read_text(encoding="utf-8") == first
    facts = [f for x in json.loads(first)["bodies"] for f in x["fun_facts"]]
    assert not any("độ F" in f["vi"] or " dặm" in f["vi"] for f in facts)


def test_mp3_duration_tu_khung_dung_san():
    import nasa_sounds as ns
    # MPEG-1 Layer III, 128 kbps, 44,1 kHz, không padding: mỗi khung 417 byte, 1152 mẫu
    hdr = bytes([0xFF, 0xFB, 0x90, 0x00])
    frame = hdr + bytes(413)
    data = b"ID3" + bytes([3, 0, 0, 0, 0, 0, 10]) + bytes(10) + frame * 100
    assert ns.mp3_duration(data) == round(100 * 1152 / 44100, 2)
    # rác giữa các khung bị bỏ qua
    assert ns.mp3_duration(b"\x00junk" + frame * 10) == round(10 * 1152 / 44100, 2)


@needs_data
def test_ban_ghi_nasa_du_10_file(tmp_path):
    import nasa_sounds as ns
    cat = ns.build(imp.DATA_NASA, tmp_path)
    assert len(cat["items"]) == 10
    for it in cat["items"]:
        assert (tmp_path / "assets" / "sounds" / "nasa" / it["file"]).exists()
        assert 1 < it["duration_s"] < 60
        assert all(k == imp.fold_ascii(k).lower() for k in it["keys"]), it["keys"]


def test_f3_chep_luoi_that(tmp_path):
    import make_touch_fixture as fx
    src = tmp_path / "touch"
    (src / "vn").mkdir(parents=True)
    old = fx.OUT
    fx.OUT = src / "vn"
    try:
        fx.make()
    finally:
        fx.OUT = old
    dst = tmp_path / "app_touch"
    assert imp.copy_touch(src, dst)
    assert sorted(p.name for p in dst.iterdir()) == ["elev.png", "grid.json", "pop.png", "slope.png", "water.png"]
    # chưa build → bỏ qua, không lỗi
    assert imp.copy_touch(tmp_path / "khong_co", tmp_path / "x") is False


@needs_data
def test_chay_ca_script_tu_dau_den_cuoi():
    import subprocess
    r = subprocess.run([sys.executable, str(ROOT / "pipeline" / "import_data_nasa.py")], capture_output=True, text=True,
                       encoding="utf-8", env={**__import__("os").environ, "PYTHONIOENCODING": "utf-8"})
    assert r.returncode == 0, r.stderr
    assert "F3:" in r.stdout and "khí hậu 34" in r.stdout
