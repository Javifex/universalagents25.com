"""Check the landing page's local dependencies, navigation, and public metadata."""
import base64
import json
import hashlib
import struct
import tomllib
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
supabase_config = tomllib.loads((ROOT / "supabase/config.toml").read_text(encoding="utf-8"))
assert supabase_config["auth"]["minimum_password_length"] >= 12, "Local Auth must require at least 12 password characters"


class Page(HTMLParser):
    def __init__(self, text):
        super().__init__()
        self.ids, self.links, self.references, self.projects = [], [], [], []
        self.fields, self.labels = [], []
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
        for key in ("aria-controls", "aria-labelledby", "aria-describedby"):
            self.references.extend(attrs.get(key, "").split())
        if tag in ("input", "textarea"):
            self.fields.append(attrs.get("id"))
        if tag == "label":
            self.labels.append(attrs.get("for"))
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

for filename in ("index.html", "cuenta.html", "privacidad-cuenta.html"):
    current = Page((ROOT / filename).read_text(encoding="utf-8"))
    assert current.h1_count == 1, f"Use one main heading: {filename}"
    assert len(current.ids) == len(set(current.ids)), f"Duplicate IDs: {filename}"
    assert set(current.references) <= set(current.ids), f"Broken accessible reference: {filename}"
    assert set(current.fields) <= set(current.labels), f"Missing field label: {filename}"
    for link in current.links:
        url = urlsplit(link)
        if url.scheme and url.netloc != "universalagents25.com":
            continue
        target = ROOT / (url.path.lstrip("/") or filename)
        assert target.is_file(), f"Missing local asset or page: {link}"
        if url.fragment:
            target_page = current if target.name == filename else Page(target.read_text(encoding="utf-8"))
            assert url.fragment in target_page.ids, f"Missing anchor: {link}"

sdk = ROOT / "node_modules/@supabase/supabase-js/dist/umd/supabase.js"
assert (ROOT / "vendor/supabase-2.118.0.js").read_bytes() == sdk.read_bytes(), "Vendored SDK differs from locked package"
assert (ROOT / "vendor/supabase-LICENSE.txt").is_file(), "SDK license is required"
account_html = (ROOT / "cuenta.html").read_text(encoding="utf-8")
sdk_hash = base64.b64encode(hashlib.sha384(sdk.read_bytes()).digest()).decode()
assert f'integrity="sha384-{sdk_hash}"' in account_html, "SDK integrity attribute does not match package"

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
print("PASS: assets, anchors, accessibility references, metadata, manifest icons, and local password policy")
