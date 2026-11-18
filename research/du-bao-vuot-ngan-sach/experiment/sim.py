"""Synthetic spending population (Section V-B of the paper).

Four spending patterns, n_per users each, over `months` calendar months starting January 2023:
  A1 steady daily spending
  A2 front-loaded: 30-45% of the month paid on day 1 (rent)
  A3 payday burst: 30% of discretionary spending on days 10-12
  A4 shock-prone: a large unplanned purchase in about 15% of months
Every user has a slowly drifting monthly level and month-to-month noise. Amounts are in million VND,
but every model works with ratios to the budget, so the unit does not matter.
"""
import calendar

import numpy as np

PATTERNS = ["A1", "A2", "A3", "A4"]


def simulate(n_per=500, months=36, seed=2026, start_year=2023):
    rng = np.random.default_rng(seed)
    month_list = [(start_year + k // 12, k % 12 + 1) for k in range(months)]
    days = np.array([calendar.monthrange(y, m)[1] for (y, m) in month_list])
    weekday0 = [calendar.weekday(y, m, 1) for (y, m) in month_list]  # 0 = Monday

    pattern = np.repeat(np.arange(4), n_per)
    n = len(pattern)
    level0 = rng.lognormal(np.log(10.0), 0.4, n)
    walk = np.cumsum(rng.normal(0.0, 0.03, (n, months)), axis=1)
    month_noise = np.exp(rng.normal(0.0, 0.12, (n, months)))
    front = rng.uniform(0.30, 0.45, n)

    Y = np.zeros((n, months, 31))
    for m in range(months):
        T = days[m]
        wd = (weekday0[m] + np.arange(T)) % 7
        weekend = np.where(wd >= 5, 1.25, 1.0)
        weekend = weekend / weekend.mean()
        level = level0 * np.exp(walk[:, m]) * month_noise[:, m]
        fixed = np.where(pattern == 1, front * level, 0.0)
        rest = level - fixed
        burst = np.where(pattern == 2, 0.30 * rest, 0.0)
        rest = rest - burst
        daily = (rest / T)[:, None] * weekend[None, :] * rng.gamma(2.0, 0.5, (n, T))
        daily[:, 0] += fixed
        daily[:, 9:12] += (burst / 3.0)[:, None] * rng.gamma(4.0, 0.25, (n, 3))
        shock = (pattern == 3) & (rng.random(n) < 0.15)
        shock_day = rng.integers(0, T, n)
        shock_size = level * rng.lognormal(np.log(0.4), 0.3, n)
        idx = np.nonzero(shock)[0]
        daily[idx, shock_day[idx]] += shock_size[idx]
        Y[:, m, :T] = daily
    return Y, days, pattern
