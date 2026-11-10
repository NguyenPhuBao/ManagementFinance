"""Cases for the app's data-path test (tier 2): src/Client-app/test/features/budget/data/du_bao_vuot_nguon_test.dart
loads each user into an in-memory copy of the app's SQLite schema and asks DuBaoVuotNguon, as the budget page does.

Sample: N rows of results/cases_vn.npz (kappa 1.0, test months), one per user, seeded. Per row: every transaction of
the user from their first month to day t of the scored month, with its real minute of day; the budget B; the
expected p0, p1, p2 (core.build_rows) and p3 (same fixed fit the app embeds). The Dart test adds rows the app must
ignore (salary, an opening balance months earlier, a balance adjustment, a transfer, a deleted expense).

Run:  python -u app_drift_cases.py [N=300] [seed=11]  ->  results/app_drift_cases.json (gitignored, ~MBs)
"""
import json
import pathlib
import sys

import numpy as np

import tabformer
import tabformer_vn
from app_m23 import p3_fixed

HERE = pathlib.Path(__file__).resolve().parent

if __name__ == "__main__":
    n_want = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 11
    z = np.load(HERE / "results" / "cases_vn.npz")
    C = {k: z[k] for k in z.files}
    fit = json.loads((HERE / "results" / "m3_coef_vn.json").read_text(encoding="utf-8"))
    p3 = p3_fixed(C, fit)
    rng = np.random.default_rng(seed)
    order = rng.permutation(len(C["o"]))
    picked, seen = [], set()
    for i in order:
        u = int(C["uid"][i])
        if u in seen:
            continue
        seen.add(u)
        picked.append(int(i))
        if len(picked) == n_want:
            break
    vn, _ = tabformer_vn.convert()
    minute = tabformer.transactions()["min"]
    mi = (vn["y"] - tabformer.FIRST_YEAR) * 12 + vn["m"] - 1
    by_user = {}
    for j in np.argsort(vn["u"], kind="stable"):
        by_user.setdefault(int(vn["u"][j]), []).append(int(j))
    out = []
    for i in picked:
        u, m, t = int(C["uid"][i]), int(C["month"][i]), int(C["t"][i])
        js = [j for j in by_user[u] if mi[j] < m or (mi[j] == m and vn["d"][j] <= t)]
        out.append({"uid": u, "y": tabformer.FIRST_YEAR + m // 12, "mo": m % 12 + 1, "t": t, "B": float(C["B"][i]),
                    "o": int(C["o"][i]),
                    "exp": [float(C["p0"][i]), float(C["p1"][i]), float(C["p2"][i]), float(p3[i])],
                    "tx": [[int(vn["y"][j]), int(vn["m"][j]), int(vn["d"][j]), int(minute[j]), int(vn["a"][j])]
                           for j in js]})
    path = HERE / "results" / "app_drift_cases.json"
    path.write_text(json.dumps(out), encoding="utf-8")
    print(f"{len(out)} users, {sum(len(c['tx']) for c in out)} transactions, "
          f"{sum(c['o'] for c in out)} over budget, {path.stat().st_size / 1e6:.1f} MB", flush=True)
