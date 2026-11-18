"""Paired bootstrap over users for Brier-score differences at kappa = 1.0 (Section V-F).

Rebuilds the kappa = 1.0 forecasts exactly as run_berka.py / run_synthetic.py do (same seed, the lambda saved in results/<source>.json,
same M3 subsample), averages the Brier score per user, and resamples users 2,000 times.
Run:  python -u bootstrap.py   ->  results/bootstrap.json
      python -u bootstrap.py tabformer   ->  results/bootstrap_tabformer.json (run_tabformer.py users and split)
"""
import json
import pathlib
import sys

import numpy as np

import berka
from core import HISTORY, build_rows, fit_m3
from sim import simulate

HERE = pathlib.Path(__file__).resolve().parent
SEED, B = 2026, 2000
PAIRS = [("p3", "p1"), ("p3", "p0"), ("p1", "p0"), ("p2", "p1")]


def paired(R, first_test, rng):
    test = (R["month"] >= first_test) & (R["S"] <= R["B"])
    users, inv = np.unique(R["user"][test], return_inverse=True)
    cnt = np.bincount(inv)
    per = {m: np.bincount(inv, (R[m][test] - R["o"][test]) ** 2) / cnt for m in ["p0", "p1", "p2", "p3"]}
    out = {}
    idx = rng.integers(0, len(users), (B, len(users)))
    for a, b in PAIRS:
        d = per[a] - per[b]
        boot = d[idx].mean(axis=1)
        out[f"{a}-{b}"] = {"mean": float(d.mean()), "ci95": [float(np.quantile(boot, 0.025)), float(np.quantile(boot, 0.975))],
                           "share_users_better": float(np.mean(d < 0))}
    return out, int(len(users))


def tabformer_only():
    import tabformer
    Y, days, start, end, ids, _ = tabformer.load()
    full = end == Y.shape[1] - 1
    Y, start = Y[full], start[full]
    months = np.concatenate([np.arange(s + HISTORY, Y.shape[1]) for s in start])
    ft = int(np.quantile(months, 0.2))
    lam = json.loads((HERE / "results" / "tabformer.json").read_text(encoding="utf-8"))["lambda"]
    R = build_rows(Y, days, start, np.zeros(len(start), dtype=int), 1.0, lam)
    R["p3"] = fit_m3(R, np.random.default_rng(SEED), ft)
    res, n = paired(R, ft, np.random.default_rng(SEED + 1))
    res["users"], res["lambda"] = n, lam
    (HERE / "results" / "bootstrap_tabformer.json").write_text(json.dumps(res, indent=1), encoding="utf-8")
    print(json.dumps(res, indent=1))


def main():
    if "tabformer" in sys.argv:
        return tabformer_only()
    res = {}
    Y, days, start, ids = berka.load()
    months = np.concatenate([np.arange(s + HISTORY, Y.shape[1]) for s in start])
    ft = int(np.quantile(months, 0.2))
    lam = json.loads((HERE / "results" / "berka.json").read_text(encoding="utf-8"))["lambda"]
    R = build_rows(Y, days, start, np.zeros(len(ids), dtype=int), 1.0, lam)
    R["p3"] = fit_m3(R, np.random.default_rng(SEED), ft)
    res["berka"], n = paired(R, ft, np.random.default_rng(SEED + 1))
    res["berka"]["users"] = n
    Y, days, pattern = simulate(seed=SEED)
    lam = json.loads((HERE / "results" / "synthetic.json").read_text(encoding="utf-8"))["lambda"]
    R = build_rows(Y, days, np.zeros(len(pattern), dtype=int), pattern, 1.0, lam)
    R["p3"] = fit_m3(R, np.random.default_rng(SEED), 12)
    res["synthetic"], n = paired(R, 12, np.random.default_rng(SEED + 1))
    res["synthetic"]["users"] = n
    (HERE / "results" / "bootstrap.json").write_text(json.dumps(res, indent=1), encoding="utf-8")
    print(json.dumps(res, indent=1))


if __name__ == "__main__":
    main()
