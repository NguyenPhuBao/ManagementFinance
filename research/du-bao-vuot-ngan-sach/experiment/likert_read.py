"""Read the Likert Form A (likert_form.py) of one rater and summarise it for Table VI of the paper.

Scope cut on 2026-11-10 (user's choice): only Form A (the AI-proposed data conversion: 80 mapping items, 4 income
tiers, 20 converted user-months), rated by one author. Form B (30 warnings) and the two-rater agreement were dropped;
the Form B workbooks and B_khoa.json stay in ../likert/ but are not used.

For each part: number of items, mean score, share of items scored 4 or 5, and every item scored 1 or 2 (with the
category the rater proposed, on the mapping sheet). Items scored 1 or 2 must be revised in vn_mapping.py before it
is locked.

Run:  python -u likert_read.py [Dat|Bao]   ->  results/likert.json (refuses to run while the form has empty scores)
"""
import json
import pathlib
import sys

import numpy as np
from openpyxl import load_workbook

HERE = pathlib.Path(__file__).resolve().parent
L = HERE.parent / "likert"
RATER = sys.argv[1] if len(sys.argv) > 1 else "Dat"


def scores(path, sheet, col):
    ws = load_workbook(path, data_only=True)[sheet]
    rows = list(ws.iter_rows(min_row=2, values_only=True))
    idx = ord(col) - ord("A")
    vals = [r[idx] for r in rows]
    empty = [i + 1 for i, v in enumerate(vals) if v in (None, "")]
    if empty:
        raise SystemExit(f"{path.name} / {sheet} / column {col}: empty score in rows {empty[:10]}")
    bad = [i + 1 for i, v in enumerate(vals) if int(v) not in (1, 2, 3, 4, 5)]
    if bad:
        raise SystemExit(f"{path.name} / {sheet} / column {col}: score outside 1..5 in rows {bad[:10]}")
    return [int(v) for v in vals], rows


if __name__ == "__main__":
    path = L / f"Likert_A_DuLieu_{RATER}.xlsx"
    out = {"rater": RATER, "form": "A"}
    for sheet, col in (("1_Anh_xa", "F"), ("2_Bac_thu_nhap", "F"), ("3_Thang_mau", "H")):
        s, rows = scores(path, sheet, col)
        a = np.array(s)
        low = [{"stt": i + 1, "item": [str(v) for v in rows[i][1:5]], "score": int(x),
                "proposed": rows[i][6] if sheet == "1_Anh_xa" else None}
               for i, x in enumerate(s) if x <= 2]
        out[sheet] = {"n": int(len(a)), "mean": float(a.mean()), "share_4_5": float(np.mean(a >= 4)),
                      "counts": {str(k): int((a == k).sum()) for k in range(1, 6)}, "low_items": low}
    (HERE / "results" / "likert.json").write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
    print(json.dumps(out, ensure_ascii=False, indent=1))
