"""Read the two raters' Likert forms (likert_form.py, likert_form_b.py) and summarise them for Table V.

For each part: mean score of each rater, exact and within-one agreement, quadratic-weighted Cohen's kappa.
Form A: lists every item scored 1 or 2 by either rater, with the category the rater proposed (mapping sheet).
Form B: unblinds with ../likert/B_khoa.json and reports, per forecaster, the mean score for months that ended over
budget and for months that did not, so the human view can be compared with the hidden outcome.

Run:  python -u likert_read.py   ->  results/likert.json (refuses to run while a form has empty score cells)
"""
import json
import pathlib

import numpy as np
from openpyxl import load_workbook

HERE = pathlib.Path(__file__).resolve().parent
L = HERE.parent / "likert"
RATERS = ["Dat", "Bao"]


def kappa_w(a, b, k=5):
    """Quadratic-weighted Cohen's kappa for two raters on a 1..k scale."""
    a, b = np.asarray(a) - 1, np.asarray(b) - 1
    o = np.zeros((k, k))
    for x, y in zip(a, b):
        o[x, y] += 1
    o /= o.sum()
    e = np.outer(o.sum(axis=1), o.sum(axis=0))
    w = np.array([[(i - j) ** 2 for j in range(k)] for i in range(k)]) / (k - 1) ** 2
    den = (w * e).sum()
    return float(1 - (w * o).sum() / den) if den > 0 else float("nan")


def scores(path, sheet, col):
    ws = load_workbook(path, data_only=True)[sheet]
    rows = list(ws.iter_rows(min_row=2, values_only=True))
    idx = ord(col) - ord("A")
    vals = [r[idx] for r in rows]
    empty = [i + 1 for i, v in enumerate(vals) if v in (None, "")]
    if empty:
        raise SystemExit(f"{path.name} / {sheet} / column {col}: empty score in rows {empty[:10]}")
    return [int(v) for v in vals], rows


def compare(a, b):
    a, b = np.array(a), np.array(b)
    return {"n": int(len(a)), "mean": [float(a.mean()), float(b.mean())], "exact": float(np.mean(a == b)),
            "within1": float(np.mean(abs(a - b) <= 1)), "kappa_w": kappa_w(a, b)}


if __name__ == "__main__":
    out = {"A": {}, "B": {}}
    for sheet, col in (("1_Anh_xa", "F"), ("2_Bac_thu_nhap", "F"), ("3_Thang_mau", "H")):
        s = [scores(L / f"Likert_A_DuLieu_{r}.xlsx", sheet, col) for r in RATERS]
        out["A"][sheet] = compare(s[0][0], s[1][0])
        low = []
        for i, (x, y) in enumerate(zip(s[0][0], s[1][0])):
            if min(x, y) <= 2:
                row = s[0][1][i]
                low.append({"stt": i + 1, "item": [str(v) for v in row[1:5]], "scores": [x, y],
                            "proposed": [s[0][1][i][6], s[1][1][i][6]] if sheet == "1_Anh_xa" else None})
        out["A"][sheet]["low_items"] = low
    key = json.loads((L / "B_khoa.json").read_text(encoding="utf-8"))
    s = [scores(L / f"Likert_B_CanhBao_{r}.xlsx", "Canh_bao", c) for r in RATERS for c in "HJL"]
    per = {m: [[], []] for m in ["p1", "p2", "p3"]}          # per method: rater-1 list, rater-2 list
    outcome = {m: [] for m in per}
    for i, k in enumerate(key):
        for pos, m in enumerate(k["order"]):
            per[m][0].append(s[pos][0][i])
            per[m][1].append(s[3 + pos][0][i])
            outcome[m].append(k["o"])
    for m in per:
        o = np.array(outcome[m])
        both = (np.array(per[m][0]) + np.array(per[m][1])) / 2
        out["B"][m] = {**compare(per[m][0], per[m][1]),
                       "mean_both_over": float(both[o == 1].mean()), "mean_both_not_over": float(both[o == 0].mean())}
    (HERE / "results" / "likert.json").write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
    print(json.dumps(out, ensure_ascii=False, indent=1))
