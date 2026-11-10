"""Descriptive statistics of the converted data for the 1,518 users kept by run_tabformer_vn.py (paper, Table II).

Run:  python -u data_profile_vn.py   ->  results/data_profile_vn.json
Same selection as run_tabformer_vn.py: at least MIN_MONTHS months from 2015-01 and spending up to the last month.
Rows are counted inside the months used (2015-01..2020-01) for the kept users only.
"""
import json
import pathlib

import numpy as np

import tabformer
from tabformer_vn import convert, rows
from vn_mapping import CATEGORIES, STATUS, TIERS

HERE = pathlib.Path(__file__).resolve().parent

if __name__ == "__main__":
    t = rows()
    vn, f = convert(t)
    Y, days, start, end, ids, _ = tabformer.load({k: vn[k] for k in ["u", "y", "m", "d", "a"]})
    full = end == Y.shape[1] - 1
    Y, start, ids = Y[full], start[full], ids[full]
    months = Y.shape[1]
    mi = (vn["y"] - tabformer.FIRST_YEAR) * 12 + vn["m"] - 1
    sel = np.isin(vn["u"], ids) & (mi < months)
    a, cat, u = vn["a"][sel], vn["cat"][sel], vn["u"][sel]

    tiers = []
    for i, (name, share, lo, hi) in enumerate(TIERS):
        us = [x for x in ids if f[int(x)][0] == i]
        pos = np.flatnonzero(np.isin(ids, us))
        med = [float(np.median(Y[p, start[p]:].sum(axis=1))) for p in pos]
        tiers.append({"tier": name, "assumed_share": share, "lo": lo, "hi": hi, "users": len(us),
                      "median_monthly_vnd": float(np.median(med)) if med else None})
    totals = np.concatenate([Y[p, start[p]:].sum(axis=1) for p in range(len(ids))])
    # transactions and spending days per user-month with spending; same-payment repeats (same user, MCC, exact USD
    # amount seen in >= 6 distinct months, the definition of profile_tabformer.py) - all on the kept users only
    import pandas as pd
    raw = pd.DataFrame({"u": t["u"][sel], "ym": mi[sel], "d": t["d"][sel], "mcc": t["mcc"][sel], "usd": t["a"][sel]})
    um = raw.groupby(["u", "ym"]).agg(n=("d", "size"), nd=("d", "nunique"))
    rec = raw.groupby(["u", "mcc", "usd"]).ym.nunique()
    rmask = raw.set_index(["u", "mcc", "usd"]).index.isin(rec[rec >= 6].index)
    active_months = int(sum(months - s for s in start))
    share = np.bincount(cat, weights=a, minlength=len(CATEGORIES))
    cnt = np.bincount(cat, minlength=len(CATEGORIES))
    prof = {
        "mapping_status": STATUS, "users": int(len(ids)), "rows": int(len(a)), "user_months": active_months,
        "months_per_user_median": float(np.median(months - start)),
        "user_months_with_spending": int(len(um)),
        "tx_per_user_month_median": float(um.n.median()),
        "spending_days_per_user_month_median": float(um.nd.median()),
        "repeat_payment_share_of_amount": round(float(raw.usd[rmask].sum() / raw.usd.sum()), 3),
        "tiers": tiers,
        "category_amount_share_pct": {c: round(100 * float(s / share.sum()), 1) for c, s in zip(CATEGORIES, share)},
        "category_row_share_pct": {c: round(100 * float(n / cnt.sum()), 1) for c, n in zip(CATEGORIES, cnt)},
        "amount_vnd_quantiles": {q: float(np.quantile(a, float(q))) for q in ["0.1", "0.5", "0.9", "0.99"]},
        "monthly_total_vnd_quantiles": {q: float(np.quantile(totals, float(q))) for q in ["0.1", "0.5", "0.9"]},
    }
    (HERE / "results" / "data_profile_vn.json").write_text(json.dumps(prof, ensure_ascii=False, indent=1), encoding="utf-8")
    print(json.dumps(prof, ensure_ascii=False, indent=1))
