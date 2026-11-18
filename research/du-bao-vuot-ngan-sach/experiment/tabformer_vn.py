"""TabFormer converted to a Vietnamese setting (rules in vn_mapping.py).

Each user gets one factor f = target / (median monthly USD spending over the user's active months from 2015),
where the target (VND/month) comes from the user's income tier. Every transaction becomes
max(1,000, round(a * f / 1,000) * 1,000) VND and carries the FlowMoney category of its MCC.

Because the budget is kappa times the user's own three-month average and every M3 feature is divided by that
budget, a per-user factor leaves every forecast unchanged; only the 1,000 VND rounding can move numbers.
run_tabformer_vn.py checks this by re-running the experiment.

Run:  python -u tabformer_vn.py      (writes results/tabformer_vn_profile.json)
"""
import json
import pathlib

import numpy as np

import tabformer
from vn_mapping import CATEGORIES, MCC, ROUND_VND, STATUS, TIERS

HERE = pathlib.Path(__file__).resolve().parent
MCC_NPZ = tabformer.RAW / "tabformer_2015_mcc.npz"


def rows():
    z = np.load(MCC_NPZ)
    return {k: z[k] for k in z.files}


def factors(t):
    """Per-user tier and factor. Returns dict user -> (tier index, factor, median USD, target VND)."""
    mi = (t["y"] - tabformer.FIRST_YEAR) * 12 + t["m"] - 1
    key = t["u"].astype(np.int64) * 1000 + mi
    uk, inv = np.unique(key, return_inverse=True)
    month_sum = np.bincount(inv, weights=t["a"])
    users = uk // 1000
    out = {}
    uu = np.unique(users)
    med = np.array([np.median(month_sum[users == u]) for u in uu])
    rank = med.argsort().argsort() / max(len(uu) - 1, 1)          # 0..1, ties broken by order
    edges = np.cumsum([0] + [s for _, s, _, _ in TIERS])
    for u, m, r in zip(uu, med, rank):
        k = min(int(np.searchsorted(edges, r, side="right")) - 1, len(TIERS) - 1)
        _, _, lo, hi = TIERS[k]
        w = (r - edges[k]) / (edges[k + 1] - edges[k])
        target = lo * (hi / lo) ** min(max(w, 0.0), 1.0)
        out[int(u)] = (k, target / m, float(m), float(target))
    return out


def convert(t=None):
    t = rows() if t is None else t
    f = factors(t)
    fac = np.zeros(t["u"].max() + 1)
    for u, (_, x, _, _) in f.items():
        fac[u] = x
    vnd = np.maximum(ROUND_VND, np.round(t["a"] * fac[t["u"]] / ROUND_VND) * ROUND_VND)
    cat_index = {c: i for i, c in enumerate(CATEGORIES)}
    lut = np.full(t["mcc"].max() + 1, -1)
    for code, (_, cat, _) in MCC.items():
        lut[code] = cat_index[cat]
    cat = lut[t["mcc"]]
    assert (cat >= 0).all(), "MCC without a category"
    vn = dict(t)
    vn["a"] = vnd
    vn["cat"] = cat
    return vn, f


def load():
    vn, _ = convert()
    return tabformer.load({k: vn[k] for k in ["u", "y", "m", "d", "a"]})


if __name__ == "__main__":
    t = rows()
    vn, f = convert(t)
    tiers = [{"tier": n, "users": int(sum(1 for v in f.values() if v[0] == i)),
              "target_lo": lo, "target_hi": hi} for i, (n, _, lo, hi) in enumerate(TIERS)]
    share = np.bincount(vn["cat"], weights=vn["a"], minlength=len(CATEGORIES))
    cnt = np.bincount(vn["cat"], minlength=len(CATEGORIES))
    amt = vn["a"]
    prof = {"mapping_status": STATUS, "users": len(f), "rows": int(len(amt)), "tiers": tiers,
            "category_share_pct": {c: round(100 * float(s / share.sum()), 2) for c, s in zip(CATEGORIES, share)},
            "category_rows": {c: int(n) for c, n in zip(CATEGORIES, cnt)},
            "amount_vnd_quantiles": {q: float(np.quantile(amt, float(q))) for q in ["0.1", "0.25", "0.5", "0.75", "0.9", "0.99"]},
            "share_at_floor_1000": float(np.mean(amt == ROUND_VND)),
            "factor_quantiles": {q: float(np.quantile([v[1] for v in f.values()], float(q))) for q in ["0.1", "0.5", "0.9"]}}
    (HERE / "results" / "tabformer_vn_profile.json").write_text(json.dumps(prof, ensure_ascii=False, indent=1), encoding="utf-8")
    print(json.dumps(prof, ensure_ascii=False, indent=1))
