"""Profile IBM TabFormer card_transaction.v1.csv to judge whether it fits the budget-overrun study."""
import pathlib

import numpy as np
import pandas as pd

F = pathlib.Path(__file__).resolve().parent.parent / "data" / "raw" / "tabformer" / "card_transaction.v1.csv"
cols = ["User", "Year", "Month", "Day", "Time", "Amount", "MCC", "Errors?", "Is Fraud?", "Use Chip"]
parts = []
for ch in pd.read_csv(F, usecols=cols, chunksize=2_000_000, dtype={"Errors?": "string", "Use Chip": "category"}):
    ch["Amount"] = ch["Amount"].str.replace("$", "", regex=False).astype(float)
    ch["hour"] = ch["Time"].str.slice(0, 2).astype(int)
    parts.append(ch.drop(columns=["Time"]))
    print("chunk", len(parts), flush=True)
d = pd.concat(parts, ignore_index=True)
print("rows", len(d), "users", d.User.nunique())
print("years", d.Year.min(), d.Year.max())
print("rows per year (last 12):\n", d.Year.value_counts().sort_index().tail(12).to_string())
print("negative amounts", (d.Amount < 0).mean(), "zero", (d.Amount == 0).mean())
print("fraud share", (d["Is Fraud?"] == "Yes").mean(), "errors share", d["Errors?"].notna().mean())
print("use chip", d["Use Chip"].value_counts(normalize=True).round(3).to_dict())
print("hour distribution (share by hour):", d.hour.value_counts(normalize=True).sort_index().round(3).to_dict())
spend = d[(d.Amount > 0) & (d["Is Fraud?"] == "No")]
spend = spend.assign(ym=spend.Year * 12 + spend.Month - 1)
um = spend.groupby(["User", "ym"]).agg(tot=("Amount", "sum"), n=("Amount", "size"),
                                        ndays=("Day", "nunique"))
span = um.reset_index().groupby("User").ym.agg(["min", "max", "count"])
span["len"] = span["max"] - span["min"] + 1
print("months span per user: median", span.len.median(), "p10", span.len.quantile(.1), "p90", span.len.quantile(.9))
print("users with >=18 months:", (span.len >= 18).sum(), "| active-month share median", (span["count"] / span.len).median())
recent = um.reset_index()
recent = recent[recent.ym >= 2015 * 12]
print("users active 2015+ :", recent.User.nunique(), "with >=18 months 2015+:", (recent.groupby("User").size() >= 18).sum())
print("per user-month: median tx", um.n.median(), "median days with spend", um.ndays.median(),
      "median total $", round(um.tot.median(), 1))
cv = um.reset_index().groupby("User").tot.agg(lambda s: s.std() / s.mean())
print("CV of monthly totals per user: median", round(cv.median(), 3), "p10", round(cv.quantile(.1), 3), "p90", round(cv.quantile(.9), 3))
top = spend.groupby("MCC").Amount.sum().sort_values(ascending=False)
print("top MCC by amount share:", (top / top.sum()).head(8).round(3).to_dict())
# recurring same-amount payments: share of amount in (user, MCC, amount) seen in >=6 distinct months
rec = spend.groupby(["User", "MCC", "Amount"]).ym.nunique()
rec_keys = rec[rec >= 6].index
mask = spend.set_index(["User", "MCC", "Amount"]).index.isin(rec_keys)
print("share of spend in exact-amount repeats >=6 months:", round(spend.Amount[mask].sum() / spend.Amount.sum(), 3))
