"""Compare core.py's M1 with FlowMoney's nhip_chi.dart on the same cases (export_cases.py + dart_check/doi_chieu.dart).

Reports, for each time-of-day convention of the Dart run: whether K matches, how often r_med and the median
spent share agree to 1e-6 (relative), and whether the app's decision (projection S + r_med > B) agrees with
the decision taken from M1's probability (p1 > 0.5). Writes results/m1_compare.json.
"""
import json
import pathlib

import numpy as np

R = pathlib.Path(__file__).resolve().parent / "results"


def main():
    cases = json.loads((R / "m1_cases.json").read_text(encoding="utf-8"))["cases"]
    dart = json.loads((R / "m1_dart.json").read_text(encoding="utf-8"))
    py = {k: np.array([c["py"][k] for c in cases]) for k in ["K", "rmed", "share", "p1"]}
    S = np.array([c["S"] for c in cases])
    B = np.array([c["B"] for c in cases])
    py_vuot = S + py["rmed"] > B
    out = {"n": len(cases)}
    for conv in ["h00", "h12", "h2359"]:
        d = [r[conv] for r in dart]
        nulls = sum(v is None for v in d)
        K = np.array([v["K"] if v else -1 for v in d])
        rm = np.array([v["rmed"] if v else np.nan for v in d])
        sh = np.array([v["share"] if v else np.nan for v in d])
        vu = np.array([v["vuot"] if v else False for v in d])
        tol = 1e-6 * np.maximum(1.0, np.abs(py["rmed"]))
        rm_ok = np.abs(rm - py["rmed"]) <= tol
        sh_ok = np.abs(sh - py["share"]) <= 1e-6
        rel = np.abs(rm - py["rmed"]) / np.maximum(B, 1e-9)
        out[conv] = {
            "dart_null": int(nulls),
            "K_match": float(np.mean(K == py["K"])),
            "rmed_match": float(np.mean(rm_ok)),
            "share_match": float(np.mean(sh_ok)),
            "rmed_absdiff_over_B_median_when_differs": float(np.median(rel[~rm_ok])) if (~rm_ok).any() else 0.0,
            "decision_match_vs_python_point": float(np.mean(vu == py_vuot)),
            "decision_match_vs_p1_gt_half": float(np.mean(vu == (py["p1"] > 0.5))),
        }
    # Python's own point rule vs its probability rule (same numbers, no Dart involved)
    out["python_point_vs_p1_gt_half"] = float(np.mean(py_vuot == (py["p1"] > 0.5)))
    odd = py["K"] % 2 == 1
    out["python_point_vs_p1_gt_half_oddK"] = float(np.mean((py_vuot == (py["p1"] > 0.5))[odd]))
    out["python_point_vs_p1_gt_half_evenK"] = float(np.mean((py_vuot == (py["p1"] > 0.5))[~odd]))
    out["share_evenK"] = float(np.mean(~odd))
    (R / "m1_compare.json").write_text(json.dumps(out, indent=1), encoding="utf-8")
    print(json.dumps(out, indent=1))


if __name__ == "__main__":
    main()
