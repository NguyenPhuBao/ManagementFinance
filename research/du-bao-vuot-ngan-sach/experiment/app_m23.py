"""M2 and M3 inside the FlowMoney app (trial build, branch TranQuangDat, not released).

1. Fits M3 ONCE on TabFormer-VN (kappa 1.0, lambda 0.01, rows of months < first_test = the tuning window,
   the same 4,000-row subsample rule as core.fit_m3, fixed seed) and writes results/m3_coef_vn.json, which
   gen_m3_dart.py turns into the Dart constants the app embeds. The paper's main results use a rolling
   refit every six months; an app cannot embed a schedule, so the trial build uses this single fit.
2. Reference forecasts for the five users loaded into the app (results/app_users.json): their exported
   transactions (April..10 November 2026) bucketed by day, core.build_rows at checkpoint t = 10 with the
   app's budget (rounded to 1,000 VND, as loaded), p3 from the fixed fit. Writes results/app_m23.json; the
   Dart test of the app asserts the same numbers.

Run:  python -u app_m23.py
"""
import calendar
import json
import pathlib

import numpy as np
from sklearn.linear_model import QuantileRegressor

import core
from core import HISTORY, M3_ROWS, TAUS, build_rows, m3_features
from tabformer_vn import load

HERE = pathlib.Path(__file__).resolve().parent
SEED, LAM, FIRST_TEST = 2026, 0.01, 17          # results/tabformer_vn.json: lambda 0.01, first_test_month 17


def fit_fixed():
    Y, days, start, end, ids, _ = load()
    full = end == Y.shape[1] - 1
    Y, start = Y[full], start[full]
    R = build_rows(Y, days, start, np.zeros(len(start), dtype=int), 1.0, LAM)
    X = m3_features(R)
    z = (R["tot"] - R["S"]) / R["B"]
    rng = np.random.default_rng(SEED)
    train = np.nonzero(R["month"] < FIRST_TEST)[0]
    n_all = len(train)
    if len(train) > M3_ROWS:
        train = rng.choice(train, M3_ROWS, replace=False)
    mean, sd = X[train].mean(axis=0), X[train].std(axis=0) + 1e-12
    Xs = (X[train] - mean) / sd
    coefs = []
    for tau in TAUS:
        qr = QuantileRegressor(quantile=tau, alpha=0.0, solver="highs").fit(Xs, z[train])
        coefs.append([float(qr.intercept_)] + [float(c) for c in qr.coef_])
    out = {"lambda": LAM, "first_test_month": FIRST_TEST, "seed": SEED, "train_rows": int(len(train)),
           "train_rows_available": int(n_all), "taus": [float(t) for t in TAUS],
           "features": ["x", "S/B", "rmed/B", "nmu/B", "nsd/B", "cal", "cv"],
           "mean": [float(v) for v in mean], "sd": [float(v) for v in sd], "coef": coefs}
    (HERE / "results" / "m3_coef_vn.json").write_text(json.dumps(out, indent=1), encoding="utf-8")
    print(f"fixed M3 fit: {len(train)} of {n_all} rows", flush=True)
    return out


def p3_fixed(R, fit):
    X = (m3_features(R) - np.array(fit["mean"])) / np.array(fit["sd"])
    W = np.array(fit["coef"])
    Q = np.sort(W[:, 0][None, :] + X @ W[:, 1:].T, axis=1)
    v = (R["B"] - R["S"]) / R["B"]
    F = np.array([np.interp(v[i], Q[i], TAUS, left=TAUS[0] / 2, right=1 - (1 - TAUS[-1]) / 2) for i in range(len(v))])
    return 1 - F


def app_reference(fit):
    users = json.loads((HERE / "results" / "app_users.json").read_text(encoding="utf-8"))
    months = list(range(4, 12))                                  # April..November 2026
    days = np.array([calendar.monthrange(2026, m)[1] for m in months])
    out = []
    for u in users:
        Y = np.zeros((1, len(months), 31))
        for tx in u["transactions"]:
            mon, day = int(tx["date"][5:7]), int(tx["date"][8:10])
            Y[0, months.index(mon), day - 1] += tx["amount"]
        b_app = round(u["budget"] / 1000) * 1000.0
        mean3 = Y[0, HISTORY - 3 + 1:HISTORY + 1].sum(axis=1).mean()   # Aug..Oct (indices 4..6)
        R = build_rows(Y, days, np.array([0]), np.array([0]), b_app / mean3, LAM)
        i = int(np.nonzero((R["t"] == 10) & (R["month"] == months.index(11)))[0][0])
        Ri = {k: v[i:i + 1] for k, v in R.items()}
        p3 = float(p3_fixed(Ri, fit)[0])
        row = {"n": u["n"], "B": float(Ri["B"][0]), "S": float(Ri["S"][0]), "K": int(Ri["K"][0]),
               "p0": float(Ri["p0"][0]), "p1": float(Ri["p1"][0]), "p2": float(Ri["p2"][0]), "p3": p3,
               "features": [float(v) for v in m3_features(Ri)[0]],
               "rolling_paper": {"p1": u["p1"], "p2": u["p2"], "p3": u["p3"]}}
        out.append(row)
        print(f"#{u['n']} B={row['B']:,.0f} S={row['S']:,.0f} K={row['K']} p1={row['p1']:.4f} p2={row['p2']:.4f} "
              f"p3={p3:.4f}  (paper, full history + rolling fit: {u['p1']:.2f} {u['p2']:.2f} {u['p3']:.2f})", flush=True)
    (HERE / "results" / "app_m23.json").write_text(json.dumps(out, indent=1), encoding="utf-8")


if __name__ == "__main__":
    assert core.HISTORY == 6
    app_reference(fit_fixed())
