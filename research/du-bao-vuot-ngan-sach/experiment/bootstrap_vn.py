"""Paired bootstrap over users for Brier-score differences on the VND-converted TabFormer data, kappa = 1.0.

Uses the row-level forecasts of cases_vn.py (test months, checkpoints before the overrun), averages the Brier score
per user and resamples users 2,000 times (seed 2026), as bootstrap.py does for the earlier data sets.
Run:  python -u bootstrap_vn.py   ->  results/bootstrap_vn.json
"""
import json
import pathlib

import numpy as np

HERE = pathlib.Path(__file__).resolve().parent
SEED, B = 2026, 2000
PAIRS = [("p3", "p1"), ("p2", "p1"), ("p3", "p2")]

if __name__ == "__main__":
    z = np.load(HERE / "results" / "cases_vn.npz")
    live = z["S"] <= z["B"]
    users, inv = np.unique(z["user"][live], return_inverse=True)
    cnt = np.bincount(inv)
    per = {m: np.bincount(inv, (z[m][live] - z["o"][live]) ** 2) / cnt for m in ["p1", "p2", "p3"]}
    rng = np.random.default_rng(SEED)
    idx = rng.integers(0, len(users), (B, len(users)))
    out = {"users": int(len(users)), "resamples": B, "seed": SEED}
    for a, b in PAIRS:
        d = per[a] - per[b]
        boot = d[idx].mean(axis=1)
        out[f"{a}-{b}"] = {"mean": float(d.mean()), "ci95": [float(np.quantile(boot, 0.025)), float(np.quantile(boot, 0.975))],
                           "share_users_better": float(np.mean(d < 0))}
    (HERE / "results" / "bootstrap_vn.json").write_text(json.dumps(out, indent=1), encoding="utf-8")
    print(json.dumps(out, indent=1))
