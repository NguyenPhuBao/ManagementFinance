"""Load IBM TabFormer synthetic card transactions (2015 onwards) into the layout used by core.py.

Raw file: ../data/raw/tabformer/card_transaction.v1.csv, from transactions.tgz in https://github.com/IBM/TabFormer
(data/credit_card, Apache-2.0; synthetic data from the generator of Altman, arXiv:1910.03033).
SHA-256 of transactions.tgz at download (2026-11-09): e9f589a0958f40d60f81b1a2e8428db86e00c05755caf44fb055827976c0efa2.

Spending = transactions with a positive amount that are not marked as fraud (refunds are negative and are
dropped; transactions with an "Errors?" note are kept). A user's cards are pooled. Periods are calendar months
from 2015-01 to the last full month in the file. A user starts at their first month with spending in that
window and ends at their last; users spanning fewer than MIN_MONTHS months are dropped, and months after a
user's last month are not scored (end[] is passed to core.py through `start`/`end`).
The parsed spending rows are cached in tabformer_2015.npz next to the CSV (including the time of day, for the
check against the app's Dart code).
"""
import calendar
import pathlib

import numpy as np
import pandas as pd

RAW = pathlib.Path(__file__).resolve().parent.parent / "data" / "raw" / "tabformer"
CSV, CACHE = RAW / "card_transaction.v1.csv", RAW / "tabformer_2015.npz"
FIRST_YEAR = 2015
MIN_MONTHS = 18


def _parse():
    cols = ["User", "Year", "Month", "Day", "Time", "Amount", "Is Fraud?"]
    keep = []
    for ch in pd.read_csv(CSV, usecols=cols, chunksize=2_000_000):
        ch = ch[ch.Year >= FIRST_YEAR]
        amt = ch["Amount"].str.replace("$", "", regex=False).astype(float)
        ok = (amt > 0) & (ch["Is Fraud?"] == "No")
        ch = ch[ok]
        hm = ch["Time"].str.split(":", expand=True).astype(int)
        keep.append(pd.DataFrame({"u": ch.User.to_numpy(), "y": ch.Year.to_numpy(), "m": ch.Month.to_numpy(),
                                  "d": ch.Day.to_numpy(), "min": (hm[0] * 60 + hm[1]).to_numpy(), "a": amt[ok].to_numpy()}))
    t = pd.concat(keep, ignore_index=True)
    np.savez_compressed(CACHE, **{k: t[k].to_numpy() for k in t.columns})


def transactions():
    if not CACHE.exists():
        _parse()
    z = np.load(CACHE)
    return {k: z[k] for k in z.files}


def load():
    t = transactions()
    mi = (t["y"] - FIRST_YEAR) * 12 + t["m"] - 1
    last_day = t["y"].max() * 10000 + t["m"][t["y"] == t["y"].max()].max() * 100
    ly, lm = int(t["y"].max()), int(t["m"][t["y"] == t["y"].max()].max())
    full_last = t["d"][(t["y"] == ly) & (t["m"] == lm)].max() == calendar.monthrange(ly, lm)[1]
    months = int(mi.max()) + (1 if full_last else 0)          # drop a partial last month
    sel = mi < months
    users = np.unique(t["u"][sel])
    pos = np.full(users.max() + 1, -1)
    pos[users] = np.arange(len(users))
    ui, mi_s = pos[t["u"][sel]], mi[sel]
    Y = np.zeros((len(users), months, 31))
    np.add.at(Y, (ui, mi_s, t["d"][sel] - 1), t["a"][sel])
    active = Y.sum(axis=2) > 0
    first = active.argmax(axis=1)
    last = months - 1 - active[:, ::-1].argmax(axis=1)
    keep = (last - first + 1) >= MIN_MONTHS
    days = np.array([calendar.monthrange(FIRST_YEAR + m // 12, m % 12 + 1)[1] for m in range(months)])
    return Y[keep], days, first[keep], last[keep], users[keep], (ly, lm, bool(full_last), last_day)


if __name__ == "__main__":
    Y, days, start, end, ids, info = load()
    print("last month in file", info[:3], "| months used", Y.shape[1], "| users", len(ids))
    print("users ending before the last month:", int((end < Y.shape[1] - 1).sum()),
          "| end month quantiles", np.quantile(end, [0, 0.1, 0.5]).tolist())
    print("start month quantiles", np.quantile(start, [0.5, 0.9, 1]).tolist())
