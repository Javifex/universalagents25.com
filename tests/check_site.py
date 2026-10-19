"""Check the landing page's local dependencies, navigation, and public metadata."""
import json
import struct
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]


class Page(HTMLParser):
    def __init__(self, text):
        super().__init__()
        self.ids, self.links, self.references, self.projects = [], [], [], []
        self.h1_count = 0
        self.structured_data = None
        self.in_json = False
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if "id" in attrs:
            self.ids.append(attrs["id"])
        self.h1_count += tag == "h1"
        for key in ("href", "src"):
            if key in attrs:
                self.links.append(attrs[key])
        for key in ("aria-controls", "aria-labelledby"):
            self.references.extend(attrs.get(key, "").split())
        if "data-project" in attrs:
            self.projects.append(attrs["data-project"])
        if tag == "meta" and attrs.get("property") == "og:image":
            self.links.append(attrs["content"])
        if tag == "script" and attrs.get("type") == "application/ld+json":
            self.in_json = True

    def handle_data(self, data):
        if self.in_json and data.strip():
            self.structured_data = json.loads(data)

    def handle_endtag(self, tag):
        if tag == "script":
            self.in_json = False


page = Page((ROOT / "index.html").read_text(encoding="utf-8"))
assert page.h1_count == 1, "Use one main heading"
assert len(page.ids) == len(set(page.ids)), "Duplicate HTML IDs"
assert set(page.references) <= set(page.ids), "Broken accessible label/control"
assert set(page.projects) == {"contenido", "informes", "propuestas"}
assert page.structured_data["@type"] == "WebSite"
assert page.structured_data["name"] == "Universal Agents 25", "Use the complete brand name"

for link in page.links:
    url = urlsplit(link)
    if url.scheme and url.netloc != "universalagents25.com":
        continue
    target = ROOT / (url.path.lstrip("/") or "index.html")
    assert target.is_file(), f"Missing local asset or page: {link}"
    if url.fragment:
        target_page = page if target.name == "index.html" else Page(target.read_text(encoding="utf-8"))
        assert url.fragment in target_page.ids, f"Missing anchor: {link}"

policy = Page((ROOT / "politica.html").read_text(encoding="utf-8"))
for link in policy.links:
    url = urlsplit(link)
    if url.path == "index.html" and url.fragment:
        assert url.fragment in page.ids, f"Broken policy return link: {link}"

manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8-sig"))
assert manifest["name"] == "Universal Agents 25", "Use the complete installed app name"
for icon in manifest["icons"]:
    data = (ROOT / urlsplit(icon["src"]).path.lstrip("/")).read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "Invalid PNG header"
    width, height = struct.unpack(">II", data[16:24])
    assert icon["sizes"] == f"{width}x{height}", "Incorrect icon dimensions"

assert (ROOT / "CNAME").read_text().strip() == "universalagents25.com"
print("PASS: assets, anchors, accessibility references, metadata, and manifest icons")
