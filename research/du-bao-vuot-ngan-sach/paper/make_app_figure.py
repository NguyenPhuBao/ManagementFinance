"""Fig. 4: two screenshots of FlowMoney's budget-detail page from the real-app test (../app_test/uN_detail_m23.png, trial build with M1/M2/M3),
cropped to the top (remaining budget + NHỊP CHI block) and placed side by side with pymupdf (no PIL here).

Run:  python make_app_figure.py   ->  fig4_app.png (the screenshots are Vietnamese UI, so the _vi copy is identical)
"""
import pathlib

import pymupdf

HERE = pathlib.Path(__file__).resolve().parent
SHOTS = [HERE.parent / "app_test" / "u1_detail_m23.png", HERE.parent / "app_test" / "u4_detail_m23.png"]
CROP_H = 1230          # px kept from the top (header, remaining budget, NHỊP CHI incl. the trial probability line)
GAP = 40               # px between the two shots
LABEL_H = 70           # px band above each shot for "(a)" / "(b)"

if __name__ == "__main__":
    w = 1080 * len(SHOTS) + GAP * (len(SHOTS) - 1)
    h = LABEL_H + CROP_H
    doc = pymupdf.open()
    page = doc.new_page(width=w, height=h)
    page.draw_rect(page.rect, color=None, fill=(1, 1, 1))
    for k, shot in enumerate(SHOTS):
        x = k * (1080 + GAP)
        # the full screenshot is placed below the label band and runs past the page bottom; the page edge crops it
        page.insert_image(pymupdf.Rect(x, LABEL_H, x + 1080, LABEL_H + 2400), filename=str(shot))
        page.draw_rect(pymupdf.Rect(x, LABEL_H, x + 1080, h), color=(0.6, 0.6, 0.6), width=3)
        page.insert_text((x + 10, 52), "(" + "ab"[k] + ")", fontsize=48, fontname="tiro")
    page.draw_rect(pymupdf.Rect(0, h - 1, w, h + 10), color=None, fill=(1, 1, 1))
    pix = page.get_pixmap(matrix=pymupdf.Matrix(0.5, 0.5))
    pix.save(HERE / "fig4_app.png")
    pix.save(HERE / "fig4_app_vi.png")       # same picture: build_paper.js looks for the _vi name in Vietnamese
    print("fig4_app.png", pix.width, "x", pix.height)
