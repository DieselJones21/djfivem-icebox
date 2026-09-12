#!/usr/bin/env python3
"""Cut chain screenshots into small transparent inventory icons."""
from __future__ import annotations

from io import BytesIO
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ASSETS = Path("/home/ubuntu/.cursor/projects/workspace/assets")
OUTS = [ROOT / "install" / "images", ROOT / "html" / "assets" / "items"]
SIZE = 128

CHAINS = [
    ("icebox_trapper", "494fbbec-371e-4986-a849-2253303def50.png"),
    ("icebox_block_baby", "2d48067d-51d7-4229-9374-ab9aa5d92f9b.png"),
    ("icebox_smokey", "985f392a-d0d3-4d2d-8c0e-e3b089a1da56.png"),
    ("icebox_smokey_2", "f35d97a2-7464-4e54-9391-22b41d91508e.png"),
    ("icebox_self_made", "13c03d2b-750b-4441-a9fb-72377391c838.png"),
    ("icebox_dumb_rich", "dbcf8385-7afc-4266-886b-2aaa53002dba.png"),
    ("icebox_face_shot", "99fb5719-f3b1-4191-97f9-8c0be19c463a.png"),
    ("icebox_slime", "b77b04ea-dddc-4613-87b7-33f047e6fa57.png"),
    ("icebox_est", "9773f08c-502a-43c2-9ef0-0b019087f3db.png"),
    ("icebox_sharky", "2ed9e52b-292f-4617-96d6-b5bc098587b7.png"),
    ("icebox_capalot", "d3a392f5-c5ca-4a33-ae5f-68830e62d7ba.png"),
]

# One method per piece — already tuned against these screenshots.
METHOD = {
    "icebox_trapper": "rembg",
    "icebox_block_baby": "rembg",
    "icebox_smokey": "sam_box",
    "icebox_smokey_2": "sam_box",
    "icebox_self_made": "rembg_crop",
    "icebox_dumb_rich": "sam_pts",
    "icebox_face_shot": "sam_box",
    "icebox_slime": "sam_box",
    "icebox_est": "sam_pts",
    "icebox_sharky": "sam_pts",
    "icebox_capalot": "sam_pts",
}

BOX = {
    "icebox_smokey": (0.10, 0.05, 0.90, 0.95),
    "icebox_smokey_2": (0.08, 0.05, 0.92, 0.95),
    "icebox_self_made": (0.22, 0.05, 0.78, 0.98),
    "icebox_dumb_rich": (0.05, 0.10, 0.62, 0.88),
    "icebox_face_shot": (0.12, 0.02, 0.88, 0.95),
    "icebox_slime": (0.16, 0.02, 0.84, 0.92),
    "icebox_est": (0.06, 0.16, 0.94, 0.98),
    "icebox_sharky": (0.28, 0.06, 0.72, 0.92),
    "icebox_capalot": (0.18, 0.05, 0.84, 0.97),
}

POINTS = {
    "icebox_dumb_rich": {
        "pos": [(0.32, 0.45), (0.48, 0.55), (0.38, 0.28)],
        "neg": [(0.80, 0.70), (0.70, 0.15)],
    },
    "icebox_est": {
        "pos": [(0.50, 0.70), (0.50, 0.55), (0.50, 0.32), (0.38, 0.26), (0.62, 0.26)],
        "neg": [(0.50, 0.07), (0.16, 0.38), (0.84, 0.38), (0.10, 0.72), (0.90, 0.72)],
    },
    "icebox_sharky": {
        "pos": [(0.50, 0.28), (0.50, 0.50), (0.50, 0.78), (0.50, 0.18)],
        "neg": [(0.08, 0.40), (0.92, 0.40), (0.50, 0.02)],
    },
    "icebox_capalot": {
        "pos": [(0.50, 0.28), (0.50, 0.48), (0.50, 0.68), (0.62, 0.55), (0.38, 0.40)],
        "neg": [(0.08, 0.40), (0.92, 0.40), (0.50, 0.04), (0.24, 0.48), (0.82, 0.28)],
    },
}


def find_src(filename: str) -> Path:
    for folder in (ASSETS, ROOT / "install" / "chain-photos"):
        path = folder / filename
        if path.exists():
            return path
    raise FileNotFoundError(filename)


def apply_alpha(im: Image.Image, alpha: np.ndarray) -> Image.Image:
    rgba = np.array(im.convert("RGBA"))
    rgba[:, :, 3] = alpha
    return Image.fromarray(rgba)


def mask_to_alpha(mask: np.ndarray, size: tuple[int, int]) -> np.ndarray:
    m = Image.fromarray((np.clip(mask, 0, 1) * 255).astype(np.uint8))
    if m.size != size:
        m = m.resize(size, Image.Resampling.BILINEAR)
    return np.array(m)


def rembg_cut(im: Image.Image, session) -> Image.Image:
    from rembg import remove

    buf = BytesIO()
    im.save(buf, "PNG")
    return Image.open(BytesIO(remove(buf.getvalue(), session=session))).convert("RGBA")


def rembg_crop(im: Image.Image, session, side=0.10, top=0.10) -> Image.Image:
    w, h = im.size
    box = (int(w * side), int(h * top), int(w * (1 - side)), int(h * 0.98))
    cropped = im.crop(box)
    cut = rembg_cut(cropped, session)
    canvas = Image.new("RGBA", im.size, (0, 0, 0, 0))
    canvas.paste(cut, (box[0], box[1]), cut)
    return canvas


def sam_box(im: Image.Image, model, box: tuple[float, float, float, float]) -> Image.Image | None:
    w, h = im.size
    l, t, r, b = box
    bbox = [int(l * w), int(t * h), int(r * w), int(b * h)]
    results = model.predict(source=np.array(im.convert("RGB")), bboxes=[bbox], verbose=False)
    if results[0].masks is None or results[0].masks.data.shape[0] == 0:
        return None
    alpha = mask_to_alpha(results[0].masks.data[0].cpu().numpy(), (w, h))
    return apply_alpha(im, alpha)


def sam_pts(im: Image.Image, model, pos, neg) -> Image.Image | None:
    w, h = im.size
    pts = [[int(x * w), int(y * h)] for x, y in pos + neg]
    labels = [1] * len(pos) + [0] * len(neg)
    results = model.predict(
        source=np.array(im.convert("RGB")),
        points=[pts],
        labels=[labels],
        verbose=False,
    )
    if results[0].masks is None or results[0].masks.data.shape[0] == 0:
        return None
    alpha = mask_to_alpha(results[0].masks.data[0].cpu().numpy(), (w, h))
    return apply_alpha(im, alpha)


def strip_skin(cut: Image.Image) -> Image.Image:
    arr = np.array(cut.convert("RGBA"))
    r, g, b, a = [arr[:, :, i].astype(np.float32) for i in range(4)]
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    sat = np.where(mx < 1, 0, (mx - mn) / np.maximum(mx, 1) * 255)
    skin = (r > 95) & (g > 50) & (b > 30) & (r > g + 10) & (r > b + 22) & (sat < 125) & (mx > 70)
    arr[:, :, 3] = np.where(skin, np.minimum(a, 12), a).astype(np.uint8)
    return Image.fromarray(arr)


def trim(im: Image.Image, pad: int = 5) -> Image.Image:
    a = np.array(im.split()[-1])
    ys, xs = np.where(a > 16)
    if len(xs) == 0:
        return im
    x0, x1 = max(0, int(xs.min()) - pad), min(im.width - 1, int(xs.max()) + pad)
    y0, y1 = max(0, int(ys.min()) - pad), min(im.height - 1, int(ys.max()) + pad)
    return im.crop((x0, y0, x1 + 1, y1 + 1))


def square_fit(im: Image.Image, size: int = SIZE) -> Image.Image:
    w, h = im.size
    side = max(w, h)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(im, ((side - w) // 2, (side - h) // 2), im)
    return canvas.resize((size, size), Image.Resampling.LANCZOS)


def save_icon(im: Image.Image) -> bytes:
    alpha = im.split()[-1].filter(ImageFilter.GaussianBlur(0.35))
    im.putalpha(alpha)
    buf = BytesIO()
    im.save(buf, format="PNG", optimize=True, compress_level=9)
    return buf.getvalue()


def process_one(name: str, src: Path, rembg_session, sam_model) -> bytes:
    orig = Image.open(src).convert("RGBA")
    methods = [METHOD[name]]
    if name in POINTS:
        methods.append("sam_pts")
    if name in BOX:
        methods.append("sam_box")
    methods.extend(["rembg_crop", "rembg"])
    seen: set[str] = set()
    cut = None
    used = None
    for method in methods:
        if method in seen:
            continue
        seen.add(method)
        if method == "rembg":
            cut = rembg_cut(orig, rembg_session)
        elif method == "rembg_crop":
            cut = rembg_crop(orig, rembg_session)
        elif method == "sam_box":
            cut = sam_box(orig, sam_model, BOX[name])
        elif method == "sam_pts":
            spec = POINTS[name]
            cut = sam_pts(orig, sam_model, spec["pos"], spec["neg"])
        if cut is not None:
            used = method
            break
    if cut is None:
        raise RuntimeError(f"no mask for {name}")
    print(f"  method={used}")
    cut = strip_skin(cut)
    icon = square_fit(trim(cut))
    return save_icon(icon)


def main() -> None:
    from rembg import new_session
    from ultralytics import SAM

    rembg_session = new_session()
    sam_model = SAM("sam2_t.pt")
    for out in OUTS:
        out.mkdir(parents=True, exist_ok=True)
    for name, filename in CHAINS:
        data = process_one(name, find_src(filename), rembg_session, sam_model)
        for out in OUTS:
            (out / f"{name}.png").write_bytes(data)
        print(f"{name:20} {len(data):5} bytes")


if __name__ == "__main__":
    main()
