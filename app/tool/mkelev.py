"""Tạo assets/world/elev_glob.bin (lưới độ cao 0,5°) từ lưới ETOPO 20' (matplotlib/basemap doc/examples).

    python tool/mkelev.py <thư mục chứa etopo20data.gz, etopo20lats.gz, etopo20lons.gz>
"""
import gzip
import os
import sys

import numpy as np

src = sys.argv[1]
d = np.loadtxt(gzip.open(os.path.join(src, 'etopo20data.gz')))[:, :1080]  # hàng: vĩ độ nam → bắc
lons = 20.1666667 + np.arange(1080) / 3.0
lons = ((lons + 180) % 360) - 180
order = np.argsort(lons)
d, lons = d[:, order], lons[order]
lats = -89.8333333 + np.arange(540) / 3.0


def samp(lat, lon):
    fi = (lat - lats[0]) * 3
    fj = (lon - lons[0]) * 3
    i0 = np.clip(np.floor(fi).astype(int), 0, 538)
    j0 = np.floor(fj).astype(int)
    ti = np.clip(fi - i0, 0, 1)
    tj = fj - j0
    a0, a1 = j0 % 1080, (j0 + 1) % 1080
    a = d[i0, a0] * (1 - tj) + d[i0, a1] * tj
    b = d[i0 + 1, a0] * (1 - tj) + d[i0 + 1, a1] * tj
    return a * (1 - ti) + b * ti


R, C = 360, 720
LA, LO = np.meshgrid(89.75 - np.arange(R) * 0.5, -179.75 + np.arange(C) * 0.5, indexing='ij')
acc = sum(samp(LA + a, LO + b) for a in (-0.166, 0, 0.166) for b in (-0.166, 0, 0.166))
g = np.round(acc / 9).astype('<i2')
out = os.path.join(os.path.dirname(__file__), '..', 'assets', 'world', 'elev_glob.bin')
g.tofile(out)
print('đã ghi', out, g.shape, g.min(), g.max())
