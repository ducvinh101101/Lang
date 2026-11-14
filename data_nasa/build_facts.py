# build_facts.py — tách assets/content/fact.md (NASA Space Place) thành từng câu sự thật cho F2.
# Dùng cho khẩu lệnh "sự thật thú vị về <hành tinh>": app chọn ngẫu nhiên 1 phần tử trong facts[<id>].
#
# Chạy:  python build_facts.py           -> ghi assets/content/facts.json
# Quy tắc:
#   - Mỗi gạch đầu dòng dưới tiêu đề ### là một sự thật (câu ngắn, đọc được ngay).
#   - Đoạn văn dài được giữ lại làm sự thật loại "paragraph", sau khi bỏ chú thích ảnh ("Nguồn ảnh: …")
#     và câu hướng dẫn thao tác trên web ("Nhấp và kéo…").
#   - fact.md cào mỗi trang 2 lần (có và không có /en/): gộp theo nội dung, giữ cả hai link nguồn.
import hashlib, json, re, sys, unicodedata
from datetime import date
from pathlib import Path

SRC = Path("assets/content/fact.md")
OUT = Path("assets/content/facts.json")

PLANETS = {  # tên trong tiêu đề -> id (khớp planets_extended.json)
    "Sao Thủy": "mercury", "Sao Kim": "venus", "Trái Đất": "earth", "Sao Hỏa": "mars",
    "Sao Mộc": "jupiter", "Sao Thổ": "saturn", "Sao Thiên Vương": "uranus",
    "Sao Hải Vương": "neptune", "Sao Diêm Vương": "pluto", "Mặt Trời": "sun",
    "Mặt Trăng": "moon", "Các hành tinh": "solar_system",
}
# Câu không phải sự thật: chú thích ảnh, hướng dẫn thao tác web, liên kết điều hướng.
SKIP = re.compile(r"^(Nguồn ảnh|Hình ảnh này|Khám phá .*Nhấp và kéo|Nhấp vào|Bạn có muốn biết thêm|"
                  r"Tổng quan về|Xem thêm|Tìm hiểu thêm)", re.I)
CAPTION = re.compile(r"\s*Nguồn ảnh:.*$")
NAV = re.compile(r"(Nhấp và kéo|Cuộn hoặc chụm|Nhấp vào một hành tinh)", re.I)
IMAGE_TOPICS = re.compile(r"trông như thế nào\?$", re.I)   # mục toàn chú thích ảnh
# Câu chỉ có nghĩa khi nhìn ảnh (app phục vụ người khiếm thị) hoặc là phương án trả lời câu đố.
VISUAL = re.compile(r"(trong hình|hình trên|hình này|ảnh này|bức ảnh|hình minh họa|hình ảnh|"
                    r"tất cả những điều trên|chọn câu trả lời)", re.I)


def norm(t):
    t = unicodedata.normalize("NFC", t).casefold()
    return re.sub(r"\W+", " ", t).strip()


def clean(t):
    t = re.sub(r"\*\*|__|`", "", t)
    t = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", t)
    t = CAPTION.sub("", t).strip()
    return re.sub(r"\s+", " ", t)


def sections(md):
    parts = re.split(r"^## \d+\. Tìm hiểu về (.+)$", md, flags=re.M)
    for i in range(1, len(parts), 2):
        yield parts[i].strip(), parts[i + 1]


def facts_of(body):
    url = re.search(r"Nguồn trích dẫn:\*\*\s*\[([^\]]+)\]", body)
    url = url[1] if url else None
    topic, out = None, []
    for block in re.split(r"\n\s*\n", body):
        for line in block.strip().splitlines():
            line = line.strip()
            if not line or line.startswith(("- **", "---")):
                continue
            if line.startswith("#"):
                topic = line.lstrip("#").strip().rstrip(":")
                continue
            if topic and IMAGE_TOPICS.search(topic):
                continue
            bullet = line.startswith("- ")
            text = clean(line[2:] if bullet else line)
            if not text or SKIP.match(text) or NAV.search(text) or VISUAL.search(text) or text.endswith("?"):
                continue
            words = len(text.split())
            if words < 5 or (not bullet and words > 90):     # quá ngắn (tên mục) hoặc quá dài để đọc
                continue
            if not text.endswith((".", "!", "?", ")", "”", '"')):
                continue
            out.append({"text": text, "kind": "bullet" if bullet else "paragraph",
                        "topic_vi": topic, "source_url": url})
    return url, out


def main():
    md = SRC.read_text(encoding="utf-8-sig")
    updated = re.search(r"Ngày cập nhật:\*\*\s*([\d-]+)", md)
    planets = {}
    seen = {}
    for title, body in sections(md):
        pid = PLANETS.get(title)
        if pid is None:
            sys.exit(f"Chưa biết id cho mục '{title}' — thêm vào PLANETS")
        url, items = facts_of(body)
        p = planets.setdefault(pid, {"name_vi": title, "source_urls": [], "facts": []})
        if url and url not in p["source_urls"]:
            p["source_urls"].append(url)
        for f in items:
            key = (pid, norm(f["text"]))
            if key in seen:                       # trang cào lại lần 2: chỉ thêm link
                if f["source_url"] not in seen[key]["source_urls"]:
                    seen[key]["source_urls"].append(f["source_url"])
                continue
            fact = {"id": f"{pid}-{hashlib.sha1(key[1].encode()).hexdigest()[:8]}",
                    "text": f["text"], "kind": f["kind"], "topic_vi": f["topic_vi"],
                    "source_urls": [f["source_url"]]}
            seen[key] = fact
            p["facts"].append(fact)
    for p in planets.values():                    # gạch đầu dòng (ngắn, rõ) lên trước
        p["facts"].sort(key=lambda f: f["kind"] != "bullet")
    doc = {
        "schema_version": 1,
        "data_card": {
            "dataset": "Sự thật về các thiên thể từ NASA Space Place (bản dịch tiếng Việt)",
            "provider": "NASA Space Place, NASA/Caltech-JPL", "url": "https://spaceplace.nasa.gov/",
            "accessed": updated[1] if updated else date.today().isoformat(),
            "processing": "Tách từ fact.md bằng build_facts.py: mỗi gạch đầu dòng hoặc đoạn văn là một sự thật; "
                          "bỏ chú thích ảnh, câu điều hướng web; gộp nội dung trùng giữa hai lần cào.",
            "limitation_vi": "Bản dịch máy từ tiếng Anh; một số đơn vị vẫn là độ F như bản gốc.",
            "citation": "NASA Space Place. https://spaceplace.nasa.gov/",
            "usage_vi": "Khẩu lệnh 'sự thật thú vị về <hành tinh>': chọn ngẫu nhiên một phần tử facts; "
                        "ưu tiên kind = bullet vì ngắn, hợp để đọc.",
        },
        "aliases_vi": {pid: [p["name_vi"]] for pid, p in planets.items()},
        "planets": planets,
    }
    OUT.write_text(json.dumps(doc, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    for pid, p in planets.items():
        b = sum(f["kind"] == "bullet" for f in p["facts"])
        print(f"{pid:13s} {len(p['facts']):3d} sự thật ({b} gạch đầu dòng), nguồn: {len(p['source_urls'])} link")
    print("->", OUT)


if __name__ == "__main__":
    main()
