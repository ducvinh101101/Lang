"""MÁY HÁT TRÁI ĐẤT (NASA Space Apps 2026 — thử thách #14 "The Earth Information Jukebox").

Biến các hình ảnh dữ liệu NASA SVS (video bản đồ phẳng / quả cầu) thành SỐ LIỆU mà app "hát" được:
    app/assets/eic/index.json
    app/assets/eic/<id>/meta.json   mô tả 508, chú giải âm thanh, lý do chọn âm, nguồn, số liệu từng khung
    app/assets/eic/<id>/fNN.jpg     khung hình 768 × 384 (bản đồ phẳng −180…180°, 90…−90°)

Chạy (từ thư mục gốc repo):
    python pipeline/build_eic.py                       # video trong data_nasa/svs/full/ (hoặc data_nasa/svs/)
    python pipeline/build_eic.py --only nightlights co2

Cần: ffmpeg trong PATH, pip install numpy pillow.

Các video (tải bằng data_nasa/svs/tai_svs.bat hoặc từ trang SVS):
    nightlights  SVS 5475  nightlights_2012-2024_KSC_04_plus2_2048x1024_30p_sos.mp4
    co2          SVS 5436  soscomp_1-29-2025a_1024p30.mp4  (+ nền dyamondPointCloud_..._surface_8k_1024p30.mp4)
    ocean        SVS 3912  flat_global_ecco2_2028x1024_comp_p30.mp4
    lightning    SVS 5011  iss_lightning_sos_yearly_07312023_2048p60.mp4
    forest       SVS 4950  GEDI_global_w_colorbar_1080p60.mp4 (+ GEDI_colorbar_0to50_01_print.jpg)

Cách đổi MÀU → SỐ (mỗi bộ một cách, ghi rõ trong meta.json → "method"):
    • sét: đếm chấm vàng, tìm chu kỳ năm, gộp cùng tháng của 2017–2023
    • đèn đêm: độ sáng VƯỢT nền (ảnh trừ trung vị lân cận 15 px) — điểm sáng nhỏ trên nền tối
    • CO₂: độ "cam" của lớp CO₂ = (R−B) của video tổng hợp trừ (R−B) của video nền cùng khung
    • nhiệt độ biển: so màu với thang màu nằm ngay trong video (khớp màu gần nhất)
    • rừng GEDI: video là quả cầu xoay → tìm kinh độ tâm từng khung bằng cách khớp viền lục địa với
      lưới độ cao ETOPO (app/assets/world/elev_glob.bin), chiếu ngược trực giao về lưới 2°, so màu với thang 0–50 m
Đây là số liệu ĐỌC TỪ HÌNH (xấp xỉ, đủ để nghe xu hướng và so nơi này với nơi khác), không phải số đo gốc.
"""
from __future__ import annotations

import argparse
import base64
import warnings
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

warnings.filterwarnings("ignore", category=RuntimeWarning)
ROOT = Path(__file__).resolve().parents[1]
GW, GH = 64, 32  # lưới rê tay
IMG_W, IMG_H = 768, 384
VN_BOX = (6.0, 24.0, 102.0, 118.0)  # lat0, lat1, lon0, lon1 — Việt Nam + Biển Đông


# ---------------------------------------------------------------- tiện ích chung
def ffmpeg_frames(video: Path, frames: list[int], size: tuple[int, int] | None = None) -> list[np.ndarray]:
    """Lấy đúng các khung số [frames] (đếm từ 0) dưới dạng mảng RGB uint8."""
    with tempfile.TemporaryDirectory() as td:
        sel = "+".join(f"eq(n\\,{n})" for n in frames)
        vf = f"select='{sel}'" + (f",scale={size[0]}:{size[1]}" if size else "")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(video), "-vf", vf, "-vsync", "0",
                        str(Path(td) / "f_%04d.png")], check=True)
        out = [np.asarray(Image.open(p).convert("RGB")) for p in sorted(Path(td).glob("f_*.png"))]
    if len(out) != len(frames):
        raise RuntimeError(f"{video.name}: cần {len(frames)} khung, lấy được {len(out)}")
    return out


def n_frames(video: Path) -> int:
    r = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-count_packets", "-show_entries",
                        "stream=nb_read_packets", "-of", "csv=p=0", str(video)], capture_output=True, text=True, check=True)
    return int(r.stdout.strip().split(",")[0])


def land_mask(h: int, w: int) -> np.ndarray:
    """True = đất liền, lưới h × w phủ −180…180, 90…−90 (từ ETOPO 0,5° của app)."""
    e = np.fromfile(ROOT / "app/assets/world/elev_glob.bin", "<i2").reshape(360, 720)
    ys = ((np.arange(h) + 0.5) / h * 360).astype(int)
    xs = ((np.arange(w) + 0.5) / w * 720).astype(int)
    return e[np.ix_(ys, xs)] > 0


def block_mean(a: np.ndarray, h: int, w: int) -> np.ndarray:
    """Trung bình theo khối, bỏ qua NaN."""
    H, W = a.shape
    a = a[: H - H % h, : W - W % w]
    b = a.reshape(h, a.shape[0] // h, w, a.shape[1] // w)
    with np.errstate(invalid="ignore"):
        return np.nanmean(b, axis=(1, 3))


def bright_excess(rgb: np.ndarray, k: int = 15) -> np.ndarray:
    """Độ sáng vượt trung vị lân cận: điểm sáng nhỏ (đèn, chớp sét) nổi lên, nền mịn bị trừ đi."""
    im = Image.fromarray(rgb).convert("L")
    a = np.asarray(im).astype(np.float32)
    b = np.asarray(im.filter(ImageFilter.MedianFilter(k))).astype(np.float32)
    return np.clip(a - b - 6, 0, None)


def lat_weights(h: int) -> np.ndarray:
    lat = 90 - (np.arange(h) + 0.5) * 180 / h
    return np.cos(np.radians(lat))[:, None]


def to_jpeg(rgb: np.ndarray, path: Path) -> None:
    Image.fromarray(rgb).resize((IMG_W, IMG_H), Image.LANCZOS).save(path, quality=74, optimize=True, progressive=True)


def summarize(fields: list[np.ndarray], thr: float = 0.12) -> list[dict]:
    """fields: mảng [h, w] giá trị 0…1 (NaN = không có số liệu) → v, area, cx, d, vn, grid."""
    out, prev = [], None
    for f in fields:
        h, w = f.shape
        wt = np.broadcast_to(lat_weights(h), f.shape)
        ok = np.isfinite(f)
        fv = np.where(ok, f, 0)
        v = float((fv * wt)[ok].sum() / max(1e-9, wt[ok].sum()))
        area = float((wt * (ok & (fv > thr))).sum() / max(1e-9, wt[ok].sum()))
        # vị trí đông–tây của 10 % ô mạnh nhất (trung bình hướng trên vòng tròn kinh độ)
        cx = 0.0
        if ok.any():
            q = np.nanpercentile(f, 90)
            m = ok & (fv >= q) & (fv > 0)
            if m.any():
                lon = np.radians(-180 + (np.nonzero(m)[1] + 0.5) * 360 / w)
                wts = fv[m]
                ang = np.degrees(np.arctan2((np.sin(lon) * wts).sum(), (np.cos(lon) * wts).sum()))
                cx = float(ang / 180)
        la0, la1, lo0, lo1 = VN_BOX
        r0, r1 = int((90 - la1) / 180 * h), int(np.ceil((90 - la0) / 180 * h))
        c0, c1 = int((lo0 + 180) / 360 * w), int(np.ceil((lo1 + 180) / 360 * w))
        sub = f[r0:r1, c0:c1]
        vn = float(np.nanmean(sub)) if np.isfinite(sub).any() else 0.0
        both = np.isfinite(f) & (np.isfinite(prev) if prev is not None else False)
        d = float(np.abs(f - prev)[both].mean() * 4) if prev is not None and both.any() else 0.0
        prev = f
        g = block_mean(f, GH, GW) if (h, w) != (GH, GW) else f
        gb = np.where(np.isfinite(g), np.clip(np.round(g * 254), 0, 254), 255).astype(np.uint8)
        v, area, cx, vn, d = (x if np.isfinite(x) else 0.0 for x in (v, area, cx, vn, d))
        out.append({"v": round(v, 4), "area": round(area, 4), "cx": round(cx, 3), "d": round(min(1.0, d), 4),
                    "vn": round(vn, 4), "grid": base64.b64encode(gb.tobytes()).decode()})
    return out


def write_set(out: Path, meta: dict, images: list[np.ndarray], fields: list[np.ndarray], labels: list[tuple[str, str]],
              thr: float = 0.12, scale_v: bool = True) -> None:
    d = out / meta["id"]
    if d.exists():
        shutil.rmtree(d)
    d.mkdir(parents=True)
    stats = summarize(fields, thr)
    if scale_v:  # giữ TỈ LỆ giữa các khung (để "tăng 19 %" vẫn đúng) nhưng đưa giá trị lớn nhất về 0,9 cho dễ nghe
        top = max(s["v"] for s in stats) or 1
        for s in stats:
            s["v"] = round(0.9 * s["v"] / top, 4)
    # mức đổi d: đưa về thang tương đối của chính bộ này (0 = khung đổi ít nhất, 1 = đổi nhiều nhất)
    ds = [s["d"] for s in stats[1:]]
    if ds and max(ds) > min(ds):
        lo, hi = min(ds), max(ds)
        for s in stats[1:]:
            s["d"] = round((s["d"] - lo) / (hi - lo), 4)
    frames = []
    for i, (img, st, (lv, le)) in enumerate(zip(images, stats, labels)):
        name = f"f{i:02d}.jpg"
        to_jpeg(img, d / name)
        frames.append({"label_vi": lv, "label_en": le, "img": name, **st})
    meta = {**meta, "grid_w": GW, "grid_h": GH, "frames": frames}
    (d / "meta.json").write_text(json.dumps(meta, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    v = [f["v"] for f in frames]
    print(f"  {meta['id']}: {len(frames)} khung, v {min(v):.2f}…{max(v):.2f}, vn {frames[0]['vn']:.2f}→{frames[-1]['vn']:.2f}, "
          f"{sum(p.stat().st_size for p in d.iterdir()) / 1024:.0f} KB")


def find(svs: Path, name: str) -> Path:
    for p in (svs / "full" / name, svs / name):
        if p.exists():
            return p
    raise FileNotFoundError(f"thiếu video {name} trong {svs}/full hoặc {svs}")


# ---------------------------------------------------------------- 1. ánh đèn ban đêm (SVS 5475)
def build_nightlights(svs: Path, out: Path) -> None:
    v = find(svs, "nightlights_2012-2024_KSC_04_plus2_2048x1024_30p_sos.mp4")
    # mỗi năm 60 khung (cắt cứng ở khung 59, 119, …): lấy khung giữa của từng năm 2012…2023
    idx = [30 + 60 * k for k in range(12)]
    imgs = ffmpeg_frames(v, idx)
    land = land_mask(1024, 2048)
    ex = []
    for im in imgs:
        e = bright_excess(im)
        e[480:560, :] = np.where(_label_cols(2048)[None, :], 0, e[480:560, :])  # bỏ chữ số năm in trên hình
        ex.append(block_mean(e, 128, 256))
    p = np.percentile(np.stack(ex), 99.5)
    lm = land_mask(128, 256)
    fields = [np.where(lm, np.clip(e / p, 0, 1) ** 0.5, np.nan) for e in ex]
    labels = [(f"năm {2012 + k}", f"{2012 + k}") for k in range(12)]
    write_set(out, META["nightlights"], imgs, fields, labels, thr=0.08)


def _label_cols(w: int) -> np.ndarray:
    c = np.zeros(w, bool)
    for x in (0.2, 0.45, 0.71, 0.96):
        c[max(0, int(x * w) - 70): int(x * w) + 70] = True
    return c


# ---------------------------------------------------------------- 2. CO₂ gần mặt đất (SVS 5436 / 5196)
DY_DAYS = ["Jan 15", "Jan 18", "Jan 21", "Jan 24", "Jan 27", "Jan 30", "Feb 02", "Feb 05", "Feb 08", "Feb 11", "Feb 14",
           "Feb 17", "Feb 20", "Feb 23", "Feb 26", "Feb 29"]


def build_co2(svs: Path, out: Path) -> None:
    comp = find(svs, "soscomp_1-29-2025a_1024p30.mp4")
    base = find(svs, "dyamondPointCloud_1-29-2025a_dyamond_co2_sos_surface_8k_1024p30.mp4")
    # dyamond_timestamps.txt: khung 3 = 15/1/2020, mỗi ngày 24 khung (mỗi giờ một khung). Lấy 16 ngày, cách 3 ngày;
    # giá trị của một ngày = trung bình 6 khung cách 4 giờ (bỏ dao động ngày–đêm), hình = khung 12 giờ.
    days = [3 + 24 * 3 * k for k in range(16)]
    hours = [0, 4, 8, 12, 16, 20]
    idx = sorted({d + h for d in days for h in hours})
    small = (512, 256)
    C = dict(zip(idx, ffmpeg_frames(comp, idx, small)))
    B = dict(zip(idx, ffmpeg_frames(base, idx, small)))
    big = ffmpeg_frames(comp, [d + 12 for d in days])

    def orange(c, b):
        c = c.astype(np.float32)
        b = b.astype(np.float32)
        return np.clip((c[..., 0] - c[..., 2]) - (b[..., 0] - b[..., 2]), 0, None) + 0.5 * np.clip(
            (b[..., 2] - c[..., 2]), 0, None)

    raw = [block_mean(np.mean([orange(C[d + h], B[d + h]) for h in hours], axis=0), 128, 256) for d in days]
    p = np.percentile(np.stack(raw), 99.5)
    fields = [np.clip(r / p, 0, 1) for r in raw]
    labels = []
    for s in DY_DAYS:
        m, dd = s.split()
        mm = {"Jan": 1, "Feb": 2, "Mar": 3}[m]
        labels.append((f"ngày {int(dd)} tháng {mm} năm 2020", f"{s}, 2020"))
    write_set(out, META["co2"], big, fields, labels, thr=0.1)


# ---------------------------------------------------------------- 3. nhiệt độ mặt biển & dòng chảy (SVS 3912)
def build_ocean(svs: Path, out: Path) -> None:
    v = find(svs, "flat_global_ecco2_2028x1024_comp_p30.mp4")
    n = n_frames(v)
    # flat_ecco2_dates.txt: khung 0 = 25/3/2007 12:00, mỗi khung ≈ 4 giờ 8 phút, khung cuối = 3/3/2008.
    import datetime as dt
    t0, t1 = dt.datetime(2007, 3, 25, 12), dt.datetime(2008, 3, 3, 12)
    # ngày 1 hằng tháng, 4/2007 → 3/2008
    dates = [dt.datetime(2007 + (3 + k) // 12, (3 + k) % 12 + 1, 1, 12) for k in range(12)]
    idx = [int(round((d - t0) / (t1 - t0) * (n - 1))) for d in dates]
    imgs = ffmpeg_frames(v, idx)
    h, w = imgs[0].shape[:2]
    ramp, box = _ocean_ramp(imgs[0])
    land = land_mask(h, w)
    fields, shown = [], []
    for im in imgs:
        a = im.astype(np.float32)
        val = _nearest_ramp(a, ramp, maxdist=60.0)
        val[land] = np.nan
        if box is not None:
            y0, y1, x0, x1 = box
            val[y0:y1, x0:x1] = np.nan
        f = block_mean(val, 128, 256)
        f[land_mask(128, 256)] = np.nan
        fields.append(f)
    labels = [(f"đầu tháng {d.month} năm {d.year}", f"early {d.strftime('%B %Y')}") for d in dates]
    write_set(out, META["ocean"], imgs, fields, labels, thr=0.5, scale_v=False)


def _ocean_ramp(img: np.ndarray):
    """Tìm thang màu nằm ngang trong khung hình (dải nhiều màu bão hoà, ít đổi theo hàng)."""
    a = img.astype(np.float32)
    h, w = a.shape[:2]
    best = None
    # thang màu nằm ở góc dưới bên trái (chỉ tìm ở đó để khỏi nhầm với dòng chảy màu)
    for y in range(int(h * 0.88), h - 2):
        row = a[y, : w // 4]
        sat = row.max(1) - row.min(1)
        run = sat > 60
        # đoạn liên tục dài nhất
        cur = start = 0
        for x in range(len(run)):
            if run[x]:
                if cur == 0:
                    start = x
                cur += 1
                if best is None or cur > best[0]:
                    best = (cur, y, start)
            else:
                cur = 0
    if best is None or best[0] < w * 0.08:
        raise RuntimeError("không tìm thấy thang màu trong video ECCO2")
    L, y, x0 = best
    # các hàng liền kề có cùng dải
    ys = [yy for yy in range(y - 12, y + 13) if 0 <= yy < h and np.abs(a[yy, x0:x0 + L] - a[y, x0:x0 + L]).mean() < 25]
    ramp = a[min(ys):max(ys) + 1, x0 + 2:x0 + L - 2].mean(0)
    print(f"  ocean: thang màu ở hàng {min(ys)}–{max(ys)}, cột {x0}–{x0 + L} ({len(ramp)} màu)")
    return ramp, (max(0, min(ys) - 40), min(h, max(ys) + 40), max(0, x0 - 60), min(w, x0 + L + 60))


def _nearest_ramp(a: np.ndarray, ramp: np.ndarray, maxdist: float) -> np.ndarray:
    r = ramp[:: max(1, len(ramp) // 128)]
    flat = a.reshape(-1, 3)
    out = np.full(len(flat), np.nan, np.float32)
    sat = flat.max(1) - flat.min(1)
    cand = np.nonzero(sat > 40)[0]
    for s in range(0, len(cand), 200000):
        c = cand[s:s + 200000]
        d = ((flat[c][:, None, :] - r[None, :, :]) ** 2).sum(2)
        k = d.argmin(1)
        good = d[np.arange(len(c)), k] < maxdist ** 2
        out[c[good]] = k[good] / (len(r) - 1)
    return out.reshape(a.shape[:2])


# ---------------------------------------------------------------- 4. sét nhìn từ ISS (SVS 5011)
def build_lightning(svs: Path, out: Path) -> None:
    """Video SVS 5011 chạy lặp từng năm 2017→2023 (cửa sổ trượt 10 ngày), không in ngày tháng.
    Tìm từng năm từ tỉ lệ sét Bắc / Nam bán cầu (mỗi lần tỉ lệ Bắc vượt lên 0,5 ≈ giữa tháng 3),
    rồi GỘP mọi khung cùng tháng của các năm → 12 tháng "trung bình 2017–2023"."""
    v = find(svs, "iss_lightning_sos_yearly_07312023_2048p60.mp4")
    W, H, step = 1024, 512, 6
    proc = subprocess.Popen(["ffmpeg", "-v", "error", "-i", str(v), "-vf", f"select='not(mod(n\\,{step}))',scale={W}:{H}",
                             "-vsync", "0", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], stdout=subprocess.PIPE)
    masks, frames_no, base = [], [], None
    k = 0
    while True:
        buf = proc.stdout.read(W * H * 3)
        if len(buf) < W * H * 3:
            break
        a = np.frombuffer(buf, np.uint8).reshape(H, W, 3).astype(np.int16)
        y = (a[..., 0] > 110) & (a[..., 1] > 90) & (a[..., 2] < 70) & (a[..., 0] - a[..., 2] > 60)
        if base is None and k * step > 100:
            base = a.astype(np.uint8)
        masks.append(np.packbits(y))
        frames_no.append(k * step)
        k += 1
    proc.wait()
    fr = np.array(frames_no)
    cnt = np.array([np.unpackbits(m).sum() for m in masks])
    nh = np.array([np.unpackbits(m)[: W * H // 2].sum() for m in masks])
    ok = cnt > 20
    # tỉ lệ sét Bắc bán cầu theo thời gian (làm mượt ~1 giây video); mỗi lần nó VƯỢT LÊN 0,5 là khoảng giữa tháng 3
    # (đo trên dữ liệu: Bắc bán cầu chiếm ½ số sét vào tháng 3, ¾ vào tháng 5–8). Giữa hai lần vượt: nội suy đều.
    frac = np.where(ok, nh / np.maximum(1, cnt), np.nan)
    good = np.nonzero(ok)[0]
    frac = np.interp(np.arange(len(frac)), good, frac[good])
    k = max(1, 60 // step)
    sm = np.convolve(frac, np.ones(2 * k + 1) / (2 * k + 1), mode="same")
    ups = [i for i in range(1, len(sm)) if sm[i - 1] < 0.5 <= sm[i] and ok[i]]
    ups = [u for n_, u in enumerate(ups) if n_ == 0 or u - ups[n_ - 1] > 300 // step]  # bỏ vượt lặp do nhiễu
    L = float(np.median(np.diff(ups)))
    print(f"  lightning: {len(ups)} lần vượt (giữa tháng 3), mỗi năm ≈ {L * step:.0f} khung video")
    phase = np.empty(len(fr))
    for i in range(len(fr)):
        a_ = max([u for u in ups if u <= i], default=None)
        b_ = min([u for u in ups if u > i], default=None)
        if a_ is not None and b_ is not None:
            t = (i - a_) / (b_ - a_)
        elif a_ is not None:
            t = (i - a_) / L
        else:
            t = (i - b_) / L
        phase[i] = (2.5 / 12 + t) % 1
    month = np.floor(phase * 12).astype(int) % 12
    acc = np.zeros((12, H, W), np.float32)
    num = np.zeros(12)
    for m, mk, good in zip(month, masks, ok):
        if good:
            acc[m] += np.unpackbits(mk).reshape(H, W)
            num[m] += 1
    dens = [acc[m] / max(1, num[m]) for m in range(12)]
    raw = [block_mean(d, 128, 256) for d in dens]
    p = np.percentile(np.stack(raw), 99.5)
    fields = [np.clip(r / p, 0, 1) ** 0.5 for r in raw]
    # ảnh: nền tối của video + chấm vàng theo mật độ sét của tháng
    bg = (base.astype(np.float32) * 0.8)
    pd = np.percentile(np.stack(dens), 99.7)
    imgs = []
    for d in dens:
        t = np.clip(d / pd, 0, 1)[..., None]
        im = bg * (1 - t) + np.array([255, 214, 40], np.float32) * t
        imgs.append(np.clip(im, 0, 255).astype(np.uint8))
    vi = [f"tháng {m + 1}" for m in range(12)]
    en = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November",
          "December"]
    labels = [(f"{vi[m]}, trung bình 2017 đến 2023", f"{en[m]}, 2017 to 2023 average") for m in range(12)]
    write_set(out, META["lightning"], imgs, fields, labels, thr=0.08)


# ---------------------------------------------------------------- 5. chiều cao tán rừng GEDI (SVS 4950)
def build_forest(svs: Path, out: Path) -> None:
    v = find(svs, "GEDI_global_w_colorbar_1080p60.mp4")
    cbj = find(svs, "GEDI_colorbar_0to50_01_print.jpg")
    cb = np.asarray(Image.open(cbj).convert("RGB")).astype(np.float32)
    ramp = cb[510:516, 54:485].mean(0)  # 0 m (trái) … 50 m (phải)
    n = n_frames(v)
    idx = list(range(0, n, 75))
    frames = ffmpeg_frames(v, idx)
    e = np.fromfile(ROOT / "app/assets/world/elev_glob.bin", "<i2").reshape(360, 720)
    LAND = e > 0
    CX, CY, R = 960, 540, 516  # quả cầu trong khung 1920 × 1080 (đo từ vùng biển xanh)
    ys, xs = np.mgrid[0:1080:6, 0:1920:6]
    X, Y = (xs - CX) / R, -(ys - CY) / R
    ins = X ** 2 + Y ** 2 < 0.85 ** 2
    Xs, Ys = X[ins], Y[ins]
    Zs = np.sqrt(1 - Xs ** 2 - Ys ** 2)

    def ll(Xa, Ya, Za, l0, p0):
        p = np.radians(p0)
        lat = np.degrees(np.arcsin(Za * np.sin(p) + Ya * np.cos(p)))
        lon = (np.degrees(np.radians(l0) + np.arctan2(Xa, Za * np.cos(p) - Ya * np.sin(p))) + 180) % 360 - 180
        return lat, lon

    def landat(lat, lon):
        r = np.clip(((89.75 - lat) / 0.5).round().astype(int), 0, 359)
        c = np.clip(((lon + 179.75) / 0.5).round().astype(int), 0, 719)
        return LAND[r, c]

    def blue(a):
        return (a[..., 2] > a[..., 0] + 25) & (a[..., 2] > a[..., 1] + 5)

    S = np.zeros((90, 180))
    N = np.zeros((90, 180))
    Yb, Xb = np.mgrid[0:1080:2, 0:1920:2]
    Xf, Yf = (Xb - CX) / R, -(Yb - CY) / R
    insb = Xf ** 2 + Yf ** 2 < 0.8 ** 2
    Xf, Yf = Xf[insb], Yf[insb]
    Zf = np.sqrt(1 - Xf ** 2 - Yf ** 2)
    prev = None
    rs = ramp[::4]
    for fr in frames:
        a = fr.astype(np.int32)
        land = ~blue(a[ys[ins], xs[ins]])
        best = (-1, 0, 0)
        lons = np.arange(-180, 180, 3) if prev is None else np.arange(prev - 15, prev + 4, 1)
        for p0 in range(0, 31, 3):
            for l0 in lons:
                s = (landat(*ll(Xs, Ys, Zs, l0, p0)) == land).mean()
                if s > best[0]:
                    best = (s, int(l0), p0)
        prev = best[1]
        lat, lon = ll(Xf, Yf, Zf, best[1], best[2])
        px = fr[Yb[insb], Xb[insb]].astype(np.float32)
        k = ~blue(px)
        d = ((px[k][:, None, :] - rs[None]) ** 2).sum(2)
        hgt = d.argmin(1) / (len(rs) - 1) * 50
        r = np.clip(((90 - lat[k]) / 2).astype(int), 0, 89)
        c = np.clip(((lon[k] + 180) / 2).astype(int), 0, 179)
        np.add.at(S, (r, c), hgt)
        np.add.at(N, (r, c), 1)
    H = np.where(N > 0, S / np.maximum(N, 1), np.nan)
    H[~(LAND.reshape(90, 4, 180, 4).max((1, 3)))] = np.nan
    field = np.clip(H / 50, 0, 1)
    # ảnh nền: tô lại bản đồ phẳng bằng đúng thang màu GEDI, biển xanh thẫm
    base = np.zeros((90, 180, 3), np.float32)
    base[:] = (14, 30, 58)
    ok = np.isfinite(field)
    base[ok] = ramp[np.clip((field[ok] * (len(ramp) - 1)).astype(int), 0, len(ramp) - 1)]
    landonly = LAND.reshape(90, 4, 180, 4).max((1, 3)) & ~ok
    base[landonly] = (60, 60, 60)
    big = np.asarray(Image.fromarray(base.astype(np.uint8)).resize((IMG_W, IMG_H), Image.BICUBIC)).copy()
    # 12 "khung" = 12 dải kinh độ 30° quét từ TÂY sang ĐÔNG; mỗi khung chỉ giữ số liệu trong dải đó cho giọng chính
    imgs, fields, labels = [], [], []
    for k in range(12):
        lo0 = -180 + 30 * k
        im = (big * 0.6).astype(np.uint8)
        x0, x1 = int(k * IMG_W / 12), int((k + 1) * IMG_W / 12)
        im[:, x0:x1] = big[:, x0:x1]
        imgs.append(im)
        f = np.full_like(field, np.nan)
        c0, c1 = k * 15, (k + 1) * 15
        f[:, c0:c1] = field[:, c0:c1]
        fields.append(f)
        labels.append((f"kinh độ {_lon_vi(lo0)} đến {_lon_vi(lo0 + 30)}", f"longitude {_lon_en(lo0)} to {_lon_en(lo0 + 30)}"))
    write_set(out, META["forest"], imgs, fields, labels, thr=0.4)
    # lưới rê tay: cả bản đồ (không chỉ dải) cho mọi khung
    d = out / "forest"
    m = json.loads((d / "meta.json").read_text(encoding="utf-8"))
    g = block_mean(field, GH, GW)
    gb = np.where(np.isfinite(g), np.clip(np.round(g * 254), 0, 254), 255).astype(np.uint8)
    b64 = base64.b64encode(gb.tobytes()).decode()
    prev_v = None
    for fr in m["frames"]:
        fr["grid"] = b64
        fr["d"] = 0.0 if prev_v is None else round(min(1.0, abs(fr["v"] - prev_v) / 0.9), 4)
        prev_v = fr["v"]
    (d / "meta.json").write_text(json.dumps(m, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")


def _lon_vi(x):
    return "180 độ" if abs(x) == 180 else ("0 độ" if x == 0 else f"{abs(x)} độ {'Đông' if x > 0 else 'Tây'}")


def _lon_en(x):
    return "180°" if abs(x) == 180 else ("0°" if x == 0 else f"{abs(x)}°{'E' if x > 0 else 'W'}")


# ---------------------------------------------------------------- mô tả, chú giải, lý do (đề #14 yêu cầu)
META = {
    "nightlights": {
        "id": "nightlights", "svs_id": 5475, "url": "https://svs.gsfc.nasa.gov/5475",
        "source": "NASA Black Marble (VIIRS), NASA Scientific Visualization Studio",
        "title_vi": "Ánh đèn ban đêm của Trái Đất, 2012 đến 2023", "title_en": "Earth's night lights, 2012 to 2023",
        "describe_vi": "Bản đồ cả thế giới lúc đêm, nền tối. Mỗi đốm sáng vàng là một thành phố, như hạt cát vàng rắc trên tấm vải đen. "
                       "Dày nhất ở châu Âu, miền đông nước Mỹ, Ấn Độ, Trung Quốc; châu Phi và Nam Mỹ thưa hơn.",
        "describe_en": "A world map at night on a dark background. Each yellow speck is a city, like gold sand on black cloth. "
                       "Densest in Europe, the eastern United States, India and China; sparser in Africa and South America.",
        "legend_vi": "Mỗi năm một nhịp: tiếng đàn bầu càng cao là cả thế giới càng sáng; tiếng t'rưng càng dày là càng nhiều nơi có đèn; "
                     "tiếng nghiêng sang tai nào là vùng sáng nhất đang ở phía đó.",
        "legend_en": "One beat per year: a higher monochord means a brighter world; more t'rung notes mean more places lit; "
                     "the sound leans toward the side where the brightest region is.",
        "why_vi": "Ánh sáng là thứ mắt thấy, nên chúng tôi đổi độ sáng thành độ cao của tiếng đàn bầu, thứ tai nghe rõ nhất. "
                  "Đèn là nhiều điểm nhỏ rời nhau nên dùng tiếng t'rưng gõ rời từng nốt, như đếm từng ngọn đèn. "
                  "Chia theo năm để nghe được xu hướng: đô thị hoá làm thế giới sáng dần.",
        "why_en": "Light is something you see, so brightness becomes the pitch of the monochord, the clearest thing the ear follows. "
                  "Lights are many separate points, so the t'rung plays separate notes, like counting lamps. One beat per year reveals the trend.",
        "scale_vi": "độ sáng ánh đèn, tương đối", "scale_en": "relative brightness",
        "unit_vi": "", "unit_en": "", "low": 0, "high": 1,
        "sound": {"voice": "danbau", "pulse": "trung", "bed": "none"},
        "aliases": ["den dem", "den thanh pho", "black marble"],
        "method": "Độ sáng vượt nền (trừ trung vị 15 px), che chữ số năm, chỉ tính trên đất liền, chuẩn hoá theo bách phân vị 99,5 của cả 12 năm.",
    },
    "co2": {
        "id": "co2", "svs_id": 5436, "url": "https://svs.gsfc.nasa.gov/5436",
        "source": "NASA GMAO GEOS, mô phỏng DYAMOND, NASA Scientific Visualization Studio (SVS 5196 / 5436)",
        "title_vi": "Khí CO₂ gần mặt đất, tháng 1 đến tháng 3 năm 2020", "title_en": "Near-surface CO₂, January to March 2020",
        "describe_vi": "Bản đồ thế giới, đất màu xám trắng, biển xanh đen. Những mảng màu cam như khói lan ra từ các vùng đông dân và rừng nhiệt đới: "
                       "Đông Á, Ấn Độ, Đông Nam Á, Trung Phi; châu Âu và miền đông nước Mỹ nhạt hơn.",
        "describe_en": "A world map with grey-white land and dark-blue oceans. Orange patches spread like smoke from populated areas and tropical forests: "
                       "East Asia, India, Southeast Asia, Central Africa; lighter over Europe and the eastern United States.",
        "legend_vi": "Mỗi nhịp là một ngày (cách 3 ngày): đàn bầu càng cao là CO₂ gần mặt đất càng nhiều; tiếng lách tách dày là vùng có CO₂ cao trải rộng; "
                     "tiếng gió nổi lên khi khí bị gió thổi đi, thay đổi nhanh.",
        "legend_en": "One beat per day, every three days: a higher monochord means more CO₂ near the ground; denser crackles mean high CO₂ covers more area; "
                     "wind rises when the gas is blown around quickly.",
        "why_vi": "CO₂ vô hình, giống khói, nên chúng tôi dùng tiếng lách tách như lửa cháy cho diện tích phát thải, và tiếng gió cho sự di chuyển của khí. "
                  "Lấy trung bình cả ngày để bỏ dao động ngày đêm, chỉ giữ lại thay đổi thật giữa các ngày.",
        "why_en": "CO₂ is invisible, like smoke, so a fire-like crackle marks how widely it is emitted and wind marks how it moves. "
                  "Each day is averaged to remove the day–night cycle and keep the real day-to-day change.",
        "scale_vi": "mức CO₂ gần mặt đất, tương đối", "scale_en": "relative near-surface CO₂",
        "unit_vi": "", "unit_en": "", "low": 0, "high": 1,
        "sound": {"voice": "danbau", "pulse": "crackle", "bed": "wind"},
        "aliases": ["khi co2", "khi nha kinh", "dyamond"],
        "method": "Độ cam (R−B) của video tổng hợp trừ video nền cùng khung, trung bình 6 khung cách 4 giờ mỗi ngày.",
    },
    "ocean": {
        "id": "ocean", "svs_id": 3912, "sweep": "season", "url": "https://svs.gsfc.nasa.gov/3912",
        "source": "Mô hình ECCO2 (MIT / NASA JPL), NASA Scientific Visualization Studio",
        "title_vi": "Nhiệt độ mặt biển và dòng chảy, 2007 đến 2008", "title_en": "Sea surface temperature and currents, 2007 to 2008",
        "describe_vi": "Bản đồ thế giới, đất liền màu đen. Mặt biển phủ những sợi chỉ màu chảy như tóc rối: đỏ cam ở vùng xích đạo nóng, "
                       "xanh lam tím ở hai cực lạnh. Có những xoáy nước tròn như vân tay dọc các dòng hải lưu lớn.",
        "describe_en": "A world map with black land. The sea is covered by flowing coloured threads like loose hair: red-orange near the warm equator, "
                       "blue-purple near the cold poles, with round eddies like fingerprints along the big currents.",
        "legend_vi": "Mỗi nhịp là một tháng: đàn bầu cao thấp theo nhiệt độ mặt BIỂN ĐÔNG; tiếng sóng nổi lên khi nước toàn cầu đổi nhanh; "
                     "rê tay lên biển để nghe nước nóng hay lạnh.",
        "legend_en": "One beat per month: the monochord follows the sea temperature of the EAST SEA; waves rise when the global ocean changes quickly; "
                     "slide over the sea to hear warm or cold water.",
        "why_vi": "Người Việt sống cạnh Biển Đông nên giọng chính đi theo nhiệt độ biển nhà mình: nghe rõ mùa hè nóng, mùa đông mát. "
                  "Dòng chảy là chuyển động của nước nên dùng tiếng sóng, ai cũng nhận ra ngay.",
        "why_en": "Vietnamese people live by the East Sea, so the main voice follows its temperature: summer warm, winter cool. "
                  "Currents are moving water, so we use wave sounds anyone recognises.",
        "scale_vi": "nhiệt độ mặt biển", "scale_en": "sea surface temperature",
        "unit_vi": "độ C", "unit_en": "°C", "low": 0, "high": 32,
        "sound": {"voice": "danbau", "pulse": "none", "bed": "song", "pitch": "vn"},
        "aliases": ["nhiet do bien", "hai luu", "ecco2", "bien dong"],
        "method": "So màu từng điểm với thang màu có sẵn trong video (khớp màu gần nhất), bỏ đất liền và vùng chữ, trung bình theo ô. "
                  "Thang 0…32 °C đúng như thang màu in trong video (Sea Surface Temp °C).",
    },
    "lightning": {
        "id": "lightning", "svs_id": 5011, "sweep": "season", "url": "https://svs.gsfc.nasa.gov/5011",
        "source": "Cảm biến LIS trên Trạm Vũ trụ Quốc tế (ISS), 2017 đến 2023, NASA Scientific Visualization Studio",
        "title_vi": "Sét nhìn từ Trạm Vũ trụ Quốc tế, 12 tháng, trung bình 2017 đến 2023", "title_en": "Lightning seen from the Space Station, month by month, 2017 to 2023 average",
        "describe_vi": "Bản đồ thế giới tối. Mỗi chớp sét là một chấm sáng loé lên. Sét dày ở vùng nhiệt đới: châu Phi giữa, Nam Mỹ, Đông Nam Á; "
                       "dải sét dịch lên phía bắc vào mùa hè và xuống phía nam vào mùa đông.",
        "describe_en": "A dark world map where each flash is a brief bright dot. Lightning is densest in the tropics: central Africa, South America, Southeast Asia; "
                       "the band moves north in northern summer and south in winter.",
        "legend_vi": "Mỗi nhịp là một tháng: tiếng trống dồn dày là nhiều sét; đàn bầu cao là sét mạnh trên toàn cầu; "
                     "tiếng sấm vang khi số sét đổi nhiều; tai trái tai phải cho biết sét đang dồn về phía tây hay phía đông.",
        "legend_en": "One beat per month: denser drums mean more lightning; a higher monochord means more global activity; "
                     "thunder rolls when activity changes a lot; left or right ear tells you whether storms are west or east.",
        "why_vi": "Sét đến cùng tiếng sấm, nên trống và sấm là âm thanh tự nhiên nhất. Đếm số tiếng trống là đếm số chớp. "
                  "Chia theo tháng để nghe được mùa mưa bão dịch chuyển, rất gần với Việt Nam mùa hè.",
        "why_en": "Lightning comes with thunder, so drums and thunder are the most natural sounds; counting drum hits is counting flashes. "
                  "Monthly beats reveal the storm season moving across the year.",
        "scale_vi": "mật độ sét, tương đối", "scale_en": "relative flash density",
        "unit_vi": "", "unit_en": "", "low": 0, "high": 1,
        "sound": {"voice": "danbau", "pulse": "trong", "bed": "thunder"},
        "aliases": ["set", "tia set", "lis"],
        "method": "Đếm chấm sét vàng trên mọi khung thứ 6 của video (cửa sổ trượt 10 ngày), tìm chu kỳ năm bằng tỉ lệ sét Bắc/Nam bán cầu, gộp các khung cùng tháng của 2017–2023.",
    },
    "forest": {
        "id": "forest", "svs_id": 4950, "sweep": "space", "url": "https://svs.gsfc.nasa.gov/4950",
        "source": "Thiết bị GEDI trên Trạm Vũ trụ Quốc tế, 4/2019 đến 4/2020, NASA Scientific Visualization Studio",
        "title_vi": "Chiều cao tán rừng toàn cầu đo bằng tia laser GEDI", "title_en": "Global forest canopy height from the GEDI laser",
        "describe_vi": "Bản đồ đất liền thế giới giữa 52 độ Bắc và 52 độ Nam. Màu nâu là cây thấp, đồng cỏ, sa mạc; xanh lá là rừng; "
                       "xanh nhạt gần trắng là rừng rất cao, như rừng Amazon, lưu vực Congo, Đông Nam Á.",
        "describe_en": "Land between 52° north and south. Brown is low vegetation, grass and desert; green is forest; "
                       "pale green to white is very tall forest, like the Amazon, the Congo basin and Southeast Asia.",
        "legend_vi": "Quét từ Tây sang Đông, mỗi nhịp một dải kinh độ 30 độ: đàn bầu càng cao là tán rừng trung bình càng cao; "
                     "tiếng t'rưng dày là rừng cao phủ rộng. Rê tay lên hình để nghe chiều cao rừng từng nơi, đọc bằng mét.",
        "legend_en": "A sweep from west to east, one beat per 30° of longitude: a higher monochord means taller average canopy; "
                     "more t'rung notes mean tall forest covers more land. Slide over the map to hear canopy height in metres.",
        "why_vi": "Rừng không đổi nhanh theo thời gian mà khác nhau theo nơi, nên chúng tôi quét theo không gian từ Tây sang Đông thay vì theo năm. "
                  "Tiếng t'rưng làm bằng tre nứa, gợi đúng rừng; cây càng cao tiếng đàn càng cao, dễ hình dung.",
        "why_en": "Forests vary by place rather than over time, so we sweep across space from west to east instead of through years. "
                  "The bamboo t'rung evokes the forest; taller trees mean a higher pitch.",
        "scale_vi": "chiều cao tán rừng 0 đến 50 mét", "scale_en": "canopy height 0 to 50 metres",
        "unit_vi": "mét", "unit_en": "metres", "low": 0, "high": 50,
        "sound": {"voice": "sao", "pulse": "trung", "bed": "none"},
        "aliases": ["rung", "tan rung", "gedi", "chieu cao rung"],
        "method": "Video là quả cầu xoay: tìm kinh độ tâm từng khung bằng cách khớp viền lục địa với ETOPO, chiếu ngược trực giao về lưới 2°, "
                  "so màu với thang 0–50 m, trung bình nhiều khung nhìn thấy cùng một ô.",
    },
}

BUILDERS = {"nightlights": build_nightlights, "co2": build_co2, "ocean": build_ocean, "lightning": build_lightning,
            "forest": build_forest}
ORDER = ["nightlights", "lightning", "co2", "ocean", "forest"]


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--svs", type=Path, default=ROOT / "data_nasa/svs")
    ap.add_argument("--out", type=Path, default=ROOT / "app/assets/eic")
    ap.add_argument("--only", nargs="*", choices=list(BUILDERS))
    a = ap.parse_args()
    a.out.mkdir(parents=True, exist_ok=True)
    for k in a.only or ORDER:
        print(f"[{k}]")
        try:
            BUILDERS[k](a.svs, a.out)
        except FileNotFoundError as e:
            print(f"  bỏ qua: {e}")
    done = [k for k in ORDER if (a.out / k / "meta.json").exists()]
    (a.out / "index.json").write_text(json.dumps({"sets": done}, ensure_ascii=False), encoding="utf-8")
    print("index.json:", done)


if __name__ == "__main__":
    sys.exit(main())
