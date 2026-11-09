"""Export Berka test cases for checking M1 (core.py) against FlowMoney's own Dart rule (nhip_chi.dart).

For a random sample of (account, month, checkpoint) rows with K >= 3 usable past periods, write the six past
calendar months with their daily spending, the current month, the checkpoint t, spent-so-far S and budget B,
plus what core.py computes from the same numbers: the median remaining spend r_med, the M1 probability p1 and
the median spent share at x (the pace chip). dart_check/doi_chieu.dart reads the file and runs the app's code.

Usage: python -u export_cases.py [n_cases] [seed]  ->  results/m1_cases.json
"""
import json
import pathlib
import sys

import numpy as np

import berka
from core import CHECKPOINTS, HISTORY, MIN_K

OUT = pathlib.Path(__file__).resolve().parent / "results" / "m1_cases.json"


def main():
    n_cases = int(sys.argv[1]) if len(sys.argv) > 1 else 20000
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 7
    kappa = 1.0
    rng = np.random.default_rng(seed)
    Y, days, start, ids = berka.load()
    n, months, _ = Y.shape
    C = np.concatenate([np.zeros((n, months, 1)), np.cumsum(Y, axis=2)], axis=2)
    tot = np.array([C[:, m, days[m]] for m in range(months)]).T

    cand = []
    for m in range(HISTORY, months):
        past = list(range(m - HISTORY, m))
        K = (tot[:, past] > 0).sum(axis=1)
        B = kappa * tot[:, m - 3:m].mean(axis=1)
        ok = np.nonzero((m - HISTORY >= start) & (B > 0) & (K >= MIN_K))[0]
        for u in ok:
            for t in CHECKPOINTS:
                cand.append((u, m, t))
    pick = rng.choice(len(cand), size=min(n_cases, len(cand)), replace=False)

    cases = []
    for i in pick:
        u, m, t = cand[i]
        T = days[m]
        x = t / T
        S = float(C[u, m, t])
        B = float(kappa * tot[u, m - 3:m].mean())
        past, rem, share = [], [], []
        for k in range(m - HISTORY, m):
            entries = [[d + 1, float(Y[u, k, d])] for d in range(days[k]) if Y[u, k, d] > 0]
            past.append({"y": 1993 + k // 12, "m": k % 12 + 1, "e": entries})
            if tot[u, k] > 0:
                dk = int(np.floor(x * days[k] + 1e-9))
                rem.append(tot[u, k] - C[u, k, dk])
                share.append(C[u, k, dk] / tot[u, k])
        rem, share = np.array(rem), np.array(share)
        K = len(rem)
        cases.append({
            "acc": int(ids[u]), "y": 1993 + m // 12, "m": m % 12 + 1, "t": t, "S": S, "B": B,
            "past": past,
            "py": {"K": K, "rmed": float(np.median(rem)), "share": float(np.median(share)),
                   "p1": float((np.sum(S + rem > B) + 0.5) / (K + 1))},
        })
    OUT.write_text(json.dumps({"kappa": kappa, "seed": seed, "cases": cases}), encoding="utf-8")
    print(f"{len(cases)} cases from {len(cand)} candidates -> {OUT}")


if __name__ == "__main__":
    main()
