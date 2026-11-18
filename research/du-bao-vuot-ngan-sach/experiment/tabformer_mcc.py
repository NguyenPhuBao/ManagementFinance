"""Merchant category codes (MCC) of the TabFormer spending rows, for the Vietnamese-standard conversion.

Same filter as tabformer._parse (year >= 2015, amount > 0, not fraud), row order kept, so the arrays line up
with tabformer_2015.npz. Writes data/raw/tabformer/tabformer_2015_mcc.npz (u, y, m, d, a, mcc) and prints the
spending share of every MCC.

Run:  python -u tabformer_mcc.py
"""
import numpy as np
import pandas as pd

from tabformer import CSV, FIRST_YEAR, RAW, transactions

OUT = RAW / "tabformer_2015_mcc.npz"

if __name__ == "__main__":
    cols = ["User", "Year", "Month", "Day", "Amount", "Is Fraud?", "MCC"]
    keep = []
    for ch in pd.read_csv(CSV, usecols=cols, chunksize=2_000_000):
        ch = ch[ch.Year >= FIRST_YEAR]
        amt = ch["Amount"].str.replace("$", "", regex=False).astype(float)
        ok = (amt > 0) & (ch["Is Fraud?"] == "No")
        ch = ch[ok]
        keep.append(pd.DataFrame({"u": ch.User.to_numpy(), "y": ch.Year.to_numpy(), "m": ch.Month.to_numpy(),
                                  "d": ch.Day.to_numpy(), "a": amt[ok].to_numpy(), "mcc": ch.MCC.to_numpy()}))
        print("chunk", len(keep), flush=True)
    t = pd.concat(keep, ignore_index=True)
    old = transactions()
    same = len(old["u"]) == len(t) and all(np.array_equal(old[k], t[k].to_numpy()) for k in ["u", "y", "m", "d", "a"])
    print("rows", len(t), "| aligned with tabformer_2015.npz:", same, flush=True)
    np.savez_compressed(OUT, **{k: t[k].to_numpy() for k in t.columns})
    share = t.groupby("mcc")["a"].agg(["sum", "count"]).sort_values("sum", ascending=False)
    share["pct"] = 100 * share["sum"] / share["sum"].sum()
    print("MCC_COUNT", len(share))
    for mcc, r in share.iterrows():
        print(f"MCC|{mcc}|{r['count']:.0f}|{r['pct']:.3f}")
