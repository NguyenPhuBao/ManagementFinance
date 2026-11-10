"""Fig. 4: the NHỊP CHI (spending rhythm) card of FlowMoney's Total budget page in the trial build, for two users of the
real-app test (../app_test/uN_detail_m23.png). Only the card is kept and the two crops are stacked, so the text stays
readable at column width (2026-11-10; the earlier side-by-side full-screen version was unreadable in print).

Run:  python make_app_figure.py   ->  fig4_app.png (the screenshots are Vietnamese UI, so the _vi copy is identical)
"""
import pathlib

import pymupdf

HERE = pathlib.Path(__file__).resolve().parent
SHOTS = [HERE.parent / "app_test" / "u1_detail_m23.png", HERE.parent / "app_test" / "u4_detail_m23.png"]
X0, X1 = 40, 1040      # px kept horizontally (the card spans about 52-1027)
Y0, Y1 = 760, 1222     # px kept vertically: the NHỊP CHI card incl. the trial probability line
LABEL_W = 70           # px band left of each crop for "(a)" / "(b)"
GAP = 24               # px between the two crops

if __name__ == "__main__":
    cw, ch = X1 - X0, Y1 - Y0
    w = LABEL_W + cw
    h = len(SHOTS) * ch + GAP * (len(SHOTS) - 1)
    doc = pymupdf.open()
    page = doc.new_page(width=w, height=h)
    page.draw_rect(page.rect, color=None, fill=(1, 1, 1))
    for k, shot in enumerate(SHOTS):
        y = k * (ch + GAP)
        clip = pymupdf.Rect(LABEL_W, y, w, y + ch)
        src = pymupdf.open(str(shot))                      # an image opens as a one-page document
        sp = src[0]
        sx, sy = sp.rect.width / 1080, sp.rect.height / 2400
        crop = sp.get_pixmap(clip=pymupdf.Rect(X0 * sx, Y0 * sy, X1 * sx, Y1 * sy), matrix=pymupdf.Matrix(1 / sx, 1 / sy))
        page.insert_image(clip, pixmap=crop)
        src.close()
        page.draw_rect(clip, color=(0.6, 0.6, 0.6), width=2)
        page.insert_text((8, y + 46), "(" + "ab"[k] + ")", fontsize=40, fontname="tiro")
    pix = page.get_pixmap(matrix=pymupdf.Matrix(0.6, 0.6), clip=page.rect)
    pix.save(HERE / "fig4_app.png")
    pix.save(HERE / "fig4_app_vi.png")       # same picture: build_paper.js looks for the _vi name in Vietnamese
    print("fig4_app.png", pix.width, "x", pix.height)
