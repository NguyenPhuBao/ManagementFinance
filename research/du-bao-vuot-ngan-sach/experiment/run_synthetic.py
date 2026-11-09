"""Preliminary experiment on the synthetic population: M0-M3, rolling-origin evaluation, metrics.

Run:  python run_synthetic.py            (writes results/synthetic.json)
Simplifications for this preliminary run, stated in the paper: M3 is refitted every 6 months on a random
subsample of earlier rows; M2 uses the Gaussian form only.
"""
import json
import pathlib
import time

import numpy as np
from scipy.stats import norm
from sklearn.linear_model import QuantileRegressor
from sklearn.metrics import roc_auc_score

from sim import PATTERNS, simulate

HERE = pathlib.Path(__file__).resolve().parent
OUT = HERE / "results"
CHECKPOINTS = [5, 10, 15, 20, 25]
KAPPAS = [1.0, 0.9, 1.1]  # 1.0 first: the figures need only it, and results are saved after each kappa
TAUS = np.round(np.arange(0.05, 0.951, 0.05), 2)
LAMBDAS = [0.02, 0.05, 0.1, 0.2]
FIRST_EVAL, FIRST_TEST = 6, 12      # months 6-11 tune lambda, months 12-35 are reported
REFIT_EVERY, M3_ROWS = 6, 4000  # highs time grows faster than linearly: 4,000 rows ~0.6 s/fit, 15,000 ~8 s/fit
SEED = 2026


def ewma_states(Y, days, lam):
    """mu, v after each day, laid out as [user, month, day-index] (day-index t-1 = after day t)."""
    n, months, _ = Y.shape
    flat = np.concatenate([Y[:, m, :days[m]] for m in range(months)], axis=1)
    mu = flat[:, :30].mean(axis=1)
    v = flat[:, :30].var(axis=1)
    MU = np.zeros_like(flat)
    V = np.zeros_like(flat)
    MU[:, :30] = mu[:, None]
    V[:, :30] = v[:, None]
    for d in range(30, flat.shape[1]):
        y = flat[:, d]
        v = lam * (y - mu) ** 2 + (1 - lam) * v
        mu = lam * y + (1 - lam) * mu
        MU[:, d] = mu
        V[:, d] = v
    out_mu = np.zeros((n, months, 31))
    out_v = np.zeros((n, months, 31))
    off = 0
    for m in range(months):
        out_mu[:, m, :days[m]] = MU[:, off:off + days[m]]
        out_v[:, m, :days[m]] = V[:, off:off + days[m]]
        off += days[m]
    return out_mu, out_v


def build_rows(Y, days, pattern, kappa, lam):
    """One row per (user, month >= FIRST_EVAL, checkpoint) with every quantity the forecasters need."""
    n, months, _ = Y.shape
    C = np.concatenate([np.zeros((n, months, 1)), np.cumsum(Y, axis=2)], axis=2)  # C[..., d] = spent after day d
    tot = np.array([C[:, m, days[m]] for m in range(months)]).T
    MU, V = ewma_states(Y, days, lam)
    rows = {k: [] for k in ["user", "month", "t", "x", "S", "B", "tot", "o", "cross", "pattern",
                            "p0", "p1", "p2", "rmed", "nmu", "nsd", "cal", "cv"]}
    for m in range(FIRST_EVAL, months):
        T = days[m]
        B = kappa * tot[:, m - 3:m].mean(axis=1)
        past = list(range(m - 6, m))
        K = len(past)
        cross = np.full(n, 999)
        over = C[:, m, 1:T + 1] > B[:, None]
        has = over.any(axis=1)
        cross[has] = over[has].argmax(axis=1) + 1
        for t in CHECKPOINTS:
            x = t / T
            S = C[:, m, t]
            pred0, rem = [], []
            for k in past:
                dk = int(np.floor(x * days[k] + 1e-9))
                ck = C[:, k, dk]
                rem.append(tot[:, k] - ck)
                with np.errstate(divide="ignore", invalid="ignore"):
                    pred0.append(np.where(ck > 0, S * tot[:, k] / ck, np.nan))
            pred0 = np.array(pred0)
            rem = np.array(rem)
            p0 = (np.nansum(pred0 > B, axis=0) + 0.5) / (np.sum(~np.isnan(pred0), axis=0) + 1)
            p1 = (np.sum(S + rem > B, axis=0) + 0.5) / (K + 1)
            nleft = T - t
            mu, v = MU[:, m, t - 1], V[:, m, t - 1]
            sd = np.sqrt(np.maximum(nleft * v, 1e-12))
            p2 = 1 - norm.cdf((B - S - nleft * mu) / sd)
            pt = tot[:, past]
            cal = np.mean(rem / np.maximum(pt.T, 1e-12), axis=0)
            cv = pt.std(axis=1) / pt.mean(axis=1)
            for key, val in [("user", np.arange(n)), ("month", np.full(n, m)), ("t", np.full(n, t)), ("x", np.full(n, x)),
                             ("S", S), ("B", B), ("tot", tot[:, m]), ("o", (tot[:, m] > B).astype(int)), ("cross", cross),
                             ("pattern", pattern), ("p0", p0), ("p1", p1), ("p2", p2), ("rmed", np.median(rem, axis=0)),
                             ("nmu", nleft * mu), ("nsd", sd), ("cal", cal), ("cv", cv)]:
                rows[key].append(val)
    return {k: np.concatenate(v) for k, v in rows.items()}


def m3_features(R):
    B = R["B"]
    return np.column_stack([R["x"], R["S"] / B, R["rmed"] / B, R["nmu"] / B, R["nsd"] / B, R["cal"], R["cv"]])


def fit_m3(R, rng):
    """Rolling-origin M3: refit every REFIT_EVERY months on a subsample of all earlier rows."""
    X = m3_features(R)
    z = (R["tot"] - R["S"]) / R["B"]
    p3 = np.full(len(z), np.nan)
    months = R["month"]
    for start in range(FIRST_TEST, months.max() + 1, REFIT_EVERY):
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
    key = R["user"] * 100 + R["month"]
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


def main():
    t0 = time.time()
    rng = np.random.default_rng(SEED)
    Y, days, pattern = simulate(seed=SEED)
    # tune lambda for M2 on validation months, kappa = 1.0
    best = None
    for lam in LAMBDAS:
        R = build_rows(Y, days, pattern, 1.0, lam)
        sel = (R["month"] < FIRST_TEST) & (R["S"] <= R["B"])
        b = float(np.mean((R["p2"][sel] - R["o"][sel]) ** 2))
        print(f"lambda={lam} validation Brier={b:.4f}")
        if best is None or b < best[1]:
            best = (lam, b)
    lam = best[0]
    result = {"lambda": lam, "seed": SEED, "users": int(len(pattern)), "months": int(Y.shape[1]),
              "test_months": f"{FIRST_TEST}-{Y.shape[1] - 1}", "kappa": {}}
    for kappa in KAPPAS:
        R = build_rows(Y, days, pattern, kappa, lam)
        R["p3"] = fit_m3(R, rng)
        test = (R["month"] >= FIRST_TEST) & (R["S"] <= R["B"])
        res = {"overall": {}, "by_checkpoint": {}, "by_pattern": {}}
        for mname in ["p0", "p1", "p2", "p3"]:
            res["overall"][mname] = scores(R[mname][test], R["o"][test])
            res["by_checkpoint"][mname] = {str(t): scores(R[mname][test & (R["t"] == t)], R["o"][test & (R["t"] == t)])["brier"] for t in CHECKPOINTS}
            res["by_pattern"][mname] = {PATTERNS[a]: scores(R[mname][test & (R["pattern"] == a)], R["o"][test & (R["pattern"] == a)])["brier"] for a in range(4)}
        if kappa == 1.0:
            d15 = test & (R["t"] == 15)
            res["reliability_day15"] = {m: reliability(R[m][d15], R["o"][d15]) for m in ["p0", "p1", "p2", "p3"]}
            sub = R["month"] >= FIRST_TEST
            Rt = {k: v[sub] for k, v in R.items()}
            grid = np.round(np.arange(0.02, 1.0, 0.02), 2)
            res["warning"] = {m: warning_curve(Rt, Rt[m], grid) for m in ["p0", "p1", "p2", "p3"]}
            res["at_far10"] = {m: at_far(res["warning"][m], 0.10) for m in ["p0", "p1", "p2", "p3"]}
        result["kappa"][str(kappa)] = res
        OUT.mkdir(exist_ok=True)
        (OUT / "synthetic.json").write_text(json.dumps(result, indent=1), encoding="utf-8")
        print(f"kappa={kappa} done and saved ({time.time() - t0:.0f}s)")
        for mname in ["p0", "p1", "p2", "p3"]:
            o = res["overall"][mname]
            print(f"  {mname}: brier={o['brier']:.4f} logloss={o['logloss']:.4f} auc={o['auc']:.3f} ece={o['ece']:.4f} n={o['n']} base={o['base_rate']:.3f}")
    OUT.mkdir(exist_ok=True)
    (OUT / "synthetic.json").write_text(json.dumps(result, indent=1), encoding="utf-8")
    print(f"saved results/synthetic.json in {time.time() - t0:.0f}s")


if __name__ == "__main__":
    main()
