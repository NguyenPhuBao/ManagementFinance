"""Forecasters M0-M3, rolling-origin evaluation and metrics, shared by the synthetic and the Berka runs.

Data layout: Y[user, month, day-1] = amount spent that day (padded to 31 days); days[month] = days in that
calendar month; start[user] = first month the user has data. A row (user, month m, checkpoint t) exists when
the user has six earlier months (m - 6 >= start), the budget is positive, and at least one of the six earlier
months has spending. Past periods with no spending are skipped, as in FlowMoney's `nhip_chi.dart`; with
fewer than three such periods M1 falls back to M0, as the application does.
"""
import json
import os
import time

import numpy as np
from scipy.stats import norm
from sklearn.linear_model import QuantileRegressor
from sklearn.metrics import roc_auc_score

CHECKPOINTS = [5, 10, 15, 20, 25]
KAPPAS = [float(k) for k in os.environ.get("KAPPAS", "1.0,0.9,1.1").split(",")]  # 1.0 first: the figures need only it, and results are saved after each kappa
TAUS = np.round(np.arange(0.05, 0.951, 0.05), 2)
LAMBDAS = [0.001, 0.002, 0.005, 0.01, 0.02, 0.05, 0.1, 0.2]  # widened 2026-11-09: 0.02 sat at the edge (lambda_scan.py)
HISTORY = 6                # past periods used by M0/M1 (FlowMoney: kSoKyHocToiDa = 6)
MIN_K = 3                  # FlowMoney: kSoKyHocToiThieu = 3
REFIT_EVERY, M3_ROWS = 6, int(os.environ.get("M3_ROWS", 4000))  # highs time grows faster than linearly: 4,000 rows ~0.6 s/fit, 15,000 ~8 s/fit
METHODS = ["p0", "p1", "p2", "p3"]


def ewma_states(Y, days, lam, start):
    """mu, v after each day, laid out as [user, month, day-index]. Each user starts at their own first month;
    the first 30 days initialise mu and v."""
    n, months, _ = Y.shape
    offsets = np.concatenate([[0], np.cumsum(days)])
    flat = np.concatenate([Y[:, m, :days[m]] for m in range(months)], axis=1)
    s = offsets[start]
    idx = s[:, None] + np.arange(30)[None, :]
    init = flat[np.arange(n)[:, None], idx]
    mu, v = init.mean(axis=1), init.var(axis=1)
    MU = np.repeat(mu[:, None], flat.shape[1], axis=1)
    V = np.repeat(v[:, None], flat.shape[1], axis=1)
    for d in range(flat.shape[1]):
        act = d >= s + 30
        if not act.any():
            continue
        y = flat[:, d]
        v_new = lam * (y - mu) ** 2 + (1 - lam) * v
        mu_new = lam * y + (1 - lam) * mu
        v = np.where(act, v_new, v)
        mu = np.where(act, mu_new, mu)
        MU[:, d] = mu
        V[:, d] = v
    out_mu = np.zeros((n, months, 31))
    out_v = np.zeros((n, months, 31))
    for m in range(months):
        out_mu[:, m, :days[m]] = MU[:, offsets[m]:offsets[m + 1]]
        out_v[:, m, :days[m]] = V[:, offsets[m]:offsets[m + 1]]
    return out_mu, out_v


def build_rows(Y, days, start, pattern, kappa, lam):
    n, months, _ = Y.shape
    C = np.concatenate([np.zeros((n, months, 1)), np.cumsum(Y, axis=2)], axis=2)  # C[..., d] = spent after day d
    tot = np.array([C[:, m, days[m]] for m in range(months)]).T
    MU, V = ewma_states(Y, days, lam, start)
    keys = ["user", "month", "t", "x", "S", "B", "tot", "o", "cross", "pattern", "K",
            "p0", "p1", "p2", "rmed", "nmu", "nsd", "cal", "cv"]
    rows = {k: [] for k in keys}
    for m in range(HISTORY, months):
        T = days[m]
        past = list(range(m - HISTORY, m))
        tp = tot[:, past]                                   # (n, 6)
        pos = tp > 0
        K = pos.sum(axis=1)
        B = kappa * tot[:, m - 3:m].mean(axis=1)
        ok = (m - HISTORY >= start) & (B > 0) & (K >= 1)
        if not ok.any():
            continue
        cross = np.full(n, 999)
        over = C[:, m, 1:T + 1] > B[:, None]
        has = over.any(axis=1)
        cross[has] = over[has].argmax(axis=1) + 1
        with np.errstate(divide="ignore", invalid="ignore"):
            cv = np.nanstd(np.where(pos, tp, np.nan), axis=1) / np.nanmean(np.where(pos, tp, np.nan), axis=1)
        for t in CHECKPOINTS:
            x = t / T
            S = C[:, m, t]
            pred0, rem = [], []
            for j, k in enumerate(past):
                dk = int(np.floor(x * days[k] + 1e-9))
                ck = C[:, k, dk]
                rem.append(np.where(pos[:, j], tot[:, k] - ck, np.nan))
                with np.errstate(divide="ignore", invalid="ignore"):
                    pred0.append(np.where(pos[:, j] & (ck > 0), S * tot[:, k] / ck, np.nan))
            pred0, rem = np.array(pred0), np.array(rem)
            p0 = (np.nansum(pred0 > B, axis=0) + 0.5) / (np.sum(~np.isnan(pred0), axis=0) + 1)
            with np.errstate(invalid="ignore"):
                p1 = (np.nansum(S + rem > B, axis=0) + 0.5) / (K + 1)
            p1 = np.where(K >= MIN_K, p1, p0)               # application falls back to pro-rata
            nleft = T - t
            mu, v = MU[:, m, t - 1], V[:, m, t - 1]
            sd = np.sqrt(np.maximum(nleft * v, 1e-12))
            p2 = 1 - norm.cdf((B - S - nleft * mu) / sd)
            with np.errstate(divide="ignore", invalid="ignore"):
                rmed = np.nanmedian(np.where(np.isnan(rem), np.nan, rem), axis=0)
                cal = np.nanmean(rem / np.where(pos.T, tp.T, np.nan), axis=0)
            sel = np.nonzero(ok)[0]
            for key, val in [("user", np.arange(n)), ("month", np.full(n, m)), ("t", np.full(n, t)), ("x", np.full(n, x)),
                             ("S", S), ("B", B), ("tot", tot[:, m]), ("o", (tot[:, m] > B).astype(int)), ("cross", cross),
                             ("pattern", pattern), ("K", K), ("p0", p0), ("p1", p1), ("p2", p2), ("rmed", rmed),
                             ("nmu", nleft * mu), ("nsd", sd), ("cal", cal), ("cv", cv)]:
                rows[key].append(val[sel])
    R = {k: np.concatenate(v) for k, v in rows.items()}
    R["cv"] = np.nan_to_num(R["cv"], nan=0.0)
    R["cal"] = np.nan_to_num(R["cal"], nan=0.5)
    R["rmed"] = np.nan_to_num(R["rmed"], nan=0.0)
    return R


def m3_features(R):
    B = R["B"]
    return np.column_stack([R["x"], R["S"] / B, R["rmed"] / B, R["nmu"] / B, R["nsd"] / B, R["cal"], R["cv"]])


def fit_m3(R, rng, first_test):
    """Rolling-origin M3: refit every REFIT_EVERY months on a subsample of all earlier rows."""
    X = m3_features(R)
    z = (R["tot"] - R["S"]) / R["B"]
    p3 = np.full(len(z), np.nan)
    months = R["month"]
    for start in range(first_test, months.max() + 1, REFIT_EVERY):
        train = np.nonzero(months < start)[0]
        if len(train) > M3_ROWS:
            train = rng.choice(train, M3_ROWS, replace=False)
        mean, sd = X[train].mean(axis=0), X[train].std(axis=0) + 1e-12
        Xs = (X - mean) / sd
        target = np.nonzero((months >= start) & (months < start + REFIT_EVERY))[0]
        Q = np.zeros((len(target), len(TAUS)))
        for j, tau in enumerate(TAUS):
            qr = QuantileRegressor(quantile=tau, alpha=0.0, solver="highs").fit(Xs[train], z[train])
            Q[:, j] = qr.predict(Xs[target])
        Q.sort(axis=1)
        v = (R["B"][target] - R["S"][target]) / R["B"][target]
        F = np.array([np.interp(v[i], Q[i], TAUS, left=TAUS[0] / 2, right=1 - (1 - TAUS[-1]) / 2) for i in range(len(target))])
        p3[target] = 1 - F
        print(f"    M3 refit at month {start}: {len(train)} training rows, {len(target)} forecasts", flush=True)
    return p3


def ece(p, o, bins=10):
    order = np.argsort(p)
    total = 0.0
    for chunk in np.array_split(order, bins):
        total += len(chunk) / len(p) * abs(o[chunk].mean() - p[chunk].mean())
    return total


def reliability(p, o, bins=10):
    order = np.argsort(p)
    return [[float(p[c].mean()), float(o[c].mean())] for c in np.array_split(order, bins)]


def scores(p, o):
    pc = np.clip(p, 1e-3, 1 - 1e-3)
    return {"brier": float(np.mean((p - o) ** 2)),
            "logloss": float(-np.mean(o * np.log(pc) + (1 - o) * np.log(1 - pc))),
            "auc": float(roc_auc_score(o, p)), "ece": float(ece(p, o)), "n": int(len(p)),
            "base_rate": float(o.mean())}


def warning_curve(R, p, grid):
    """For each threshold: false-alarm rate, recall and median lead time over user-months."""
    key = R["user"] * 1000 + R["month"]
    uniq, inv = np.unique(key, return_inverse=True)
    o_m = np.zeros(len(uniq), dtype=int)
    cross_m = np.zeros(len(uniq))
    o_m[inv] = R["o"]
    cross_m[inv] = R["cross"]
    live = R["S"] <= R["B"]              # checkpoints before the overrun
    neg, pos = np.sum(o_m == 0), np.sum(o_m == 1)
    out = []
    for thr in grid:
        hit = live & (p >= thr)
        first = np.full(len(uniq), 999.0)
        np.minimum.at(first, inv[hit], R["t"][hit].astype(float))
        alerted = first < 999
        fa = np.sum(alerted & (o_m == 0))
        det = alerted & (o_m == 1)
        leads = cross_m[det] - first[det]
        out.append({"thr": float(thr), "far": float(fa / neg), "recall": float(det.sum() / pos),
                    "lead_median": float(np.median(leads)) if len(leads) else 0.0})
    return out


def at_far(curve, target):
    ok = [c for c in curve if c["far"] <= target + 1e-12]
    return max(ok, key=lambda c: c["recall"]) if ok else None


def run(Y, days, start, pattern, pattern_names, first_test, out_path, seed, extra=None):
    """Tune lambda on months < first_test (kappa = 1.0), then score months >= first_test for every kappa."""
    t0 = time.time()
    rng = np.random.default_rng(seed)
    best = None
    for lam in LAMBDAS:
        R = build_rows(Y, days, start, pattern, 1.0, lam)
        sel = (R["month"] < first_test) & (R["S"] <= R["B"])
        b = float(np.mean((R["p2"][sel] - R["o"][sel]) ** 2))
        print(f"lambda={lam} validation Brier={b:.4f} ({time.time() - t0:.0f}s)", flush=True)
        if best is None or b < best[1]:
            best = (lam, b)
    lam = best[0]
    result = {"lambda": lam, "validation_brier": best[1], "seed": seed, "users": int(len(pattern)),
              "months": int(Y.shape[1]), "first_test_month": int(first_test), "kappa": {}}
    if extra:
        result.update(extra)
    for kappa in KAPPAS:
        R = build_rows(Y, days, start, pattern, kappa, lam)
        R["p3"] = fit_m3(R, rng, first_test)
        test = (R["month"] >= first_test) & (R["S"] <= R["B"])
        res = {"overall": {}, "by_checkpoint": {}, "by_pattern": {},
               "user_months": int(len(np.unique(R["user"][R["month"] >= first_test] * 1000 + R["month"][R["month"] >= first_test]))),
               "users_scored": int(len(np.unique(R["user"][test]))),
               "m1_fallback_share": float(np.mean(R["K"][test] < MIN_K))}
        for mname in METHODS:
            res["overall"][mname] = scores(R[mname][test], R["o"][test])
            res["by_checkpoint"][mname] = {str(t): scores(R[mname][test & (R["t"] == t)], R["o"][test & (R["t"] == t)])["brier"] for t in CHECKPOINTS}
            res["by_pattern"][mname] = {name: scores(R[mname][test & (R["pattern"] == a)], R["o"][test & (R["pattern"] == a)])["brier"]
                                        for a, name in enumerate(pattern_names) if np.any(test & (R["pattern"] == a))}
        if kappa == 1.0:
            d15 = test & (R["t"] == 15)
            res["reliability_day15"] = {m: reliability(R[m][d15], R["o"][d15]) for m in METHODS}
            sub = R["month"] >= first_test
            Rt = {k: v[sub] for k, v in R.items()}
            grid = np.round(np.arange(0.02, 1.0, 0.02), 2)
            res["warning"] = {m: warning_curve(Rt, Rt[m], grid) for m in METHODS}
            res["at_far10"] = {m: at_far(res["warning"][m], 0.10) for m in METHODS}
        result["kappa"][str(kappa)] = res
        out_path.parent.mkdir(exist_ok=True)
        out_path.write_text(json.dumps(result, indent=1), encoding="utf-8")
        print(f"kappa={kappa} done and saved ({time.time() - t0:.0f}s)", flush=True)
        for mname in METHODS:
            o = res["overall"][mname]
            print(f"  {mname}: brier={o['brier']:.4f} logloss={o['logloss']:.4f} auc={o['auc']:.3f} ece={o['ece']:.4f} n={o['n']} base={o['base_rate']:.3f}", flush=True)
    print(f"saved {out_path.name} in {time.time() - t0:.0f}s", flush=True)
    return result
