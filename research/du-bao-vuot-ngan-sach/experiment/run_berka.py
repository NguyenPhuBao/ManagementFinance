"""Main experiment on the PKDD-99 Berka data. Writes results/berka.json (and berka_nofixed.json with --nofixed).

Run:  python -u run_berka.py [--nofixed]
The first 20% of scored user-months (by calendar month) tune lambda for M2; the rest are reported.
"""
import os
import pathlib
import sys

import numpy as np

from berka import load
from core import HISTORY, run

HERE = pathlib.Path(__file__).resolve().parent
SEED = 2026

if __name__ == "__main__":
    nofixed = "--nofixed" in sys.argv
    Y, days, start, ids = load(exclude_fixed=nofixed)
    # first evaluable month of each account is start + HISTORY; split so ~20% of user-months come before first_test
    months = np.concatenate([np.arange(s + HISTORY, Y.shape[1]) for s in start])
    first_test = int(np.quantile(months, 0.2))
    print(f"accounts={len(ids)} user-months={len(months)} first_test_month={first_test} "
          f"(= {1993 + first_test // 12}-{first_test % 12 + 1:02d})", flush=True)
    name = "berka_nofixed.json" if nofixed else "berka.json"
    if os.environ.get("M3_ROWS"):
        name = name.replace(".json", "_rows" + os.environ["M3_ROWS"] + ".json")
    run(Y, days, start, np.zeros(len(ids), dtype=int), ["all"], first_test, HERE / "results" / name, SEED,
        extra={"accounts": int(len(ids)), "exclude_fixed": nofixed})
