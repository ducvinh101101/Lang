# Lắng – Hear and Touch NASA Earth Data

> **NASA Space Apps Challenge 2026 · Challenge 14: The Earth Information Jukebox** · Team Lắng (Hanoi, Vietnam)
> Web app: **lang-app-woad.vercel.app** · Vietnamese README: [README.vi.md](README.vi.md)

*Lắng* is Vietnamese for "listen closely". Lắng is a talking globe that lets **blind and low-vision people, older adults and children** hear and touch NASA Earth data **without seeing or reading**. You speak a question; a short tone confirms it; the answer comes back as music on Vietnamese folk instruments, followed by the real numbers read aloud.

## What it does

| Part | Say (examples) | What you hear / feel | NASA data |
|---|---|---|---|
| **Earth Jukebox** (Challenge 14) | "Earth Jukebox", "listen to lightning", "month 5", "explain" | Five NASA visualizations played frame by frame: pitch = value, beat density = area, left/right = west/east, a gong when Vietnam changes. Spoken image descriptions; slide a finger over the image to hear each region. | NASA SVS 5475/5313 (Black Marble), 5011 (LIS on ISS), 5436/5196 (GEOS CO₂), 3912 (ECCO2), 4950 (GEDI) |
| **Hear the climate** | "weather in Hue", "Hanoi past and present", "Typhoon Yagi", "global warming" | Temperature on the *đàn bầu* (one-string zither), rain on the *t'rưng* (bamboo xylophone); 15-day storm replays | GISTEMP v4, NASA POWER (MERRA-2), SEDAC GDIS |
| **Touch the land** | "explore by touch in Da Lat", "scan the terrain" | A bamboo flute rises with elevation, the phone vibrates with slope, water/forest/town sounds | SRTM, MODIS MCD12Q1, SEDAC GPWv4 |
| **Explore space** | "tell me about Mars", "NASA sounds", "play a game" | Planet facts, ten real NASA recordings, four voice-only games | NSSDCA, NASA Science, Space Place, NASA Historical Sounds |

Things you can hear in the Earth Jukebox: Vietnam's night lights grew about **44%** from 2012 to 2023 (17% globally); lightning over Vietnam peaks in **May**, two months before the global peak.

## Accessibility

- Voice-first: nothing on screen has to be seen. Vietnamese and English.
- Interrupt with "stop"; go back with "go back", a **Z gesture** or a **two-finger swipe down**; switch parts with a **two-finger swipe left/right**; **hold one finger** anywhere to talk.
- Offline on Android: speech recognition, voice, climate history, storm replays, terrain grid, space facts and the Earth Jukebox.
- High-contrast interface; image descriptions follow Section 508 practice.

## How it works

```
NASA archives / APIs ──► pipeline/ (Python): download → convert units → validate → compress → data card
NASA SVS videos ──────► pipeline/build_eic.py: colour → numbers (64 × 32 grid + summary values per frame)
                                   │
                                   ▼
app/ (Flutter: Android, iOS, Windows, web)
  speech in  : sherpa-onnx (Vietnamese Zipformer, NVIDIA Parakeet English) + Silero VAD, all on device
  speech out : Piper vi_VN-vais1000 (on device); browser voice or the same Piper voice via /api/tts on the web
  sound      : folk instruments synthesised on device (flutter_soloud); values → 5-note pentatonic scale, 3 octaves
  AI         : open questions only, Gemma 4 / Gemini given the relevant NASA data first (retrieval-augmented)
```

Formulas and accuracy of every data-to-sound mapping: [docs/CHUYEN_DU_LIEU_THANH_AM_THANH.md](docs/CHUYEN_DU_LIEU_THANH_AM_THANH.md) (Vietnamese).

## Validation

- Compressing 300 months of NASA POWER data: largest error **0.058 °C** (temperature) and **1.485 mm/month** (rain) — `pipeline/validate.py`.
- Our 2024 GISTEMP value (+1.28 °C vs 1951–1980) matches NASA's.
- Đà Lạt reads 1,492 m (real city ≈ 1,500 m).
- About **3,900 automated tests** run in CI on every push, including **3,300+ voice-command sentences**.
- We found that NASA POWER's long series for Vietnam has jumps over time (Hà Nội: −0.97 °C vs +1.02 °C in ERA5), so long-term trends use the ERA5 reanalysis and the app names that source aloud.

**Limits:** POWER cells are ~50 km; Earth Jukebox values are read from image colours and are approximate; fire-season figures are still illustrative; not yet tested with blind users.

## Run it

```bash
cd app
flutter pub get
flutter test
flutter run -d chrome      # web
flutter run                # Android phone or Windows
```

Optional API keys (Gemini, NASA, Groq…) go in `app/keys.json` (see `app/keys.example.json`); the file is git-ignored. The app works without keys; only the AI assistant and some live features need them.

Data pipeline (Python 3.11+):

```bash
pip install -r requirements.txt
python -m pytest -q
python -m pipeline.update --only temp rain
python pipeline/build_eic.py           # Earth Jukebox frames from NASA SVS videos (see data_nasa/svs/)
```

## Repository

```
app/         Flutter app (lib/, assets/, test/)
pipeline/    Python data pipeline and Earth Jukebox builder
data_nasa/   NASA crawlers, raw manifests and processed data
docs/        Data guide, sound formulas, user guides (USER_GUIDE_LANG_EN.md), slides, demo scripts
.github/     CI: tests, Android APK and iOS IPA builds
```

English documents: [User guide](docs/USER_GUIDE_LANG_EN.md) · [Pitch deck](docs/Slide_SpaceApps_Global_EN.pptx). Other documents in `docs/` are in Vietnamese.

## NASA data

NASA SVS / Earth Information Center (5475, 5313, 5011, 5436, 5196, 3912, 4950) · GISTEMP v4 · NASA POWER · SEDAC GDIS and GPWv4 rev11 · SRTMGL30 / SRTM GL1 · MODIS MCD12Q1 · FIRMS MODIS C6.1 · EONET · NASA Global Landslide Catalog · NSSDCA Planetary Fact Sheet · NASA Science / Space Place · NASA Historical Sounds · APOD. Full list with links and dates: [app/assets/data/credits.csv](app/assets/data/credits.csv) and [docs/DATA_SOURCES.md](docs/DATA_SOURCES.md).

## Other sources and credits

ERA5 (Copernicus C3S / ECMWF) via Open-Meteo · Open-Meteo forecast · © OpenStreetMap contributors (ODbL) · Natural Earth · EC JRC Global Surface Water · WWF HydroRIVERS · USGS earthquakes · GADM 4.1 · sherpa-onnx (Apache-2.0) · NVIDIA Parakeet TDT-CTC 110M (CC-BY-4.0) · Silero VAD (MIT) · Piper voice vi_VN-vais1000 / VAIS-1000 corpus (CC BY 4.0) · espeak-ng data (GPL-3.0) · SoLoud / flutter_soloud · Be Vietnam Pro and Baloo 2 fonts (SIL OFL).

## Use of AI

- **Building:** Claude (Anthropic) and Antigravity were used as coding and documentation assistants; the team reviewed and tested all output.
- **In the app:** Gemma 4 / Gemini (open questions, grounded in NASA data), optional Groq Whisper large-v3 speech recognition, and on-device sherpa-onnx, Parakeet, Silero and Piper models.
- No AI-generated images, music or data.

## Team

Vinh (team lead, developer) · Tuấn Minh (lead presenter) · Minh Sơn (NASA data) · Minh Phúc (sound design) · Xuân Phúc and Hoàng (testing and outreach)

## License

Team code: Apache-2.0. Third-party models, voices, fonts and data keep their own licences (listed above).
