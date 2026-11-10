"""Bulk check of the app's own forecasting code (trial build) on every scored TabFormer-VN row.

  python -u app_bulk.py export     -> results/app_bulk/{meta.json, Y.f64, rows.f64}
  dart run dart_check/app_bulk.dart -> results/app_bulk/out.f64   (runs src/Client-app/.../du_bao_vuot_ngan_sach.dart)
  python -u app_bulk.py compare    -> results/app_bulk.json

Rows = results/cases_vn.npz (cases_vn.py): kappa 1.0, lambda 0.01, months >= first_test, all five checkpoints;
328,670 rows. Per row the app code gets the user's daily spending from their first month up to day t of the
current month and the budget B, as the app's data source does. Comparison: p0, p1, p2 against core.build_rows;
p3 against core's features run through the SAME fixed fit the app embeds (m3_coef_vn.json). Scores (Brier, log
loss, AUC, ECE, warning at <= 10 % false alarms) use the app's numbers on live rows (S <= B), next to the
paper's rolling-fit M3.
"""
import json
import pathlib
import sys

import numpy as np

from core import at_far, m3_features, scores, warning_curve
from app_m23 import p3_fixed
from tabformer_vn import load

HERE = pathlib.Path(__file__).resolve().parent
DIR = HERE / "results" / "app_bulk"


def cases():
    z = np.load(HERE / "results" / "cases_vn.npz")
    return {k: z[k] for k in z.files}


def export():
    Y, days, start, end, ids, _ = load()
    full = end == Y.shape[1] - 1
    Y, start = Y[full], start[full]
    C = cases()
    DIR.mkdir(parents=True, exist_ok=True)
    Y.astype("<f8").tofile(DIR / "Y.f64")
    rows = np.column_stack([C["user"], C["month"], C["t"], C["B"]]).astype("<f8")
    rows.tofile(DIR / "rows.f64")
    (DIR / "meta.json").write_text(json.dumps({"users": int(Y.shape[0]), "months": int(Y.shape[1]),
                                               "days": [int(d) for d in days], "start": [int(s) for s in start],
                                               "rows": int(len(rows))}), encoding="utf-8")
    print(f"exported {Y.shape[0]} users x {Y.shape[1]} months, {len(rows)} rows", flush=True)


def compare():
    C = cases()
    out = np.fromfile(DIR / "out.f64", dtype="<f8").reshape(-1, 4)
    assert len(out) == len(C["o"])
    fit = json.loads((HERE / "results" / "m3_coef_vn.json").read_text(encoding="utf-8"))
    ref = {"p0": C["p0"], "p1": C["p1"], "p2": C["p2"], "p3": p3_fixed(C, fit)}
    app = {m: out[:, j] for j, m in enumerate(["p0", "p1", "p2", "p3"])}
    res = {"rows": int(len(out)), "null_rows": int(np.isnan(out).any(axis=1).sum()), "match": {}}
    for m in ref:
        d = np.abs(app[m] - ref[m])
        res["match"][m] = {"max_abs_diff": float(np.nanmax(d)), "rows_over_1e-6": int(np.sum(d > 1e-6)),
                           "rows_over_1e-3": int(np.sum(d > 1e-3))}
        print(f"{m}: max |app - python| = {np.nanmax(d):.2e}, rows > 1e-6: {np.sum(d > 1e-6)}", flush=True)
    live = C["S"] <= C["B"]
    o = C["o"][live]
    series = {"app_p1": app["p1"], "app_p2": app["p2"], "app_p3_fixed": app["p3"], "paper_p3_rolling": C["p3"]}
    res["live_rows"] = int(live.sum())
    res["users"] = int(len(np.unique(C["user"][live])))
    res["scores"] = {k: scores(v[live], o) for k, v in series.items()}
    Rt = {k: C[k] for k in ["user", "month", "S", "B", "o", "cross", "t"]}
    grid = np.round(np.arange(0.02, 1.0, 0.02), 2)
    res["at_far10"] = {k: at_far(warning_curve(Rt, v, grid), 0.10) for k, v in series.items()}
    for k in series:
        s, w = res["scores"][k], res["at_far10"][k]
        print(f"{k}: brier={s['brier']:.4f} ece={s['ece']:.4f} auc={s['auc']:.3f} "
              f"recall@far10={w['recall']:.3f} lead={w['lead_median']:.0f}", flush=True)
    (HERE / "results" / "app_bulk.json").write_text(json.dumps(res, indent=1), encoding="utf-8")


if __name__ == "__main__":
    {"export": export, "compare": compare}[sys.argv[1]]()
