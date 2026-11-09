"""Draw Fig. 3 (reliability diagrams, day 15) and Fig. 4 (warning trade-off) from results/synthetic.json.

Run:  python plots.py   ->  ../paper/fig3_reliability[_vi].png, ../paper/fig4_warning[_vi].png
SVG is rasterised with pymupdf (no matplotlib on this machine). MuPDF ignores stroke-dasharray, so dashes
are drawn as segments.
"""
import json
import math
import pathlib

import pymupdf

HERE = pathlib.Path(__file__).resolve().parent
PAPER = HERE.parent / "paper"
FONT = "font-family='Times New Roman, Times, serif'"
METHODS = ["p0", "p1", "p2", "p3"]
STYLE = {  # stroke colour, width, dash (None = solid), marker
    "p0": ("#7f7f7f", 1.0, (4, 3), "tri"),
    "p1": ("#000000", 1.2, None, "circle"),
    "p2": ("#7f7f7f", 1.0, (1.5, 2), "diamond"),
    "p3": ("#000000", 1.8, None, "square"),
}
LAB = {
    "en": dict(names={"p0": "M0 Pro-rata", "p1": "M1 Median rhythm", "p2": "M2 EWMA", "p3": "M3 Quantile regr."},
               fx="Forecast probability", fy="Observed frequency",
               far="False-alarm rate", recall="Recall", lead="Median lead time (days)", sfx=""),
    "vi": dict(names={"p0": "M0 Chia đều", "p1": "M1 Trung vị nhịp chi", "p2": "M2 EWMA", "p3": "M3 Hồi quy phân vị"},
               fx="Xác suất dự báo", fy="Tần suất quan sát",
               far="Tỉ lệ báo nhầm", recall="Tỉ lệ phát hiện", lead="Trung vị số ngày báo trước", sfx="_vi"),
}


def seg_line(pts, color, width, dash):
    if dash is None:
        p = " ".join(f"{x:.1f},{y:.1f}" for x, y in pts)
        return f"<polyline points='{p}' fill='none' stroke='{color}' stroke-width='{width}'/>"
    out, on, left = [], True, dash[0]
    for (xa, ya), (xb, yb) in zip(pts, pts[1:]):
        seg = math.hypot(xb - xa, yb - ya)
        pos = 0.0
        while pos < seg - 1e-9:
            step = min(left, seg - pos)
            if on:
                f0, f1 = pos / seg, (pos + step) / seg
                out.append(f"<line x1='{xa + (xb - xa) * f0:.1f}' y1='{ya + (yb - ya) * f0:.1f}' x2='{xa + (xb - xa) * f1:.1f}' "
                           f"y2='{ya + (yb - ya) * f1:.1f}' stroke='{color}' stroke-width='{width}'/>")
            pos += step
            left -= step
            if left <= 1e-9:
                on = not on
                left = dash[0] if on else dash[1]
    return "".join(out)


def marker(kind, x, y, color, r=2.4):
    if kind == "circle":
        return f"<circle cx='{x:.1f}' cy='{y:.1f}' r='{r}' fill='{color}'/>"
    if kind == "square":
        return f"<rect x='{x - r:.1f}' y='{y - r:.1f}' width='{2 * r}' height='{2 * r}' fill='{color}'/>"
    if kind == "tri":
        return f"<polygon points='{x:.1f},{y - r - 0.6:.1f} {x - r:.1f},{y + r:.1f} {x + r:.1f},{y + r:.1f}' fill='{color}'/>"
    return f"<polygon points='{x:.1f},{y - r - 0.5:.1f} {x + r:.1f},{y:.1f} {x:.1f},{y + r + 0.5:.1f} {x - r:.1f},{y:.1f}' fill='{color}'/>"


def axes(x0, y0, w, h, xlim, ylim, xticks, yticks, xlabel, ylabel, fmt=lambda v: f"{v:g}"):
    X = lambda v: x0 + w * (v - xlim[0]) / (xlim[1] - xlim[0])
    Y = lambda v: y0 + h * (1 - (v - ylim[0]) / (ylim[1] - ylim[0]))
    s = [f"<rect x='{x0}' y='{y0}' width='{w}' height='{h}' fill='none' stroke='#000' stroke-width='0.8'/>"]
    for v in xticks:
        s.append(f"<line x1='{X(v):.1f}' y1='{y0 + h}' x2='{X(v):.1f}' y2='{y0 + h + 3}' stroke='#000' stroke-width='0.8'/>")
        s.append(f"<text x='{X(v):.1f}' y='{y0 + h + 12}' {FONT} font-size='8.5' text-anchor='middle'>{fmt(v)}</text>")
    for v in yticks:
        s.append(f"<line x1='{x0 - 3}' y1='{Y(v):.1f}' x2='{x0}' y2='{Y(v):.1f}' stroke='#000' stroke-width='0.8'/>")
        s.append(f"<text x='{x0 - 5}' y='{Y(v) + 3:.1f}' {FONT} font-size='8.5' text-anchor='end'>{fmt(v)}</text>")
    if xlabel:
        s.append(f"<text x='{x0 + w / 2}' y='{y0 + h + 24}' {FONT} font-size='9' text-anchor='middle'>{xlabel}</text>")
    if ylabel:
        cy = y0 + h / 2
        s.append(f"<text x='{x0 - 26}' y='{cy}' {FONT} font-size='9' text-anchor='middle' transform='rotate(-90 {x0 - 26} {cy})'>{ylabel}</text>")
    return "".join(s), X, Y


def save(svg, name):
    path = PAPER / (name + ".svg")
    path.write_text(svg, encoding="utf-8")
    doc = pymupdf.open(str(path))
    doc[0].get_pixmap(dpi=300, alpha=False).save(str(PAPER / (name + ".png")))
    doc.close()


def fig3(res, lang, name="fig3_reliability"):
    lb = LAB[lang]
    rel = res["kappa"]["1.0"]["reliability_day15"]
    W, H = 340, 330
    s = [f"<svg xmlns='http://www.w3.org/2000/svg' width='{W}' height='{H}' viewBox='0 0 {W} {H}'>", f"<rect width='{W}' height='{H}' fill='#fff'/>"]
    pw, ph = 120, 112
    for idx, m in enumerate(METHODS):
        col, row = idx % 2, idx // 2
        x0, y0 = 44 + col * 158, 18 + row * 152
        a, X, Y = axes(x0, y0, pw, ph, (0, 1), (0, 1), [0, 0.5, 1], [0, 0.5, 1],
                       lb["fx"] if row == 1 else "", lb["fy"] if col == 0 else "")
        s.append(a)
        s.append(seg_line([(X(0), Y(0)), (X(1), Y(1))], "#999999", 0.8, (3, 2)))
        pts = [(X(p), Y(o)) for p, o in rel[m]]
        color, width, dash, mk = STYLE[m]
        s.append(seg_line(pts, "#000000", 1.1, None))
        s.extend(marker("circle", x, y, "#000000", 2.0) for x, y in pts)
        s.append(f"<text x='{x0 + 4}' y='{y0 + 11}' {FONT} font-size='9'>{lb['names'][m]}</text>")
        ece = res["kappa"]["1.0"]["overall"][m]["ece"]
        s.append(f"<text x='{x0 + pw - 4}' y='{y0 + ph - 5}' {FONT} font-size='8.5' text-anchor='end'>ECE {ece:.3f}</text>")
    s.append("</svg>")
    save("".join(s), name + lb["sfx"])


def fig4(res, lang, name="fig4_warning"):
    lb = LAB[lang]
    warn = res["kappa"]["1.0"]["warning"]
    W, H = 340, 330
    s = [f"<svg xmlns='http://www.w3.org/2000/svg' width='{W}' height='{H}' viewBox='0 0 {W} {H}'>", f"<rect width='{W}' height='{H}' fill='#fff'/>"]
    xlim = (0, 0.5)
    maxlead = max(c["lead_median"] for m in METHODS for c in warn[m] if c["far"] <= 0.5)
    lead_top = max(5, math.ceil(maxlead / 5) * 5)
    panels = [("recall", (0, 1), [0, 0.25, 0.5, 0.75, 1], lb["recall"], 16),
              ("lead_median", (0, lead_top), list(range(0, lead_top + 1, 5)), lb["lead"], 150)]
    for key, ylim, yticks, ylabel, y0 in panels:
        a, X, Y = axes(52, y0, 270, 104, xlim, ylim, [0, 0.1, 0.2, 0.3, 0.4, 0.5], yticks,
                       lb["far"] if key == "lead_median" else "", ylabel)
        s.append(a)
        tag = "(a)" if key == "recall" else "(b)"
        s.append(f"<text x='58' y='{y0 + 11}' {FONT} font-size='9'>{tag}</text>")
        for m in METHODS:
            color, width, dash, mk = STYLE[m]
            pts = sorted({(c["far"], c[key]) for c in warn[m] if c["far"] <= xlim[1]})
            xy = [(X(f), Y(v)) for f, v in pts]
            if len(xy) > 1:
                s.append(seg_line(xy, color, width, dash))
            s.extend(marker(mk, x, y, color, 1.8) for x, y in xy[::3])
    # legend under the panels
    for idx, m in enumerate(METHODS):
        color, width, dash, mk = STYLE[m]
        lx, ly = 56 + (idx % 2) * 135, 292 + (idx // 2) * 14
        s.append(seg_line([(lx, ly), (lx + 22, ly)], color, width, dash))
        s.append(marker(mk, lx + 11, ly, color, 1.8))
        s.append(f"<text x='{lx + 27}' y='{ly + 3}' {FONT} font-size='9'>{lb['names'][m]}</text>")
    s.append("</svg>")
    save("".join(s), name + lb["sfx"])


if __name__ == "__main__":
    import sys
    source = sys.argv[1] if len(sys.argv) > 1 else "synthetic"   # results/<source>.json
    res = json.loads((HERE / "results" / (source + ".json")).read_text(encoding="utf-8"))
    a, b = (sys.argv[2].split(",") if len(sys.argv) > 2 else ("3", "4"))
    for lang in ("en", "vi"):
        fig3(res, lang, f"fig{a}_reliability")
        fig4(res, lang, f"fig{b}_warning")
    print("ok from", source)
