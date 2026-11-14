"""Tạo lưới F3 mẫu 4×3 ô (cùng bảng mã với data_nasa/build_f3.py) cho test của app: app/test/fixtures/touch/vn/."""
import json
from pathlib import Path

from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "app" / "test" / "fixtures" / "touch" / "vn"


def make():
    OUT.mkdir(parents=True, exist_ok=True)
    cols, rows = 4, 3
    # hàng trên (bắc) trước; 255 = không có số liệu (với độ cao: biển)
    elev = [80, 160, 255, 255,     # 1000 m, 2000 m, biển, biển
            8, 16, 24, 255,        # 100, 200, 300 m, biển
            0, 4, 40, 255]         # 0, 50, 500 m, biển
    slope = [100, 40, 255, 255, 4, 0, 8, 255, 0, 2, 60, 255]           # 25°, 10°, …, 1°, 0°, 2°
    water = [0, 0, 255, 255, 0, 200, 0, 255, 250, 0, 0, 255]           # 0,8 và 1,0 = sông hồ
    pop = [0, 40, 255, 255, 160, 120, 0, 255, 0, 80, 0, 255]           # 10^(b·0,025) − 1 người/km²
    for name, vals in [("elev", elev), ("slope", slope), ("water", water), ("pop", pop)]:
        im = Image.new("L", (cols, rows))
        im.putdata(vals)
        im.save(OUT / f"{name}.png")
    meta = {
        "level": "vn",
        "grid": {"lon0": 104.0, "lat_top": 23.0, "step": 1.0, "cols": cols, "rows": rows},
        "layers": [
            {"name": "elev", "file": "elev.png", "scale": 12.5, "offset": 0, "log": False},
            {"name": "slope", "file": "slope.png", "scale": 0.25, "offset": 0, "log": False},
            {"name": "water", "file": "water.png", "scale": 0.004, "offset": 0, "log": False, "on_threshold": 0.5},
            {"name": "pop", "file": "pop.png", "scale": 0.025, "offset": 0, "log": True},
        ],
        "data_cards": {"elev": {"dataset": "NASA SRTMGL30 (mẫu kiểm thử)"}},
    }
    (OUT / "grid.json").write_text(json.dumps(meta, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    make()
