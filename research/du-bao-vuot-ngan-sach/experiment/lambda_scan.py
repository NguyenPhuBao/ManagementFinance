"""Scan smaller EWMA constants for M2 (lambda = 0.02 sat at the edge of the grid on all three data sets).

For each data set, kappa = 1.0: validation Brier (months < first_test, the score used to pick lambda) and
test Brier (months >= first_test) of M2 only. Writes results/lambda_scan.json.
Run:  python -u lambda_scan.py
"""
import json
import pathlib
import time

import numpy as np

from core import HISTORY, build_rows

HERE = pathlib.Path(__file__).resolve().parent
GRID = [0.002, 0.005, 0.01, 0.02, 0.05]


def first_test_of(Y, start):
    months = np.concatenate([np.arange(s + HISTORY, Y.shape[1]) for s in start])
    return int(np.quantile(months, 0.2))


def scan(name, Y, days, start, pattern, first_test):
    out = {}
    for lam in GRID:
        t0 = time.time()
        R = build_rows(Y, days, start, pattern, 1.0, lam)
        ok = R["S"] <= R["B"]
        val = ok & (R["month"] < first_test)
        test = ok & (R["month"] >= first_test)
        out[str(lam)] = {"val": float(np.mean((R["p2"][val] - R["o"][val]) ** 2)),
                         "test": float(np.mean((R["p2"][test] - R["o"][test]) ** 2))}
        print(f"{name} lambda={lam}: val={out[str(lam)]['val']:.4f} test={out[str(lam)]['test']:.4f} ({time.time() - t0:.0f}s)", flush=True)
    return out


def main():
    import berka
    import tabformer
    from sim import simulate
    res = {}
    Y, days, start, _ = berka.load()
    res["berka"] = scan("berka", Y, days, start, np.zeros(len(start), dtype=int), first_test_of(Y, start))
    Y, days, start, end, _, _ = tabformer.load()
    full = end == Y.shape[1] - 1
    Y, start = Y[full], start[full]
    res["tabformer"] = scan("tabformer", Y, days, start, np.zeros(len(start), dtype=int), first_test_of(Y, start))
    Y, days, pattern = simulate(seed=2026)
    res["synthetic"] = scan("synthetic", Y, days, np.zeros(len(pattern), dtype=int), pattern, 12)
    (HERE / "results" / "lambda_scan.json").write_text(json.dumps(res, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
