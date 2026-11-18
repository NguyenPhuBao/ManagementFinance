"""Row-level forecasts (kappa = 1.0) on the VND-converted TabFormer data, for the Likert-B warning form and for
picking the users loaded into the real app.

Same lambda, seed and refit schedule as run_tabformer_vn.py; kappa 1.0 is the first kappa there, so the random
subsamples of M3 and therefore p3 are the same. Writes results/cases_vn.npz (gitignored-size: ~20 MB).

Run:  python -u cases_vn.py
"""
import json
import pathlib

import numpy as np

from core import HISTORY, build_rows, fit_m3
from tabformer_vn import load

HERE = pathlib.Path(__file__).resolve().parent
SEED = 2026

if __name__ == "__main__":
    res = json.loads((HERE / "results" / "tabformer_vn.json").read_text(encoding="utf-8"))
    Y, days, start, end, ids, _ = load()
    full = end == Y.shape[1] - 1
    Y, start, ids = Y[full], start[full], ids[full]
    first_test = res["first_test_month"]
    R = build_rows(Y, days, start, np.zeros(len(ids), dtype=int), 1.0, res["lambda"])
    R["p3"] = fit_m3(R, np.random.default_rng(SEED), first_test)
    test = R["month"] >= first_test
    out = {k: v[test] for k, v in R.items()}
    out["uid"] = ids[out["user"]]
    np.savez_compressed(HERE / "results" / "cases_vn.npz", **out)
    live = out["S"] <= out["B"]
    for m in ["p1", "p2", "p3"]:
        print(m, "brier", float(np.mean((out[m][live] - out["o"][live]) ** 2)))
    print("rows", len(out["o"]), "first_test", first_test, "lambda", res["lambda"])
