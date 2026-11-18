"""Likert form B: two authors rate 30 budget warnings on the VND-converted data, blind to method and outcome.

30 live rows (spent <= budget at the checkpoint, K >= 3): days 10, 15, 20 x (5 months that end over budget,
5 that do not), seeded. For each case the rater sees the budget, the spending so far, the same point and the
month total of the three previous months, and three warnings A/B/C = M1/M2/M3 in a per-case shuffled order.
Statement per warning: "Mức cảnh báo này hợp lý với số liệu ở trên" (1-5). The key (method order, outcome)
goes to ../likert/B_khoa.json and must not be opened by a rater before both forms are returned.

Run:  python -u likert_form_b.py    (needs results/cases_vn.npz from cases_vn.py)
"""
import json
import pathlib

import numpy as np
from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.worksheet.datavalidation import DataValidation

from tabformer_vn import load

HERE = pathlib.Path(__file__).resolve().parent
OUT = HERE.parent / "likert"
SEED = 2026
DAYS = [10, 15, 20]
SCALE = "1 = Hoàn toàn không đồng ý · 2 = Không đồng ý · 3 = Phân vân · 4 = Đồng ý · 5 = Hoàn toàn đồng ý"


def vnd(x):
    return f"{int(round(x / 1000.0)) * 1000:,}".replace(",", ".") + " đ"


def level(p):
    return "Cao" if p >= 0.7 else ("Trung bình" if p >= 0.4 else "Thấp")


def pick(C, rng):
    live = (C["S"] <= C["B"]) & (C["K"] >= 3)
    out = []
    for t in DAYS:
        for o in (1, 0):
            idx = np.nonzero(live & (C["t"] == t) & (C["o"] == o))[0]
            out += list(rng.choice(idx, 5, replace=False))
    rng.shuffle(out)
    return out


if __name__ == "__main__":
    z = np.load(HERE / "results" / "cases_vn.npz")
    C = {k: z[k] for k in z.files}
    Y, days, start, end, ids, _ = load()
    full = end == Y.shape[1] - 1
    Y = Y[full]
    rng = np.random.default_rng(SEED)
    cases = pick(C, rng)
    key, rows = [], []
    for n, i in enumerate(cases, 1):
        u, m, t = int(C["user"][i]), int(C["month"][i]), int(C["t"][i])
        past = []
        for k in (m - 3, m - 2, m - 1):
            x = t / days[m]
            dk = int(np.floor(x * days[k] + 1e-9))
            past.append(f"tới ngày {dk}: {vnd(Y[u, k, :dk].sum())} / cả tháng {vnd(Y[u, k, :days[k]].sum())}")
        order = list(rng.permutation(["p1", "p2", "p3"]))
        warn = [f"Khả năng vượt ngân sách cuối tháng: {round(100 * float(C[mth][i]))} % ({level(float(C[mth][i]))})" for mth in order]
        rows.append([n, f"{t}/{days[m]}", vnd(C["B"][i]), vnd(C["S"][i]), f"{100 * C['S'][i] / C['B'][i]:.0f} %",
                     "\n".join(past), warn[0], None, warn[1], None, warn[2], None, None])
        key.append({"stt": n, "row": int(i), "uid": int(C["uid"][i]), "month": m, "t": t, "order": order,
                    "o": int(C["o"][i]), "p": {mth: float(C[mth][i]) for mth in ["p1", "p2", "p3"]}})
    OUT.mkdir(exist_ok=True)
    (OUT / "B_khoa.json").write_text(json.dumps(key, ensure_ascii=False, indent=1), encoding="utf-8")
    header = ["STT", "Ngày / số ngày của tháng", "Ngân sách tháng", "Đã chi tới hôm nay", "Đã dùng",
              "3 tháng trước (cùng thời điểm / cả tháng)", "Cảnh báo A", "Điểm A (1–5)", "Cảnh báo B", "Điểm B (1–5)",
              "Cảnh báo C", "Điểm C (1–5)", "Nhận xét"]
    for rater in ["Dat", "Bao"]:
        wb = Workbook()
        ws = wb.active
        ws.title = "Huong_dan"
        for r, s in enumerate([
            "PHIẾU CHẤM B — Cảnh báo vượt ngân sách (đề tài NCKH dự báo vượt ngân sách)",
            f"Người chấm: {rater}. Chấm ĐỘC LẬP, không bàn, không mở tệp B_khoa.json trước khi nộp phiếu.",
            "Mỗi dòng là một người dùng ở một ngày trong tháng. Ngân sách = trung bình chi 3 tháng trước. Số liệu là dữ liệu",
            "TabFormer (IBM) đã đổi sang VND. A, B, C là ba cách dự báo, thứ tự xáo khác nhau ở mỗi dòng.",
            "Với MỖI cảnh báo, chấm câu: 'Mức cảnh báo này hợp lý với số liệu ở trên'. " + SCALE,
            "Không có đáp án đúng; hãy chấm theo cảm nhận của bạn khi tự nhìn số liệu.",
        ], 1):
            ws.cell(r, 1, s)
        ws.column_dimensions["A"].width = 120
        ws["A1"].font = Font(bold=True)
        s = wb.create_sheet("Canh_bao")
        s.append(header)
        for c in s[1]:
            c.font, c.fill = Font(bold=True), PatternFill("solid", fgColor="DDEBF7")
            c.alignment = Alignment(wrap_text=True, vertical="top")
        for r in rows:
            s.append(r)
        dv = DataValidation(type="list", formula1='"1,2,3,4,5"', allow_blank=True)
        s.add_data_validation(dv)
        for col in "HJL":
            dv.add(f"{col}2:{col}{len(rows) + 1}")
            for rr in range(2, len(rows) + 2):
                s[f"{col}{rr}"].fill = PatternFill("solid", fgColor="FFF2CC")
        for col, w in {"A": 5, "B": 10, "C": 14, "D": 14, "E": 8, "F": 46, "G": 26, "H": 9, "I": 26, "J": 9,
                       "K": 26, "L": 9, "M": 25}.items():
            s.column_dimensions[col].width = w
        for row in s.iter_rows(min_row=2):
            for c in row:
                c.alignment = Alignment(wrap_text=True, vertical="top")
        s.freeze_panes = "B2"
        path = OUT / f"Likert_B_CanhBao_{rater}.xlsx"
        wb.save(path)
        print(path)
    print("cases", len(rows), "over:", sum(k["o"] for k in key))
