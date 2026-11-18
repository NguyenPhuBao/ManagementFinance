"""Third dataset: IBM TabFormer synthetic card transactions, 2015-01 to 2020-01. Writes results/tabformer.json.

Run:  python -u run_tabformer.py
Users whose spending stops before the last month (27 of 1,545) are dropped, since core.py scores every month
up to the end. As for Berka, the first 20% of scored user-months tune lambda for M2; the rest are reported.
"""
import pathlib

import numpy as np

from core import HISTORY, run
from tabformer import load

HERE = pathlib.Path(__file__).resolve().parent
SEED = 2026

if __name__ == "__main__":
    Y, days, start, end, ids, _ = load()
    full = end == Y.shape[1] - 1
    Y, start, ids = Y[full], start[full], ids[full]
    months = np.concatenate([np.arange(s + HISTORY, Y.shape[1]) for s in start])
    first_test = int(np.quantile(months, 0.2))
    print(f"users={len(ids)} (dropped {int((~full).sum())} that stop early) user-months={len(months)} "
          f"first_test_month={first_test} (= {2015 + first_test // 12}-{first_test % 12 + 1:02d})", flush=True)
    run(Y, days, start, np.zeros(len(ids), dtype=int), ["all"], first_test, HERE / "results" / "tabformer.json", SEED,
        extra={"accounts": int(len(ids)), "dropped_stop_early": int((~full).sum()), "period": "2015-01..2020-01"})
