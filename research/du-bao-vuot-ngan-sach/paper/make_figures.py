"""Draw the two figures of the paper draft as SVG, then rasterise them to PNG with pymupdf.

Run from anywhere:  python -I make_figures.py
Outputs fig1_pipeline.png / fig2_problem.png (English) and *_vi.png (Vietnamese) next to this script.
Fig. 2 uses a hand-made illustrative series (no real data) and says so in its caption.
"""
import math
import re
import pathlib

import pymupdf

HERE = pathlib.Path(__file__).resolve().parent
FONT = "font-family='Times New Roman, Times, serif'"

LAB = {
    "en": dict(log="FlowMoney: transactions in SQLite on the phone", daily="Daily spending series per user",
               cp=["Checkpoint t: elapsed share x, amount spent S,", "budget B, past closed periods"],
               m=[["M1 Median", "rhythm (app)"], ["M2 EWMA", "rate"], ["M3 Quantile", "regression"]],
               dist="Predictive distribution of remaining spend R",
               alert="p = P(S + R &gt; B);  warn on the Budget page when p &#8805; p*",
               budget="Budget B", check="checkpoint t",
               legend=["solid: observed spending", "dashed: median forecast", "shaded: 10-90% band"],
               xlab="Day of period", ylab="Cumulative spending (million VND)", suffix=""),
    "vi": dict(log="FlowMoney: giao dịch trong SQLite trên điện thoại", daily="Chuỗi chi tiêu theo ngày của mỗi người",
               cp=["Mốc t: phần kỳ đã trôi x, số đã chi S,", "ngân sách B, các kỳ đã đóng"],
               m=[["M1 Trung vị", "nhịp chi (app)"], ["M2 EWMA", "tốc độ chi"], ["M3 Hồi quy", "phân vị"]],
               dist="Phân phối dự báo của phần còn chi R",
               alert="p = P(S + R &gt; B);  cảnh báo ở trang Ngân sách khi p &#8805; p*",
               budget="Ngân sách B", check="mốc t",
               legend=["nét liền: đã chi thực tế", "nét đứt: dự báo trung vị", "vùng xám: dải 10-90%"],
               xlab="Ngày trong kỳ", ylab="Chi tiêu tích luỹ (triệu đồng)", suffix="_vi"),
}


def to_png(svg: str, name: str, dpi: int = 300) -> None:
    svg_path = HERE / (name + ".svg")
    svg_path.write_text(svg, encoding="utf-8")
    doc = pymupdf.open(str(svg_path))
    pix = doc[0].get_pixmap(dpi=dpi, alpha=False)
    pix.save(str(HERE / (name + ".png")))
    doc.close()


def box(x, y, w, h, lines, fill="#ffffff"):
    out = [f"<rect x='{x}' y='{y}' width='{w}' height='{h}' rx='4' fill='{fill}' stroke='#000' stroke-width='1'/>"]
    n = len(lines)
    for i, t in enumerate(lines):
        ty = y + h / 2 + (i - (n - 1) / 2) * 12 + 4
        out.append(f"<text x='{x + w / 2}' y='{ty}' {FONT} font-size='10.5' text-anchor='middle'>{t}</text>")
    return "".join(out)


def arrow(x1, y1, x2, y2):
    ang = math.atan2(y2 - y1, x2 - x1)
    a1 = (x2 - 6 * math.cos(ang - 0.4), y2 - 6 * math.sin(ang - 0.4))
    a2 = (x2 - 6 * math.cos(ang + 0.4), y2 - 6 * math.sin(ang + 0.4))
    return (f"<line x1='{x1}' y1='{y1}' x2='{x2}' y2='{y2}' stroke='#000' stroke-width='1'/>"
            f"<polygon points='{x2},{y2} {a1[0]:.1f},{a1[1]:.1f} {a2[0]:.1f},{a2[1]:.1f}' fill='#000'/>")


def dashed(points, dash=4.0, gap=3.0, width=1.0):
    """Polyline drawn as explicit dash segments (MuPDF ignores stroke-dasharray)."""
    out, on, left = [], True, dash
    for (xa, ya), (xb, yb) in zip(points, points[1:]):
        seg = math.hypot(xb - xa, yb - ya)
        pos = 0.0
        while pos < seg - 1e-9:
            step = min(left, seg - pos)
            if on:
                f0, f1 = pos / seg, (pos + step) / seg
                out.append(f"<line x1='{xa + (xb - xa) * f0:.1f}' y1='{ya + (yb - ya) * f0:.1f}' "
                           f"x2='{xa + (xb - xa) * f1:.1f}' y2='{ya + (yb - ya) * f1:.1f}' stroke='#000' stroke-width='{width}'/>")
            pos += step
            left -= step
            if left <= 1e-9:
                on = not on
                left = dash if on else gap
    return "".join(out)


def sub(text):
    """Turn X_y into X with subscript y (tspan); used inside <text>."""
    return re.sub(r"_(\w\*?)", lambda m: f"<tspan dy='3' font-size='8'>{m.group(1)}</tspan><tspan dy='-3'></tspan>", text)


F1 = {  # Fig. 1 (2026-11-10): top band = FlowMoney's business flow, bottom band = the experiment
    "en": dict(
        app="(A) FlowMoney app (graduation project)",
        cap=[["Manual", "entry"], ["Quick input", "(text, voice)"], ["Receipt", "scan"], ["Bank", "notification"]],
        db=["Entry form confirmed by the user, saved in SQLite on the phone", "(offline-first, background sync with the server)"],
        bud="Monthly budget B (set by the user)", daily="Daily spending up to day t",
        m=[["M1 median", "(released app)"], ["M2 EWMA", "(trial build)"], ["M3 quantile", "(trial build)"]],
        out=["Budget page: pace label", "(slow, on track, fast)"], prob=["Probability p = P(overrun);", "warn when p ≥ p*"],
        exp="(B) Experiment of this paper",
        src=["IBM TabFormer", "(synthetic cards)"], conv=["Conversion to VN levels", "(AI-proposed, Likert-rated)"],
        runs=[["(a) Offline run", "1,513 users"], ["(b) 5 users loaded", "via the sync API"], ["(c) Trial build", "on the phone"]],
        legend="solid: in the released app;  dashed: added for this study"),
    "vi": dict(
        app="(A) Ứng dụng FlowMoney (khoá luận tốt nghiệp)",
        cap=[["Nhập", "thủ công"], ["Nhập nhanh", "(gõ, nói)"], ["Quét", "hoá đơn"], ["Đọc biến động", "số dư"]],
        db=["Form nhập do người dùng xác nhận, lưu vào SQLite trên điện thoại", "(offline-first, đồng bộ nền với máy chủ)"],
        bud="Ngân sách tháng B (người dùng đặt)", daily="Chi tiêu theo ngày tới ngày t",
        m=[["M1 trung vị", "(app đang chạy)"], ["M2 EWMA", "(bản thử)"], ["M3 hồi quy", "phân vị (bản thử)"]],
        out=["Trang Ngân sách: nhãn nhịp chi", "(chậm, đúng nhịp, nhanh)"], prob=["Xác suất p = P(vượt);", "cảnh báo khi p ≥ p*"],
        exp="(B) Thực nghiệm của bài",
        src=["IBM TabFormer", "(thẻ mô phỏng)"], conv=["Chuyển sang mức chi VN", "(AI đề xuất, chấm Likert)"],
        runs=[["(a) Chạy offline", "1.513 người"], ["(b) Nạp 5 người", "qua API đồng bộ"], ["(c) Bản thử", "trên điện thoại"]],
        legend="nét liền: có trong app phát hành;  nét đứt: thêm cho nghiên cứu này"),
}


def dbox(x, y, w, h, lines, fs=9.5, fill="#ffffff"):
    """Box with a dashed outline (MuPDF ignores stroke-dasharray, so the outline is drawn as segments)."""
    pts = [(x, y), (x + w, y), (x + w, y + h), (x, y + h), (x, y)]
    out = [f"<rect x='{x}' y='{y}' width='{w}' height='{h}' fill='{fill}' stroke='none'/>", dashed(pts, 3.0, 2.0, 1.0)]
    n = len(lines)
    for i, t in enumerate(lines):
        ty = y + h / 2 + (i - (n - 1) / 2) * 11 + 3.5
        out.append(f"<text x='{x + w / 2}' y='{ty}' {FONT} font-size='{fs}' text-anchor='middle'>{t}</text>")
    return "".join(out)


def sbox(x, y, w, h, lines, fs=9.5, fill="#ffffff", stroke="#000"):
    out = [f"<rect x='{x}' y='{y}' width='{w}' height='{h}' rx='3' fill='{fill}' stroke='{stroke}' stroke-width='1'/>"]
    n = len(lines)
    for i, t in enumerate(lines):
        ty = y + h / 2 + (i - (n - 1) / 2) * 11 + 3.5
        out.append(f"<text x='{x + w / 2}' y='{ty}' {FONT} font-size='{fs}' text-anchor='middle'>{t}</text>")
    return "".join(out)


def fig1(lang):
    lb = F1[lang]
    W, H = 340, 406
    BLUE, GREEN = "#eaf1fb", "#eef7ee"
    s = [f"<svg xmlns='http://www.w3.org/2000/svg' width='{W}' height='{H}' viewBox='0 0 {W} {H}'>",
         f"<rect width='{W}' height='{H}' fill='#fff'/>"]
    # band A: the app
    s.append(f"<rect x='3' y='3' width='{W - 6}' height='274' rx='5' fill='{BLUE}' stroke='#4a6fa5' stroke-width='1'/>")
    s.append(f"<text x='10' y='16' {FONT} font-size='10' font-style='italic'>{lb['app']}</text>")
    cw, gap, x0 = 76, 6, 12
    for k, c in enumerate(lb["cap"]):
        x = x0 + k * (cw + gap)
        s.append(sbox(x, 24, cw, 28, c, fs=9))
        s.append(arrow(x + cw / 2, 52, x + cw / 2, 64))
    s.append(sbox(12, 64, 316, 32, lb["db"], fs=9.5))
    s.append(arrow(90, 96, 90, 110))
    s.append(arrow(250, 96, 250, 110))
    s.append(sbox(12, 110, 156, 24, [lb["daily"]], fs=9))
    s.append(sbox(174, 110, 154, 24, [lb["bud"]], fs=9))
    s.append(arrow(90, 134, 170, 150))
    s.append(arrow(250, 134, 170, 150))
    xs = [16, 125, 234]
    for k, (x, nm) in enumerate(zip(xs, lb["m"])):
        s.append(arrow(170, 150, x + 45, 166))
        if k == 0:
            s.append(sbox(x, 166, 90, 32, nm, fs=9, fill="#ffffff"))
        else:
            s.append(dbox(x, 166, 90, 32, nm, fs=9))
        if k == 0:   # the released M1 gives no probability: its arrow into the trial-build box is dashed
            s.append(dashed([(x + 45, 198), (242, 221)], 3, 2, 1.0))
            s.append(arrow(242, 221, 250, 222))
        else:
            s.append(arrow(x + 45, 198, 250, 222))
    s.append(arrow(61, 198, 70, 222))
    s.append(sbox(12, 222, 146, 32, lb["out"], fs=9))
    s.append(dbox(166, 222, 162, 32, lb["prob"], fs=9))
    s.append(f"<text x='170' y='270' {FONT} font-size='8.5' text-anchor='middle' font-style='italic'>{lb['legend']}</text>")
    # band B: the experiment
    B0 = 284
    s.append(f"<rect x='3' y='{B0}' width='{W - 6}' height='118' rx='5' fill='{GREEN}' stroke='#4f8a4f' stroke-width='1'/>")
    s.append(f"<text x='10' y='{B0 + 13}' {FONT} font-size='10' font-style='italic'>{lb['exp']}</text>")
    s.append(sbox(12, B0 + 20, 120, 30, lb["src"], fs=9))
    s.append(arrow(132, B0 + 35, 150, B0 + 35))
    s.append(dbox(150, B0 + 20, 178, 30, lb["conv"], fs=9))
    rw = 100
    for k, rn in enumerate(lb["runs"]):
        x = 12 + k * (rw + 8)
        s.append(arrow(239, B0 + 50, x + rw / 2, B0 + 72))
        s.append(dbox(x, B0 + 72, rw, 32, rn, fs=9))
    # (b) feeds the app's database through the sync API
    s.append(dashed([(205, B0 + 72), (205, B0 + 62), (334, B0 + 62), (334, 80), (328, 80)], 3, 2, 0.9))
    s.append("<polygon points='328,80 334,77 334,83' fill='#000'/>")
    s.append("</svg>")
    to_png("".join(s), "fig1_pipeline" + ("_vi" if lang == "vi" else ""))


def fig1_old(lang):
    lb = LAB[lang]
    W, H = 340, 300
    s = [f"<svg xmlns='http://www.w3.org/2000/svg' width='{W}' height='{H}' viewBox='0 0 {W} {H}'>",
         "<defs><marker id='a' markerWidth='8' markerHeight='8' refX='7' refY='3' orient='auto'>"
         "<path d='M0,0 L7,3 L0,6 z' fill='#000'/></marker></defs>",
         f"<rect width='{W}' height='{H}' fill='#fff'/>"]
    s.append(box(15, 6, 310, 30, [lb["log"]]))
    s.append(arrow(170, 36, 170, 50))
    s.append(box(60, 50, 220, 30, [lb["daily"]]))
    s.append(arrow(170, 80, 170, 94))
    s.append(box(40, 94, 260, 40, lb["cp"]))
    xs = [14, 125, 236]          # three forecasters (M0 dropped 2026-11-10)
    names = lb["m"]
    for x, nm in zip(xs, names):
        s.append(arrow(170, 134, x + 45, 154))
        s.append(box(x, 154, 90, 36, nm, fill="#f2f2f2"))
        s.append(arrow(x + 45, 190, 170, 212))
    s.append(box(40, 212, 260, 30, [lb["dist"]]))
    s.append(arrow(170, 242, 170, 256))
    s.append(box(10, 256, 320, 36, [lb["alert"]]))
    s.append("</svg>")
    to_png("".join(s), "fig1_pipeline" + lb["suffix"])


def fig2(lang):
    lb = LAB[lang]
    # Illustrative month of 30 days: rent on day 1, regular daily spending, payday spike on day 10.
    W, H = 340, 210
    L, R, T, Bm = 46, 12, 12, 34
    pw, ph = W - L - R, H - T - Bm
    days = list(range(0, 31))
    daily = [0] * 31
    daily[1] = 3.5
    for d in range(1, 31):
        daily[d] += 0.18 + 0.06 * math.sin(d * 1.7)
    daily[10] += 1.2
    cum = [0.0]
    for d in range(1, 31):
        cum.append(cum[-1] + daily[d])
    t = 12
    budget = 10.0
    ymax = 12.0

    def X(d):
        return L + pw * d / 30

    def Y(v):
        return T + ph * (1 - v / ymax)

    s = [f"<svg xmlns='http://www.w3.org/2000/svg' width='{W}' height='{H}' viewBox='0 0 {W} {H}'>",
         f"<rect width='{W}' height='{H}' fill='#fff'/>"]
    # forecast band (10th-90th percentile) widening to the end of period
    up, lo = [], []
    for d in range(t, 31):
        med = cum[t] + (cum[30] - cum[t]) * (d - t) / (30 - t)
        w = 0.55 * math.sqrt((d - t) / (30 - t)) * 2.4
        up.append((X(d), Y(med + w)))
        lo.append((X(d), Y(med - w)))
    pts = " ".join(f"{a:.1f},{b:.1f}" for a, b in up + lo[::-1])
    s.append(f"<polygon points='{pts}' fill='#d9d9d9' stroke='none'/>")
    med_pts = " ".join(f"{X(d):.1f},{Y(cum[t] + (cum[30] - cum[t]) * (d - t) / (30 - t)):.1f}" for d in range(t, 31))
    s.append(dashed([(X(d), Y(cum[t] + (cum[30] - cum[t]) * (d - t) / (30 - t))) for d in range(t, 31)], width=1.2))
    obs = " ".join(f"{X(d):.1f},{Y(cum[d]):.1f}" for d in range(0, t + 1))
    s.append(f"<polyline points='{obs}' fill='none' stroke='#000' stroke-width='1.8'/>")
    # budget line
    s.append(f"<line x1='{X(0)}' y1='{Y(budget)}' x2='{X(30)}' y2='{Y(budget)}' stroke='#000' stroke-width='1'/>")
    s.append(f"<text x='{X(1)}' y='{Y(budget) - 4}' {FONT} font-size='10'>{lb['budget']}</text>")
    # checkpoint line
    s.append(dashed([(X(t), Y(0)), (X(t), Y(ymax))], dash=2, gap=2, width=0.8))
    s.append(f"<text x='{X(t) + 3}' y='{Y(ymax) + 10}' {FONT} font-size='10'>{lb['check']}</text>")
    for i, t_ in enumerate(lb["legend"]):
        s.append(f"<text x='{X(14)}' y='{Y(3.0 - i * 0.9)}' {FONT} font-size='10'>{t_}</text>")
    # axes
    s.append(f"<line x1='{L}' y1='{Y(0)}' x2='{L + pw}' y2='{Y(0)}' stroke='#000'/>")
    s.append(f"<line x1='{L}' y1='{Y(0)}' x2='{L}' y2='{Y(ymax)}' stroke='#000'/>")
    for d in (0, 5, 10, 15, 20, 25, 30):
        s.append(f"<line x1='{X(d)}' y1='{Y(0)}' x2='{X(d)}' y2='{Y(0) + 3}' stroke='#000'/>")
        s.append(f"<text x='{X(d)}' y='{Y(0) + 14}' {FONT} font-size='9.5' text-anchor='middle'>{d}</text>")
    for v in (0, 4, 8, 12):
        s.append(f"<line x1='{L - 3}' y1='{Y(v)}' x2='{L}' y2='{Y(v)}' stroke='#000'/>")
        s.append(f"<text x='{L - 5}' y='{Y(v) + 3}' {FONT} font-size='9.5' text-anchor='end'>{v}</text>")
    s.append(f"<text x='{L + pw / 2}' y='{H - 4}' {FONT} font-size='10' text-anchor='middle'>{lb['xlab']}</text>")
    s.append(f"<text x='12' y='{T + ph / 2}' {FONT} font-size='10' text-anchor='middle' "
             f"transform='rotate(-90 12 {T + ph / 2})'>{lb['ylab']}</text>")
    s.append("</svg>")
    to_png("".join(s), "fig2_problem" + lb["suffix"])


if __name__ == "__main__":
    for lang in ("en", "vi"):
        fig1(lang)
        fig2(lang)
    print("ok")
