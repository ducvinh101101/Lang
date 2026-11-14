"""Kiểm tra phần sửa data_nasa/touchmap.py cho bản SRTMGL30 trên LP DAAC Cloud (chỉ có .DEM, biển ghi 0 m)."""
import sys
from pathlib import Path

import numpy as np
import pytest

ROOT = Path(__file__).resolve().parent.parent
DN = ROOT / "data_nasa"
pytestmark = pytest.mark.skipif(not (DN / "touchmap.py").exists(), reason="chưa có kho data_nasa")
sys.path.insert(0, str(DN))


def test_dung_hdr_tu_ten_o(tmp_path):
    import touchmap as tm
    f = tmp_path / "E100N40.DEM"
    with open(f, "wb") as h:
        h.truncate(4800 * 6000 * 2)  # file thưa, đúng kích thước ô chuẩn
    h = tm.gtopo30_header(str(f))
    assert h["NCOLS"] == "4800" and h["NROWS"] == "6000" and h["BYTEORDER"] == "M"
    assert abs(float(h["ULXMAP"]) - (100 + 1 / 240)) < 1e-9
    assert abs(float(h["ULYMAP"]) - (40 - 1 / 240)) < 1e-9
    r = tm.read_gtopo_dem(str(f))
    assert r.arr.shape == (6000, 4800)
    w = tmp_path / "W020S10.DEM"
    with open(w, "wb") as h2:
        h2.truncate(4800 * 6000 * 2)
    hw = tm.gtopo30_header(str(w))
    assert float(hw["ULXMAP"]) < -19.9 and float(hw["ULYMAP"]) < -10


def test_sai_kich_thuoc_thi_bao_loi(tmp_path):
    import touchmap as tm
    f = tmp_path / "E100N40.DEM"
    f.write_bytes(b"\x00" * 100)
    with pytest.raises(ValueError):
        tm.gtopo30_header(str(f))


def test_bien_la_vung_0m_noi_bien_khoi():
    import touchmap as tm
    # 0 = biển hoặc đất trũng; số dương = đất. Cột trái là biển khơi; giữa có một hồ trũng 0 m bị đất bao quanh.
    a = np.array([
        [0, 5, 5, 5, 5],
        [0, 5, 0, 0, 5],
        [0, 5, 0, 0, 5],
        [0, 0, 5, 5, 5],   # biển lấn vào ô (3,1)
        [0, 5, 5, 5, 5],
    ], dtype=np.int16)
    r = tm.Raster(a, 0.5, 4.5, 1.0, 1.0, -9999)   # tâm ô góc trên trái (0,5; 4,5), ô 1°
    out = tm.mask_open_sea(r, [(0.5, 2.5)])         # hạt giống ở cột biển
    sea = np.isnan(out.arr)
    assert sea[:, 0].all() and sea[3, 1]            # biển + vịnh nối liền
    assert not sea[1, 2] and not sea[2, 3]          # vùng 0 m kín giữ là đất
    assert out.arr[1, 2] == 0 and out.arr[0, 1] == 5
    # hạt giống rơi vào đất → không đánh dấu gì
    assert not np.isnan(tm.mask_open_sea(r, [(1.5, 0.5)]).arr).any()
