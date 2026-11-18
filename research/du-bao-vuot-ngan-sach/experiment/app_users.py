"""Pick the converted users loaded into the real FlowMoney app, and export their transactions shifted to 2026.

For each user: a source November (2016-2019, inside the test window), day 10 checkpoint, spent <= budget, K = 6
spending months among the six before. Picks 2 months that end over budget and 3 that do not, one per income tier
where possible (seeded). Exports May..Oct in full and November days 1..10 of the source year, moved to 2026 (same
month lengths). Day-10 times are clamped to 08:00 at the latest so nothing lies in the future at the test time;
the Dart check uses the exported timestamps as they are.

Budget loaded in the app = monthly total budget for November 2026 = kappa (1.0) x mean of Aug..Oct spending, the
same B as the experiment. Writes results/app_users.json (also forecasts p1, p2, p3 of the experiment).

Run:  python -u app_users.py
"""
import json
import pathlib

import numpy as np

import tabformer
import tabformer_vn
from vn_mapping import CATEGORIES, TIERS

HERE = pathlib.Path(__file__).resolve().parent
SEED = 7
NOVS = {(y - tabformer.FIRST_YEAR) * 12 + 10: y for y in (2016, 2017, 2018, 2019)}

if __name__ == "__main__":
    z = np.load(HERE / "results" / "cases_vn.npz")
    C = {k: z[k] for k in z.files}
    t = tabformer_vn.rows()
    vn, f = tabformer_vn.convert(t)
    minute = tabformer.transactions()["min"]
    rng = np.random.default_rng(SEED)
    ok = (C["t"] == 10) & (C["S"] <= C["B"]) & (C["K"] == 6) & np.isin(C["month"], list(NOVS))
    picked = []
    for o, want in ((1, 2), (0, 3)):
        idx = list(rng.permutation(np.nonzero(ok & (C["o"] == o))[0]))
        for i in idx:
            tier = f[int(C["uid"][i])][0]
            if tier in [p[1] for p in picked] and len(set(p[1] for p in picked)) < len(TIERS):
                continue
            picked.append((int(i), tier))
            if sum(1 for p in picked if C["o"][p[0]] == o) == want:
                break
    mi = (vn["y"] - tabformer.FIRST_YEAR) * 12 + vn["m"] - 1
    out = []
    for n, (i, tier) in enumerate(picked, 1):
        u, m = int(C["uid"][i]), int(C["month"][i])
        year = NOVS[m]
        # April too: the app drops a period that starts before the account's first transaction, so May must
        # not be the first month for the app to learn six periods (May..Oct) like the experiment.
        sel = (vn["u"] == u) & (mi >= m - 7) & (mi <= m) & ~((mi == m) & (vn["d"] > 10))
        tx = []
        for j in np.nonzero(sel)[0]:
            mon = int(vn["m"][j])
            mm = int(minute[j])
            if mon == 11 and int(vn["d"][j]) == 10:
                mm = min(mm, 8 * 60)
            tx.append({"date": f"2026-{mon:02d}-{int(vn['d'][j]):02d}T{mm // 60:02d}:{mm % 60:02d}:00",
                       "amount": int(vn["a"][j]), "category": CATEGORIES[int(vn["cat"][j])]})
        # Synthetic salary on day 1 of every month (1.3 x the user's tier target), only so the wallet balance stays
        # positive in the app; income never enters a spending forecast.
        salary = int(round(1.3 * f[u][3] / 100_000) * 100_000)
        income = [{"date": f"2026-{mon:02d}-01T07:00:00", "amount": salary, "category": "Lương"} for mon in range(4, 12)]
        out.append({"n": n, "uid": u, "source_year": year, "tier": TIERS[tier][0], "budget": float(C["B"][i]),
                    "income": income,
                    "spent_day10": float(C["S"][i]), "month_total": float(C["tot"][i]), "over": int(C["o"][i]),
                    "p1": float(C["p1"][i]), "p2": float(C["p2"][i]), "p3": float(C["p3"][i]),
                    "rmed_core": float(C["rmed"][i]), "transactions": tx})
        print(f"#{n} uid={u} {year} {TIERS[tier][0]} B={C['B'][i]:,.0f} S={C['S'][i]:,.0f} tot={C['tot'][i]:,.0f} "
              f"over={C['o'][i]} p1={C['p1'][i]:.2f} p2={C['p2'][i]:.2f} p3={C['p3'][i]:.2f} tx={len(tx)}")
    (HERE / "results" / "app_users.json").write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
