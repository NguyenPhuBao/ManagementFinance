"""Preliminary experiment on the synthetic population (Section V-B). Writes results/synthetic.json.

Run:  python -u run_synthetic.py
Shortcuts stated in the paper: M3 is refitted every 6 months on a 4,000-row subsample; M2 is Gaussian only.
"""
import pathlib

import numpy as np

from core import run
from sim import PATTERNS, simulate

HERE = pathlib.Path(__file__).resolve().parent
SEED = 2026
FIRST_TEST = 12  # months 6-11 tune lambda (20% of the 30 evaluable months), months 12-35 are reported

if __name__ == "__main__":
    Y, days, pattern = simulate(seed=SEED)
    run(Y, days, np.zeros(len(pattern), dtype=int), pattern, PATTERNS, FIRST_TEST,
        HERE / "results" / "synthetic.json", SEED)
