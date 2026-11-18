"""Load the PKDD-99 Berka data (Section V-A) into the layout used by core.py.

Raw files: ../data/raw/trans.asc and account.asc (semicolon-separated, dates as YYMMDD), downloaded from
https://github.com/ldaniel/R_Bank_Berka (data/), a mirror of the PKDD-99 Discovery Challenge files.
SHA-256 at download (2026-11-09): trans.asc 111c70dc…19bd3e, account.asc 215f4bfc…2432eb.

Spending = debit transactions (type VYDAJ or VYBER) except bank charges: statement fees (k_symbol SLUZBY) and
penalty interest (SANKC. UROK). With exclude_fixed=True, loan repayments (UVER) and household standing
payments (SIPO) are removed too (sensitivity analysis). Calendar months 1993-01 to 1998-12 are the periods.
An account starts in the first full month after it was opened; accounts with fewer than 18 months are dropped.
"""
import calendar
import pathlib

import numpy as np
import pandas as pd

RAW = pathlib.Path(__file__).resolve().parent.parent / "data" / "raw"
BANK_CHARGES = {"SLUZBY", "SANKC. UROK"}
FIXED = {"UVER", "SIPO"}
MIN_MONTHS = 18


def load(exclude_fixed=False):
    t = pd.read_csv(RAW / "trans.asc", sep=";", low_memory=False)
    a = pd.read_csv(RAW / "account.asc", sep=";")
    k = t["k_symbol"].fillna("").str.strip()
    spend = t["type"].isin(["VYDAJ", "VYBER"]) & ~k.isin(BANK_CHARGES)
    if exclude_fixed:
        spend &= ~k.isin(FIXED)
    t = t[spend]
    months = 72
    days = np.array([calendar.monthrange(1993 + m // 12, m % 12 + 1)[1] for m in range(months)])
    acc_month = ((a["date"] // 10000) - 93) * 12 + (a["date"] // 100 % 100) - 1
    start = (acc_month + 1).to_numpy()
    keep = start <= months - MIN_MONTHS
    ids = a["account_id"].to_numpy()[keep]
    start = start[keep]
    pos = {acc: i for i, acc in enumerate(ids)}
    t = t[t["account_id"].isin(pos)]
    mi = ((t["date"] // 10000) - 93) * 12 + (t["date"] // 100 % 100) - 1
    di = t["date"] % 100 - 1
    ui = t["account_id"].map(pos)
    Y = np.zeros((len(ids), months, 31))
    np.add.at(Y, (ui.to_numpy(), mi.to_numpy(), di.to_numpy()), t["amount"].to_numpy())
    # transactions before an account's start month are dropped from its series
    for i in range(len(ids)):
        Y[i, :start[i]] = 0.0
    return Y, days, start, ids
