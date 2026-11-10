"""Likert form A: human check of the AI-proposed Vietnamese conversion (vn_mapping.py), before it is locked.

One identical workbook per rater (the two authors rate independently, without seeing each other's scores):
  1_Anh_xa      MCC group -> FlowMoney category        (82 items: 79 codes + 3 ISO ranges)
  2_Bac_thu_nhap income tiers and their VND range      (4 items)
  3_Thang_mau   20 converted user-months, 5 per tier   (20 items)
Each item: 1 = hoàn toàn không đồng ý ... 5 = hoàn toàn đồng ý. Read back with likert_read.py.

Run:  python -u likert_form.py    -> ../likert/Likert_A_DuLieu_{Dat,Bao}.xlsx
"""
import pathlib

import numpy as np
from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.worksheet.datavalidation import DataValidation

import tabformer
import tabformer_vn
from vn_mapping import CATEGORIES, MCC, STATUS, TIERS

OUT = pathlib.Path(__file__).resolve().parent.parent / "likert"
RATERS = ["Dat", "Bao"]
SEED = 2026
SCALE = "1 = Hoàn toàn không đồng ý · 2 = Không đồng ý · 3 = Phân vân · 4 = Đồng ý · 5 = Hoàn toàn đồng ý"
HEAD = PatternFill("solid", fgColor="DDEBF7")
SCORE = PatternFill("solid", fgColor="FFF2CC")


def vnd(x):
    return f"{int(round(x)):,}".replace(",", ".") + " đ"


def mapping_items():
    groups = {}
    for code, (desc, cat, note) in sorted(MCC.items()):
        if 3000 <= code <= 3299:
            k = ("3000–3299", desc)
        elif 3351 <= code <= 3441:
            k = ("3351–3441", desc)
        elif 3501 <= code <= 3999:
            k = ("3501–3999", desc)
        else:
            k = (str(code), desc)
        groups[k] = (cat, note)
    return [(c, d, cat, note) for (c, d), (cat, note) in groups.items()]


def sample_months(vn, f):
    """Five user-months per tier from users the experiment keeps, months 2017 onward, seeded."""
    Y, days, start, end, ids, _ = tabformer.load({k: vn[k] for k in ["u", "y", "m", "d", "a"]})
    full = end == Y.shape[1] - 1
    keep = set(int(u) for u in ids[full])
    rng = np.random.default_rng(SEED)
    mi = (vn["y"] - tabformer.FIRST_YEAR) * 12 + vn["m"] - 1
    out = []
    for k, (name, _, _, _) in enumerate(TIERS):
        users = sorted(u for u, v in f.items() if v[0] == k and u in keep)
        for u in rng.choice(users, 5, replace=False):
            sel_u = vn["u"] == u
            months = np.unique(mi[sel_u & (mi >= 24)])
            m = int(rng.choice(months))
            sel = sel_u & (mi == m)
            out.append((name, int(u), m, sel))
    return out


def build(rater, items, months, vn):
    wb = Workbook()
    ws = wb.active
    ws.title = "Huong_dan"
    lines = [
        "PHIẾU CHẤM A — Dữ liệu TabFormer chuyển sang chuẩn Việt Nam (đề tài NCKH dự báo vượt ngân sách)",
        f"Người chấm: {rater}. Trạng thái bảng ánh xạ lúc phát phiếu: {STATUS}.",
        "Bảng ánh xạ và bậc thu nhập do Claude (Claude Code, claude-opus-5-5) đề xuất ngày 10/11/2026. Phiếu này là bước",
        "người kiểm tra trước khi khoá dữ liệu. Chấm ĐỘC LẬP: không bàn, không xem điểm của người kia trước khi nộp.",
        "Ô vàng là ô chấm, chọn 1–5 trong danh sách thả xuống. " + SCALE,
        "Ở trang 1, nếu chấm 1 hoặc 2 thì ghi danh mục bạn đề nghị. Mọi trang có cột Nhận xét (không bắt buộc).",
        "Tiền đã đổi sang VND theo bậc thu nhập; giao dịch gốc là của bộ sinh dữ liệu thẻ của IBM (TabFormer, người dùng Mỹ).",
    ]
    for i, s in enumerate(lines, 1):
        ws.cell(i, 1, s)
    ws.column_dimensions["A"].width = 120
    ws["A1"].font = Font(bold=True)
    dv_cat = f'"{",".join(CATEGORIES)}"'

    def sheet(title, header, rows, score_cols, widths, cat_col=None):
        s = wb.create_sheet(title)
        s.append(header)
        for c in s[1]:
            c.font, c.fill = Font(bold=True), HEAD
            c.alignment = Alignment(wrap_text=True, vertical="top")
        for r in rows:
            s.append(r)
        n = len(rows) + 1
        dv = DataValidation(type="list", formula1='"1,2,3,4,5"', allow_blank=True)
        s.add_data_validation(dv)
        for col in score_cols:
            dv.add(f"{col}2:{col}{n}")
            for row in range(2, n + 1):
                s[f"{col}{row}"].fill = SCORE
        if cat_col:
            dv2 = DataValidation(type="list", formula1=dv_cat, allow_blank=True)
            s.add_data_validation(dv2)
            dv2.add(f"{cat_col}2:{cat_col}{n}")
        for col, w in widths.items():
            s.column_dimensions[col].width = w
        for row in s.iter_rows(min_row=2):
            for c in row:
                c.alignment = Alignment(wrap_text=True, vertical="top")
        s.freeze_panes = "A2"

    sheet("1_Anh_xa",
          ["STT", "Mã MCC", "Ngành hàng (tiếng Anh)", "Danh mục FlowMoney đề xuất", "Lý do AI ghi",
           "Điểm: 'Khoản chi ở ngành này nên ghi vào danh mục đề xuất' (1–5)", "Danh mục bạn đề nghị (nếu 1–2)", "Nhận xét"],
          [[i, c, d, cat, note, None, None, None] for i, (c, d, cat, note) in enumerate(items, 1)],
          ["F"], {"A": 5, "B": 11, "C": 30, "D": 16, "E": 40, "F": 22, "G": 18, "H": 30}, cat_col="G")
    sheet("2_Bac_thu_nhap",
          ["STT", "Bậc", "Tỉ lệ người dùng", "Chi tiêu tháng (trung vị) từ", "đến",
           "Điểm: 'Mức chi tháng này hợp lý cho người Việt thuộc bậc này, năm 2026' (1–5)", "Nhận xét"],
          [[i, n, f"{int(sh * 100)} %", vnd(lo), vnd(hi), None, None] for i, (n, sh, lo, hi) in enumerate(TIERS, 1)],
          ["F"], {"A": 5, "B": 16, "C": 10, "D": 16, "E": 16, "F": 30, "G": 30})
    rows = []
    for i, (tier, u, m, sel) in enumerate(months, 1):
        a, cat, d = vn["a"][sel], vn["cat"][sel], vn["d"][sel]
        by = np.bincount(cat, weights=a, minlength=len(CATEGORIES))
        parts = [f"{CATEGORIES[j]} {vnd(by[j])} ({100 * by[j] / a.sum():.0f}%)" for j in np.argsort(-by) if by[j] > 0]
        top = np.argsort(-a)[:3]
        big = [f"ngày {d[j]}: {vnd(a[j])} – {CATEGORIES[cat[j]]} ({MCC[int(vn['mcc'][sel][j])][0]})" for j in top]
        rows.append([i, tier, vnd(a.sum()), len(a), len(np.unique(d)), "; ".join(parts), "\n".join(big), None, None])
    sheet("3_Thang_mau",
          ["STT", "Bậc thu nhập", "Tổng chi tháng", "Số giao dịch", "Số ngày có chi", "Theo danh mục",
           "3 khoản lớn nhất", "Điểm: 'Tháng chi tiêu này giống của một người Việt thuộc bậc đã ghi' (1–5)", "Nhận xét"],
          rows, ["H"], {"A": 5, "B": 14, "C": 14, "D": 9, "E": 9, "F": 55, "G": 50, "H": 24, "I": 30})
    OUT.mkdir(exist_ok=True)
    path = OUT / f"Likert_A_DuLieu_{rater}.xlsx"
    wb.save(path)
    return path


if __name__ == "__main__":
    t = tabformer_vn.rows()
    vn, f = tabformer_vn.convert(t)
    items = mapping_items()
    months = sample_months(vn, f)
    key = [(tier, u, m) for tier, u, m, _ in months]
    (OUT).mkdir(exist_ok=True)
    (OUT / "A_mau_thang.txt").write_text("\n".join(f"{i}\t{t}\tuser={u}\tmonth_index={m}" for i, (t, u, m) in enumerate(key, 1)), encoding="utf-8")
    for r in RATERS:
        print(build(r, items, months, vn), len(items), "mapping items,", len(months), "months")
