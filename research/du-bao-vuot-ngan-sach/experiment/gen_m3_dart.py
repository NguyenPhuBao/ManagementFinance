"""Write results/m3_coef_vn.json (app_m23.py) as Dart constants for the app's trial build.

Run:  python -u gen_m3_dart.py   -> src/Client-app/lib/features/budget/domain/he_so_m3_vn.g.dart
"""
import json
import pathlib

HERE = pathlib.Path(__file__).resolve().parent
OUT = HERE.parents[2] / "src" / "Client-app" / "lib" / "features" / "budget" / "domain" / "he_so_m3_vn.g.dart"


def num(v):
    return repr(float(v))


if __name__ == "__main__":
    f = json.loads((HERE / "results" / "m3_coef_vn.json").read_text(encoding="utf-8"))
    lines = [
        "// SINH RA bởi research/du-bao-vuot-ngan-sach/experiment/gen_m3_dart.py — đừng sửa tay.",
        "// Hệ số M3 (hồi quy phân vị tuyến tính gộp) khớp MỘT lần trên TabFormer-VN:",
        f"// λ = {f['lambda']}, tháng < {f['first_test_month']}, {f['train_rows']} / {f['train_rows_available']} dòng, seed {f['seed']}.",
        "// Bản thử NCKH (nhánh TranQuangDat), không phát hành.",
        "",
        f"const double kLambdaM2 = {num(f['lambda'])};",
        "",
        "/// Đặc trưng: " + ", ".join(f["features"]) + ".",
        "const List<double> kM3TrungBinh = [" + ", ".join(num(v) for v in f["mean"]) + "];",
        "const List<double> kM3DoLech = [" + ", ".join(num(v) for v in f["sd"]) + "];",
        "const List<double> kM3PhanVi = [" + ", ".join(num(v) for v in f["taus"]) + "];",
        "",
        "/// Mỗi dòng một phân vị: [hệ số chặn, 7 hệ số].",
        "const List<List<double>> kM3HeSo = [",
    ]
    for row in f["coef"]:
        lines.append("  [" + ", ".join(num(v) for v in row) + "],")
    lines.append("];")
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print(f"wrote {OUT}")
