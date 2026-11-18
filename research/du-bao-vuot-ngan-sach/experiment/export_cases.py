"""Export test cases for checking M1 (core.py) against FlowMoney's own Dart rule (nhip_chi.dart).

For a random sample of (account, month, checkpoint) rows with K >= 3 usable past periods, write the six past
calendar months with their spending, the current month, the checkpoint t, spent-so-far S and budget B, plus
what core.py computes from the same numbers: the median remaining spend r_med, the M1 probability p1 and the
median spent share at x (the pace chip). dart_check/doi_chieu.dart reads the file and runs the app's code.

Berka has dates only: entries are [day, daily total]. TabFormer has the time of day: entries are one per
transaction, [day, amount, minute of day], and the Dart run adds a fourth convention, the real time.

Usage: python -u export_cases.py [berka|tabformer|tabformer_vn] [n_cases] [seed]  ->  results/m1_cases[_tabformer].json
"""
import json
import pathlib
import sys

import numpy as np

from core import CHECKPOINTS, HISTORY, MIN_K

HERE = pathlib.Path(__file__).resolve().parent


def main():
    source = sys.argv[1] if len(sys.argv) > 1 else "berka"
    n_cases = int(sys.argv[2]) if len(sys.argv) > 2 else 20000
    seed = int(sys.argv[3]) if len(sys.argv) > 3 else 7
    kappa = 1.0
    rng = np.random.default_rng(seed)
    if source == "berka":
        import berka
        Y, days, start, ids = berka.load()
        year0, tx = 1993, None
    else:
        import tabformer
        if source == "tabformer_vn":           # VND amounts (tabformer_vn.py); minute of day from the USD cache
            import tabformer_vn
            vn, _ = tabformer_vn.convert()
            t = {k: vn[k] for k in ["u", "y", "m", "d", "a"]}
            t["min"] = tabformer.transactions()["min"]
            Y, days, start, end, ids, _ = tabformer.load(t)
        else:
            t = tabformer.transactions()
            Y, days, start, end, ids, _ = tabformer.load()
        full = end == Y.shape[1] - 1
        Y, start, ids = Y[full], start[full], ids[full]
        year0 = tabformer.FIRST_YEAR
        pos = {u: i for i, u in enumerate(ids)}
        mi = (t["y"] - year0) * 12 + t["m"] - 1
        tx = {}
        for u, k, d, mn, a in zip(t["u"], mi, t["d"], t["min"], t["a"]):
            if u in pos and k < Y.shape[1]:
                tx.setdefault((pos[u], int(k)), []).append([int(d), float(a), int(mn)])
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
            for t_ in CHECKPOINTS:
                cand.append((u, m, t_))
    pick = rng.choice(len(cand), size=min(n_cases, len(cand)), replace=False)

    cases = []
    for i in pick:
        u, m, t_ = cand[i]
        x = t_ / days[m]
        S = float(C[u, m, t_])
        B = float(kappa * tot[u, m - 3:m].mean())
        past, rem, share = [], [], []
        for k in range(m - HISTORY, m):
            if tx is None:
                entries = [[d + 1, float(Y[u, k, d])] for d in range(days[k]) if Y[u, k, d] > 0]
            else:
                entries = tx.get((u, k), []) if k >= start[u] else []
            past.append({"y": year0 + k // 12, "m": k % 12 + 1, "e": entries})
            if tot[u, k] > 0:
                dk = int(np.floor(x * days[k] + 1e-9))
                rem.append(tot[u, k] - C[u, k, dk])
                share.append(C[u, k, dk] / tot[u, k])
        rem, share = np.array(rem), np.array(share)
        K = len(rem)
        cases.append({
            "acc": int(ids[u]), "y": year0 + m // 12, "m": m % 12 + 1, "t": t_, "S": S, "B": B,
            "past": past,
            "py": {"K": K, "rmed": float(np.median(rem)), "share": float(np.median(share)),
                   "p1": float((np.sum(S + rem > B) + 0.5) / (K + 1))},
        })
    out = HERE / "results" / ("m1_cases.json" if source == "berka" else f"m1_cases_{source}.json")
    out.write_text(json.dumps({"source": source, "kappa": kappa, "seed": seed, "cases": cases}), encoding="utf-8")
    print(f"{len(cases)} cases from {len(cand)} candidates -> {out}")


if __name__ == "__main__":
    main()
