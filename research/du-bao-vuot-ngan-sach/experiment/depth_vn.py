"""In-depth breakdown for the single research question (kappa = 1.0, VND-converted TabFormer).

The supervisor asked (2026-11-12) for a short paper with ONE research question studied in depth. The question is
which forecaster gives the most reliable overrun probability and the earliest warning; this script breaks the
headline result of results/tabformer_vn.json down by
  - checkpoint day (Brier, ECE; warning thresholds are per month, so no per-day recall),
  - income tier (Brier, ECE, and recall / false alarms / lead at the thresholds chosen on all users),
  - volatility of the user's past monthly totals (tertiles of the M3 feature cv),
and adds per-user bootstrap intervals for M3 - M1 and M2 - M1 in every group.

Reads results/cases_vn.npz (rows of cases_vn.py, same seed and refit schedule as the paper) and the tier of each
user from tabformer_vn.factors. Writes results/depth_vn.json.

Run:  python -u depth_vn.py
"""
import json
import pathlib

import numpy as np

from core import ece
from tabformer_vn import TIERS, factors, rows

HERE = pathlib.Path(__file__).resolve().parent
METHODS = ["p1", "p2", "p3"]
B_BOOT = 2000
SEED = 2026


def brier(p, o):
    return float(np.mean((p - o) ** 2))


def user_diff_ci(R, mask, a, b, rng):
    """Mean over users of (Brier_a - Brier_b), with a 95% bootstrap interval over users."""
    u = R["user"][mask]
    sa = (R[a][mask] - R["o"][mask]) ** 2
    sb = (R[b][mask] - R["o"][mask]) ** 2
    uu, inv = np.unique(u, return_inverse=True)
    n = np.bincount(inv)
    d = np.bincount(inv, weights=sa) / n - np.bincount(inv, weights=sb) / n
    boots = np.array([d[rng.integers(0, len(d), len(d))].mean() for _ in range(B_BOOT)])
    return {"mean": float(d.mean()), "lo": float(np.quantile(boots, 0.025)), "hi": float(np.quantile(boots, 0.975)),
            "share_users_better": float(np.mean(d < 0)), "users": int(len(d))}


def warning_at(R, sub, p, thr):
    """Recall, false-alarm rate and median lead at a fixed threshold, over the user-months in `sub`."""
    key = R["user"][sub] * 1000 + R["month"][sub]
    uniq, inv = np.unique(key, return_inverse=True)
    o_m = np.zeros(len(uniq), dtype=int)
    cross_m = np.zeros(len(uniq))
    o_m[inv] = R["o"][sub]
    cross_m[inv] = R["cross"][sub]
    live = R["S"][sub] <= R["B"][sub]
    hit = live & (p[sub] >= thr)
    first = np.full(len(uniq), 999.0)
    np.minimum.at(first, inv[hit], R["t"][sub][hit].astype(float))
    alerted = first < 999
    det = alerted & (o_m == 1)
    leads = cross_m[det] - first[det]
    return {"recall": float(det.sum() / max((o_m == 1).sum(), 1)),
            "far": float(np.sum(alerted & (o_m == 0)) / max((o_m == 0).sum(), 1)),
            "lead_median": float(np.median(leads)) if len(leads) else 0.0,
            "months": int(len(uniq)), "overrun_months": int((o_m == 1).sum())}


def group_scores(R, live, rng):
    out = {"n": int(live.sum()), "base_rate": float(R["o"][live].mean())}
    for m in METHODS:
        out[m] = {"brier": brier(R[m][live], R["o"][live]), "ece": float(ece(R[m][live], R["o"][live]))}
    out["d31"] = user_diff_ci(R, live, "p3", "p1", rng)
    out["d21"] = user_diff_ci(R, live, "p2", "p1", rng)
    out["d32"] = user_diff_ci(R, live, "p3", "p2", rng)
    return out


if __name__ == "__main__":
    z = np.load(HERE / "results" / "cases_vn.npz")
    R = {k: z[k] for k in z.files}
    res = json.loads((HERE / "results" / "tabformer_vn.json").read_text(encoding="utf-8"))["kappa"]["1.0"]
    thr = {m: res["at_far10"][m]["thr"] for m in METHODS}
    live = R["S"] <= R["B"]
    rng = np.random.default_rng(SEED)

    f = factors(rows())
    tier = np.array([f[int(u)][0] for u in R["uid"]])

    out = {"kappa": 1.0, "thresholds_all_users": thr, "bootstrap": B_BOOT, "seed": SEED,
           "check_overall_brier": {m: brier(R[m][live], R["o"][live]) for m in METHODS},
           "check_reported_brier": {m: res["overall"][m]["brier"] for m in METHODS},
           "overall": group_scores(R, live, rng), "by_checkpoint": {}, "by_tier": {}, "by_cv_tertile": {}}

    for t in sorted(np.unique(R["t"])):
        out["by_checkpoint"][str(int(t))] = group_scores(R, live & (R["t"] == t), rng)

    everyone = np.ones(len(live), dtype=bool)
    out["warning_all"] = {m: warning_at(R, everyone, R[m], thr[m]) for m in METHODS}
    for i, (name, share, lo, hi) in enumerate(TIERS):
        sel = tier == i
        g = group_scores(R, live & sel, rng)
        g["tier"] = name
        g["users"] = int(len(np.unique(R["user"][sel])))
        g["warning"] = {m: warning_at(R, sel, R[m], thr[m]) for m in METHODS}
        out["by_tier"][str(i)] = g

    # Volatility of past monthly totals: tertiles over users (median cv per user), so a user stays in one group.
    uu, inv = np.unique(R["user"], return_inverse=True)
    ucv = np.array([np.median(R["cv"][inv == k]) for k in range(len(uu))])
    cuts = np.quantile(ucv, [1 / 3, 2 / 3])
    grp = np.searchsorted(cuts, ucv[inv], side="right")
    out["cv_cuts"] = [float(c) for c in cuts]
    for g_i, name in enumerate(["low", "middle", "high"]):
        sel = grp == g_i
        g = group_scores(R, live & sel, rng)
        g["cv_median"] = float(np.median(ucv[np.searchsorted(cuts, ucv, side="right") == g_i]))
        g["users"] = int(len(np.unique(R["user"][sel])))
        g["warning"] = {m: warning_at(R, sel, R[m], thr[m]) for m in METHODS}
        out["by_cv_tertile"][name] = g

    p = HERE / "results" / "depth_vn.json"
    p.write_text(json.dumps(out, indent=1), encoding="utf-8")
    print(json.dumps(out, indent=1)[:6000])
